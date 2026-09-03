import 'dart:convert';

import 'package:chameleon/chameleon.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/app.dart';
import 'package:spectra/core/errors/problem_view.dart';
import 'package:spectra/core/routing/routes.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/data/memory/in_memory_repositories.dart';
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

/// Delegates to another [SavedCardsRepository], but [save] throws once
/// while [failNextSave] is true — for exercising [CardEditor.save]'s
/// failure path (ruling 29 item 1) without a fake device that can fail a
/// write.
final class _FlakySavedCardsRepository implements SavedCardsRepository {
  _FlakySavedCardsRepository(this._delegate);
  final SavedCardsRepository _delegate;
  bool failNextSave = false;
  bool failNextById = false;
  bool failNextDelete = false;

  @override
  Future<List<SavedCard>> all() => _delegate.all();

  @override
  Future<SavedCard?> byId(String id) async {
    if (failNextById) {
      failNextById = false;
      throw const SessionNotReady('boom');
    }
    return _delegate.byId(id);
  }

  @override
  Future<void> save(SavedCard card) async {
    if (failNextSave) {
      failNextSave = false;
      throw const SessionNotReady('boom');
    }
    return _delegate.save(card);
  }

  @override
  Future<void> delete(String id) async {
    if (failNextDelete) {
      failNextDelete = false;
      throw const SessionNotReady('boom');
    }
    return _delegate.delete(id);
  }

  @override
  Stream<List<SavedCard>> watchAll() => _delegate.watchAll();
}

