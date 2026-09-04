import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra/core/errors/warning_callout.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

Widget _themed(Widget child) => MaterialApp(
  home: SpectraTheme(
    colors: SpectraColors.light,
    brightness: Brightness.light,
    child: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

void main() {
  testWidgetsApp('a title-only callout is one warning-coloured line', (
    tester,
  ) async {
    await tester.pumpWidget(
      _themed(const WarningCallout(title: '4 sectors could not be read.')),
    );
    await tester.pump();

    expect(find.text('4 sectors could not be read.'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    final BuildContext context = tester.element(find.byType(WarningCallout));
    expect(
      tester
          .widget<Text>(find.text('4 sectors could not be read.'))
          .style
          ?.color,
      SpectraTheme.of(context).colors.warning,
    );
  });

  testWidgetsApp('a body line renders under the title', (tester) async {
    await tester.pumpWidget(
      _themed(
        const WarningCallout(
          title: 'Some sectors have no known key',
          body: 'Sectors 0, 3 and 7 were never read.',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Some sectors have no known key'), findsOneWidget);
    expect(find.text('Sectors 0, 3 and 7 were never read.'), findsOneWidget);
  });
}
