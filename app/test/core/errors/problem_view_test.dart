import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/core/errors/problem_view.dart';
import 'package:spectra/l10n/app_localizations.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

/// The shared problem card under a theme and the two localization
/// delegates, with no app root and no device: this is a rendering test.
Widget _localizedApp(Widget child) => MaterialApp(
  localizationsDelegates: const <LocalizationsDelegate<Object?>>[
    AppLocalizations.delegate,
    ...SpectraUiLocalizations.localizationsDelegates,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: SpectraTheme(
    colors: SpectraColors.light,
    brightness: Brightness.light,
    child: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

void main() {
  Future<void> pumpProblem(
    WidgetTester tester,
    Object error, {
    SpectraButtonVariant? variant,
    String? instructions,
  }) async {
    await tester.pumpWidget(
      _localizedApp(
        ProblemView(
          error: error,
          instructions: instructions,
          variant: variant,
          onAction: () {},
        ),
      ),
    );
    await tester.pump();
  }

  testWidgetsApp('a firmware-level failure offers the update action', (
    tester,
  ) async {
    await pumpProblem(tester, const NotImplemented());
    expect(find.text('Update firmware'), findsOneWidget);
  });

  testWidgetsApp('a permission failure sends the user to settings', (
    tester,
  ) async {
    await pumpProblem(tester, const PermissionDenied());
    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgetsApp('every other recovery reads as Try again', (tester) async {
    await pumpProblem(tester, const MalformedResponse('bad payload'));
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgetsApp('an error with no recovery renders no action button', (
    tester,
  ) async {
    await pumpProblem(tester, const ParameterError());
    expect(find.byType(SpectraButton), findsNothing);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgetsApp('the raw line is one tap away', (tester) async {
    await pumpProblem(tester, const ParameterError());
    expect(find.textContaining('ParameterError'), findsNothing);
    await tester.tap(find.text('Details'));
    await pumpFrames(tester);
    expect(find.textContaining('ParameterError'), findsWidgets);
  });

  testWidgetsApp('the caller chooses the button weight', (tester) async {
    await pumpProblem(tester, const MalformedResponse('bad payload'));
    expect(
      tester.widget<SpectraButton>(find.byType(SpectraButton)).variant,
      SpectraButtonVariant.primary,
      reason: 'the default matches SpectraButton itself',
    );

    await pumpProblem(
      tester,
      const MalformedResponse('bad payload'),
      variant: SpectraButtonVariant.secondary,
    );
    expect(
      tester.widget<SpectraButton>(find.byType(SpectraButton)).variant,
      SpectraButtonVariant.secondary,
    );
  });

  testWidgetsApp("the caller's instructions win over the catalog's", (
    tester,
  ) async {
    await pumpProblem(
      tester,
      const PermissionDenied(),
      instructions: 'Enable Bluetooth for Spectra in system settings.',
    );
    expect(
      find.text('Enable Bluetooth for Spectra in system settings.'),
      findsOneWidget,
    );
  });
}
