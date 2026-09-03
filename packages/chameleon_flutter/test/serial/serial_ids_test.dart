import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('USB identifiers match the firmware and the bootloader', () {
    expect(ChameleonUsbIds.applicationVid, 0x6868);
    expect(ChameleonUsbIds.applicationPid, 0x8686);
    expect(ChameleonUsbIds.bootloaderVid, 0x1915);
    expect(ChameleonUsbIds.bootloaderPid, 0x521F);
    expect(ChameleonUsbIds.manufacturer, 'Proxgrind');
  });

  test('line settings are 115200 8N1', () {
    expect(ChameleonUsbIds.baudRate, 115200);
    expect(ChameleonUsbIds.dataBits, 8);
    expect(ChameleonUsbIds.stopBits, 1);
  });
}
