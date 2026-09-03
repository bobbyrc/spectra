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

  /// Assigned when the request actually goes on the wire, not when it is
  /// queued: only the newest dispatch may claim a response.
  int generation = 0;

  void fail(Object error) {
    timer?.cancel();
    timer = null;
    if (!completer.isCompleted) completer.completeError(error);
  }

  void succeed(Frame? f) {
    timer?.cancel();
    timer = null;
    if (!completer.isCompleted) completer.complete(f);
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
    void Function(DecodeDiagnostic)? onDiagnostic,
  }) : // A named parameter cannot be private, so `this._log` is not an option.
       // ignore: prefer_initializing_formals
       _log = log,
       _decoder = FrameDecoder(onDiagnostic: onDiagnostic) {
    _incomingSub = _transport.incoming.listen(_onBytes);
    _stateSub = _transport.state.listen(_onState);
  }

  final Transport _transport;
  final FrameLog? _log;
  final FrameDecoder _decoder;
  late final StreamSubscription<Uint8List> _incomingSub;
  late final StreamSubscription<TransportState> _stateSub;
  final Queue<_Pending> _queue = Queue();
  final StreamController<Frame> _unexpected = StreamController.broadcast();
  _Pending? _inFlight;
  _Drain? _draining;
  int _generation = 0;
  bool _closed = false;

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
    if (_closed) return Future.error(const Disconnected());
    final p = _Pending(request, timeout, expectsResponse, cancel);
    _queue.addLast(p);
    cancel?.onCancel(() => _cancel(p));
    _pump();
    return p.completer.future;
  }

  /// Fails everything outstanding, closes the streams this dispatcher owns
  /// and drops its transport subscriptions. Later sends fail immediately.
  Future<void> dispose() async {
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
      unawaited(
        _transport
            .write(p.request.encode())
            .then(
              (_) {
                if (_inFlight != p) return;
                if (!p.expectsResponse) {
                  _inFlight = null;
                  p.succeed(null);
                  _pump();
                  return;
                }
                p.timer = Timer(p.timeout, () => _timeout(p));
              },
              onError: (Object e) {
                if (_inFlight == p) _inFlight = null;
                p.fail(
                  e is ChameleonException ? e : Disconnected(e.toString()),
                );
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
  /// or one more timeout elapses.
  void _startDrain(_Pending p) {
    final d = _Drain(p.request.command);
    _draining = d;
    d.timer = Timer(p.timeout, () => _endDrain(d));
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
    if (s is TransportClosed) {
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
