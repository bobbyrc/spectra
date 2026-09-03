import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/dfu/dfu_runtime.dart';
import 'package:spectra/core/errors/app_failures.dart';
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
