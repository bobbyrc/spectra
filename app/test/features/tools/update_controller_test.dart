import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/dfu/dfu_runtime.dart';
import 'package:spectra/core/errors/app_failures.dart';
import 'package:spectra/core/session/active_device.dart';
import 'package:spectra/core/session/sessions.dart';
import 'package:spectra/features/tools/state/update_controller.dart';

import '../../fixtures/dfu_package_fixture.dart';
import '../../support/app_harness.dart';
import '../../support/dfu_test_support.dart';

void main() {
  testWidgetsApp('loads a package and reports its target', (tester) async {
    await tester.pumpWidget(
      buildDfuTestApp(
        source: MemoryFirmwarePackageSource(buildDfuZip(size: 4096)),
      ),
    );
    await tester.pump();

    final controller = readProvider(tester, updateControllerProvider.notifier);
    await controller.loadPackage('ultra-dfu-app.zip');
    await pumpFrames(tester);

    final state = readProvider(tester, updateControllerProvider);
    expect(state.package?.targetModel, DeviceModel.ultra);
    expect(state.error, isNull);
  });

  testWidgetsApp('a bad package leaves an error and no package', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildDfuTestApp(
        source: MemoryFirmwarePackageSource(Uint8List.fromList(<int>[1, 2, 3])),
      ),
    );
    await tester.pump();

    final controller = readProvider(tester, updateControllerProvider.notifier);
    await controller.loadPackage('broken.zip');
    await pumpFrames(tester);

    final state = readProvider(tester, updateControllerProvider);
    expect(state.package, isNull);
    expect(state.error, isA<DfuError>());
  });

  testWidgetsApp('start with no package and no device does nothing bad', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildDfuTestApp(source: MemoryFirmwarePackageSource(buildDfuZip())),
    );
    await tester.pump();

    final controller = readProvider(tester, updateControllerProvider.notifier);
    await controller.start();
    await pumpFrames(tester);

    expect(readProvider(tester, updateControllerProvider).running, isFalse);
    expect(readProvider(tester, dfuActivityProvider), isFalse);
  });

  testWidgetsApp('start with no package and no device reports UpdateNoTarget', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildDfuTestApp(source: MemoryFirmwarePackageSource(buildDfuZip())),
    );
    await tester.pump();

    final controller = readProvider(tester, updateControllerProvider.notifier);
    await controller.loadPackage('ultra-dfu-app.zip');
    await pumpFrames(tester);
    await controller.start();
    await pumpFrames(tester);

    expect(
      readProvider(tester, updateControllerProvider).error,
      isA<UpdateNoTarget>(),
    );
  });

  testWidgetsApp('a recovery run flashes the emulated bootloader', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildDfuTestApp(
        source: MemoryFirmwarePackageSource(buildDfuZip(size: 4096)),
      ),
    );
    await tester.pump();

    final controller = readProvider(tester, updateControllerProvider.notifier);
    await controller.loadPackage('ultra-dfu-app.zip');
    await pumpFrames(tester);

    final run = controller.start(bootloader: FakeScanner.emulatedBootloader);
    await pumpFrames(tester, count: 60);
    await run;

    final state = readProvider(tester, updateControllerProvider);
    expect(state.completed, isTrue);
    expect(state.error, isNull);
    expect(state.phase, DfuPhase.done);
    expect(state.progress?.bytesSent, 4096);
    expect(readProvider(tester, dfuActivityProvider), isFalse);
    // Not just the byte count the controller reported: what the bootloader
    // actually holds, which is the only proof the image went across intact.
    expect(
      readProvider(tester, emulatorBootloaderProvider).bootloader.flashed,
      buildBin(4096),
    );
  });

  testWidgetsApp('a recovery run leaves an unrelated live session connected', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      buildDfuTestApp(
        source: MemoryFirmwarePackageSource(buildDfuZip(size: 4096)),
      ),
    );
    await connectToEmulator(tester);

    // The session connected before the recovery run starts: unrelated to
    // the bootloader being flashed, since `bootloader` targets its own
    // device and never this session's.
    final before = readProvider(tester, activeSessionProvider);
    expect(before, isNotNull);
    final beforeSession = before!.session;
    final beforeIdentity = before.identity;

    final controller = readProvider(tester, updateControllerProvider.notifier);
    await controller.loadPackage('ultra-dfu-app.zip');
    await pumpFrames(tester);

    final run = controller.start(bootloader: FakeScanner.emulatedBootloader);
    await pumpFrames(tester, count: 60);
    await run;

    final state = readProvider(tester, updateControllerProvider);
    expect(state.completed, isTrue);
    expect(state.error, isNull);

    // The unrelated session is untouched: a recovery run never uses it, so
    // it must not be the one this run disconnects. Checking the connection
    // state directly (not just map membership) catches a version of the
    // bug that disconnects and silently reconnects under the same identity.
    expect(
      beforeSession.connectionState.value,
      isNot(isA<SessionDisconnected>()),
    );
    expect(
      readProvider(tester, sessionsProvider).sessions[beforeIdentity]?.session,
      same(beforeSession),
    );
  });

  testWidgetsApp('a failed run clears the activity flag and reports why', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildDfuTestApp(
        // A package whose image hash is stored the wrong way round: the
        // orchestrator refuses it before a byte is written, which is the
        // cheapest way to a real DfuFailed.
        source: MemoryFirmwarePackageSource(
          buildDfuZip(size: 4096, reverseHash: false),
        ),
      ),
    );
    await tester.pump();

    final controller = readProvider(tester, updateControllerProvider.notifier);
    await controller.loadPackage('ultra-dfu-app.zip');
    await pumpFrames(tester);

    final run = controller.start(bootloader: FakeScanner.emulatedBootloader);
    await pumpFrames(tester, count: 60);
    await run;

    final state = readProvider(tester, updateControllerProvider);
    expect(state.completed, isFalse);
    expect(state.running, isFalse);
    expect(state.error, isA<DfuError>());
    expect(readProvider(tester, dfuActivityProvider), isFalse);
  });

  testWidgetsApp('the activity flag is set while a flash runs and cleared '
      'when it is cancelled', (tester) async {
    await tester.pumpWidget(
      buildDfuTestApp(
        source: MemoryFirmwarePackageSource(buildDfuZip(size: 4096)),
        openChannel: slowBootloaderOpener(),
      ),
    );
    await tester.pump();

    final controller = readProvider(tester, updateControllerProvider.notifier);
    await controller.loadPackage('ultra-dfu-app.zip');
    await pumpFrames(tester);

    final run = controller.start(bootloader: FakeScanner.emulatedBootloader);
    await pumpFrames(tester, count: 3, step: const Duration(milliseconds: 20));
    expect(readProvider(tester, updateControllerProvider).running, isTrue);
    expect(readProvider(tester, dfuActivityProvider), isTrue);

    controller.cancel();
    await pumpFrames(tester, count: 60);
    await run;

    final state = readProvider(tester, updateControllerProvider);
    expect(state.running, isFalse);
    expect(state.completed, isFalse);
    expect(state.error, isA<CommandCancelled>());
    expect(readProvider(tester, dfuActivityProvider), isFalse);
  });

  testWidgetsApp('a BLE bootloader is refused while the flag is off', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      buildDfuTestApp(
        source: MemoryFirmwarePackageSource(buildDfuZip(size: 4096)),
        openChannel: (_) async {
          opened = true;
          throw DfuError('the channel must never be opened');
        },
      ),
    );
    await tester.pump();

    final controller = readProvider(tester, updateControllerProvider.notifier);
    await controller.loadPackage('ultra-dfu-app.zip');
    await pumpFrames(tester);

    await controller.start(
      bootloader: const DiscoveredDevice(
        name: 'Chameleon Ultra DFU',
        kind: TransportKind.ble,
        transportId: 'ble-bootloader',
        isBootloader: true,
      ),
    );
    await pumpFrames(tester);

    final state = readProvider(tester, updateControllerProvider);
    expect(state.error, isA<UpdateBleDisabled>());
    expect(state.running, isFalse);
    expect(opened, isFalse, reason: 'nothing may be opened over BLE yet (H2)');
    expect(readProvider(tester, dfuActivityProvider), isFalse);
  });

  testWidgetsApp('a failed connected run leaves no session behind', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      buildDfuTestApp(
        source: MemoryFirmwarePackageSource(buildDfuZip(size: 4096)),
        // Fails after ENTER_BOOTLOADER has gone out, which is the only way
        // to reach a session the flash has left in SessionUpdating.
        openChannel: (_) async => throw DfuError('scripted channel failure'),
      ),
    );
    await connectToEmulator(tester);

    final controller = readProvider(tester, updateControllerProvider.notifier);
    await controller.loadPackage('ultra-dfu-app.zip');
    await pumpFrames(tester);

    final run = controller.start();
    await pumpFrames(tester, count: 60);
    await run;

    final state = readProvider(tester, updateControllerProvider);
    expect(state.error, isA<DfuError>());
    expect(state.running, isFalse);
    expect(state.completed, isFalse);
    expect(readProvider(tester, dfuActivityProvider), isFalse);
    // Ruling 8-11: a session left in SessionUpdating pins routing to the
    // update screen, so a failed run has to close it exactly as a
    // successful one does.
    expect(readProvider(tester, sessionsProvider).sessions, isEmpty);
  });

  testWidgetsApp(
    'a session that fails to close still resets the activity flag',
    (tester) async {
      useDesktopSurface(tester);
      await tester.pumpWidget(
        buildDfuTestApp(
          source: MemoryFirmwarePackageSource(buildDfuZip(size: 4096)),
          // Not `transportFactoryProvider`'s default: the closed transport
          // is the connected session's own, exactly what `_closeUpdatingSession`
          // calls close() on once the flash leaves it in `SessionUpdating`.
          transport: (_) =>
              FakeDevice()..closeError = const PortBusy('port gone'),
        ),
      );
      await connectToEmulator(tester);

      final controller = readProvider(
        tester,
        updateControllerProvider.notifier,
      );
      await controller.loadPackage('ultra-dfu-app.zip');
      await pumpFrames(tester);

      final run = controller.start();
      await pumpFrames(tester, count: 60);
      await run;

      final state = readProvider(tester, updateControllerProvider);
      // A close failure is surfaced, but only because the run itself
      // otherwise succeeded — nothing else already claimed `state.error`.
      expect(state.error, isA<PortBusy>());
      expect(state.running, isFalse);
      expect(state.completed, isFalse);
      // The whole point: a throwing close must not skip these resets and
      // strand the router on this screen forever (spec 5.6).
      expect(readProvider(tester, dfuActivityProvider), isFalse);
    },
  );

  testWidgetsApp('a run refused before ENTER_BOOTLOADER keeps the session', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      buildDfuTestApp(
        source: MemoryFirmwarePackageSource(
          buildDfuZip(size: 4096, reverseHash: false),
        ),
      ),
    );
    await connectToEmulator(tester);

    final controller = readProvider(tester, updateControllerProvider.notifier);
    await controller.loadPackage('ultra-dfu-app.zip');
    await pumpFrames(tester);

    final run = controller.start();
    await pumpFrames(tester, count: 20);
    await run;

    expect(
      readProvider(tester, updateControllerProvider).error,
      isA<DfuError>(),
    );
    // The other half of ruling 8-11: the image was refused before a byte
    // went out, so the device never rebooted and its session is still good.
    expect(readProvider(tester, sessionsProvider).sessions, isNotEmpty);
  });

  testWidgetsApp('a second start while one is running is dropped', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildDfuTestApp(
        source: MemoryFirmwarePackageSource(buildDfuZip(size: 4096)),
        openChannel: slowBootloaderOpener(),
      ),
    );
    await tester.pump();

    final controller = readProvider(tester, updateControllerProvider.notifier);
    await controller.loadPackage('ultra-dfu-app.zip');
    await pumpFrames(tester);

    final run = controller.start(bootloader: FakeScanner.emulatedBootloader);
    await pumpFrames(tester, count: 5, step: const Duration(milliseconds: 20));
    final progressed = readProvider(tester, updateControllerProvider).progress;
    expect(progressed, isNotNull, reason: 'the first run has to be under way');

    // Drop, do not queue: the second call returns at once and leaves the run
    // in flight untouched — no reset of phase or progress, no second flash.
    await controller.start(bootloader: FakeScanner.emulatedBootloader);
    final during = readProvider(tester, updateControllerProvider);
    expect(during.running, isTrue);
    expect(
      during.progress?.bytesSent,
      greaterThanOrEqualTo(progressed!.bytesSent),
    );

    controller.cancel();
    await pumpFrames(tester, count: 60);
    await run;
    expect(readProvider(tester, dfuActivityProvider), isFalse);
  });

  testWidgetsApp('debugFail puts the controller in a failed state', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildDfuTestApp(source: MemoryFirmwarePackageSource(buildDfuZip())),
    );
    await tester.pump();
    readProvider(
      tester,
      updateControllerProvider.notifier,
    ).debugFail(DfuError('scripted'));
    await tester.pump();
    expect(
      readProvider(tester, updateControllerProvider).error,
      isA<DfuError>(),
    );
  });
}
