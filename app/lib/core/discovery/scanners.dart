/// Emulator mode and the platform scanner list (spec 4.2, spec 7.5).
///
/// [scannerPlatformProvider], [scannerBleAdapterProvider] and
/// [scannerSerialAdapterProvider] are [scannersProvider]'s injection seams
/// for [ChameleonTransports.defaultScanners]'s `platform`, `bleAdapter` and
/// `serialAdapter` parameters. Production overrides none of them, so
/// `defaultScanners` gets `null` for all three and falls back to its own
/// real-platform defaults (`currentHostPlatform()`, `UniversalBleAdapter()`,
/// `defaultSerialPortAdapter()`). Tests override them with stand-ins that
/// implement `BleAdapter`/`SerialPortAdapter` but are never asked to do
/// anything — `BleScanner`/`SerialScanner` only store the adapter they are
/// given at construction and call it once `scan()` runs — so a test that
/// only reads [scannersProvider]'s list (never calls `scan()` on anything in
/// it) can use a stub whose methods all throw `UnimplementedError`. Kept
/// even though only two tests exercise them today: they are the seam the
/// app (and any future settings screen that lets a user pin a platform or
/// adapter) hangs off.
library;

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

/// See the file header. `null` is [ChameleonTransports.defaultScanners]'s
/// own "use the real platform" default.
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
