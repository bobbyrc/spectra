import 'dart:io';

import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports the platform the test process runs on', () {
    final expected = switch (true) {
      _ when Platform.isMacOS => HostPlatform.macos,
      _ when Platform.isLinux => HostPlatform.linux,
      _ when Platform.isWindows => HostPlatform.windows,
      _ => HostPlatform.unknown,
    };
    expect(currentHostPlatform(), expected);
  });

  test('guidance values cover both link kinds', () {
    expect(
      TransportGuidance.values,
      contains(TransportGuidance.linuxModemManager),
    );
    expect(
      TransportGuidance.values,
      contains(TransportGuidance.windowsPairDevice),
    );
  });
}
