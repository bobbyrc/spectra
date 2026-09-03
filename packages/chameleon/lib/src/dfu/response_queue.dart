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
        for (final w in _waiters) {
          w.completeError(StateError('DFU response stream closed'));
        }
        _waiters.clear();
        _done = true;
      },
    );
  }

  late final StreamSubscription<T> _sub;
  final List<T> _buffer = [];
  final List<Object> _errors = [];
  final List<Completer<T>> _waiters = [];
  bool _done = false;

  Future<T> get next {
    if (_buffer.isNotEmpty) return Future.value(_buffer.removeAt(0));
    if (_errors.isNotEmpty) return Future.error(_errors.removeAt(0));
    if (_done) return Future.error(StateError('DFU response stream closed'));
    final c = Completer<T>();
    _waiters.add(c);
    return c.future;
  }

  Future<void> cancel() => _sub.cancel();
}
