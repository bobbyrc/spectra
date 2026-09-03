import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/features/dictionaries/state/dictionaries_provider.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

/// Creates a list called Hotel and opens it. Returns nothing: every test
/// below asserts on what is on screen.
Future<void> _openHotel(WidgetTester tester) async {
  useDesktopSurface(tester);
  await pumpTestApp(tester);
  await connectToEmulator(tester);
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
  await tester.tap(find.text('Hotel'));
  await pumpFrames(tester);
}

Future<void> _addKey(WidgetTester tester, String key) async {
  await tester.enterText(find.byType(SpectraTextField).last, key);
  await tester.pump();
  await tester.tap(find.text('Add key'));
  await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));
}

void main() {
  testWidgetsApp('adds a key and shows it', (tester) async {
    await _openHotel(tester);
    expect(find.text('This list has no keys yet.'), findsOneWidget);

    await _addKey(tester, 'A0A1A2A3A4A5');

    expect(find.text('A0A1A2A3A4A5'), findsOneWidget);
    expect(find.text('This list has no keys yet.'), findsNothing);
  });

  testWidgetsApp('rejects a key of the wrong length', (tester) async {
    await _openHotel(tester);
    await _addKey(tester, 'A0A1A2');

    expect(find.text('A key is 12 hexadecimal characters.'), findsOneWidget);
  });

  testWidgetsApp('rejects a key the list already holds', (tester) async {
    await _openHotel(tester);
    await _addKey(tester, 'A0A1A2A3A4A5');
    await _addKey(tester, 'a0a1a2a3a4a5');

    expect(find.text('That key is already in this list.'), findsOneWidget);
    expect(find.text('A0A1A2A3A4A5'), findsOneWidget);
  });

  testWidgetsApp('removes a key', (tester) async {
    await _openHotel(tester);
    await _addKey(tester, 'A0A1A2A3A4A5');

    await tester.tap(find.byTooltip('Remove key'));
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    expect(find.text('A0A1A2A3A4A5'), findsNothing);
  });

  testWidgetsApp('renames the list', (tester) async {
    await _openHotel(tester);

    await tester.tap(find.text('Rename'));
    await pumpFrames(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(SpectraTextField),
      ),
      'Office',
    );
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Save'),
      ),
    );
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    expect(find.text('Office'), findsWidgets);
  });

  testWidgetsApp('deletes the list and returns to the list screen', (
    tester,
  ) async {
    await _openHotel(tester);

    await tester.tap(find.text('Delete list'));
    await pumpFrames(tester);
    await tester.tap(find.text('Delete list').last);
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    expect(find.text('No key lists of your own yet.'), findsOneWidget);
  });

  testWidgetsApp('the built-in list is read-only and can be duplicated', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await pumpTestApp(tester);
    await connectToEmulator(tester);
    await openDictionaries(tester);

    await tester.tap(find.text('Default keys'));
    await pumpFrames(tester);

    expect(
      find.text(
        'Built in and read-only. Duplicate it to make a list you can edit.',
      ),
      findsOneWidget,
    );
    expect(find.text('Add key'), findsNothing);
    expect(find.text('Delete list'), findsNothing);

    await tester.tap(find.text('Duplicate'));
    await pumpFrames(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Save'),
      ),
    );
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    expect(find.text('Default keys copy'), findsWidgets);
  });

  testWidgetsApp('copies the list as .dic and confirms it', (tester) async {
    final List<MethodCall> clipboard = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') clipboard.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await _openHotel(tester);
    await _addKey(tester, 'A0A1A2A3A4A5');

    await tester.tap(find.text('Copy list'));
    await pumpFrames(tester);

    expect(clipboard, hasLength(1));
    final Map<String, Object?> args =
        clipboard.single.arguments as Map<String, Object?>;
    // The `.dic` form — one key per line behind a `# <name>` comment, not
    // the whole-library JSON shape `app_settings_section.dart`'s export
    // uses.
    expect(args['text'], '# Hotel\nA0A1A2A3A4A5');
    expect(find.text('List copied to the clipboard.'), findsOneWidget);
  });

  testWidgetsApp('a failed write shows the shared problem view', (
    tester,
  ) async {
    await _openHotel(tester);

    readProvider(
      tester,
      dictionaryLibraryProvider.notifier,
    ).debugFail(StateError('disk full'));
    await pumpFrames(tester, count: 3);

    // `StateError` is not a `ChameleonException`, so `ErrorCatalog` falls
    // through to its generic fallback rather than `errorBackgroundTask`
    // (matches `dictionaries_page_test.dart`'s identical assertion).
    expect(find.text('Something unexpected went wrong.'), findsOneWidget);
  });
}
