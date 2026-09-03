import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'scanners.g.dart';

/// Spec 7.5: the connect screen lists real devices plus one emulated
/// Chameleon Ultra. On by default, because it is also how screenshots and
/// manual QA happen with no hardware attached.
@Riverpod(keepAlive: true)
class EmulatorMode extends _$EmulatorMode {
  @override
  bool build() => true;

  void setEnabled(bool enabled) => state = enabled;
}

/// Seams for [scannersProvider]'s platform and adapter inputs to
/// [ChameleonTransports.defaultScanners]. Production leaves all three
/// `null`, which is [defaultScanners]'s own "use the real one" default;
/// tests override them so a scan never touches `UniversalBleAdapter` or
/// libserialport.
@Riverpod(keepAlive: true)
HostPlatform? scannerPlatform(Ref ref) => null;

@Riverpod(keepAlive: true)
BleAdapter? scannerBleAdapter(Ref ref) => null;

@Riverpod(keepAlive: true)
SerialPortAdapter? scannerSerialAdapter(Ref ref) => null;

/// The platform's scanners, plus the SDK's [FakeScanner] in emulator mode
/// (spec 8.2: a plain list, no registry).
@Riverpod(keepAlive: true)
List<DeviceScanner> scanners(Ref ref) => ChameleonTransports.defaultScanners(
  emulator: ref.watch(emulatorModeProvider),
  platform: ref.watch(scannerPlatformProvider),
  bleAdapter: ref.watch(scannerBleAdapterProvider),
  serialAdapter: ref.watch(scannerSerialAdapterProvider),
);
