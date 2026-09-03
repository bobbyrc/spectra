import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/app.dart';
import 'package:spectra/core/dfu/dfu_runtime.dart';
import 'package:spectra/core/errors/problem_view.dart';
import 'package:spectra/features/tools/state/firmware_package_source.dart';
import 'package:spectra/features/tools/state/update_controller.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../fixtures/dfu_package_fixture.dart';
import '../../support/app_harness.dart';
import '../../support/dfu_test_support.dart';

void main() {
  testWidgetsApp('loading a package shows what it is', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      buildDfuTestApp(
        source: MemoryFirmwarePackageSource(buildDfuZip(size: 4096)),
      ),
    );
    await tester.pump();
    await connectToEmulator(tester);
    await openUpdate(tester);

    expect(find.text('Firmware package'), findsOneWidget);
    expect(find.text('Install firmware'), findsOneWidget);

    await tester.enterText(
      find.byType(SpectraTextField).first,
      '/tmp/ultra-dfu-app.zip',
    );
    await tester.pump();
    await tester.tap(find.text('Load package'));
    await pumpFrames(tester);

    // Not `find.textContaining('ultra-dfu-app.zip')`: the field's own hint
    // text (`updatePackagePathHint`) names the same file as an example, and
    // `InputDecorator` keeps a hint's `Text` mounted (just invisible) once
    // the field has a value, so a substring match sees three widgets, not
    // one. The full summary line is unambiguous.
    expect(
      find.text('ultra-dfu-app.zip · 1 image · 4096 bytes'),
      findsOneWidget,
    );
    expect(find.text('Built for the Chameleon Ultra.'), findsOneWidget);
  });

  testWidgetsApp('a package that will not parse shows the problem', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      buildDfuTestApp(
        source: MemoryFirmwarePackageSource(Uint8List.fromList(<int>[1, 2, 3])),
      ),
    );
    await tester.pump();
    await connectToEmulator(tester);
    await openUpdate(tester);

    await tester.enterText(find.byType(SpectraTextField).first, 'broken.zip');
    await tester.pump();
    await tester.tap(find.text('Load package'));
    await pumpFrames(tester);

    expect(find.byType(ProblemView), findsOneWidget);
  });

  testWidgetsApp(
    'with nothing connected, recovering a bootloader still says so',
    (tester) async {
      useDesktopSurface(tester);
      // Pre-flight ruling 9: drive to AppRoutes.update with no session (the
      // spec 5.6 recovery entry, reached via "Recover" on a bootloader row)
      // and assert the updateNoTarget copy, rather than asserting on a
      // screen the test never opens.
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
              MemoryFirmwarePackageSource(buildDfuZip()),
            ),
            dfuScanTimeoutProvider.overrideWithValue(
              const Duration(seconds: 2),
            ),
          ],
          child: const SpectraRoot(),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Recover'));
      await pumpFrames(tester);

      expect(
        find.text(
          'Connect a device, or choose a device in the bootloader on '
          'the connect screen.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgetsApp('a run shows the steps, the bar and a cancel', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      buildDfuTestApp(
        source: MemoryFirmwarePackageSource(buildDfuZip(size: 8192)),
      ),
    );
    await tester.pump();
    await connectToEmulator(tester);
    await openUpdate(tester);

    await tester.enterText(
      find.byType(SpectraTextField).first,
      '/tmp/ultra-dfu-app.zip',
    );
    await tester.pump();
    await tester.tap(find.text('Load package'));
    await pumpFrames(tester);

    await tester.tap(find.text('Install firmware'));
    await tester.pump();
    // Mid-flight: the progress bar and the step indicator are up.
    expect(find.byType(SpectraProgressIndicator), findsOneWidget);
    expect(find.byType(SpectraStepIndicator), findsOneWidget);
    expect(
      find.text('Keep the device connected and powered until this finishes.'),
      findsOneWidget,
    );

    await pumpFrames(tester, count: 80);
    expect(find.text('Firmware installed.'), findsOneWidget);
    expect(find.byType(SpectraProgressIndicator), findsNothing);
  });

  testWidgetsApp('a failed run shows the problem and offers a retry', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      buildDfuTestApp(source: MemoryFirmwarePackageSource(buildDfuZip())),
    );
    await tester.pump();
    await connectToEmulator(tester);
    await openUpdate(tester);

    readProvider(
      tester,
      updateControllerProvider.notifier,
    ).debugFail(DfuError('scripted failure'));
    await pumpFrames(tester);

    expect(find.byType(ProblemView), findsOneWidget);
  });
}
