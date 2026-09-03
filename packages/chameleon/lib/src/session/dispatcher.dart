import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import '../codec/frame.dart';
import '../codec/frame_decoder.dart';
import '../protocol/errors.dart';
import '../transport/frame_log.dart';
import '../transport/transport.dart';
import 'cancel_token.dart';

/// One queued command: its request, deadline, cancellation hook and the
/// generation token it was dispatched under.
final class _Pending {
  _Pending(this.request, this.timeout, this.expectsResponse, this.cancel);
  final Frame request;
  final Duration timeout;
  final bool expectsResponse;
  final CancelToken? cancel;
  final Completer<Frame?> completer = Completer();
  Timer? timer;

  /// Releases this command's [CancelToken] registration, so a long-lived
  /// token does not accumulate a closure per command.
  void Function()? releaseCancel;

  /// Assigned when the request actually goes on the wire, not when it is
  /// queued: only the newest dispatch may claim a response.
  ///
  /// With one command in flight at a time this is an invariant assertion
  /// rather than a matching mechanism — the in-flight command's generation
  /// is always the newest — and it is kept for exactly that reason: it turns
  /// a future regression in the queueing into a dropped frame rather than a
  /// response handed to the wrong caller.
  int generation = 0;

  void fail(Object error, [StackTrace? stackTrace]) {
    _settle();
    if (!completer.isCompleted) {
      if (stackTrace == null) {
        completer.completeError(error);
      } else {
        completer.completeError(error, stackTrace);
      }
    }
  }

  void succeed(Frame? f) {
    _settle();
    if (!completer.isCompleted) completer.complete(f);
  }

  void _settle() {
    timer?.cancel();
    timer = null;
    releaseCancel?.call();
    releaseCancel = null;
  }
}

/// The command id of a command abandoned (cancelled or timed out) while in
/// flight, plus the timer that bounds how long we wait for its stray
/// response. That response, if it still arrives, is consumed and dropped
/// rather than matched to a fresh command with the same id.
final class _Drain {
  _Drain(this.commandId);
  final int commandId;
  Timer? timer;
}

/// One command in flight, responses matched by command id plus a per-dispatch
/// generation token, with timeouts, cancellation and draining (spec 4.3).
///
/// A response is accepted only when its command id matches the in-flight
/// request *and* that request's generation is still the newest dispatched
/// one. A response for an abandoned generation (cancelled, or timed out) is
/// consumed silently to end the drain and is never surfaced: the caller has
/// already been given an error and no longer wants the payload. Only a frame
/// that matches nothing in flight or draining reaches [unexpectedFrames].
final class CommandDispatcher {
  CommandDispatcher(
    this._transport, {
    FrameLog? log,
    this.drainWindow = const Duration(milliseconds: 500),
    void Function(DecodeDiagnostic)? onDiagnostic,
  }) : // A named parameter cannot be private, so `this._log` is not an option.
       // ignore: prefer_initializing_formals
       _log = log,
       _decoder = FrameDecoder(onDiagnostic: onDiagnostic) {
    _closed = _transport.currentState is TransportClosed;
    // A conforming transport never puts an error on `incoming` (see the
    // contract on [Transport]); this guard is defensive. Without it the
    // error would be an uncaught async error and every pending command
    // would hang until its timeout, with the session still believing the
    // link is up. Treated exactly like a TransportClosed state.
    _incomingSub = _transport.incoming.listen(
      _onBytes,
      onError: (Object e) {
        _closed = true;
        _failAll(
          e is ChameleonException
              ? e
              : Disconnected('the transport stream failed: $e'),
        );
      },
    );
    _stateSub = _transport.state.listen(_onState);
  }

  final Transport _transport;

  /// How long dispatch is blocked waiting for the stray response to a command
  /// that was abandoned (timed out or cancelled).
  ///
  /// Deliberately much shorter than a command timeout: a device that dropped
  /// one response would otherwise stall every later command for a full
  /// timeout. A response arriving after the window has closed is no longer
  /// recognised as stale — it reaches [unexpectedFrames], or, if a command
  /// with the same id is in flight by then, is matched to it. The window is a
  /// bound on how long staleness is tracked, not a guarantee.
  final Duration drainWindow;

  final FrameLog? _log;
  final FrameDecoder _decoder;
  late final StreamSubscription<Uint8List> _incomingSub;
  late final StreamSubscription<TransportState> _stateSub;
  final Queue<_Pending> _queue = Queue();
  final StreamController<Frame> _unexpected = StreamController.broadcast();
  _Pending? _inFlight;
  _Drain? _draining;
  int _generation = 0;

  /// The transport is unusable: not open yet, or closed. Cleared if the
  /// transport opens again.
  bool _closed = false;

  /// [dispose] was called; permanent, unlike [_closed].
  bool _disposed = false;

  bool get isIdle => _inFlight == null && _draining == null && _queue.isEmpty;

