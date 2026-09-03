import 'package:chameleon/chameleon.dart';

import 'ble/ble_adapter.dart';
import 'ble/ble_scanner.dart';
import 'ble/ble_transport.dart';
import 'ble/universal_ble_adapter.dart';
import 'host_platform.dart';
import 'serial/serial_adapter.dart';
import 'serial/serial_adapter_factory.dart';
import 'serial/serial_scanner.dart';
import 'serial/serial_transport.dart';

/// Where the app gets its scanners and transports (spec 8.2).
///
/// Deliberately a plain list and a switch, not a registry: adding a
/// transport means editing this file, which is exactly the amount of
/// ceremony a five-platform app needs.
abstract final class ChameleonTransports {
  /// The scanners to run concurrently on this platform. Their results are
  /// merged by the app (spec 4.2).
  ///
  /// [emulator] prepends the SDK's [FakeScanner] so the app's emulator mode
  /// works with no device attached (spec 7.5). The adapter parameters exist
  /// for tests; production passes none.
  static List<DeviceScanner> defaultScanners({
    bool emulator = false,
    HostPlatform? platform,
    BleAdapter? bleAdapter,
    SerialPortAdapter? serialAdapter,
  }) {
    final resolved = platform ?? currentHostPlatform();
    final serial =
        serialAdapter ?? defaultSerialPortAdapter(platform: resolved);
    return <DeviceScanner>[
      if (emulator) FakeScanner(),
      BleScanner(adapter: bleAdapter ?? UniversalBleAdapter()),
      if (serial != null && resolved != HostPlatform.ios)
        SerialScanner(adapter: serial),
    ];
  }

  /// A transport for a device one of those scanners reported.
  static Transport transportFor(
    DiscoveredDevice device, {
    HostPlatform? platform,
    BleAdapter? bleAdapter,
    SerialPortAdapter? serialAdapter,
    SerialControlLineMode controlLines = SerialControlLineMode.dtrOnly,
  }) {
    final resolved = platform ?? currentHostPlatform();
    switch (device.kind) {
      case TransportKind.fake:
        return FakeDevice();
      case TransportKind.ble:
        return BleTransport(
          deviceId: device.transportId,
          adapter: bleAdapter ?? UniversalBleAdapter(),
          platform: resolved,
        );
      case TransportKind.usb:
        final serial =
            serialAdapter ?? defaultSerialPortAdapter(platform: resolved);
        if (serial == null) {
          throw const DeviceNotFound('this platform has no serial transport');
        }
        return SerialTransport(
          path: device.transportId,
          adapter: serial,
          controlLines: controlLines,
          platform: resolved,
        );
    }
  }
}
