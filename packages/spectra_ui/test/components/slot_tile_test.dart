import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  testWidgets('shows the slot number and nickname', (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 300,
        child: const SpectraSlotTile(
          number: 3,
          enabled: true,
          nickname: 'Office badge',
          tagTypes: <String>['MIFARE Classic 1K'],
        ),
      ),
    );
    expect(find.text('Slot 3'), findsOneWidget);
    expect(find.text('Office badge'), findsOneWidget);
    expect(find.text('MIFARE Classic 1K'), findsOneWidget);
  });

  testWidgets('falls back to Empty with no nickname and no tag types', (
    tester,
  ) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 300,
        child: const SpectraSlotTile(number: 5, enabled: true),
      ),
    );
    expect(find.text('Empty'), findsOneWidget);
  });

  testWidgets('a disabled slot says so and dims its text', (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 300,
        child: const SpectraSlotTile(
          number: 2,
          enabled: false,
          nickname: 'Spare',
        ),
      ),
    );
    expect(find.text('Disabled'), findsOneWidget);
    final Text nickname = tester.widget<Text>(find.text('Spare'));
    expect(nickname.style!.color, SpectraColors.light.textDisabled);
  });

  testWidgets('the active slot is marked and accented', (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 300,
        child: const SpectraSlotTile(
          number: 1,
          enabled: true,
          nickname: 'Gate',
          active: true,
        ),
      ),
    );
    expect(find.text('Active'), findsOneWidget);
    final DecoratedBox box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(SpectraSlotTile),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(
      (box.decoration as BoxDecoration).border!.top.color,
      SpectraColors.light.accent,
    );
  });

  testWidgets('taps are reported and the target is at least 48px', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      spectraHarness(
        width: 300,
        child: SpectraSlotTile(
          number: 4,
          enabled: true,
          nickname: 'Gate',
          onTap: () => taps++,
        ),
      ),
    );
    await tester.tap(find.byType(SpectraSlotTile));
    expect(taps, 1);
    expect(
      tester.getSize(find.byType(SpectraSlotTile)).height,
      greaterThanOrEqualTo(48),
    );
  });
}
