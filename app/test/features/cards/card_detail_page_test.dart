import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/core/routing/routes.dart';
import 'package:spectra/features/cards/cards.dart';
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
