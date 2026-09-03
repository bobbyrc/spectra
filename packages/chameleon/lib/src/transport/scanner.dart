import 'transport.dart';

final class DiscoveredDevice {
  const DiscoveredDevice({
    required this.name,
    required this.kind,
    required this.transportId,
    this.isBootloader = false,
  });

  final String name;
  final TransportKind kind;

  /// Transport-specific identifier: serial port path, BLE address, fake id.
  final String transportId;
  final bool isBootloader;

  @override
  bool operator ==(Object other) =>
      other is DiscoveredDevice &&
      other.kind == kind &&
      other.transportId == transportId;

  @override
  int get hashCode => Object.hash(kind, transportId);

  @override
  String toString() =>
      'DiscoveredDevice($name, $kind, $transportId, bootloader=$isBootloader)';
}

/// Emits the current list of visible devices whenever it changes.
abstract interface class DeviceScanner {
  TransportKind get kind;
  Stream<List<DiscoveredDevice>> scan();
}
