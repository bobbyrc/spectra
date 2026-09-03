import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  testWidgets('calls onPressed and meets the 48px touch target', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      spectraHarness(
        child: SpectraButton(label: 'Connect', onPressed: () => taps++),
      ),
    );
    await tester.tap(find.text('Connect'));
    expect(taps, 1);
    expect(
      tester.getSize(find.byType(SpectraButton)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('a null onPressed disables the button', (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        child: const SpectraButton(label: 'Connect', onPressed: null),
      ),
    );
    await tester.tap(find.text('Connect'), warnIfMissed: false);
    expect(tester.takeException(), isNull);
    final Semantics node = tester.widget<Semantics>(
      find
          .descendant(
            of: find.byType(SpectraButton),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(node.properties.enabled, isFalse);
  });

  testWidgets('busy replaces the label with a spinner and blocks taps', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      spectraHarness(
        child: SpectraButton(
          label: 'Connect',
          busy: true,
          onPressed: () => taps++,
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(SpectraButton), warnIfMissed: false);
    expect(taps, 0);
  });

  testWidgets('the danger variant paints from the danger token', (
    tester,
  ) async {
    await tester.pumpWidget(
      spectraHarness(
        child: SpectraButton(
          label: 'Erase',
          variant: SpectraButtonVariant.danger,
          onPressed: () {},
        ),
      ),
    );
    // The button's own fill, not SpectraTappable's transparent focus-ring
    // overlay, which is also a DecoratedBox inside the same subtree.
    final Iterable<Color?> fills = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(SpectraButton),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((DecoratedBox box) => (box.decoration as BoxDecoration).color);
    expect(fills, contains(SpectraColors.light.danger));
  });

  testWidgets('a semanticsLabel overrides the visible label for a11y', (
    tester,
  ) async {
    await tester.pumpWidget(
      spectraHarness(
        child: SpectraButton(
          label: 'Erase',
          semanticsLabel: 'Erase all slots',
          onPressed: () {},
        ),
      ),
    );
    expect(find.bySemanticsLabel('Erase all slots'), findsOneWidget);
  });
}
