import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/errors/problem_view.dart';
import 'package:spectra/core/session/session_streams.dart';
import 'package:spectra/features/settings/state/device_settings_controller.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

Future<void> _openSettings(WidgetTester tester) async {
  useDesktopSurface(tester);
  await pumpTestApp(tester, transport: (_) => FakeDevice());
  await connectToEmulator(tester);
  await tester.tap(find.text('Settings').last);
  await pumpFrames(tester);
}

void main() {
  testWidgetsApp('shows the device settings the fake reports', (tester) async {
    await _openSettings(tester);

    expect(find.text('Start-up animation'), findsOneWidget);
    expect(find.text('Full'), findsOneWidget);
    expect(find.text('Next slot'), findsOneWidget); // button A default
  });

  testWidgetsApp('changing the animation writes through and asks to be saved', (
    tester,
  ) async {
    await _openSettings(tester);

    await tester.tap(find.text('Start-up animation'));
    await pumpFrames(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('None'),
      ),
    );
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    expect(
      readProvider(tester, settingsProvider).value!.animation,
      AnimationMode.none,
    );
    expect(
      find.text(
        'Unsaved. Save these settings to the device so they survive a reboot.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Save to device'));
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));
    expect(
      readProvider(tester, deviceSettingsControllerProvider).dirty,
      isFalse,
    );
    expect(find.text('Settings saved to the device.'), findsOneWidget);
  });

  testWidgetsApp('the pairing switch carries the spec 5.1 warning', (
    tester,
  ) async {
    await _openSettings(tester);
    expect(
      find.textContaining('only advertises to hosts it has already bonded'),
      findsOneWidget,
    );
  });

  testWidgetsApp('a six-digit passkey is required', (tester) async {
    await _openSettings(tester);

    await tester.enterText(find.byType(SpectraTextField).first, '12345');
    await tester.pump();
    expect(find.text('The passkey is six digits.'), findsOneWidget);
  });

  testWidgetsApp('forgetting paired hosts asks for confirmation first', (
    tester,
  ) async {
    await _openSettings(tester);

    await tester.tap(find.text('Forget paired hosts'));
    await pumpFrames(tester);
    expect(find.text('Forget the paired hosts?'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(SpectraDialog),
        matching: find.text('Forget paired hosts'),
      ),
    );
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));
    expect(find.text('The device forgot its paired hosts.'), findsOneWidget);
  });

  testWidgetsApp('cancelling the forget-bonds confirmation clears no bonds', (
    tester,
  ) async {
    await _openSettings(tester);

    await tester.tap(find.text('Forget paired hosts'));
    await pumpFrames(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraDialog),
        matching: find.text('Cancel'),
      ),
    );
    await pumpFrames(tester);
    expect(find.text('The device forgot its paired hosts.'), findsNothing);
  });

  testWidgetsApp('a failed write is shown through ProblemView', (tester) async {
    await _openSettings(tester);
    readProvider(
      tester,
      deviceSettingsControllerProvider.notifier,
    ).debugFail(const HfTagNotFound());
    await pumpFrames(tester, count: 3);

    expect(find.byType(ProblemView), findsOneWidget);
  });

  testWidgetsApp('a failed save shows no "settings saved" snackbar', (
    tester,
  ) async {
    final FakeDevice device = FakeDevice();
    useDesktopSurface(tester);
    await pumpTestApp(tester, transport: (_) => device);
    await connectToEmulator(tester);
    await tester.tap(find.text('Settings').last);
    await pumpFrames(tester);

    device.failNextWrite();
    await tester.tap(find.text('Save to device'));
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    expect(find.byType(ProblemView), findsOneWidget);
    expect(find.text('Settings saved to the device.'), findsNothing);
  });

  testWidgetsApp('a failed forget-bonds shows no "bonds deleted" snackbar', (
    tester,
  ) async {
    final FakeDevice device = FakeDevice();
    useDesktopSurface(tester);
    await pumpTestApp(tester, transport: (_) => device);
    await connectToEmulator(tester);
    await tester.tap(find.text('Settings').last);
    await pumpFrames(tester);

    await tester.tap(find.text('Forget paired hosts'));
    await pumpFrames(tester);
    device.failNextWrite();
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraDialog),
        matching: find.text('Forget paired hosts'),
      ),
    );
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    expect(find.byType(ProblemView), findsOneWidget);
    expect(find.text('The device forgot its paired hosts.'), findsNothing);
  });
}
