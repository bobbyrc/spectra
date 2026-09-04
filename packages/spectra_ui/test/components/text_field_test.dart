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

  testWidgets('forwards keyboardType, textInputAction and readOnly', (
    tester,
  ) async {
    await tester.pumpWidget(
      spectraHarness(
        child: const SpectraTextField(
          label: 'Port',
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          readOnly: true,
        ),
      ),
    );
    final TextField field = tester.widget(find.byType(TextField));
    expect(field.keyboardType, TextInputType.number);
    expect(field.textInputAction, TextInputAction.done);
    expect(field.readOnly, isTrue);
  });

  testWidgets('reports submission through onSubmitted', (tester) async {
    final submitted = <String>[];
    await tester.pumpWidget(
      spectraHarness(
        child: SpectraTextField(label: 'Port', onSubmitted: submitted.add),
      ),
    );
    await tester.enterText(find.byType(TextField), '/dev/cu.usbmodem1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(submitted, <String>['/dev/cu.usbmodem1']);
  });

  testWidgets('takes focus from an external focus node and autofocus', (
    tester,
  ) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(
      spectraHarness(
        child: SpectraTextField(
          label: 'Port',
          focusNode: node,
          autofocus: true,
        ),
      ),
    );
    await tester.pump();
    expect(node.hasFocus, isTrue);
  });

  testWidgets('semanticsLabel overrides the visible label for screen readers', (
    tester,
  ) async {
    await tester.pumpWidget(
      spectraHarness(
        child: const SpectraTextField(
          label: 'Port',
          semanticsLabel: 'Serial port path',
        ),
      ),
    );
    expect(find.bySemanticsLabel('Serial port path'), findsWidgets);
  });
}
