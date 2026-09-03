import 'dart:io';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/app.dart';
import 'package:spectra/core/errors/problem_view.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/data/memory/in_memory_repositories.dart';
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

/// Delegates everything but `save`, which throws on its second call — for
/// exercising [ImportOutcome]'s partial-write case: card 1 of 2 lands,
/// card 2 fails, and the sheet has to be honest about both halves.
final class _FailsOnSecondSaveRepository implements SavedCardsRepository {
  _FailsOnSecondSaveRepository(this._delegate);
  final SavedCardsRepository _delegate;
  int _saves = 0;

  @override
  Future<List<SavedCard>> all() => _delegate.all();

  @override
  Future<SavedCard?> byId(String id) => _delegate.byId(id);

  @override
  Future<void> save(SavedCard card) async {
    _saves++;
    if (_saves == 2) throw const SessionNotReady('boom');
    return _delegate.save(card);
  }

  @override
  Future<void> delete(String id) => _delegate.delete(id);

  @override
  Stream<List<SavedCard>> watchAll() => _delegate.watchAll();
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

    final Future<ImportOutcome> pending = library.importJson(fixture);
    // Dispose the notifier while the write is still on the wire.
    sub.close();
    await pumpFrames(tester, count: 5);

    // The write itself must not throw even though nothing is left to
    // report its outcome to (Phase 6 ruling 2).
    await pending;
  });

  testWidgetsApp(
    'a failure partway through reports what was written and what broke',
    (tester) async {
      useDesktopSurface(tester);
      final SavedCardsRepository failing = _FailsOnSecondSaveRepository(
        InMemorySavedCardsRepository(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            ...appOverrides(transport: (_) => FakeDevice()),
            savedCardsRepositoryProvider.overrideWithValue(failing),
          ],
          child: const SpectraRoot(),
        ),
      );
      await connectToEmulator(tester);
      await tester.tap(find.text('Cards').last);
      await pumpFrames(tester);
      await tester.tap(find.text('Import'));
      await pumpFrames(tester);

      await tester.enterText(
        find.descendant(
          of: find.byType(SpectraBottomSheet),
          matching: find.byType(SpectraTextField),
        ),
        '{"cards":[{"name":"A","tag":"mifare1k","data":["00"]},'
        '{"name":"B","tag":"mifare1k","data":["00"]}]}',
      );
      await pumpFrames(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(SpectraBottomSheet),
          matching: find.text('Import'),
        ),
      );
      await pumpFrames(tester, count: 20);

      // The sheet stays open — a partial import never pops the sheet —
      // and shows both the honest count and the problem that stopped it.
      expect(find.byType(SpectraBottomSheet), findsOneWidget);
      expect(find.text('Imported 1 card.'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SpectraBottomSheet),
          matching: find.byType(ProblemView),
        ),
        findsOneWidget,
      );

      keepAlive(tester, savedCardsProvider);
      await pumpFrames(tester);
      final List<SavedCard> cards =
          readProvider(tester, savedCardsProvider).value ?? const <SavedCard>[];
      expect(cards, hasLength(1));
      expect(cards.single.name, 'A');
    },
  );
}
