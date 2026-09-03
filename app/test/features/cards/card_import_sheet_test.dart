import 'dart:io';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/features/cards/state/saved_cards_provider.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

Future<void> openImport(WidgetTester tester) async {
  useDesktopSurface(tester);
  await pumpTestApp(tester, transport: (_) => FakeDevice());
  await connectToEmulator(tester);
  await tester.tap(find.text('Cards').last);
  await pumpFrames(tester);
  await tester.tap(find.text('Import'));
  await pumpFrames(tester);
}

void main() {
  testWidgetsApp('pasting the fixture puts a card in the library', (
    tester,
  ) async {
    await openImport(tester);
    final String fixture = File('test/fixtures/reference_card_mifare_mini.json')
        .readAsStringSync();

    await tester.enterText(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(SpectraTextField),
      ),
      fixture,
    );
    await pumpFrames(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Import'),
      ),
    );
    await pumpFrames(tester, count: 20);

    keepAlive(tester, savedCardsProvider);
    await pumpFrames(tester);
    final List<SavedCard> cards =
        readProvider(tester, savedCardsProvider).value ?? const <SavedCard>[];
    expect(cards, hasLength(1));
    expect(cards.single.name, 'Reference Mini');
    expect(cards.single.tagType, 'mifareMini');
    expect(cards.single.bytes, hasLength(20 * 16));
    expect(cards.single.folder, 'Imported');
    expect(find.text('Reference Mini'), findsOneWidget);
  });

  testWidgetsApp('an unreadable paste explains itself and writes nothing', (
    tester,
  ) async {
    await openImport(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(SpectraTextField),
      ),
      'not json at all',
    );
    await pumpFrames(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Import'),
      ),
    );
    await pumpFrames(tester);

    expect(
      find.text('That text is not a card export Spectra can read.'),
      findsOneWidget,
    );
    keepAlive(tester, savedCardsProvider);
    await pumpFrames(tester);
    expect(
      readProvider(tester, savedCardsProvider).value ?? const <Object>[],
      isEmpty,
    );
  });

  testWidgetsApp('an unsupported tag type says which one', (tester) async {
    await openImport(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(SpectraTextField),
      ),
      '{"name":"x","tag":"iso15693","data":[]}',
    );
    await pumpFrames(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Import'),
      ),
    );
    await pumpFrames(tester);
    expect(
      find.textContaining('Spectra cannot read that tag type'),
      findsOneWidget,
    );
  });

  testWidgetsApp('the Import button starts disabled with nothing pasted', (
    tester,
  ) async {
    await openImport(tester);
    final Finder confirm = find.descendant(
      of: find.byType(SpectraBottomSheet),
      matching: find.widgetWithText(SpectraButton, 'Import'),
    );
    expect(
      (confirm.evaluate().single.widget as SpectraButton).onPressed,
      isNull,
    );

    await tester.enterText(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(SpectraTextField),
      ),
      '{"name":"x"}',
    );
    await pumpFrames(tester);
    expect(
      (confirm.evaluate().single.widget as SpectraButton).onPressed,
      isNotNull,
    );
  });

  testWidgetsApp('a dispose mid-import does not crash', (tester) async {
    useDesktopSurface(tester);
    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await connectToEmulator(tester);
    final ProviderSubscription<AsyncValue<void>> sub = keepAlive(
      tester,
      cardLibraryProvider,
    );
    final CardLibrary library = readProvider(
      tester,
      cardLibraryProvider.notifier,
    );
    final String fixture = File('test/fixtures/reference_card_mifare_mini.json')
        .readAsStringSync();

    final Future<int> pending = library.importJson(fixture);
    // Dispose the notifier while the write is still on the wire.
    sub.close();
    await pumpFrames(tester, count: 5);

    // The write itself must not throw even though nothing is left to
    // report its outcome to (Phase 6 ruling 2).
    await pending;
  });
}
