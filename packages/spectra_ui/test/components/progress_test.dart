import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  testWidgets('a determinate value drives the bar', (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 360,
        child: const SpectraProgressIndicator(label: 'Writing', value: 0.4),
      ),
    );
    final LinearProgressIndicator bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.4);
    expect(find.text('Writing'), findsOneWidget);
  });

  testWidgets('a null value is indeterminate', (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 360,
        child: const SpectraProgressIndicator(label: 'Scanning'),
      ),
    );
    final LinearProgressIndicator bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, isNull);
  });

  testWidgets('the cancel affordance appears only with onCancel', (
    tester,
  ) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 360,
        child: const SpectraProgressIndicator(label: 'Writing', value: 0.4),
      ),
    );
    expect(find.text('Cancel'), findsNothing);

    var cancels = 0;
    await tester.pumpWidget(
      spectraHarness(
        width: 360,
        child: SpectraProgressIndicator(
          label: 'Writing',
          value: 0.4,
          onCancel: () => cancels++,
        ),
      ),
    );
    await tester.tap(find.text('Cancel'));
    expect(cancels, 1);
  });

  testWidgets('the step indicator labels its position', (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 360,
        child: const SpectraStepIndicator(
          steps: <String>['Prepare', 'Transfer', 'Verify'],
          currentIndex: 1,
        ),
      ),
    );
    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
  });

  testWidgets('a failed step tints from the danger token', (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 360,
        child: const SpectraStepIndicator(
          steps: <String>['Prepare', 'Transfer', 'Verify'],
          currentIndex: 1,
          failed: true,
        ),
      ),
    );
    final Text label = tester.widget<Text>(find.text('Transfer'));
    expect(label.style!.color, SpectraColors.light.danger);
  });
}
