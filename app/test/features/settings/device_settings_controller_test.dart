import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/errors/app_failures.dart';
import 'package:spectra/core/session/session_streams.dart';
import 'package:spectra/features/settings/state/device_settings_controller.dart';
import 'package:spectra/features/settings/state/settings_labels.dart';

import '../../support/app_harness.dart';

void main() {
  testWidgetsApp('a change writes through and marks the settings unsaved', (
    tester,
  ) async {
    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await connectToEmulator(tester);
    keepAlive(tester, settingsProvider);
    keepAlive(tester, deviceSettingsControllerProvider);
    await pumpFrames(tester);

    final DeviceSettingsController controller = readProvider(
      tester,
      deviceSettingsControllerProvider.notifier,
    );
    final Future<void> pending = controller.setAnimation(AnimationMode.none);
    await pumpFrames(tester, count: 5, step: const Duration(milliseconds: 20));
    await pending;
    await pumpFrames(tester, count: 3);

    expect(
      readProvider(tester, settingsProvider).value!.animation,
      AnimationMode.none,
    );
    expect(
      readProvider(tester, deviceSettingsControllerProvider).dirty,
      isTrue,
    );
  });

  testWidgetsApp('saving clears the unsaved marker', (tester) async {
    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await connectToEmulator(tester);
    keepAlive(tester, settingsProvider);
    keepAlive(tester, deviceSettingsControllerProvider);
    await pumpFrames(tester);

    final DeviceSettingsController controller = readProvider(
      tester,
      deviceSettingsControllerProvider.notifier,
    );
    final Future<void> changed = controller.setButton(
      DeviceButton.a,
      ButtonFunction.battery,
    );
    await pumpFrames(tester, count: 5, step: const Duration(milliseconds: 20));
    await changed;

    final Future<void> saved = controller.saveToDevice();
    await pumpFrames(tester, count: 5, step: const Duration(milliseconds: 20));
    await saved;
    await pumpFrames(tester, count: 3);

    final DeviceSettingsEditState state = readProvider(
      tester,
      deviceSettingsControllerProvider,
    );
    expect(state.dirty, isFalse);
    expect(state.error, isNull);
    expect(
      readProvider(tester, settingsProvider).value!.buttonA,
      ButtonFunction.battery,
    );
  });

  testWidgetsApp('reset restores the firmware defaults and re-reads them', (
    tester,
  ) async {
    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await connectToEmulator(tester);
    keepAlive(tester, settingsProvider);
    keepAlive(tester, deviceSettingsControllerProvider);
    await pumpFrames(tester);

    final DeviceSettingsController controller = readProvider(
      tester,
      deviceSettingsControllerProvider.notifier,
    );
    final Future<void> changed = controller.setAnimation(AnimationMode.none);
    await pumpFrames(tester, count: 5, step: const Duration(milliseconds: 20));
    await changed;

    final Future<void> reset = controller.resetToFactory();
    await pumpFrames(tester, count: 5, step: const Duration(milliseconds: 20));
    await reset;
    await pumpFrames(tester, count: 3);

    expect(
      readProvider(tester, settingsProvider).value!.animation,
      AnimationMode.full,
    );
    expect(
      readProvider(tester, deviceSettingsControllerProvider).dirty,
      isFalse,
    );
  });

  testWidgetsApp('with no session the failure is typed, not thrown', (
    tester,
  ) async {
    await pumpTestApp(tester);
    keepAlive(tester, deviceSettingsControllerProvider);
    await pumpFrames(tester);

    final DeviceSettingsController controller = readProvider(
      tester,
      deviceSettingsControllerProvider.notifier,
    );
    await controller.setAnimation(AnimationMode.none);
    await pumpFrames(tester, count: 3);

    expect(
      readProvider(tester, deviceSettingsControllerProvider).error,
      isA<SessionNotReady>(),
    );
  });

  testWidgetsApp('a second call while one is in flight is dropped', (
    tester,
  ) async {
    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await connectToEmulator(tester);
    keepAlive(tester, settingsProvider);
    keepAlive(tester, deviceSettingsControllerProvider);
    await pumpFrames(tester);

    final DeviceSettingsController controller = readProvider(
      tester,
      deviceSettingsControllerProvider.notifier,
    );
    final Future<void> first = controller.setAnimation(AnimationMode.none);
    final Future<void> second = controller.setAnimation(AnimationMode.minimal);
    await pumpFrames(tester, count: 5, step: const Duration(milliseconds: 20));
    await first;
    await second;
    await pumpFrames(tester, count: 3);

    // The second call never reached the device: the first one's value stands.
    expect(
      readProvider(tester, settingsProvider).value!.animation,
      AnimationMode.none,
    );
  });

  testWidgetsApp(
    'setSleepTimeout refuses an out-of-range value without touching the '
    'device',
    (tester) async {
      final FakeDevice device = FakeDevice();
      await pumpTestApp(tester, transport: (_) => device);
      await connectToEmulator(tester);
      keepAlive(tester, deviceSettingsControllerProvider);
      await pumpFrames(tester);

      final DeviceSettingsController controller = readProvider(
        tester,
        deviceSettingsControllerProvider.notifier,
      );

      await controller.setSleepTimeout(4);
      await pumpFrames(tester, count: 3);
      expect(
        readProvider(tester, deviceSettingsControllerProvider).error,
        isA<SleepTimeoutOutOfRange>(),
      );

      await controller.setSleepTimeout(61);
      await pumpFrames(tester, count: 3);
      expect(
        readProvider(tester, deviceSettingsControllerProvider).error,
        isA<SleepTimeoutOutOfRange>(),
      );

      expect(device.received.where((Frame f) => f.command == 1040), isEmpty);
    },
  );

  testWidgetsApp('setSleepTimeout sends the firmware\'s boundary values', (
    tester,
  ) async {
    final FakeDevice device = FakeDevice();
    await pumpTestApp(tester, transport: (_) => device);
    await connectToEmulator(tester);
    keepAlive(tester, settingsProvider);
    keepAlive(tester, deviceSettingsControllerProvider);
    await pumpFrames(tester);

    final DeviceSettingsController controller = readProvider(
      tester,
      deviceSettingsControllerProvider.notifier,
    );

    final Future<void> low = controller.setSleepTimeout(5);
    await pumpFrames(tester, count: 5, step: const Duration(milliseconds: 20));
    await low;
    expect(
      readProvider(tester, settingsProvider).value!.sleepTimeoutSeconds,
      5,
    );
    expect(
      readProvider(tester, deviceSettingsControllerProvider).error,
      isNull,
    );

    final Future<void> high = controller.setSleepTimeout(60);
    await pumpFrames(tester, count: 5, step: const Duration(milliseconds: 20));
    await high;
    expect(
      readProvider(tester, settingsProvider).value!.sleepTimeoutSeconds,
      60,
    );
    expect(
      readProvider(tester, deviceSettingsControllerProvider).error,
      isNull,
    );

    expect(device.received.where((Frame f) => f.command == 1040).length, 2);
  });

  group('validation and labels', () {
    test('a pairing key is six digits', () {
      expect(isValidPairingKey('123456'), isTrue);
      expect(isValidPairingKey('12345'), isFalse);
      expect(isValidPairingKey('1234567'), isFalse);
      expect(isValidPairingKey('12345a'), isFalse);
    });

    test('a sleep timeout is 5..60 seconds inclusive', () {
      expect(isValidSleepTimeout(4), isFalse);
      expect(isValidSleepTimeout(5), isTrue);
      expect(isValidSleepTimeout(60), isTrue);
      expect(isValidSleepTimeout(61), isFalse);
    });
  });
}
