import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_ble_adapter.dart';

const nus = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';

void main() {
  test('an Ultra advertising NUS matches and is not a bootloader', () {
    const e = BleScanEntry(
      deviceId: '1',
      name: 'ChameleonUltra',
      services: [nus],
    );
    expect(isChameleonAdvertisement(e), isTrue);
    expect(isBootloaderAdvertisement(e), isFalse);
  });

  test('a Lite matches on its name prefix alone', () {
    const e = BleScanEntry(deviceId: '2', name: 'ChameleonLite_1234');
    expect(isChameleonAdvertisement(e), isTrue);
  });

  test('CU and CL are bootloaders (spec 5.5)', () {
    for (final name in const ['CU', 'CL']) {
      final e = BleScanEntry(deviceId: '3', name: name);
      expect(isChameleonAdvertisement(e), isTrue, reason: name);
      expect(isBootloaderAdvertisement(e), isTrue, reason: name);
    }
  });

  test('the FE59 DFU service marks a bootloader whatever the name', () {
    const e = BleScanEntry(deviceId: '4', name: 'Unnamed', services: ['fe59']);
    expect(isBootloaderAdvertisement(e), isTrue);
  });

  test('an unrelated device is ignored', () {
    const e = BleScanEntry(deviceId: '5', name: 'Someone AirPods');
    expect(isChameleonAdvertisement(e), isFalse);
    expect(
      isChameleonAdvertisement(const BleScanEntry(deviceId: '6', name: null)),
      isFalse,
    );
  });

  test(
    'scan emits a growing, de-duplicated list of DiscoveredDevices',
    () async {
      final adapter = FakeBleAdapter();
      final scanner = BleScanner(adapter: adapter);
      final emissions = <List<DiscoveredDevice>>[];
      final sub = scanner.scan().listen(emissions.add);
      adapter.emitAdvertisement(
        const BleScanEntry(
          deviceId: 'A',
          name: 'ChameleonUltra',
          services: [nus],
        ),
      );
      adapter.emitAdvertisement(const BleScanEntry(deviceId: 'B', name: 'CU'));
      adapter.emitAdvertisement(const BleScanEntry(deviceId: 'Z', name: 'TV'));
      adapter.emitAdvertisement(
        const BleScanEntry(
          deviceId: 'A',
          name: 'ChameleonUltra',
          services: [nus],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(emissions.last.length, 2);
      expect(
        emissions.last.first,
        const DiscoveredDevice(
          name: 'ChameleonUltra',
          kind: TransportKind.ble,
          transportId: 'A',
        ),
      );
      expect(emissions.last.last.isBootloader, isTrue);
      expect(scanner.kind, TransportKind.ble);
      await sub.cancel();
      expect(adapter.scanStopped, isTrue);
      await adapter.dispose();
    },
  );
}
