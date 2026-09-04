import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

void main() {
  // `GoogleFonts.*` resolves a bundled asset, which needs a binding and the
  // asset bundle. Without this the plain `test()` cases below each print a
  // "Binding has not yet been initialized" font-loading error.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the scale has six descending steps', () {
    final sizes = <double?>[
      SpectraTypography.display.fontSize,
      SpectraTypography.headline.fontSize,
      SpectraTypography.title.fontSize,
      SpectraTypography.body.fontSize,
      SpectraTypography.bodySmall.fontSize,
      SpectraTypography.label.fontSize,
    ];
    expect(sizes, <double>[32, 24, 18, 15, 13, 12]);
  });

  test('the sans face is Inter and resolves offline', () {
    expect(
      SpectraTypography.body.fontFamily,
      contains(SpectraTypography.sansFamily),
    );
  });

  test('the mono face is a different family at the body size', () {
    expect(SpectraTypography.mono.fontFamily, contains('JetBrainsMono'));
    expect(SpectraTypography.mono.fontSize, SpectraTypography.body.fontSize);
  });

  test('textTheme colours every step from the scheme', () {
    final theme = SpectraTypography.textTheme(SpectraColors.dark);
    expect(theme.bodyMedium!.color, SpectraColors.dark.textPrimary);
    expect(theme.bodySmall!.color, SpectraColors.dark.textSecondary);
    expect(theme.displaySmall!.fontSize, 32);
  });

  test('textTheme fills all fifteen roles with the Inter face', () {
    final TextTheme theme = SpectraTypography.textTheme(SpectraColors.light);
    final Map<String, TextStyle?> roles = <String, TextStyle?>{
      'displayLarge': theme.displayLarge,
      'displayMedium': theme.displayMedium,
      'displaySmall': theme.displaySmall,
      'headlineLarge': theme.headlineLarge,
      'headlineMedium': theme.headlineMedium,
      'headlineSmall': theme.headlineSmall,
      'titleLarge': theme.titleLarge,
      'titleMedium': theme.titleMedium,
      'titleSmall': theme.titleSmall,
      'bodyLarge': theme.bodyLarge,
      'bodyMedium': theme.bodyMedium,
      'bodySmall': theme.bodySmall,
      'labelLarge': theme.labelLarge,
      'labelMedium': theme.labelMedium,
      'labelSmall': theme.labelSmall,
    };
    for (final MapEntry<String, TextStyle?> role in roles.entries) {
      expect(role.value, isNotNull, reason: '${role.key} is unset');
      expect(
        role.value!.fontFamily,
        contains(SpectraTypography.sansFamily),
        reason: '${role.key} does not use Inter',
      );
      expect(role.value!.color, isNotNull, reason: '${role.key} has no colour');
    }
  });

  testWidgets('the bundled Inter asset loads without a network fetch', (
    WidgetTester tester,
  ) async {
    // `flutter_test_config.dart` already disables runtime fetching; assert it
    // so this test fails loudly rather than silently going to the network.
    expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
    expect(
      (await rootBundle.load(
        'packages/spectra_ui/assets/google_fonts/Inter-Regular.ttf',
      )).lengthInBytes,
      greaterThan(0),
    );
    expect(
      (await rootBundle.load(
        'packages/spectra_ui/assets/google_fonts/JetBrainsMono-Regular.ttf',
      )).lengthInBytes,
      greaterThan(0),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: spectraThemeData(SpectraColors.light, Brightness.light),
        home: Builder(
          builder: (BuildContext context) =>
              Text('Aa', style: Theme.of(context).textTheme.bodyMedium),
        ),
      ),
    );
    await GoogleFonts.pendingFonts();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
