import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/core/routing/routes.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

void main() {
  testWidgetsApp('tapping a slot opens its detail screen', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 1);

    expect(find.text('Slot 1'), findsWidgets);
    expect(find.byType(SpectraSlotTile), findsNothing);
  });

  testWidgetsApp('the back button returns to the grid', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 1);

    await tester.tap(find.byType(BackButton));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(SpectraSlotTile), findsNWidgets(8));
  });

  testWidgetsApp('slot 1 says it is already the active slot', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 1);

    expect(find.text('Active'), findsWidgets);
    expect(find.text('Make active'), findsNothing);
  });

  testWidgetsApp('making slot 4 active moves the marker on the grid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 4);

    await tester.tap(find.text('Make active'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Make active'), findsNothing);

    await tester.tap(find.byType(BackButton));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final SpectraSlotTile fourth = tester.widget<SpectraSlotTile>(
      find.byType(SpectraSlotTile).at(3),
    );
    expect(fourth.active, isTrue);
  });

  testWidgetsApp('turning the LF sense off writes through to the device', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 1);

    // Two switches: HF first, then LF.
    expect(find.byType(Switch), findsNWidgets(2));
    expect(tester.widget<Switch>(find.byType(Switch).at(1)).value, isTrue);

    await tester.tap(find.byType(Switch).at(1));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.widget<Switch>(find.byType(Switch).at(1)).value, isFalse);
  });

  testWidgetsApp('an out-of-range slot index shows the not-found copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);

    GoRouter.of(tester.element(find.text('Slots').last)).go(AppRoutes.slot(99));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('That slot does not exist.'), findsOneWidget);
  });

  testWidgetsApp('the name field is seeded from the device', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 1);

    expect(find.widgetWithText(SpectraTextField, 'Fake 1K'), findsOneWidget);
  });

  testWidgetsApp('renaming a slot writes through and shows on the grid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 2);

    await tester.enterText(find.byType(SpectraTextField).first, 'Office');
    await tester.pump();
    await tester.tap(find.text('Save name').first);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    await tester.tap(find.byType(BackButton));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Office'), findsOneWidget);
  });

  testWidgetsApp('a name over 32 bytes is refused before it is sent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final FakeDevice device = FakeDevice();
    await tester.pumpWidget(testApp(transport: (_) => device));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 2);

    final int before = device.received
        .where((Frame frame) => frame.command == 1007)
        .length;
    await tester.enterText(find.byType(SpectraTextField).first, 'x' * 33);
    await tester.pump();

    expect(find.text('Names are limited to 32 bytes.'), findsOneWidget);
    // The save action is disabled, so nothing reached the wire.
    expect(
      tester
          .widget<SpectraButton>(
            find.widgetWithText(SpectraButton, 'Save name').first,
          )
          .onPressed,
      isNull,
    );
    final int after = device.received
        .where((Frame frame) => frame.command == 1007)
        .length;
    expect(after, before);
  });

  testWidgetsApp('picking a type from the sheet writes it to the slot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 3);

    // The HF section's "Change type" is the first one on the screen.
    await tester.tap(find.text('Change type').first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Choose a tag type'), findsOneWidget);
    expect(find.text('NTAG215'), findsOneWidget);
    // The sheet offers HF types only.
    expect(find.text('EM410x'), findsNothing);

    await tester.tap(find.text('NTAG215'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('NTAG215'), findsWidgets);
    await tester.tap(find.byType(BackButton));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final SpectraSlotTile third = tester.widget<SpectraSlotTile>(
      find.byType(SpectraSlotTile).at(2),
    );
    expect(third.tagTypes, contains('NTAG215'));
  });

  testWidgetsApp('clearing a sense asks first, then empties it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 1);

    await tester.tap(find.text('Clear').first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Clear this slot?'), findsOneWidget);

    // Cancelling changes nothing.
    await tester.tap(find.text('Cancel'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('MIFARE Classic 1K'), findsWidgets);

    await tester.tap(find.text('Clear').first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Clear').last);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('MIFARE Classic 1K'), findsNothing);
    expect(find.text('Empty'), findsWidgets);
  });
}
