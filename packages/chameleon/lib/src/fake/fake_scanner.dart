import '../model/enums.dart';
import '../transport/scanner.dart';
import '../transport/transport.dart';
import 'fake_device.dart';

/// A [DeviceScanner] that reports a fixed, static list of devices instead
/// of doing hardware discovery. Defaults to a single emulated Ultra.
final class FakeScanner implements DeviceScanner {
  FakeScanner({List<DiscoveredDevice>? devices})
    : _static = devices ?? const [emulatedUltra],
      _device = null;

  /// A scanner that follows one [FakeDevice]: it lists that device's
  /// bootloader entry while the device is in DFU mode and its application
  /// entry otherwise, so a scan run after a reboot sees what it has become.
  ///
  /// Each `scan()` reports once, from the mode at subscription time; a caller
  /// waiting for the device to change mode subscribes again.
  FakeScanner.forDevice(FakeDevice device)
    : _static = const [],
      _device = device;

  static const DiscoveredDevice emulatedUltra = DiscoveredDevice(
    name: 'Emulated Chameleon Ultra',
    kind: TransportKind.fake,
    transportId: 'fake-ultra',
  );

  static const DiscoveredDevice emulatedLite = DiscoveredDevice(
    name: 'Emulated Chameleon Lite',
    kind: TransportKind.fake,
    transportId: 'fake-lite',
  );

  /// The Ultra's bootloader advertises as `CU`, the Lite's as `CL`.
  static const DiscoveredDevice emulatedBootloader = DiscoveredDevice(
    name: 'CU',
    kind: TransportKind.fake,
    transportId: 'fake-bootloader',
    isBootloader: true,
  );

  static const DiscoveredDevice emulatedLiteBootloader = DiscoveredDevice(
    name: 'CL',
    kind: TransportKind.fake,
    transportId: 'fake-bootloader-lite',
    isBootloader: true,
  );

  final List<DiscoveredDevice> _static;
  final FakeDevice? _device;

  /// What the next [scan] would report: the static list, or the entry the
  /// followed device's current mode calls for.
  List<DiscoveredDevice> get devices => List.unmodifiable(_visible());

  @override
  TransportKind get kind => TransportKind.fake;

  @override
  Stream<List<DiscoveredDevice>> scan() => Stream.value(devices);

  List<DiscoveredDevice> _visible() {
    final device = _device;
    if (device == null) return _static;
    final lite = device.firmware.config.model == DeviceModel.lite;
    if (device.inBootloader) {
      return [lite ? emulatedLiteBootloader : emulatedBootloader];
    }
    return [lite ? emulatedLite : emulatedUltra];
  }
}
