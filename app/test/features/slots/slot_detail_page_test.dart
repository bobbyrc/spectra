import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
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
}
