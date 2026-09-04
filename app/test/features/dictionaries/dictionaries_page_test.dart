import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/features/dictionaries/state/dictionaries_provider.dart';
import 'package:spectra/features/dictionaries/state/selected_dictionary.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

Future<void> _createList(WidgetTester tester, String name) async {
  await tester.tap(find.text('New list'));
  await pumpFrames(tester);
  await tester.enterText(
    find.descendant(
      of: find.byType(SpectraBottomSheet),
      matching: find.byType(SpectraTextField),
    ),
    name,
  );
  await tester.pump();
  await tester.tap(
    find.descendant(
      of: find.byType(SpectraBottomSheet),
      matching: find.text('Save'),
    ),
  );
  await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));
}

void main() {
  testWidgetsApp('lists the built-in dictionary and says it is in use', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await pumpTestApp(tester);
    await connectToEmulator(tester);
    await openDictionaries(tester);

    expect(find.text('Default keys'), findsOneWidget);
    expect(find.text('Used for reading and writing'), findsOneWidget);
    expect(find.text('No key lists of your own yet.'), findsOneWidget);
  });

  testWidgetsApp('creates a list from the sheet', (tester) async {
    useDesktopSurface(tester);
    await pumpTestApp(tester);
    await connectToEmulator(tester);
    await openDictionaries(tester);

    await _createList(tester, 'Hotel');

    expect(find.text('Hotel'), findsOneWidget);
    expect(find.text('No keys'), findsOneWidget);
    expect(find.text('No key lists of your own yet.'), findsNothing);
  });

  testWidgetsApp('choosing a list makes it the one reads use', (tester) async {
    useDesktopSurface(tester);
    await pumpTestApp(tester);
    await connectToEmulator(tester);
    await openDictionaries(tester);
    await _createList(tester, 'Hotel');

    await tester.tap(find.text('Use these keys').last);
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    expect(
      readProvider(tester, selectedDictionaryProvider).value!.name,
      'Hotel',
    );
  });

  testWidgetsApp('a failed write is shown through the shared problem view', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await pumpTestApp(tester);
    await connectToEmulator(tester);
    await openDictionaries(tester);

    readProvider(
      tester,
      dictionaryLibraryProvider.notifier,
    ).debugFail(StateError('disk full'));
    await pumpFrames(tester, count: 3);

    // `StateError` is not a `ChameleonException`, so `ErrorCatalog` falls
    // through to its generic fallback rather than `errorBackgroundTask`
    // (that copy is reserved for the SDK's own `BackgroundTaskFailed`).
    expect(find.text('Something unexpected went wrong.'), findsOneWidget);
  });
}
