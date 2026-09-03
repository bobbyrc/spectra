import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/errors/problem_view.dart';
import 'package:spectra/features/dictionaries/state/dictionaries_provider.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

Future<void> _openImport(WidgetTester tester) async {
  useDesktopSurface(tester);
  await pumpTestApp(tester);
  await connectToEmulator(tester);
  await openDictionaries(tester);
  await tester.tap(find.text('Import'));
  await pumpFrames(tester);
}

Future<void> _paste(WidgetTester tester, String text) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(SpectraBottomSheet),
      matching: find.byType(SpectraTextField),
    ),
    text,
  );
  await tester.pump();
  await tester.tap(
    find.descendant(
      of: find.byType(SpectraBottomSheet),
      matching: find.text('Import'),
    ),
  );
  await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));
}

void main() {
  testWidgetsApp('imports a pasted key list', (tester) async {
    await _openImport(tester);
    await _paste(tester, 'FFFFFFFFFFFF\nA0A1A2A3A4A5\n');

    expect(find.byType(SpectraBottomSheet), findsNothing);
    expect(readProvider(tester, dictionariesProvider).value, hasLength(2));
  });

  testWidgetsApp('imports the reference app JSON shape', (tester) async {
    await _openImport(tester);
    await _paste(
      tester,
      '{"dictionaries":[{"name":"Transport","keys":["FFFFFFFFFFFF"]}]}',
    );

    expect(find.text('Transport'), findsOneWidget);
  });

  testWidgetsApp('words a malformed paste without writing anything', (
    tester,
  ) async {
    await _openImport(tester);
    keepAlive(tester, dictionaryLibraryProvider);
    await _paste(tester, 'FFFFFFFFFFFF\nnot-a-key');

    expect(
      find.text('One of those keys is not 12 hexadecimal characters.'),
      findsOneWidget,
    );
    expect(readProvider(tester, dictionariesProvider).value, hasLength(1));
    // A bad paste is a typed `DictionaryImportException`, worded in the
    // sheet's own field — it must not also poison the notifier's shared
    // `AsyncValue` state, which would show a generic `ProblemView` on the
    // dictionaries list page behind the sheet.
    expect(
      readProvider(tester, dictionaryLibraryProvider),
      isA<AsyncData<void>>(),
    );
    expect(find.byType(ProblemView), findsNothing);
  });

  testWidgetsApp('a repository failure is shown through ProblemView, not as a '
      'parse failure', (tester) async {
    await _openImport(tester);
    keepAlive(tester, dictionaryLibraryProvider);
    readProvider(
      tester,
      dictionaryLibraryProvider.notifier,
    ).debugFail(StateError('disk full'));
    await pumpFrames(tester, count: 3);

    expect(find.text('That is not a key list Spectra can read.'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(ProblemView),
      ),
      findsOneWidget,
    );
  });

  testWidgetsApp('a double tap never closes the sheet claiming an import '
      'happened', (tester) async {
    await _openImport(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(SpectraTextField),
      ),
      'FFFFFFFFFFFF',
    );
    await tester.pump();
    final Finder confirm = find.descendant(
      of: find.byType(SpectraBottomSheet),
      matching: find.text('Import'),
    );
    await tester.tap(confirm);
    await tester.tap(confirm);
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    expect(find.byType(SpectraBottomSheet), findsNothing);
    // Exactly one list was written, never two: the second tap must not
    // have dispatched a second import.
    expect(readProvider(tester, dictionariesProvider).value, hasLength(2));
  });
}