Future<String> seedAndOpen(
  WidgetTester tester, {
  List<Override> extraOverrides = const <Override>[],
}) async {
  useDesktopSurface(tester);
  if (extraOverrides.isEmpty) {
    await pumpTestApp(tester, transport: (_) => FakeDevice());
  } else {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ...appOverrides(transport: (_) => FakeDevice()),
          ...extraOverrides,
        ],
        child: const SpectraRoot(),
      ),
    );
  }
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
    // Only block 1 was edited; block 0 (the UID and its BCC) reaches the
    // repository untouched.
    expect(stored.bytes.sublist(0, 5), <int>[0xDE, 0xAD, 0xBE, 0xEF, 0x22]);
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

  testWidgetsApp('an out-of-range block number is refused', (tester) async {
    await seedAndOpen(tester);
    await tester.enterText(find.byKey(const Key('cardEditIndex')), '64');
    await tester.enterText(
      find.byKey(const Key('cardEditValue')),
      '000102030405060708090A0B0C0D0E0F',
    );
    await pumpFrames(tester);
    await tester.ensureVisible(find.text('Apply'));
    await pumpFrames(tester);
    await tester.tap(find.text('Apply'));
    await pumpFrames(tester);
    // A 1K card has 64 blocks, indices 0-63.
    expect(find.text('Choose a number between 0 and 63.'), findsOneWidget);
  });

  testWidgetsApp('leaving the screen with unsaved edits asks first', (
    tester,
  ) async {
    await seedAndOpen(tester);
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

    await tester.tap(find.byType(BackButton));
    await pumpFrames(tester);
    expect(find.byType(SpectraDialog), findsOneWidget);
    expect(find.text('Leave without saving?'), findsOneWidget);
    // Still on the detail screen: the pop was intercepted, not let
    // through.
    expect(find.byType(CardDetailPage), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(SpectraDialog),
        matching: find.text('Discard changes'),
      ),
    );
    await pumpFrames(tester);
    expect(find.byType(CardsPage), findsOneWidget);
  });

  testWidgetsApp('a validation problem in the working copy blocks Save', (
    tester,
  ) async {
    final String id = await seedAndOpen(tester);
    // Change the UID in block 0 without updating its BCC (byte 4):
    // `validateSavedCard` rejects a MIFARE Classic dump whose BCC does
    // not match its UID.
    await tester.enterText(find.byKey(const Key('cardEditIndex')), '0');
    await tester.enterText(
      find.byKey(const Key('cardEditValue')),
      'AABBCCDD22'.padRight(32, '0'),
    );
    await pumpFrames(tester);
    await tester.ensureVisible(find.text('Apply'));
    await pumpFrames(tester);
    await tester.tap(find.text('Apply'));
    await pumpFrames(tester);

    expect(find.textContaining('does not match UID'), findsOneWidget);

    await tester.ensureVisible(find.text('Save changes'));
    await pumpFrames(tester);
    await tester.tap(find.text('Save changes'));
    await pumpFrames(tester, count: 20);

    final SavedCardsRepository repo = readProvider(
      tester,
      savedCardsRepositoryProvider,
    );
    final SavedCard stored = (await repo.byId(id))!;
    // The stored bytes are untouched — the write never happened.
    expect(stored.bytes.sublist(0, 5), <int>[0xDE, 0xAD, 0xBE, 0xEF, 0x22]);
    keepAlive(tester, cardEditorProvider(id));
    await pumpFrames(tester);
    expect(readProvider(tester, cardEditorProvider(id)).value!.dirty, isTrue);
  });

  testWidgetsApp('a failed save keeps the edits, and Try again saves them', (
    tester,
  ) async {
    final _FlakySavedCardsRepository repo = _FlakySavedCardsRepository(
      InMemorySavedCardsRepository(),
    );
    final String id = await seedAndOpen(
      tester,
      extraOverrides: <Override>[
        savedCardsRepositoryProvider.overrideWithValue(repo),
      ],
    );
    // Only the edit's own save should fail, not the seed's.
    repo.failNextSave = true;

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

    await tester.ensureVisible(find.text('Save changes'));
    await pumpFrames(tester);
    await tester.tap(find.text('Save changes'));
    await pumpFrames(tester, count: 20);

    // The write failed: ProblemView is up, and the edits are still on
    // the working copy — not lost, not written.
    expect(find.byType(ProblemView), findsOneWidget);
    final SavedCard unwritten = (await repo.byId(id))!;
    expect(unwritten.bytes.sublist(16, 32), everyElement(0));
    keepAlive(tester, cardEditorProvider(id));
    await pumpFrames(tester);
    final CardEditState afterFailure = readProvider(
      tester,
      cardEditorProvider(id),
    ).value!;
    expect(afterFailure.dirty, isTrue);
    expect(afterFailure.chunk(1), <int>[
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

    // "Try again" re-invokes save, not discard: the repository now
    // succeeds, so the edits land.
    await tester.ensureVisible(find.text('Try again'));
    await pumpFrames(tester);
    await tester.tap(find.text('Try again'));
    await pumpFrames(tester, count: 20);

    expect(find.byType(ProblemView), findsNothing);
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

  testWidgetsApp('copies the card as JSON and confirms it', (tester) async {
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

    await seedAndOpen(tester);
    await tester.ensureVisible(find.text('Copy as JSON'));
    await pumpFrames(tester);
    await tester.tap(find.text('Copy as JSON'));
    await pumpFrames(tester);

    expect(clipboard, hasLength(1));
    final Map<String, Object?> args =
        clipboard.single.arguments as Map<String, Object?>;
    final Map<String, Object?> exported =
        jsonDecode(args['text']! as String) as Map<String, Object?>;
    final List<Object?> cards = exported['cards']! as List<Object?>;
    expect(cards, hasLength(1));
    expect((cards.single as Map<String, Object?>)['name'], 'Office badge');
    expect(find.text('Copied to the clipboard.'), findsOneWidget);
  });

  testWidgetsApp('a failed discard surfaces the failure and keeps the edits', (
    tester,
  ) async {
    final _FlakySavedCardsRepository repo = _FlakySavedCardsRepository(
      InMemorySavedCardsRepository(),
    );
    final String id = await seedAndOpen(
      tester,
      extraOverrides: <Override>[
        savedCardsRepositoryProvider.overrideWithValue(repo),
      ],
    );
    keepAlive(tester, cardEditorProvider(id));
    await pumpFrames(tester);
    final CardEditor editor = readProvider(
      tester,
      cardEditorProvider(id).notifier,
    );
    editor.replaceChunk(1, Uint8List(16)..[0] = 0xAB);

    repo.failNextById = true;
    await editor.discard();
    await pumpFrames(tester);

    final CardEditState afterFailure = readProvider(
      tester,
      cardEditorProvider(id),
    ).value!;
    expect(afterFailure.error, isA<SessionNotReady>());
    expect(afterFailure.busy, isFalse);
    expect(afterFailure.dirty, isTrue);
    expect(afterFailure.chunk(1).first, 0xAB);
    expect(find.byType(ProblemView), findsOneWidget);

    // The notifier is not wedged: the next write still runs.
    final Future<void> pending = editor.save();
    await pumpFrames(tester, count: 20);
    await pending;
    final SavedCard stored = (await repo.byId(id))!;
    expect(stored.bytes[16], 0xAB);
  });

  testWidgetsApp('a failed delete surfaces the failure and unwedges', (
    tester,
  ) async {
    final _FlakySavedCardsRepository repo = _FlakySavedCardsRepository(
      InMemorySavedCardsRepository(),
    );
    final String id = await seedAndOpen(
      tester,
      extraOverrides: <Override>[
        savedCardsRepositoryProvider.overrideWithValue(repo),
      ],
    );
    keepAlive(tester, cardEditorProvider(id));
    await pumpFrames(tester);
    final CardEditor editor = readProvider(
      tester,
      cardEditorProvider(id).notifier,
    );

    repo.failNextDelete = true;
    await editor.deleteCard();
    await pumpFrames(tester);

    final CardEditState afterFailure = readProvider(
      tester,
      cardEditorProvider(id),
    ).value!;
    expect(afterFailure.error, isA<SessionNotReady>());
    expect(afterFailure.busy, isFalse);
    // The card is still there — the delete never happened.
    expect(await repo.byId(id), isNotNull);

    // A subsequent save still works: `_inFlight` was reset on the failure.
    editor.replaceChunk(1, Uint8List(16)..[0] = 0xCD);
    final Future<void> pending = editor.save();
    await pumpFrames(tester, count: 20);
    await pending;
    expect((await repo.byId(id))!.bytes[16], 0xCD);
  });

  testWidgetsApp('an Apply during an in-flight save is dropped', (
    tester,
  ) async {
    final String id = await seedAndOpen(tester);
    keepAlive(tester, cardEditorProvider(id));
    await pumpFrames(tester);
    final CardEditor editor = readProvider(
      tester,
      cardEditorProvider(id).notifier,
    );

    // `save` takes `_inFlight` synchronously, before its first await, so
    // everything up to the next pump runs while the write is in flight.
    final Future<void> pending = editor.save();
    editor.replaceChunk(1, Uint8List(16)..[0] = 0xEE);
    expect(
      readProvider(tester, cardEditorProvider(id)).value!.chunk(1),
      everyElement(0),
    );
    await pumpFrames(tester, count: 20);
    await pending;

    final SavedCardsRepository repo = readProvider(
      tester,
      savedCardsRepositoryProvider,
    );
    expect((await repo.byId(id))!.bytes[16], 0);
  });

  testWidgetsApp('Edit details renames, re-folders and re-colours the card', (
    tester,
  ) async {
    final String id = await seedAndOpen(tester);

    await tester.ensureVisible(find.text('Edit details'));
    await pumpFrames(tester);
    await tester.tap(find.text('Edit details'));
    await pumpFrames(tester);

    // The form comes up prefilled with what is stored. Its fields are
    // found through the sheet (ruling 8/10): the screen underneath has
    // text fields of its own.
    final Finder fields = find.descendant(
      of: find.byType(SpectraBottomSheet),
      matching: find.byType(SpectraTextField),
    );
    expect(
      find.descendant(of: fields.at(0), matching: find.text('Office badge')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: fields.at(1), matching: find.text('Work')),
      findsWidgets,
    );

    await tester.enterText(fields.at(0), 'Front door');
    await tester.enterText(fields.at(1), 'Home');
    await pumpFrames(tester);
    await tester.tap(find.bySemanticsLabel('Colour 3'));
    await pumpFrames(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Save'),
      ),
    );
    await pumpFrames(tester, count: 20);

    final SavedCardsRepository repo = readProvider(
      tester,
      savedCardsRepositoryProvider,
    );
    final SavedCard stored = (await repo.byId(id))!;
    expect(stored.name, 'Front door');
    expect(stored.folder, 'Home');
    expect(stored.color, cardColors[2]);
    // The dump is untouched by a details edit.
    expect(stored.bytes.sublist(0, 5), <int>[0xDE, 0xAD, 0xBE, 0xEF, 0x22]);

    // The screen it came from reflects the new name…
    expect(find.text('Front door'), findsWidgets);
    // …and so does the library row.
    await tester.tap(find.byType(BackButton));
    await pumpFrames(tester);
    expect(find.byType(CardsPage), findsOneWidget);
    expect(find.text('Front door'), findsOneWidget);
    expect(find.text('Office badge'), findsNothing);
  });

  testWidgetsApp('the colour swatches announce themselves distinctly', (
    tester,
  ) async {
    await seedAndOpen(tester);
    await tester.ensureVisible(find.text('Edit details'));
    await pumpFrames(tester);
    await tester.tap(find.text('Edit details'));
    await pumpFrames(tester);

    // Seven swatches, seven distinct labels, and the chosen one says so.
    expect(find.bySemanticsLabel('Colour 1, selected'), findsOne);
    for (int i = 2; i <= cardColors.length; i++) {
      expect(find.bySemanticsLabel('Colour $i'), findsOne);
    }

    await tester.tap(find.bySemanticsLabel('Colour 4'));
    await pumpFrames(tester);
    expect(find.bySemanticsLabel('Colour 4, selected'), findsOne);
    expect(find.bySemanticsLabel('Colour 1'), findsOne);
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
