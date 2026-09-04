import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/app.dart';
import 'package:spectra/core/errors/problem_view.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/features/cards/cards.dart';
import 'package:spectra/features/cards/state/saved_cards_provider.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

/// A repository whose [watchAll] always fails, for the picker's error path
/// (R32).
final class _BrokenStreamRepository implements SavedCardsRepository {
  @override
  Future<List<SavedCard>> all() async => <SavedCard>[];

  @override
  Future<SavedCard?> byId(String id) async => null;

  @override
  Future<void> save(SavedCard card) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Stream<List<SavedCard>> watchAll() =>
      Stream<List<SavedCard>>.error(const SessionNotReady('boom'));
}

Future<CardLibrary> openCards(
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
  await tester.tap(find.text('Cards').last);
  await pumpFrames(tester);
  return readProvider(tester, cardLibraryProvider.notifier);
}

Future<void> add(
  WidgetTester tester,
  CardLibrary library,
  String name,
  TagType type,
) async {
  final Future<String?> pending = library.add(
    name: name,
    type: type,
    bytes: Uint8List(type == TagType.em410x ? 5 : 64 * 16),
  );
  await tester.pump(const Duration(milliseconds: 20));
  await pending;
  await pumpFrames(tester);
}

void main() {
  testWidgetsApp('a broken library stream shows the problem in the picker', (
    tester,
  ) async {
    await openCards(
      tester,
      extraOverrides: <Override>[
        savedCardsRepositoryProvider.overrideWithValue(
          _BrokenStreamRepository(),
        ),
      ],
    );
    final BuildContext context = tester.element(find.byType(CardsPage));
    final Future<SavedCard?> pending = showCardPicker(context);
    await pumpFrames(tester);

    expect(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(ProblemView),
      ),
      findsOneWidget,
    );
    expect(
      find.text('No cards yet. Read one, or import from another app.'),
      findsNothing,
    );

    await tester.tap(find.byIcon(Icons.close));
    await pumpFrames(tester);
    expect(await pending, isNull);
  });

  testWidgetsApp('the picker resolves to the chosen card', (tester) async {
    final CardLibrary library = await openCards(tester);
    await add(tester, library, 'Office badge', TagType.mifare1k);

    SavedCard? chosen;
    final BuildContext context = tester.element(find.byType(CardsPage));
    final Future<SavedCard?> pending = showCardPicker(context)
        .then((SavedCard? c) {
          chosen = c;
          return c;
        });
    await pumpFrames(tester);
    expect(find.text('Choose a card'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Office badge'),
      ),
    );
    await pumpFrames(tester);
    await pending;
    expect(chosen!.name, 'Office badge');
    expect(chosen!.tagType, 'mifare1k');
  });

  testWidgetsApp('dismissing the picker resolves to null', (tester) async {
    final CardLibrary library = await openCards(tester);
    await add(tester, library, 'Office badge', TagType.mifare1k);

    final BuildContext context = tester.element(find.byType(CardsPage));
    final Future<SavedCard?> pending = showCardPicker(context);
    await pumpFrames(tester);
    await tester.tap(find.byIcon(Icons.close));
    await pumpFrames(tester);
    expect(await pending, isNull);
  });

  testWidgetsApp('isSelectable greys out the cards a caller cannot use', (
    tester,
  ) async {
    final CardLibrary library = await openCards(tester);
    await add(tester, library, 'Office badge', TagType.mifare1k);
    await add(tester, library, 'Gate fob', TagType.em410x);

    final BuildContext context = tester.element(find.byType(CardsPage));
    final Future<SavedCard?> pending = showCardPicker(
      context,
      isSelectable: (SavedCard c) =>
          tagTypeFromName(c.tagType).family == TagFamily.mifareClassic,
    );
    await pumpFrames(tester);

    final Iterable<SpectraListTile> tiles = tester.widgetList<SpectraListTile>(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(SpectraListTile),
      ),
    );
    expect(
      tiles.firstWhere((SpectraListTile t) => t.title == 'Office badge').onTap,
      isNotNull,
    );
    expect(
      tiles.firstWhere((SpectraListTile t) => t.title == 'Gate fob').onTap,
      isNull,
    );

    await tester.tap(find.byIcon(Icons.close));
    await pumpFrames(tester);
    await pending;
  });

  testWidgetsApp('an empty library shows the empty state', (tester) async {
    await openCards(tester);
    final BuildContext context = tester.element(find.byType(CardsPage));
    final Future<SavedCard?> pending = showCardPicker(context);
    await pumpFrames(tester);
    expect(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text(
          'No cards yet. Read one, or import from another app.',
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(Icons.close));
    await pumpFrames(tester);
    await pending;
  });
}
