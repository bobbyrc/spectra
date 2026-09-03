import 'package:chameleon/chameleon.dart';

/// One transport a known device has been seen on.
final class KnownTransport {
  const KnownTransport({required this.kind, required this.transportId});

  final TransportKind kind;
  final String transportId;
}

/// A device the app has connected to before (spec 4.2), independent of
/// which transport it is seen on next time.
final class KnownDevice {
  const KnownDevice({
    required this.identity,
    required this.displayName,
    required this.transports,
    required this.lastSeen,
  });

  final DeviceIdentity identity;
  final String displayName;
  final List<KnownTransport> transports;
  final DateTime lastSeen;

  /// True when a transport this device was last seen on matches [device]'s
  /// kind and transport id — used to recognise a freshly scanned device as
  /// one already known.
  bool matches(DiscoveredDevice device) => transports.any(
    (t) => t.kind == device.kind && t.transportId == device.transportId,
  );
}
