import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop gets libserialport', () {
    for (final p in const [
      HostPlatform.macos,
      HostPlatform.windows,
      HostPlatform.linux,
    ]) {
      expect(
        defaultSerialPortAdapter(platform: p),
        isA<LibSerialPortAdapter>(),
        reason: p.name,
      );
    }
  });

  test('Android gets usb_serial', () {
    expect(
      defaultSerialPortAdapter(platform: HostPlatform.android),
      isA<UsbSerialAdapter>(),
    );
  });

  test('iOS has no serial at all (spec 5.4)', () {
    expect(defaultSerialPortAdapter(platform: HostPlatform.ios), isNull);
    expect(defaultSerialPortAdapter(platform: HostPlatform.unknown), isNull);
  });
}
