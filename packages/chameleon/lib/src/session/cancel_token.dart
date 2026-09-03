/// A one-shot cancellation signal handed to a dispatched command.
///
/// Cancelling is idempotent: listeners run once, on the first [cancel], and a
/// listener registered after cancellation runs immediately.
final class CancelToken {
  bool _cancelled = false;
  final List<void Function()> _listeners = [];

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final l in List.of(_listeners)) {
      l();
    }
    _listeners.clear();
  }

  void onCancel(void Function() f) {
    if (_cancelled) {
      f();
    } else {
      _listeners.add(f);
    }
  }
}
