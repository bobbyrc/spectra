import 'package:flutter_test/flutter_test.dart';
import 'package:spectra_ui/spectra_ui.dart';

void main() {
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
}
