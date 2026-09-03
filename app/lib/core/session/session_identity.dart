import 'package:chameleon/chameleon.dart';

/// Spec 4.2: identity is the chip id, and it is only known after a
/// handshake. A session that never became ready — pre-2.0 firmware, a device
/// in the bootloader — still has to be registered somewhere, so it gets an
/// identity derived from its transport. Stable for that transport, and
/// impossible to confuse with a chip id because of the prefix.
DeviceIdentity fallbackIdentity(DiscoveredDevice device) =>
    DeviceIdentity('transport:${device.kind.name}:${device.transportId}');

/// The chip id if the handshake got far enough to read one, the fallback
/// otherwise. Never throws: a device that will not answer 1011 is still a
/// device the app has to show.
Future<DeviceIdentity> resolveIdentity(
  DeviceSession session,
  DiscoveredDevice device,
) async {
  if (session.isReady) {
    final cached = session.deviceInfo.value?.identity;
    if (cached != null) return cached;
    try {
      return await session.device.readIdentity();
    } on ChameleonException {
      // Fall through: an identity is a nicety, a session is not.
    }
  }
  return fallbackIdentity(device);
}
