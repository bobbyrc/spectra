import 'package:chameleon/chameleon.dart';
import 'package:flutter/material.dart' show BuildContext;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:spectra/core/routing/routes.dart';
import 'package:spectra/features/tools/state/recover_target.dart';
import 'package:spectra/features/tools/state/update_controller.dart';
import 'package:spectra/features/tools/state/update_steps.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../fixtures/dfu_package_fixture.dart';
import '../../support/app_harness.dart';
import '../../support/dfu_test_support.dart';

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
      buildDfuTestApp(
        source: MemoryFirmwarePackageSource(buildDfuZip(size: 4096)),
        scanners: <DeviceScanner>[
          const StaticScanner(<DiscoveredDevice>[
            FakeScanner.emulatedBootloader,
          ]),
        ],
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

  testWidgetsApp(
    'a recovery run starts the step indicator at transferring (ruling 8-3)',
    (tester) async {
      useDesktopSurface(tester);
      await tester.pumpWidget(
        buildDfuTestApp(
          source: MemoryFirmwarePackageSource(buildDfuZip(size: 8192)),
          scanners: <DeviceScanner>[
            const StaticScanner(<DiscoveredDevice>[
              FakeScanner.emulatedBootloader,
            ]),
          ],
          // A slow channel: without it, a zero-latency run could finish
          // inside the single pump this test uses to observe the step
          // immediately after tapping Install, and this assertion would
          // pass by accident even if the recovery path started at
          // `checking` like the connected path does.
          openChannel: slowBootloaderOpener(),
        ),
      );
      await pumpFrames(tester);

      await tester.tap(find.text('Recover'));
      await pumpFrames(tester);
      await tester.enterText(
        find.byType(SpectraTextField).first,
        '/tmp/ultra-dfu-app.zip',
      );
      await tester.pump();
      await tester.tap(find.text('Load package'));
      await pumpFrames(tester);

      await tester.tap(find.text('Install firmware'));
      // One pump: enough to flush the orchestrator's async* generator up to
      // its first yield, which for a bootloader run is `transferring`
      // directly (`DfuOrchestrator.run`'s own doc: the recovery path never
      // emits `checking`, `enteringBootloader` or `findingBootloader`).
      await tester.pump();

      expect(
        tester
            .widget<SpectraStepIndicator>(find.byType(SpectraStepIndicator))
            .currentIndex,
        updateStepIndex(DfuPhase.transferring),
      );

      // Stop here rather than running to completion: with `openChannel`
      // overridden the run flashes its own bootloader device, not the one
      // `dfuScanners` re-scans for afterwards (same seam
      // `update_controller_test.dart`'s slow-channel tests work around by
      // cancelling instead of finishing). All this test needs is the step
      // right after the tap, so cancel and let teardown close out cleanly.
      readProvider(tester, updateControllerProvider.notifier).cancel();
      await pumpFrames(tester, count: 60);
    },
  );

  testWidgetsApp('a stale recovery link says so and never starts a run', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      buildDfuTestApp(
        source: MemoryFirmwarePackageSource(buildDfuZip(size: 4096)),
      ),
    );
    await tester.pump();
    await connectToEmulator(tester);

    // Navigate straight to the recovery entry for a transport id no
    // scanner reports, with a ready session already connected — the case
    // a stale `?recover=` link (or a bootloader that rebooted away again)
    // produces.
    final BuildContext context = tester.element(find.text('Slots').last);
    GoRouter.of(context)
        .go(AppRoutes.recover('a-bootloader-nobody-is-reporting'));
    await pumpFrames(tester);

    // Load a package so the only reason Start stays disabled is the
    // unresolved target, not a missing package — otherwise this test
    // would pass even if the fix regressed back to falling through to
    // the connected device.
    await tester.enterText(
      find.byType(SpectraTextField).first,
      '/tmp/ultra-dfu-app.zip',
    );
    await tester.pump();
    await tester.tap(find.text('Load package'));
    await pumpFrames(tester);

    // The "nothing to update" copy appears twice: once as the stale-target
    // card that would otherwise have named the unresolved transport id, and
    // once from the unrelated "no device connected" card below it — neither
    // ever names the raw transport id.
    expect(
      find.text(
        'Connect a device, or choose a device in the bootloader on '
        'the connect screen.',
      ),
      findsNWidgets(2),
    );
    expect(
      find.textContaining('a-bootloader-nobody-is-reporting'),
      findsNothing,
    );
    // Rendered but disabled: the connected device is not a fallback
    // target for a `?recover=` link that no longer resolves.
    expect(
      tester
          .widget<SpectraButton>(
            find.widgetWithText(SpectraButton, 'Install firmware'),
          )
          .onPressed,
      isNull,
    );

    final UpdateState state = readProvider(tester, updateControllerProvider);
    expect(state.running, isFalse);
    expect(state.completed, isFalse);
  });

  testWidgetsApp('the recovery cards disappear once the run has completed', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      buildDfuTestApp(
        source: MemoryFirmwarePackageSource(buildDfuZip(size: 4096)),
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
    // Present while the run has not finished: the recovery target card
    // and the button-B instructions.
    expect(find.textContaining('Recovering the device at'), findsOneWidget);
    expect(
      find.text(
        'If the device is not listed, hold button B while plugging in '
        'the USB cable to enter the bootloader from any state.',
      ),
      findsOneWidget,
    );

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
    // Gone: a finished flash has nothing left to recover or instruct.
    expect(find.textContaining('Recovering the device at'), findsNothing);
    expect(
      find.text(
        'If the device is not listed, hold button B while plugging in '
        'the USB cable to enter the bootloader from any state.',
      ),
      findsNothing,
    );
  });
}
