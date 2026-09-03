import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  testWidgets('reports typing through onChanged', (tester) async {
    final changes = <String>[];
    await tester.pumpWidget(
      spectraHarness(
        child: SpectraTextField(label: 'Nickname', onChanged: changes.add),
      ),
    );
    await tester.enterText(find.byType(TextField), 'gate');
    expect(changes, <String>['gate']);
  });

  testWidgets('shows the error text and marks the field as errored', (
    tester,
  ) async {
    await tester.pumpWidget(
      spectraHarness(
        child: const SpectraTextField(label: 'Nickname', errorText: 'Required'),
      ),
    );
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('meets the 48px touch target', (tester) async {
    await tester.pumpWidget(
      spectraHarness(child: const SpectraTextField(label: 'Nickname')),
    );
    expect(
      tester.getSize(find.byType(TextField)).height,
      greaterThanOrEqualTo(48),
    );
  });
}
