import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_ble_adapter.dart';
import 'support/fake_serial_adapter.dart';

List<DeviceScanner> scanners(HostPlatform platform, {bool emulator = false}) =>
    ChameleonTransports.defaultScanners(
      platform: platform,
      emulator: emulator,
      bleAdapter: FakeBleAdapter(),
      serialAdapter: FakeSerialAdapter(),
    );

void main() {
  test('desktop and Android scan BLE and serial', () {
    for (final p in const [
      HostPlatform.macos,
      HostPlatform.windows,
      HostPlatform.linux,
      HostPlatform.android,
    ]) {
      final list = scanners(p);
      expect(list.map((s) => s.runtimeType).toList(), [
        BleScanner,
        SerialScanner,
      ], reason: p.name);
    }
  });

  test('iOS scans BLE only (spec 5.4)', () {
    expect(scanners(HostPlatform.ios).map((s) => s.runtimeType).toList(), [
      BleScanner,
    ]);
  });

  test('emulator mode prepends the SDK FakeScanner (spec 7.5)', () {
    final list = scanners(HostPlatform.macos, emulator: true);
    expect(list.first, isA<FakeScanner>());
    expect(list.length, 3);
  });

  test('transportFor picks the transport the discovery kind implies', () {
    final ble = ChameleonTransports.transportFor(
      const DiscoveredDevice(
        name: 'ChameleonUltra',
        kind: TransportKind.ble,
        transportId: 'AA:BB',
      ),
      platform: HostPlatform.macos,
      bleAdapter: FakeBleAdapter(),
      serialAdapter: FakeSerialAdapter(),
    );
    expect(ble, isA<BleTransport>());

    final usb = ChameleonTransports.transportFor(
      const DiscoveredDevice(
        name: 'ChameleonUltra',
        kind: TransportKind.usb,
        transportId: '/dev/cu.usbmodem1',
      ),
      platform: HostPlatform.macos,
      bleAdapter: FakeBleAdapter(),
      serialAdapter: FakeSerialAdapter(),
    );
    expect(usb, isA<SerialTransport>());
    expect((usb as SerialTransport).path, '/dev/cu.usbmodem1');
  });

  test('a fake discovery yields a FakeDevice, so emulator mode connects', () {
    final t = ChameleonTransports.transportFor(
      FakeScanner.emulatedUltra,
      platform: HostPlatform.macos,
      bleAdapter: FakeBleAdapter(),
      serialAdapter: FakeSerialAdapter(),
    );
    expect(t, isA<FakeDevice>());
  });

  test('asking for serial where there is none is DeviceNotFound', () {
    expect(
      () => ChameleonTransports.transportFor(
        const DiscoveredDevice(
          name: 'x',
          kind: TransportKind.usb,
          transportId: '/dev/x',
        ),
        platform: HostPlatform.ios,
        bleAdapter: FakeBleAdapter(),
      ),
      throwsA(isA<DeviceNotFound>()),
    );
  });
}
