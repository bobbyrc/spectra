import 'package:flutter_test/flutter_test.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  testWidgets('starts collapsed and shows the expand affordance', (
    tester,
  ) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 360,
        child: const SpectraDisclosure(
          summary: SpectraListTile(title: 'Firmware'),
          detail: SpectraListTile(title: 'Git hash abc1234'),
        ),
      ),
    );
    expect(find.text('Firmware'), findsOneWidget);
    expect(find.text('Git hash abc1234'), findsNothing);
    expect(find.bySemanticsLabel('Show details'), findsOneWidget);
  });

  testWidgets('expands on tap, reports the change and flips the affordance', (
    tester,
  ) async {
    final changes = <bool>[];
    await tester.pumpWidget(
      spectraHarness(
        width: 360,
        height: 300,
        child: SpectraDisclosure(
          summary: const SpectraListTile(title: 'Firmware'),
          detail: const SpectraListTile(title: 'Git hash abc1234'),
          onExpansionChanged: changes.add,
        ),
      ),
    );
    await tester.tap(find.text('Firmware'));
    await tester.pumpAndSettle();

    expect(changes, <bool>[true]);
    expect(find.text('Git hash abc1234'), findsOneWidget);
    expect(find.bySemanticsLabel('Hide details'), findsOneWidget);

    await tester.tap(find.text('Firmware'));
    await tester.pumpAndSettle();
    expect(changes, <bool>[true, false]);
    expect(find.text('Git hash abc1234'), findsNothing);
  });

  testWidgets('initiallyExpanded starts open', (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 360,
        height: 300,
        child: const SpectraDisclosure(
          initiallyExpanded: true,
          summary: SpectraListTile(title: 'Firmware'),
          detail: SpectraListTile(title: 'Git hash abc1234'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Git hash abc1234'), findsOneWidget);
  });
}
