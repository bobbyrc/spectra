import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  testWidgets('a tappable card reports taps and is a semantics button', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      spectraHarness(
        child: SpectraCard(
          semanticsLabel: 'Device card',
          onTap: () => taps++,
          child: const SizedBox(width: 100, height: 60),
        ),
      ),
    );
    await tester.tap(find.byType(SpectraCard));
    expect(taps, 1);
    expect(find.bySemanticsLabel('Device card'), findsOneWidget);
  });

  testWidgets('a plain card is not a button', (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        child: const SpectraCard(child: SizedBox(width: 100, height: 60)),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(SpectraCard),
        matching: find.byType(GestureDetector),
      ),
      findsNothing,
    );
  });

  testWidgets('a list tile shows title, subtitle and keeps a 48px target', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      spectraHarness(
        width: 360,
        child: SpectraListTile(
          title: 'Chameleon Ultra',
          subtitle: 'USB serial',
          onTap: () => taps++,
        ),
      ),
    );
    expect(find.text('Chameleon Ultra'), findsOneWidget);
    expect(find.text('USB serial'), findsOneWidget);
    expect(
      tester.getSize(find.byType(SpectraListTile)).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.byType(SpectraListTile));
    expect(taps, 1);
  });

  testWidgets('a section header fires its action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      spectraHarness(
        width: 360,
        child: SpectraSectionHeader(
          title: 'Slots',
          actionLabel: 'Refresh',
          onAction: () => taps++,
        ),
      ),
    );
    await tester.tap(find.text('Refresh'));
    expect(taps, 1);
  });
}
