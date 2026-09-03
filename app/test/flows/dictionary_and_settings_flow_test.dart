import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/core/session/session_streams.dart';
import 'package:spectra/features/dictionaries/state/selected_dictionary.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/app_harness.dart';

/// The roadmap's Phase 9 gate: edit a key list and change a device setting,
/// in emulator mode, through the real `DeviceSession`.
void main() {
  testWidgetsApp('create a key list, add a key, use it, then set the '
      'animation mode', (tester) async {
    useDesktopSurface(tester);
    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await tester.pump();
    await connectToEmulator(tester);

    // A key list of our own.
    await openDictionaries(tester);
    await tester.tap(find.text('New list'));
    await pumpFrames(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(SpectraTextField),
      ),
      'Hotel',
    );
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Save'),
      ),
    );
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    // A key in it.
    await tester.tap(find.text('Hotel'));
    await pumpFrames(tester);
    await tester.enterText(find.byType(SpectraTextField).last, '714C5C886E97');
    await tester.pump();
    await tester.tap(find.text('Add key'));
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));
    expect(find.text('714C5C886E97'), findsOneWidget);

    // And it is the list a read will use.
    await tester.tap(find.byType(BackButton));
    await pumpFrames(tester);
    await tester.tap(find.text('Use these keys').last);
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));
    // candidateMifareKeysProvider is autoDispose and nothing in the app
    // keeps a listener on it outside of a read; keep it alive here so the
    // read below sees its resolved value instead of the first
    // `AsyncLoading` frame (ruling 20).
    keepAlive(tester, candidateMifareKeysProvider);
    await pumpFrames(tester);
    expect(
      readProvider(tester, candidateMifareKeysProvider).value,
      hasLength(1),
    );

    // A device setting, on the emulated device.
    await tester.tap(find.text('Settings').last);
    await pumpFrames(tester);
    await tester.tap(find.text('Start-up animation'));
    await pumpFrames(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('None'),
      ),
    );
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));
    await tester.tap(find.text('Save to device'));
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    expect(
      readProvider(tester, settingsProvider).value!.animation,
      AnimationMode.none,
    );
  });
}
