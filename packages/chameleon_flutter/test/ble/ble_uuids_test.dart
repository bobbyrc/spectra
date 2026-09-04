import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the Nordic UART UUIDs match the firmware', () {
    expect(NusUuids.service, '6E400001-B5A3-F393-E0A9-E50E24DCCA9E');
    expect(NusUuids.write, '6E400002-B5A3-F393-E0A9-E50E24DCCA9E');
    expect(NusUuids.notify, '6E400003-B5A3-F393-E0A9-E50E24DCCA9E');
  });

  test('the Nordic DFU UUIDs match the bootloader', () {
    expect(NordicDfuUuids.service, 'FE59');
    expect(NordicDfuUuids.controlPoint, '8EC90001-F315-4F60-9FB8-838830DAEA50');
    expect(NordicDfuUuids.packet, '8EC90002-F315-4F60-9FB8-838830DAEA50');
  });

  test('advertised names', () {
    expect(ChameleonBleNames.applicationPrefixes, [
      'ChameleonUltra',
      'ChameleonLite',
    ]);
    expect(ChameleonBleNames.bootloaderNames, ['CU', 'CL']);
  });

  test(
    'normalizeUuid lowercases and strips braces so comparisons are stable',
    () {
      expect(
        normalizeUuid('{6E400001-B5A3-F393-E0A9-E50E24DCCA9E}'),
        '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
      );
    },
  );

  test('normalizeUuid expands a 16-bit UUID to its full 128-bit form', () {
    // Both directions: the bare short form, and the form platforms report.
    expect(normalizeUuid('FE59'), '0000fe59-0000-1000-8000-00805f9b34fb');
    expect(
      normalizeUuid('0000fe59-0000-1000-8000-00805f9b34fb'),
      '0000fe59-0000-1000-8000-00805f9b34fb',
    );
  });

  test('normalizeUuid expands a 32-bit UUID to its full 128-bit form', () {
    expect(normalizeUuid('0000FE59'), '0000fe59-0000-1000-8000-00805f9b34fb');
  });

  test('normalizeUuid only lowercases anything that is not an exact '
      '4- or 8-hex-digit short form', () {
    expect(normalizeUuid('5'), '5');
    expect(normalizeUuid('abc'), 'abc');
    expect(normalizeUuid(''), '');
    expect(normalizeUuid('zz'), 'zz');
  });
}
