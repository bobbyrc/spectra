import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

void main() {
  testWidgets('the delegate resolves English strings from context', (
    tester,
  ) async {
    late SpectraUiLocalizations l10n;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('en'),
        delegates: const <LocalizationsDelegate<Object?>>[
          SpectraUiLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        child: Builder(
          builder: (context) {
            l10n = SpectraUiLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(l10n.disclosureShow, 'Show details');
    expect(l10n.disclosureHide, 'Hide details');
    expect(l10n.slotLabel(3), 'Slot 3');
    expect(l10n.batteryLevel(87), '87%');
    expect(l10n.batteryCharging(87), '87% charging');
    expect(l10n.stepProgress(2, 5), 'Step 2 of 5');
    expect(l10n.statusConnected, 'Connected');
  });

  test('English is the only supported locale in v1', () {
    expect(SpectraUiLocalizations.supportedLocales, <Locale>[
      const Locale('en'),
    ]);
  });
}
