/// Nordic UART Service, the Chameleon's application-mode BLE link.
///
/// Values are copied from `docs/research/chameleon-protocol.md` and the
/// firmware sources. Never retype them.
abstract final class NusUuids {
  static const String service = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String write = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String notify = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E';
}

/// Nordic Secure DFU service, the bootloader's BLE link (spec 5.3).
abstract final class NordicDfuUuids {
  static const String service = 'FE59';
  static const String controlPoint = '8EC90001-F315-4F60-9FB8-838830DAEA50';
  static const String packet = '8EC90002-F315-4F60-9FB8-838830DAEA50';
}

/// Advertised names (spec 5.1 and 5.5).
abstract final class ChameleonBleNames {
  static const List<String> applicationPrefixes = <String>[
    'ChameleonUltra',
    'ChameleonLite',
  ];
  static const List<String> bootloaderNames = <String>['CU', 'CL'];
}

/// The Bluetooth SIG base UUID that a 16- or 32-bit short-form UUID is
/// substituted into to make a full 128-bit UUID.
/// https://www.bluetooth.com/specifications/assigned-numbers/
const String _bluetoothBaseUuidSuffix = '-0000-1000-8000-00805f9b34fb';

final RegExp _shortFormUuid = RegExp(r'^[0-9a-f]{1,8}$');

/// Case- and brace-insensitive form for comparing UUIDs, with 16- and 32-bit
/// short-form UUIDs (as the Chameleon's DFU service is specified, `FE59`)
/// expanded to their full 128-bit form. Platforms report UUIDs
/// inconsistently: CoreBluetooth uppercases, BlueZ lowercases, Windows wraps
/// them in braces, and some short-form values arrive un-expanded; expanding
/// here keeps every comparison against universal_ble's reported UUIDs
/// stable regardless of which form it hands back.
String normalizeUuid(String uuid) {
  final normalized = uuid
      .replaceAll('{', '')
      .replaceAll('}', '')
      .trim()
      .toLowerCase();
  if (_shortFormUuid.hasMatch(normalized)) {
    return '${normalized.padLeft(8, '0')}$_bluetoothBaseUuidSuffix';
  }
  return normalized;
}
