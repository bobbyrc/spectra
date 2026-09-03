import 'package:chameleon/chameleon.dart';

/// One live connection plus the two things the UI needs to name it: the
/// identity it is registered under and the discovery entry it came from.
final class ActiveSession {
  const ActiveSession({
    required this.identity,
    required this.device,
    required this.session,
  });

  final DeviceIdentity identity;
  final DiscoveredDevice device;
  final DeviceSession session;
}
