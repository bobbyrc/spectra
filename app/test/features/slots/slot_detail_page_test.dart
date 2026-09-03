import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/core/routing/routes.dart';
import 'package:spectra/features/slots/state/slot_editor_controller.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

void main() {
  testWidgetsApp('tapping a slot opens its detail screen', (tester) async {
    useDesktopSurface(tester);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 1);

    expect(find.text('Slot 1'), findsWidgets);
    expect(find.byType(SpectraSlotTile), findsNothing);
  });

  testWidgetsApp('the back button returns to the grid', (tester) async {
    useDesktopSurface(tester);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 1);

    await tester.tap(find.byType(BackButton));
    await pumpFrames(tester);
    expect(find.byType(SpectraSlotTile), findsNWidgets(8));
  });

  testWidgetsApp('slot 1 says it is already the active slot', (tester) async {
    useDesktopSurface(tester);

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
    useDesktopSurface(tester);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 4);

    await tester.tap(find.text('Make active'));
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));
    expect(find.text('Make active'), findsNothing);

    await tester.tap(find.byType(BackButton));
    await pumpFrames(tester);
    final SpectraSlotTile fourth = tester.widget<SpectraSlotTile>(
      find.byType(SpectraSlotTile).at(3),
    );
    expect(fourth.active, isTrue);
  });

  testWidgetsApp('turning the LF sense off writes through to the device', (
    tester,
  ) async {
    useDesktopSurface(tester);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 1);

    // Two switches: HF first, then LF.
    expect(find.byType(Switch), findsNWidgets(2));
    expect(tester.widget<Switch>(find.byType(Switch).at(1)).value, isTrue);

    await tester.tap(find.byType(Switch).at(1));
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));
    expect(tester.widget<Switch>(find.byType(Switch).at(1)).value, isFalse);
  });

  testWidgetsApp('an out-of-range slot index shows the not-found copy', (
    tester,
  ) async {
    useDesktopSurface(tester);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);

    GoRouter.of(tester.element(find.text('Slots').last)).go(AppRoutes.slot(99));
    await pumpFrames(tester);

    expect(find.text('That slot does not exist.'), findsOneWidget);
  });

  testWidgetsApp('the name field is seeded from the device', (tester) async {
    useDesktopSurface(tester);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 1);

    expect(find.widgetWithText(SpectraTextField, 'Fake 1K'), findsOneWidget);
  });

  testWidgetsApp('renaming a slot writes through and shows on the grid', (
    tester,
  ) async {
    useDesktopSurface(tester);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 2);

    await tester.enterText(find.byType(SpectraTextField).first, 'Office');
    await tester.pump();
    await tester.tap(find.text('Save name').first);
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    await tester.tap(find.byType(BackButton));
    await pumpFrames(tester);
    expect(find.text('Office'), findsOneWidget);
  });

  testWidgetsApp('a name over 32 bytes is refused before it is sent', (
    tester,
  ) async {
    useDesktopSurface(tester);

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
    useDesktopSurface(tester);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 3);

    // The HF section's "Change type" is the first one on the screen.
    await tester.tap(find.text('Change type').first);
    await pumpFrames(tester);

    expect(find.text('Choose a tag type'), findsOneWidget);
    expect(find.text('NTAG215'), findsOneWidget);
    // The sheet offers HF types only.
    expect(find.text('EM410x'), findsNothing);

    await tester.tap(find.text('NTAG215'));
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    expect(find.text('NTAG215'), findsWidgets);
    await tester.tap(find.byType(BackButton));
    await pumpFrames(tester);
    final SpectraSlotTile third = tester.widget<SpectraSlotTile>(
      find.byType(SpectraSlotTile).at(2),
    );
    expect(third.tagTypes, contains('NTAG215'));
  });

  testWidgetsApp('clearing a sense asks first, then empties it', (
    tester,
  ) async {
    useDesktopSurface(tester);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 1);

    await tester.tap(find.text('Clear').first);
    await pumpFrames(tester);
    expect(find.text('Clear this slot?'), findsOneWidget);

    // Cancelling changes nothing.
    await tester.tap(find.text('Cancel'));
    await pumpFrames(tester);
    expect(find.text('MIFARE Classic 1K'), findsWidgets);

    await tester.tap(find.text('Clear').first);
    await pumpFrames(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraDialog),
        matching: find.text('Clear'),
      ),
    );
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    expect(find.text('MIFARE Classic 1K'), findsNothing);
    expect(find.text('Empty'), findsWidgets);
  });

  testWidgetsApp('the editor renders a notifier error through the catalog', (
    tester,
  ) async {
    useDesktopSurface(tester);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 2);

    // The message has to be on the *visible* slot's editor to reach the
    // screen. `SlotEditor.state` is `@protected` (ruling 3): drive the
    // error through `debugFail` rather than assigning `state` directly.
    keepAlive(tester, slotEditorProvider(1));
    readProvider(
      tester,
      slotEditorProvider(1).notifier,
    ).debugFail(const ParameterError());
    await tester.pump();

    expect(find.text('The device rejected that value.'), findsOneWidget);
    await tester.tap(find.text('Details'));
    await pumpFrames(tester);
    expect(find.textContaining('ParameterError'), findsWidgets);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(find.text('The device rejected that value.'), findsNothing);
  });

  testWidgetsApp('every control is disabled while a change is in flight', (
    tester,
  ) async {
    useDesktopSurface(tester);

    final FakeDevice device = FakeDevice();
    await tester.pumpWidget(testApp(transport: (_) => device));
    await connectToEmulator(tester);
    await openSlots(tester);

    // Slot 2 is empty and inactive to begin with: give its HF side a type
    // so "Clear" has something to clear, which leaves every control on the
    // screen enabled before the change below starts.
    keepAlive(tester, slotEditorProvider(1));
    final Future<void> seeded = readProvider(
      tester,
      slotEditorProvider(1).notifier,
    ).setTagType(TagType.ntag215);
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));
    await seeded;

    await openSlot(tester, 2);

    Iterable<SpectraButton> buttons(String label) => tester
        .widgetList<SpectraButton>(find.widgetWithText(SpectraButton, label));
    Iterable<Switch> switches() =>
        tester.widgetList<Switch>(find.byType(Switch));

    expect(buttons('Make active'), isNotEmpty);
    expect(buttons('Clear').first.onPressed, isNotNull);
    final Offset restingSwitch = tester.getTopLeft(find.byType(Switch).first);

    // Slow the device down so the rename is observably in flight.
    device.latency = const Duration(milliseconds: 200);
    await tester.enterText(find.byType(SpectraTextField).first, 'Front door');
    await tester.pump();
    await tester.tap(find.text('Save name').first);
    await pumpFrames(tester, count: 2, step: const Duration(milliseconds: 20));

    expect(find.byType(SpectraProgressIndicator), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(Switch).first),
      restingSwitch,
      reason: 'the indicator has its own reserved row: nothing moves',
    );
    for (final Switch s in switches()) {
      expect(s.onChanged, isNull, reason: 'both senses');
    }
    for (final String label in <String>[
      'Save name',
      'Change type',
      'Clear',
      'Make active',
    ]) {
      final Iterable<SpectraButton> found = buttons(label);
      expect(found, isNotEmpty, reason: label);
      for (final SpectraButton b in found) {
        expect(b.onPressed, isNull, reason: label);
      }
    }

    device.latency = Duration.zero;
    await pumpFrames(tester, count: 40, step: const Duration(milliseconds: 50));

    expect(find.byType(SpectraProgressIndicator), findsNothing);
    for (final Switch s in switches()) {
      expect(s.onChanged, isNotNull);
    }
    expect(buttons('Change type').first.onPressed, isNotNull);
    expect(buttons('Clear').first.onPressed, isNotNull);
    expect(buttons('Make active').first.onPressed, isNotNull);
    // "Save name" comes back with the field: it is disabled again only
    // because the name now matches the device.
    await tester.enterText(find.byType(SpectraTextField).first, 'Back door');
    await tester.pump();
    expect(buttons('Save name').first.onPressed, isNotNull);
  });

  testWidgetsApp('each sense names its tag type in a labelled row', (
    tester,
  ) async {
    useDesktopSurface(tester);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 1);

    expect(find.text('Tag type'), findsNWidgets(2), reason: 'HF and LF');
    expect(
      find.descendant(
        of: find.widgetWithText(SpectraListTile, 'Tag type').first,
        matching: find.text('MIFARE Classic 1K'),
      ),
      findsOneWidget,
    );
  });
}
