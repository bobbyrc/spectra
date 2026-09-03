import 'package:meta/meta.dart';

/// A one-shot cancellation signal handed to a dispatched command.
///
/// Cancelling is idempotent: listeners run once, on the first [cancel], and a
/// listener registered after cancellation runs immediately. [onCancel] returns
/// a disposer so a long-lived token (one per user-visible operation, reused
/// across many commands) does not retain a closure per command.
final class CancelToken {
  bool _cancelled = false;
  final List<void Function()> _listeners = [];

  bool get isCancelled => _cancelled;

  /// Listeners still registered. Exposed so tests can prove the dispatcher
  /// releases its registrations.
  @visibleForTesting
  int get listenerCount => _listeners.length;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final l in List.of(_listeners)) {
      l();
    }
    _listeners.clear();
  }

  /// Registers [f] and returns a disposer that unregisters it. Calling the
  /// disposer more than once, or after [cancel], is harmless.
  void Function() onCancel(void Function() f) {
    if (_cancelled) {
      f();
      return () {};
    }
    _listeners.add(f);
    return () => _listeners.remove(f);
  }
}
