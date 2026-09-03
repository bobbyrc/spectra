import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/data/data.dart';
import 'package:spectra/features/cards/state/saved_cards_provider.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/app_harness.dart';

/// The roadmap's Phase 6 gate: scan a fake card, save it, edit it, import
/// the reference-app fixture. `testWidgetsApp` (not plain `testWidgets`) so
/// the app root's stream-backed screens settle cleanly on teardown.
void main() {
  testWidgetsApp('scan, save, edit, import', (tester) async {
    useDesktopSurface(tester);

    // The production transport factory, so the emulated device's own demo
    // cards are what gets read (Task 12, ruling 25).
    await pumpTestApp(tester);
    await connectToEmulator(tester);
    expect(find.byType(SpectraAppShell), findsOneWidget);

    // 1. Scan. The Read screen is pushed on top of the Cards branch's own
    // navigator (a `SubPageScaffold`, not a branch switch), so getting back
    // to the library later is `BackButton`, not another rail tap: the
    // shell's `onDestinationSelected` calls `goBranch(index,
    // initialLocation: false)`, which is a no-op while already on that
    // branch's index.
    await tester.tap(find.text('Cards').last);
    await pumpFrames(tester);
    await tester.tap(find.text('Read a card'));
    await pumpFrames(tester);
    await tester.tap(find.text('Scan high frequency'));
    await pumpFrames(tester, count: 40);
    expect(find.text('DEADBEEF'), findsOneWidget);

    // 2. Save.
    await tester.tap(find.text('Save to library'));
    await pumpFrames(tester);
    await tester.enterText(
      find
          .descendant(
            of: find.byType(SpectraBottomSheet),
            matching: find.byType(SpectraTextField),
          )
          .first,
      'Gate card',
    );
    await pumpFrames(tester, count: 5);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Save'),
      ),
    );
    await pumpFrames(tester, count: 20);

    keepAlive(tester, savedCardsProvider);
    await pumpFrames(tester);
    expect(
      (readProvider(tester, savedCardsProvider).value ?? const <SavedCard>[]),
      hasLength(1),
    );

    // 3. Edit: back to the library, open the saved card, change block 1.
    await tester.tap(find.byType(BackButton));
    await pumpFrames(tester);
    await tester.tap(find.text('Gate card'));
    await pumpFrames(tester);
    await tester.enterText(find.byKey(const Key('cardEditIndex')), '1');
    await tester.enterText(
      find.byKey(const Key('cardEditValue')),
      '000102030405060708090A0B0C0D0E0F',
    );
    await pumpFrames(tester, count: 5);
    await tester.ensureVisible(find.text('Apply'));
    await pumpFrames(tester);
    await tester.tap(find.text('Apply'));
    await pumpFrames(tester);
    await tester.ensureVisible(find.text('Save changes'));
    await pumpFrames(tester);
    await tester.tap(find.text('Save changes'));
    await pumpFrames(tester, count: 20);

    final SavedCardsRepository repo = readProvider(
      tester,
      savedCardsRepositoryProvider,
    );
    final SavedCard edited = (await repo.all()).single;
    expect(edited.bytes.sublist(16, 32), <int>[
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

    // 4. Import the reference-app fixture: back to the library, then Import.
    await tester.tap(find.byType(BackButton));
    await pumpFrames(tester);
    await tester.tap(find.text('Import'));
    await pumpFrames(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(SpectraTextField),
      ),
      File('test/fixtures/reference_card_mifare_mini.json').readAsStringSync(),
    );
    await pumpFrames(tester, count: 5);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Import'),
      ),
    );
    await pumpFrames(tester, count: 20);

    final List<SavedCard> all = await repo.all();
    expect(all, hasLength(2));
    expect(all.map((SavedCard c) => c.name).toSet(), <String>{
      'Gate card',
      'Reference Mini',
    });
    expect(find.text('Reference Mini'), findsOneWidget);
  });
}
