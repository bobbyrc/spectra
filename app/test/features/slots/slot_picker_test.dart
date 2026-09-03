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
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);

    int? chosen;
    final BuildContext context = tester.element(find.byType(SlotsPage));
    final Future<int?> pending = showSlotPicker(context).then((int? i) {
      chosen = i;
      return i;
    });
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Choose a slot'), findsOneWidget);
    final Finder sheetTiles = find.descendant(
      of: find.byType(SpectraBottomSheet),
      matching: find.byType(SpectraSlotTile),
    );
    expect(sheetTiles, findsNWidgets(8));

    await tester.tap(sheetTiles.at(4));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await pending;
    expect(chosen, 4, reason: 'the fifth tile in the sheet is wire index 4');
  });

  testWidgetsApp('dismissing the picker resolves to null', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);

    final BuildContext context = tester.element(find.byType(SlotsPage));
    final Future<int?> pending = showSlotPicker(context);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byIcon(Icons.close));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(await pending, isNull);
  });

  testWidgetsApp('isSelectable greys out the slots a caller cannot use', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);

    final BuildContext context = tester.element(find.byType(SlotsPage));
    final Future<int?> pending = showSlotPicker(
      context,
      // Only the seeded slot 0 has an HF type.
      isSelectable: (SlotView v) => v.slot.hfType != TagType.undefined,
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

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
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
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
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Connect a device to see its slots.'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await pending;
    },
  );
}
