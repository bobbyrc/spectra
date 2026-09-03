import 'dart:io';

import 'package:test/test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  group('Android (spec 5.7)', () {
    late String manifest;
    setUpAll(
      () => manifest = read('app/android/app/src/main/AndroidManifest.xml'),
    );

    test('declares the Android 12+ Bluetooth permissions', () {
      expect(manifest, contains('android.permission.BLUETOOTH_SCAN'));
      expect(manifest, contains('android.permission.BLUETOOTH_CONNECT'));
      expect(manifest, contains('neverForLocation'));
    });

    test('declares the pre-12 legacy permissions and location', () {
      expect(manifest, contains('android:name="android.permission.BLUETOOTH"'));
      expect(
        manifest,
        contains('android:name="android.permission.BLUETOOTH_ADMIN"'),
      );
      expect(manifest, contains('android.permission.ACCESS_FINE_LOCATION'));
      expect(manifest, contains('android:maxSdkVersion="30"'));
    });

    test('registers the USB attached intent and its device filter', () {
      expect(
        manifest,
        contains('android.hardware.usb.action.USB_DEVICE_ATTACHED'),
      );
      expect(manifest, contains('@xml/device_filter'));
    });

    test('the device filter lists the app and the bootloader ids', () {
      final filter = read('app/android/app/src/main/res/xml/device_filter.xml');
      // 0x6868 = 26728, 0x8686 = 34438, 0x1915 = 6421, 0x521F = 21023.
      expect(filter, contains('vendor-id="26728"'));
      expect(filter, contains('product-id="34438"'));
      expect(filter, contains('vendor-id="6421"'));
      expect(filter, contains('product-id="21023"'));
    });
  });

  test('iOS declares the Bluetooth usage string', () {
    final plist = read('app/ios/Runner/Info.plist');
    expect(plist, contains('NSBluetoothAlwaysUsageDescription'));
  });

  test('macOS entitles Bluetooth and serial in both configurations', () {
    for (final name in const ['DebugProfile', 'Release']) {
      final ents = read('app/macos/Runner/$name.entitlements');
      expect(
        ents,
        contains('com.apple.security.device.bluetooth'),
        reason: '$name is missing the Bluetooth entitlement',
      );
      expect(
        ents,
        contains('com.apple.security.device.serial'),
        reason: '$name is missing the serial entitlement',
      );
    }
  });

  test('the transport example matches the app', () {
    final base = 'packages/chameleon_flutter/example/macos/Runner';
    for (final name in const ['DebugProfile', 'Release']) {
      final ents = read('$base/$name.entitlements');
      expect(ents, contains('com.apple.security.device.bluetooth'));
      expect(ents, contains('com.apple.security.device.serial'));
    }
    expect(
      read('$base/Info.plist'),
      contains('NSBluetoothAlwaysUsageDescription'),
    );
  });
}