  /// Frames that matched no in-flight or draining command: asynchronous
  /// notifications, or responses the dispatcher cannot account for.
  Stream<Frame> get unexpectedFrames => _unexpected.stream;

  Future<Frame?> send(
    Frame request, {
    required Duration timeout,
    bool expectsResponse = true,
    CancelToken? cancel,
  }) {
    if (_disposed) {
      return Future.error(const Disconnected('dispatcher disposed'));
    }
    if (_closed) {
      // The transport, not the cached flag, is the authority: a dispatcher
      // built before `open()` is still marked closed for one event turn
      // after the transport has actually opened.
      if (_transport.currentState is! TransportOpen) {
        return Future.error(const Disconnected());
      }
      _closed = false;
    }
    final p = _Pending(request, timeout, expectsResponse, cancel);
    _queue.addLast(p);
    p.releaseCancel = cancel?.onCancel(() => _cancel(p));
    _pump();
    return p.completer.future;
  }

  /// Fails everything outstanding, closes the streams this dispatcher owns
  /// and drops its transport subscriptions. Later sends fail immediately.
  Future<void> dispose() async {
    _disposed = true;
    _closed = true;
    _failAll(const Disconnected('dispatcher disposed'));
    await _incomingSub.cancel();
    await _stateSub.cancel();
    if (!_unexpected.isClosed) await _unexpected.close();
  }

  void _pump() {
    if (_inFlight != null || _draining != null) return;
    while (_queue.isNotEmpty) {
      final p = _queue.removeFirst();
      if (p.cancel?.isCancelled ?? false) {
        p.fail(const CommandCancelled());
        continue;
      }
      _inFlight = p;
      p.generation = ++_generation;
      _log?.add(FrameDirection.sent, p.request);
      // The deadline covers the write too: a transport whose write never
      // completes (a stalled BLE write that reports no state change) must not
      // wedge the dispatcher forever.
      p.timer = Timer(p.timeout, () => _timeout(p));
      unawaited(
        _transport
            .write(p.request.encode())
            .then(
              (_) {
                // The timeout may have fired while the write was outstanding.
                if (_inFlight != p) return;
                if (!p.expectsResponse) {
                  _inFlight = null;
                  p.succeed(null);
                  _pump();
                }
              },
              onError: (Object e, StackTrace st) {
                if (_inFlight != p) return;
                _inFlight = null;
                p.fail(e, st);
                _pump();
              },
            ),
      );
      return;
    }
  }

  void _timeout(_Pending p) {
    if (_inFlight != p) return;
    _inFlight = null;
    _startDrain(p);
    p.fail(CommandTimeout(p.request.command, p.timeout));
  }

  void _cancel(_Pending p) {
    if (_inFlight == p) {
      _inFlight = null;
      _startDrain(p);
      p.fail(const CommandCancelled());
      return;
    }
    if (_queue.remove(p)) {
      p.fail(const CommandCancelled());
    }
  }

  /// Abandons [p]'s generation and blocks dispatch until its response arrives
  /// or [drainWindow] elapses.
  void _startDrain(_Pending p) {
    final d = _Drain(p.request.command);
    _draining = d;
    d.timer = Timer(drainWindow, () => _endDrain(d));
  }

  void _endDrain(_Drain d) {
    if (_draining != d) return;
    d.timer?.cancel();
    _draining = null;
    _pump();
  }

  void _onBytes(Uint8List chunk) {
    for (final frame in _decoder.feed(chunk)) {
      _log?.add(FrameDirection.received, frame);
      final p = _inFlight;
      // The generation check asserts the one-in-flight invariant: only the
      // newest dispatch may claim a response. Discarding stale responses is
      // the drain's job, below.
      if (p != null &&
          p.generation == _generation &&
          frame.command == p.request.command) {
        _inFlight = null;
        p.succeed(frame);
        _pump();
        continue;
      }
      final d = _draining;
      if (d != null && frame.command == d.commandId) {
        _endDrain(d);
        continue;
      }
      _unexpected.add(frame);
    }
  }

  void _onState(TransportState s) {
    if (s is TransportOpen) {
      if (!_disposed) _closed = false;
      return;
    }
    if (s is TransportClosed) {
      // A close the transport has already moved past: the event was queued
      // before a reopen and delivered after it. Failing on it would kill
      // commands queued against the live link.
      if (_transport.currentState is TransportOpen) return;
      _closed = true;
      _failAll(
        Disconnected(s.error?.message ?? 'transport closed (${s.cause.name})'),
      );
    }
  }

  void _failAll(ChameleonException error) {
    _draining?.timer?.cancel();
    _draining = null;
    final inFlight = _inFlight;
    _inFlight = null;
    inFlight?.fail(error);
    while (_queue.isNotEmpty) {
      _queue.removeFirst().fail(error);
    }
  }
}
