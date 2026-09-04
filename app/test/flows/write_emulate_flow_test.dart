import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/features/slots/slots.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/app_harness.dart';

Finder _inSheet(Finder matching) =>
    find.descendant(of: find.byType(SpectraBottomSheet), matching: matching);

/// Spec 7.7 steps 3-5 end to end, in emulator mode: read the card the fake
/// presents, save it, load it into a slot, write it back onto a card, and
/// quick-emulate a fresh read straight into a slot. No transport override —
/// the production factory (`core/emulator/demo_cards.dart`) is what gives
/// the emulated device a card to read, and this flow is worth running
/// through it.
void main() {
  testWidgetsApp('read, save, load to slot, write back, and quick emulate', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await pumpTestApp(tester);
    await connectToEmulator(tester);
    keepAlive(tester, slotViewsProvider);

    // Read.
    await tester.tap(find.text('Cards').last);
    await pumpFrames(tester);
    await tester.tap(find.text('Read a card'));
    await pumpFrames(tester);
    await tester.tap(find.text('Scan high frequency'));
    await pumpFrames(tester, count: 40);
    expect(find.text('MIFARE Classic 1K'), findsWidgets);

    // Save.
    await tester.tap(find.text('Save to library'));
    await pumpFrames(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.widgetWithText(SpectraTextField, 'Name'),
      ),
      'Office badge',
    );
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Save'),
      ),
    );
    await pumpFrames(tester, count: 20);

    // Back to the library (a rail tap on the branch already showing the
    // Read sub-page is a no-op — the shell's `onDestinationSelected` calls
    // `goBranch(index, initialLocation: false)`, per
    // `app_harness.dart`'s `openFrameLog`/`openUpdate` doc comment), then
    // open it from the library.
    await tester.tap(find.byType(BackButton));
    await pumpFrames(tester);
    await tester.tap(find.text('Office badge'));
    await pumpFrames(tester);

    // Load it into slot 5.
    await tester.ensureVisible(find.text('Load into a slot'));
    await pumpFrames(tester);
    await tester.tap(find.text('Load into a slot'));
    await pumpFrames(tester);
    await tester.tap(
      find
          .descendant(
            of: find.byType(SpectraBottomSheet),
            matching: find.byType(SpectraSlotTile),
          )
          .at(4),
    );
    await pumpFrames(tester);
    expect(find.text('Load into slot 5'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Load'),
      ),
    );
    await pumpFrames(tester, count: 40);
    expect(find.text('Loaded into slot 5.'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Close'),
      ),
    );
    await pumpFrames(tester);

    // The slot grid, and the device behind it, agree.
    await openSlots(tester);
    final SpectraSlotTile fifth = tester.widget<SpectraSlotTile>(
      find.byType(SpectraSlotTile).at(4),
    );
    expect(fifth.nickname, 'Office badge');
    expect(fifth.active, isTrue);

    List<SlotView> views = readProvider(tester, slotViewsProvider);
    expect(views[4].slot.hfNick, 'Office badge');
    expect(views[4].slot.hfEnabled, isTrue);

    // Write it back onto the card in the field: back to the Cards branch,
    // whose navigator stack still has the detail page on top.
    await tester.tap(find.text('Cards').last);
    await pumpFrames(tester);
    expect(find.text('Office badge'), findsWidgets);
    await tester.ensureVisible(find.text('Write to a card'));
    await pumpFrames(tester);
    await tester.tap(find.text('Write to a card'));
    await pumpFrames(tester);
    expect(
      _inSheet(
        find.text(
          'Writing to a physical card has not been checked '
          'on real hardware yet. Use a card you can afford to lose.',
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(_inSheet(find.text('Write')));
    await pumpFrames(tester, count: 40);
    expect(_inSheet(find.text('47 of 47 blocks written.')), findsOneWidget);
    await tester.tap(_inSheet(find.text('Close')));
    await pumpFrames(tester);

    // Quick emulate: a fresh read, straight into a slot, no save first.
    await tester.tap(find.byType(BackButton));
    await pumpFrames(tester);
    await tester.tap(find.text('Read a card'));
    await pumpFrames(tester);
    await tester.tap(find.text('Scan high frequency'));
    await pumpFrames(tester, count: 40);
    await tester.tap(find.text('Emulate this card'));
    await pumpFrames(tester);
    await tester.tap(
      find
          .descendant(
            of: find.byType(SpectraBottomSheet),
            matching: find.byType(SpectraSlotTile),
          )
          .first,
    );
    await pumpFrames(tester);
    expect(find.text('Load into slot 1'), findsOneWidget);
    await tester.tap(_inSheet(find.text('Load')));
    await pumpFrames(tester, count: 40);
    expect(_inSheet(find.text('Loaded into slot 1.')), findsOneWidget);
    await tester.tap(_inSheet(find.text('Close')));
    await pumpFrames(tester);

    views = readProvider(tester, slotViewsProvider);
    expect(views[0].slot.hfNick, 'MIFARE Classic 1K');
    expect(views[0].slot.hfEnabled, isTrue);
  });
}
