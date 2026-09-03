import 'package:chameleon/chameleon.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'active_session.dart';
import 'sessions.dart';

part 'active_device.g.dart';

/// Names the one session the UI is showing (spec 7.1). Features read
/// [activeSessionProvider] and never reach into [sessionsProvider].
@Riverpod(keepAlive: true)
class ActiveDevice extends _$ActiveDevice {
  @override
  DeviceIdentity? build() => null;

  void select(DeviceIdentity? identity) => state = identity;
}

@Riverpod(keepAlive: true)
ActiveSession? activeSession(Ref ref) {
  final identity = ref.watch(activeDeviceProvider);
  if (identity == null) return null;
  return ref.watch(deviceSessionProvider(identity));
}
