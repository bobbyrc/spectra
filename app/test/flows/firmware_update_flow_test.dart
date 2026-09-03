import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/app.dart';
import 'package:spectra/core/dfu/dfu_runtime.dart';
import 'package:spectra/core/session/sessions.dart';
import 'package:spectra/features/tools/state/firmware_package_source.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../fixtures/dfu_package_fixture.dart';
import '../support/app_harness.dart';

/// The roadmap's Phase 8 gate: flash a connected emulated device end to end,
/// and recover one already left in its bootloader with no session — both as
/// a flow test. The channel half of the gate (both transport kinds) is
/// `packages/chameleon_flutter/test/dfu/dfu_channel_flash_test.dart`.
final class _MemorySource implements FirmwarePackageSource {
  _MemorySource(this.bytes);
  final Uint8List bytes;
  @override
  Future<Uint8List> read(String path) async => bytes;
}

Widget _app({List<DeviceScanner>? scanners}) => ProviderScope(
  overrides: <Override>[
    ...appOverrides(transport: (_) => FakeDevice(), scanners: scanners),
    firmwarePackageSourceProvider.overrideWithValue(
      _MemorySource(buildDfuZip(size: 8192)),
    ),
    dfuScanTimeoutProvider.overrideWithValue(const Duration(seconds: 2)),
  ],
  child: const SpectraRoot(),
);

Future<void> _loadAndStart(WidgetTester tester) async {
  await tester.enterText(
    find.byType(SpectraTextField).first,
    '/tmp/ultra-dfu-app.zip',
  );
  await tester.pump();
  await tester.tap(find.text('Load package'));
  await pumpFrames(tester);

  await tester.tap(find.text('Install firmware'));
  // Mid-flight: the six-step indicator and the do-not-disconnect notice are
  // up before the run finishes (ruling 8-3, spec 7.4).
  await tester.pump();
  expect(find.byType(SpectraStepIndicator), findsOneWidget);
  expect(
    find.text('Keep the device connected and powered until this finishes.'),
    findsOneWidget,
  );

  await pumpFrames(tester, count: 100);
}

void main() {
  testWidgetsApp('update a connected device end to end', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(_app());
    await tester.pump();
    await connectToEmulator(tester);
    await openUpdate(tester);

    await _loadAndStart(tester);

    expect(find.text('Firmware installed.'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SpectraRoot)),
      listen: false,
    );
    // The run is over: the wakelock-and-navigation-blocking flag is down,
    // and the device the flash targeted reconnected (spec 7.4's promise
    // that a successful flash ends back on a live session, not stranded).
    expect(container.read(dfuActivityProvider), isFalse);
    expect(container.read(sessionsProvider).sessions, isNotEmpty);
  });

  testWidgetsApp('recover a device left in the bootloader', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      _app(
        scanners: <DeviceScanner>[
          const StaticScanner(<DiscoveredDevice>[
            FakeScanner.emulatedBootloader,
          ]),
        ],
      ),
    );
    await pumpFrames(tester);

    await tester.tap(find.text('Recover'));
    await pumpFrames(tester);
    await _loadAndStart(tester);

    expect(find.text('Firmware installed.'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SpectraRoot)),
      listen: false,
    );
    expect(container.read(dfuActivityProvider), isFalse);
    // The fake bootloader actually holds the image, not just a controller
    // that claims it does.
    expect(
      container.read(emulatorBootloaderProvider).bootloader.flashed,
      buildBin(8192),
    );
  });
}
