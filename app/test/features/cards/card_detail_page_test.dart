import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/core/routing/routes.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/features/cards/cards.dart';
import 'package:spectra/features/cards/state/card_editor_controller.dart';
import 'package:spectra/features/cards/state/saved_cards_provider.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

Uint8List classic1kBytes() {
  final Uint8List blocks = Uint8List(64 * 16);
  blocks.setRange(0, 4, <int>[0xDE, 0xAD, 0xBE, 0xEF]);
  blocks[4] = 0x22;
  return blocks;
}

Future<String> seedAndOpen(WidgetTester tester) async {
  useDesktopSurface(tester);
  await pumpTestApp(tester, transport: (_) => FakeDevice());
  await connectToEmulator(tester);
  keepAlive(tester, cardLibraryProvider);
  final CardLibrary library = readProvider(
    tester,
    cardLibraryProvider.notifier,
  );
  final Future<String?> pending = library.add(
    name: 'Office badge',
    type: TagType.mifare1k,
    bytes: classic1kBytes(),
    folder: 'Work',
  );
  await tester.pump(const Duration(milliseconds: 20));
  final String id = (await pending)!;
  await tester.tap(find.text('Cards').last);
  await pumpFrames(tester);
  await tester.tap(find.text('Office badge'));
  await pumpFrames(tester);
  return id;
}

