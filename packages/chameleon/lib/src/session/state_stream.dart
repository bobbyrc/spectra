import 'dart:async';

/// A current value plus a broadcast stream of changes.
///
/// The current value survives [close]: a caller that reads [value] after the
/// session shut down still sees the last state, it just stops being notified.
/// [set] and [setIfChanged] are no-ops once closed, so the last value a
/// listener saw is also the last value a late reader sees.
final class StateStream<T> {
  StateStream(this._value);

  T _value;
  final StreamController<T> _changes = StreamController.broadcast();

  T get value => _value;

  /// Every change after the moment of subscription.
  Stream<T> get changes => _changes.stream;

  /// The current value first, then every change.
  Stream<T> get values {
    late StreamController<T> out;
    StreamSubscription<T>? sub;
    out = StreamController<T>(
      onListen: () {
        out.add(_value);
        sub = _changes.stream.listen(out.add, onDone: out.close);
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  void set(T v) {
    if (_changes.isClosed) return;
    _value = v;
    _changes.add(v);
  }

  /// [set], but silent when the value has not changed. The idle poll uses
  /// this so re-reading unchanged device state wakes no listener.
  void setIfChanged(T v) {
    if (v == _value) return;
    set(v);
  }

  Future<void> close() => _changes.close();
}
