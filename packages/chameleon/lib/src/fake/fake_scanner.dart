import '../transport/scanner.dart';
import '../transport/transport.dart';

/// A [DeviceScanner] that reports a fixed, static list of devices instead
/// of doing hardware discovery. Defaults to a single emulated Ultra.
final class FakeScanner implements DeviceScanner {
  FakeScanner({List<DiscoveredDevice>? devices})
    : devices = devices ?? const [emulatedUltra];

  static const DiscoveredDevice emulatedUltra = DiscoveredDevice(
    name: 'Emulated Chameleon Ultra',
    kind: TransportKind.fake,
    transportId: 'fake-ultra',
  );

  static const DiscoveredDevice emulatedBootloader = DiscoveredDevice(
    name: 'CU',
    kind: TransportKind.fake,
    transportId: 'fake-bootloader',
    isBootloader: true,
  );

  final List<DiscoveredDevice> devices;

  @override
  TransportKind get kind => TransportKind.fake;

  @override
  Stream<List<DiscoveredDevice>> scan() =>
      Stream.value(List.unmodifiable(devices));
}
