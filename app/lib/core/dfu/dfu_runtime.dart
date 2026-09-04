import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../discovery/scanners.dart';
import '../emulator/demo_cards.dart';
import '../flags/feature_flags.dart';
import '../session/active_device.dart';
import '../session/sessions.dart'; // transportFactoryProvider

part 'dfu_runtime.g.dart';

/// True while a flash is running. Spec 7.4 and 5.6: the app holds a wakelock
/// and blocks navigation for as long as this is set. Lives in core because
/// two core rules (the router's redirect, the wakelock controller) read it
/// and the feature that sets it must not be imported by either.
@Riverpod(keepAlive: true)
class DfuActivity extends _$DfuActivity {
  @override
  bool build() => false;

  void setRunning(bool value) => state = value;
}

/// Budget for each of `DfuOrchestrator`'s scans and for the reboot before the
/// first of them. A seam so a widget test does not sit out 30 seconds when a
/// scan is meant to fail.
@Riverpod(keepAlive: true)
Duration dfuScanTimeout(Ref ref) => const Duration(seconds: 30);

/// The emulated device behind `FakeScanner.emulatedBootloader`: a fake that
/// is already in DFU mode, so the recovery path (spec 5.5) has something to
/// flash in emulator mode. Created lazily — nothing reads it unless a fake
/// bootloader is actually the target — and kept alive so the scan that
/// follows the flash sees the *same* device leave the bootloader.
@Riverpod(keepAlive: true)
FakeDevice emulatorBootloader(Ref ref) {
  final device = buildEmulatedDevice();
  device.firmware.bootloaderRequested = true;
  ref.onDispose(() => device.close());
  return device;
}

/// Which device a run is aimed at: a bootloader picked on the connect screen
/// (spec 5.5's recovery entry), or nothing — meaning the active session's
/// device, which the orchestrator reboots itself.
final class DfuTarget {
  const DfuTarget({this.bootloader});
  final DiscoveredDevice? bootloader;

  @override
  bool operator ==(Object other) =>
      other is DfuTarget && other.bootloader == bootloader;

  @override
  int get hashCode => bootloader.hashCode;
}

/// Opens a DFU channel to a discovered bootloader (spec 4.5's
/// `DfuChannelOpener`, spec 5.3's two channels).
///
/// USB is enabled everywhere it exists; BLE is refused while
/// `dfuOverBleEnabled` is off (roadmap H2), which is belt and braces beside
/// the screen never offering it — the flag is the single gate spec 5.6 asks
/// for, and it has to hold even if a caller gets here another way.
@Riverpod(keepAlive: true)
DfuChannelOpener dfuChannelOpener(Ref ref) =>
    (DiscoveredDevice bootloader) async {
      switch (bootloader.kind) {
        case TransportKind.fake:
          // The session's own fake if it is the one that just rebooted;
          // otherwise the standing emulator bootloader (the recovery entry,
          // where nothing is connected).
          final transport = ref.read(activeSessionProvider)?.session.transport;
          if (transport is FakeDevice && transport.inBootloader) {
            return transport.openDfuChannel();
          }
          return ref.read(emulatorBootloaderProvider).openDfuChannel();
        case TransportKind.usb:
          // The channel owns the transport: nothing else holds the port, and
          // closing the channel has to release it whichever way the run ended.
          final transport = ref.read(transportFactoryProvider)(bootloader);
          await transport.open();
          return SlipSerialDfuChannel(transport, ownsTransport: true);
        case TransportKind.ble:
          if (!ref.read(featureFlagsProvider).dfuOverBleEnabled) {
            throw DfuError(
              'Bluetooth firmware update is disabled until hardware handoff H2 '
              'passes (dfuOverBleEnabled)',
            );
          }
          return BleDfuChannel(
            deviceId: bootloader.transportId,
            adapter: UniversalBleAdapter(),
          );
      }
    };

/// The scanners one run uses to find the bootloader and then the device
/// again.
///
/// In emulator mode a plain `FakeScanner` reports a static list, so it would
/// never show the device as a bootloader after the reboot — and never show it
/// back in the application after the flash. `FakeScanner.forDevice` follows
/// one fake's actual mode, which is exactly what the orchestrator's two scans
/// need. Real devices use the app's own scanner list unchanged.
@Riverpod(keepAlive: true)
List<DeviceScanner> dfuScanners(Ref ref, DfuTarget target) {
  final transport = ref.watch(activeSessionProvider)?.session.transport;
  if (transport is FakeDevice) {
    return <DeviceScanner>[FakeScanner.forDevice(transport)];
  }
  final bootloader = target.bootloader;
  if (bootloader != null && bootloader.kind == TransportKind.fake) {
    return <DeviceScanner>[
      FakeScanner.forDevice(ref.read(emulatorBootloaderProvider)),
    ];
  }
  return ref.watch(scannersProvider);
}
