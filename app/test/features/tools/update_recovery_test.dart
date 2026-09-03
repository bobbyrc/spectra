import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/app.dart';
import 'package:spectra/core/dfu/dfu_runtime.dart';
import 'package:spectra/features/tools/state/firmware_package_source.dart';
import 'package:spectra/features/tools/state/recover_target.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../fixtures/dfu_package_fixture.dart';
import '../../support/app_harness.dart';

final class _MemorySource implements FirmwarePackageSource {
  _MemorySource(this.bytes);
  final Uint8List bytes;
  @override
  Future<Uint8List> read(String path) async => bytes;
}

void main() {
  group('recoverTarget', () {
    const bootloader = DiscoveredDevice(
      name: 'CU',
      kind: TransportKind.usb,
      transportId: '/dev/tty.usb',
      isBootloader: true,
    );
    const application = DiscoveredDevice(
      name: 'ChameleonUltra',
      kind: TransportKind.usb,
      transportId: '/dev/tty.app',
    );

    test('finds the named bootloader', () {
      expect(
        recoverTarget(<DiscoveredDevice>[
          application,
          bootloader,
        ], '/dev/tty.usb'),
        bootloader,
      );
    });

    test('refuses a device that is not a bootloader', () {
      expect(
        recoverTarget(<DiscoveredDevice>[application], '/dev/tty.app'),
        isNull,
      );
    });

    test('null id, or nothing visible, is no target', () {
      expect(recoverTarget(<DiscoveredDevice>[bootloader], null), isNull);
      expect(recoverTarget(const <DiscoveredDevice>[], '/dev/tty.usb'), isNull);
    });
  });

  testWidgetsApp('recovering the emulated bootloader flashes it', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ...appOverrides(
            transport: (_) => FakeDevice(),
            scanners: <DeviceScanner>[
              const StaticScanner(<DiscoveredDevice>[
                FakeScanner.emulatedBootloader,
              ]),
            ],
          ),
          firmwarePackageSourceProvider.overrideWithValue(
            _MemorySource(buildDfuZip(size: 4096)),
          ),
          dfuScanTimeoutProvider.overrideWithValue(const Duration(seconds: 2)),
        ],
        child: const SpectraRoot(),
      ),
    );
    await pumpFrames(tester);

    // The connect screen offers "Recover" for a bootloader row (spec 5.5).
    await tester.tap(find.text('Recover'));
    await pumpFrames(tester);
    expect(find.text('Firmware package'), findsOneWidget);

    await tester.enterText(
      find.byType(SpectraTextField).first,
      '/tmp/ultra-dfu-app.zip',
    );
    await tester.pump();
    await tester.tap(find.text('Load package'));
    await pumpFrames(tester);

    await tester.tap(find.text('Install firmware'));
    await pumpFrames(tester, count: 80);

    expect(find.text('Firmware installed.'), findsOneWidget);
  });
}
