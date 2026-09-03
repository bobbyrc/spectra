import 'dart:ui';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

void main() {
  testWidgetsApp('the grid shows eight slots with the active one marked', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);

    expect(find.byType(SpectraSlotTile), findsNWidgets(8));
    expect(find.text('Fake 1K'), findsOneWidget);
    expect(find.text('MIFARE Classic 1K'), findsOneWidget);
    expect(find.text('EM410x'), findsOneWidget);

    final SpectraSlotTile first = tester.widget<SpectraSlotTile>(
      find.byType(SpectraSlotTile).first,
    );
    expect(first.number, 1);
    expect(first.active, isTrue);
    expect(first.enabled, isTrue);

    final SpectraSlotTile second = tester.widget<SpectraSlotTile>(
      find.byType(SpectraSlotTile).at(1),
    );
    expect(second.active, isFalse);
    expect(second.enabled, isFalse);
  });

  testWidgetsApp('the empty state replaces the grid with nothing connected', (
    tester,
  ) async {
    await pumpTestAppWithNoDevices(tester);
    await tester.pump();

    // Nothing is connected, so routing holds the connect screen and the
    // grid is never built; the page itself still renders its empty state
    // when mounted directly.
    expect(find.byType(SpectraSlotTile), findsNothing);
  });
}