void main() {
  testWidgetsApp('the detail screen shows the fields and the hex', (
    tester,
  ) async {
    await seedAndOpen(tester);
    expect(find.byType(CardDetailPage), findsOneWidget);
    expect(find.text('DEADBEEF'), findsWidgets);
    expect(find.byType(SpectraHexViewer), findsOneWidget);
  });

  testWidgetsApp(
    'the back button returns to the library with no unsaved edits',
    (tester) async {
      await seedAndOpen(tester);
      await tester.tap(find.byType(BackButton));
      await pumpFrames(tester);
      expect(find.byType(CardsPage), findsOneWidget);
    },
  );

  testWidgetsApp('deleting a card confirms first, then removes it', (
    tester,
  ) async {
    await seedAndOpen(tester);

    // A 1K dump's hex viewer is 64 rows, so the delete button sits below
    // the fold; scroll it into view before tapping.
    await tester.ensureVisible(find.text('Delete'));
    await pumpFrames(tester);
    await tester.tap(find.text('Delete'));
    await pumpFrames(tester);
    expect(find.byType(SpectraDialog), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(SpectraDialog),
        matching: find.text('Delete'),
      ),
    );
    await pumpFrames(tester, count: 20);

    keepAlive(tester, savedCardsProvider);
    await pumpFrames(tester);
    expect(
      readProvider(tester, savedCardsProvider).value ?? const <Object>[],
      isEmpty,
    );
  });

  testWidgetsApp('an unknown id renders the not-found state', (tester) async {
    useDesktopSurface(tester);
    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await connectToEmulator(tester);
    await tester.tap(find.text('Cards').last);
    await pumpFrames(tester);

    final BuildContext context = tester.element(find.byType(CardsPage));
    GoRouter.of(context).go(AppRoutes.card('nope'));
    await pumpFrames(tester, count: 20);
    expect(find.text('That card is not in the library.'), findsOneWidget);
  });

  testWidgetsApp('editing a block changes the dump and saves it', (
    tester,
  ) async {
    final String id = await seedAndOpen(tester);

    await tester.enterText(find.byKey(const Key('cardEditIndex')), '1');
    await tester.enterText(
      find.byKey(const Key('cardEditValue')),
      '000102030405060708090A0B0C0D0E0F',
    );
    await pumpFrames(tester);
    await tester.ensureVisible(find.text('Apply'));
    await pumpFrames(tester);
    await tester.tap(find.text('Apply'));
    await pumpFrames(tester);

    // In memory only until Save.
    keepAlive(tester, cardEditorProvider(id));
    await pumpFrames(tester);
    final CardEditState edited = readProvider(
      tester,
      cardEditorProvider(id),
    ).value!;
    expect(edited.dirty, isTrue);
    expect(edited.chunk(1), <int>[
      0,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
    ]);

    await tester.ensureVisible(find.text('Save changes'));
    await pumpFrames(tester);
    await tester.tap(find.text('Save changes'));
    await pumpFrames(tester, count: 20);

    final SavedCardsRepository repo = readProvider(
      tester,
      savedCardsRepositoryProvider,
    );
    final SavedCard stored = (await repo.byId(id))!;
    expect(stored.bytes.sublist(16, 32), <int>[
      0,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
    ]);
    expect(readProvider(tester, cardEditorProvider(id)).value!.dirty, isFalse);
  });

  testWidgetsApp('saving keeps the working copy on screen while it writes', (
    tester,
  ) async {
    final String id = await seedAndOpen(tester);
    keepAlive(tester, cardEditorProvider(id));
    await pumpFrames(tester);
    final CardEditor editor = readProvider(
      tester,
      cardEditorProvider(id).notifier,
    );

    // `busy` is set synchronously, before the repository write is awaited
    // — check it before the pending future's own continuation can run and
    // clear it again.
    final Future<void> pending = editor.save();
    final CardEditState busy = readProvider(
      tester,
      cardEditorProvider(id),
    ).value!;
    expect(busy.busy, isTrue);
    expect(busy.card.name, 'Office badge');
    await pumpFrames(tester, count: 20);
    await pending;
    expect(readProvider(tester, cardEditorProvider(id)).value!.busy, isFalse);
  });

  testWidgetsApp('a bad hex value is refused before anything changes', (
    tester,
  ) async {
    final String id = await seedAndOpen(tester);

    await tester.enterText(find.byKey(const Key('cardEditIndex')), '1');
    await tester.enterText(find.byKey(const Key('cardEditValue')), 'zz');
    await pumpFrames(tester);
    await tester.ensureVisible(find.text('Apply'));
    await pumpFrames(tester);
    await tester.tap(find.text('Apply'));
    await pumpFrames(tester);

    expect(find.text('That is not hex.'), findsOneWidget);
    keepAlive(tester, cardEditorProvider(id));
    await pumpFrames(tester);
    expect(readProvider(tester, cardEditorProvider(id)).value!.dirty, isFalse);
  });

  testWidgetsApp('a wrong-length value names the length it needs', (
    tester,
  ) async {
    await seedAndOpen(tester);
    await tester.enterText(find.byKey(const Key('cardEditIndex')), '1');
    await tester.enterText(find.byKey(const Key('cardEditValue')), 'AABB');
    await pumpFrames(tester);
    await tester.ensureVisible(find.text('Apply'));
    await pumpFrames(tester);
    await tester.tap(find.text('Apply'));
    await pumpFrames(tester);
    expect(find.text('This card takes 16 bytes per block.'), findsOneWidget);
  });

  testWidgetsApp('discarding an edit puts the stored bytes back', (
    tester,
  ) async {
    final String id = await seedAndOpen(tester);
    await tester.enterText(find.byKey(const Key('cardEditIndex')), '1');
    await tester.enterText(
      find.byKey(const Key('cardEditValue')),
      '000102030405060708090A0B0C0D0E0F',
    );
    await pumpFrames(tester);
    await tester.ensureVisible(find.text('Apply'));
    await pumpFrames(tester);
    await tester.tap(find.text('Apply'));
    await pumpFrames(tester);

    await tester.ensureVisible(find.text('Discard changes'));
    await pumpFrames(tester);
    await tester.tap(find.text('Discard changes'));
    await pumpFrames(tester, count: 20);

    keepAlive(tester, cardEditorProvider(id));
    await pumpFrames(tester);
    final CardEditState reverted = readProvider(
      tester,
      cardEditorProvider(id),
    ).value!;
    expect(reverted.dirty, isFalse);
    expect(reverted.chunk(1), everyElement(0));
  });

  test('trailerHighlights covers every MIFARE Classic trailer', () {
    final List<SpectraHexHighlight> highlights = trailerHighlights(
      TagType.mifare1k,
      const Color(0xFF000000),
    );
    expect(highlights, hasLength(16));
    expect(highlights.first.start, 3 * 16);
    expect(highlights.first.length, 16);
    expect(trailerHighlights(TagType.em410x, const Color(0xFF000000)), isEmpty);
  });
}
