import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  testWidgets('SpectraDialog.show returns the chosen value', (tester) async {
    Object? result;
    await tester.pumpWidget(
      spectraHarness(
        child: Builder(
          builder: (context) => SpectraButton(
            label: 'Open',
            onPressed: () async {
              result = await SpectraDialog.show<String>(
                context: context,
                title: 'Erase slot',
                content: const SizedBox.shrink(),
                actions: (context) => <Widget>[
                  SpectraButton(
                    label: SpectraUiLocalizations.of(context).confirm,
                    variant: SpectraButtonVariant.danger,
                    onPressed: () => Navigator.of(context).pop('erased'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Erase slot'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(result, 'erased');
  });

  testWidgets('SpectraBottomSheet.show presents its title and child', (
    tester,
  ) async {
    await tester.pumpWidget(
      spectraHarness(
        child: Builder(
          builder: (context) => SpectraButton(
            label: 'Open',
            onPressed: () {
              unawaited(
                SpectraBottomSheet.show<void>(
                  context: context,
                  title: 'Pick a slot',
                  builder: (_) => const SpectraTextField(label: 'Filter'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a slot'), findsOneWidget);
    expect(find.byType(SpectraTextField), findsOneWidget);
  });
}
