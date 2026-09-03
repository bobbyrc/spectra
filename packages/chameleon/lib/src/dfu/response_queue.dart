import 'dart:async';

/// A small pull-based queue over a stream, so a request/response state machine
/// can `await` the next event.
///
/// Internal to the DFU stack; avoids a dependency on package:async purely for
/// `StreamQueue`.
final class ResponseQueue<T> {
  ResponseQueue(Stream<T> stream) {
    _sub = stream.listen(
      (e) {
        // An event arriving after its request timed out belongs to that
        // request, not to the next one: drop it rather than answering the
        // next request with a stale reply.
        if (_abandoned > 0) {
          _abandoned--;
          return;
        }
        final w = _waiters.isEmpty ? null : _waiters.removeAt(0);
        if (w != null) {
          w.complete(e);
        } else {
          _buffer.add(e);
        }
      },
      onError: (Object e) {
        final w = _waiters.isEmpty ? null : _waiters.removeAt(0);
        if (w != null) {
          w.completeError(e);
        } else {
          _errors.add(e);
        }
      },
      onDone: () {
        _done = true;
        for (final w in _waiters) {
          w.completeError(StateError('DFU response stream closed'));
        }
        _waiters.clear();
      },
    );
  }

  late final StreamSubscription<T> _sub;
  final List<T> _buffer = [];
  final List<Object> _errors = [];
  final List<Completer<T>> _waiters = [];
  bool _done = false;

  /// Requests whose waiter timed out and whose reply is still in flight.
  int _abandoned = 0;

  Future<T> get next => nextWithin(null);

  /// The next event, or a [TimeoutException] after [timeout].
  ///
  /// A timed-out waiter is discarded, so a late reply is swallowed instead of
  /// completing the request that follows it.
  Future<T> nextWithin(Duration? timeout) {
    if (_buffer.isNotEmpty) return Future.value(_buffer.removeAt(0));
    if (_errors.isNotEmpty) return Future.error(_errors.removeAt(0));
    if (_done) return Future.error(StateError('DFU response stream closed'));
    final c = Completer<T>();
    _waiters.add(c);
    if (timeout == null) return c.future;
    final timer = Timer(timeout, () {
      if (!_waiters.remove(c)) return;
      _abandoned++;
      c.completeError(TimeoutException('no DFU response', timeout));
    });
    return c.future.whenComplete(timer.cancel);
  }

  /// Stops listening.
  ///
  /// The returned future completes immediately; the subscription's own
  /// `cancel()` is started and deliberately not awaited. On a broadcast
  /// stream — which is what every [DfuChannel.responses] is — that future
  /// never completes under a fake clock, so awaiting it hangs any Flutter
  /// widget test that runs a transfer (the same reason `DeviceSession` and
  /// `CommandDispatcher` stopped awaiting theirs).
  Future<void> cancel() async => unawaited(_sub.cancel());
}
