import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/features/connect/connect.dart';
import 'package:spectra/features/slots/slots.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

void main() {
  testWidgetsApp('the picker resolves to the chosen wire index', (
    tester,
  ) async {
    useDesktopSurface(tester);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);

    int? chosen;
    final BuildContext context = tester.element(find.byType(SlotsPage));
    final Future<int?> pending = showSlotPicker(context).then((int? i) {
      chosen = i;
      return i;
    });
    await pumpFrames(tester);

    expect(find.text('Choose a slot'), findsOneWidget);
    final Finder sheetTiles = find.descendant(
      of: find.byType(SpectraBottomSheet),
      matching: find.byType(SpectraSlotTile),
    );
    expect(sheetTiles, findsNWidgets(8));

    await tester.tap(sheetTiles.at(4));
    await pumpFrames(tester);
    await pending;
    expect(chosen, 4, reason: 'the fifth tile in the sheet is wire index 4');
  });

  testWidgetsApp('dismissing the picker resolves to null', (tester) async {
    useDesktopSurface(tester);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);

    final BuildContext context = tester.element(find.byType(SlotsPage));
    final Future<int?> pending = showSlotPicker(context);
    await pumpFrames(tester);
    await tester.tap(find.byIcon(Icons.close));
    await pumpFrames(tester);
    expect(await pending, isNull);
  });

  testWidgetsApp('isSelectable greys out the slots a caller cannot use', (
    tester,
  ) async {
    useDesktopSurface(tester);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);

    final BuildContext context = tester.element(find.byType(SlotsPage));
    final Future<int?> pending = showSlotPicker(
      context,
      // Only the seeded slot 0 has an HF type.
      isSelectable: (SlotView v) => v.slot.hfType != TagType.undefined,
    );
    await pumpFrames(tester);

    final Finder sheetTiles = find.descendant(
      of: find.byType(SpectraBottomSheet),
      matching: find.byType(SpectraSlotTile),
    );
    final List<SpectraSlotTile> sheetTileWidgets = tester
        .widgetList<SpectraSlotTile>(sheetTiles)
        .toList();
    expect(sheetTileWidgets.first.onTap, isNotNull);
    expect(sheetTileWidgets.elementAt(1).onTap, isNull);

    await tester.tap(find.byIcon(Icons.close));
    await pumpFrames(tester);
    await pending;
  });

  testWidgetsApp(
    'showSlotPicker shows the empty-state copy with nothing connected',
    (tester) async {
      await pumpTestAppWithNoDevices(tester);
      await tester.pump();
      await tester.pump();

      final BuildContext context = tester.element(find.byType(ConnectPage));
      final Future<int?> pending = showSlotPicker(context);
      await pumpFrames(tester);

      expect(find.text('Connect a device to see its slots.'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await pumpFrames(tester);
      await pending;
    },
  );

  testWidgetsApp('an unselectable slot keeps the device\'s active marker', (
    tester,
  ) async {
    useDesktopSurface(tester);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);

    final BuildContext context = tester.element(find.byType(SlotsPage));
    // Slot 0 is the device's active slot; this caller cannot use it.
    final Future<int?> pending = showSlotPicker(
      context,
      isSelectable: (SlotView v) => v.index != 0,
    );
    await pumpFrames(tester);

    final Finder sheetTiles = find.descendant(
      of: find.byType(SpectraBottomSheet),
      matching: find.byType(SpectraSlotTile),
    );
    final SpectraSlotTile first = tester
        .widgetList<SpectraSlotTile>(sheetTiles)
        .first;
    expect(first.onTap, isNull, reason: 'not on offer to this caller');
    expect(first.active, isTrue, reason: 'still the active slot');
    expect(first.enabled, isTrue);
    expect(
      find.descendant(of: sheetTiles.first, matching: find.text('Disabled')),
      findsNothing,
      reason: 'unselectable is this caller\'s restriction, not the slot\'s',
    );

    await tester.tap(find.byIcon(Icons.close));
    await pumpFrames(tester);
    await pending;
  });
}
