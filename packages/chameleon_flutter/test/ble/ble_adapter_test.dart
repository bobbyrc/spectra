import 'package:chameleon_flutter/src/ble/ble_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BleScanEntry equality', () {
    test('entries with the same id, name and services are equal', () {
      const a = BleScanEntry(
        deviceId: 'aa:bb',
        name: 'ChameleonUltra',
        services: ['s1', 's2'],
      );
      const b = BleScanEntry(
        deviceId: 'aa:bb',
        name: 'ChameleonUltra',
        services: ['s1', 's2'],
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('services are compared by content, not identity', () {
      final a = BleScanEntry(
        deviceId: 'aa:bb',
        name: null,
        services: <String>['s1'].toList(),
      );
      final b = BleScanEntry(
        deviceId: 'aa:bb',
        name: null,
        services: <String>['s1'].toList(),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('any differing field breaks equality', () {
      const base = BleScanEntry(deviceId: 'a', name: 'n', services: ['s']);
      expect(
        base,
        isNot(const BleScanEntry(deviceId: 'b', name: 'n', services: ['s'])),
      );
      expect(
        base,
        isNot(const BleScanEntry(deviceId: 'a', name: null, services: ['s'])),
      );
      expect(
        base,
        isNot(const BleScanEntry(deviceId: 'a', name: 'n', services: ['t'])),
      );
      expect(base, isNot(const BleScanEntry(deviceId: 'a', name: 'n')));
    });

    test('service order is significant', () {
      const a = BleScanEntry(deviceId: 'a', name: null, services: ['s', 't']);
      const b = BleScanEntry(deviceId: 'a', name: null, services: ['t', 's']);
      expect(a, isNot(b));
    });
  });
}
