import 'package:chameleon/chameleon.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'active_device.dart';

part 'session_streams.g.dart';

/// Republishes one of the session's [StateStream]s: its current value first,
/// then every change. Returns [whenNone] while nothing is connected, so a
/// screen never has to special-case "no session" twice.
Stream<T> _sessionStream<T>(
  Ref ref,
  StateStream<T> Function(DeviceSession session) select,
  T whenNone,
) {
  final active = ref.watch(activeSessionProvider);
  if (active == null) return Stream<T>.value(whenNone);
  return select(active.session).values;
}

/// The one piece of session state routing needs synchronously (spec 7.2), so
/// it is a notifier seeded from the stream's current value rather than an
/// `AsyncValue`.
@Riverpod(keepAlive: true)
class ConnectionStatus extends _$ConnectionStatus {
  @override
  ConnectionState build() {
    final active = ref.watch(activeSessionProvider);
    if (active == null) {
      return const SessionDisconnected(DisconnectCause.requested);
    }
    final sub = active.session.connectionState.changes.listen((s) {
      state = s;
    });
    ref.onDispose(sub.cancel);
    return active.session.connectionState.value;
  }
}

@riverpod
Stream<DeviceInfo?> deviceInfo(Ref ref) =>
    _sessionStream(ref, (s) => s.deviceInfo, null);

@riverpod
Stream<BatteryInfo?> battery(Ref ref) =>
    _sessionStream(ref, (s) => s.battery, null);

@riverpod
Stream<List<Slot>> slots(Ref ref) =>
    _sessionStream(ref, (s) => s.slotsState, const <Slot>[]);

@riverpod
Stream<int?> activeSlot(Ref ref) =>
    _sessionStream(ref, (s) => s.activeSlot, null);

@riverpod
Stream<DeviceMode?> mode(Ref ref) => _sessionStream(ref, (s) => s.mode, null);

@riverpod
Stream<DeviceSettings?> settings(Ref ref) =>
    _sessionStream(ref, (s) => s.settingsState, null);
