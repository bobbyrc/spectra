import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'color_scheme.dart';

/// The six-step type scale (spec 6.1) plus the monospaced face the hex viewer
/// needs. One variable sans, loaded from `assets/google_fonts/`.
abstract final class SpectraTypography {
  static const String sansFamily = 'Inter';
  static const String monoFamily = 'JetBrains Mono';

  static TextStyle get display => GoogleFonts.inter(
    fontSize: 32,
    height: 1.15,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get headline =>
      GoogleFonts.inter(fontSize: 24, height: 1.2, fontWeight: FontWeight.w600);

  static TextStyle get title =>
      GoogleFonts.inter(fontSize: 18, height: 1.3, fontWeight: FontWeight.w600);

  static TextStyle get body => GoogleFonts.inter(
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get bodySmall =>
      GoogleFonts.inter(fontSize: 13, height: 1.4, fontWeight: FontWeight.w400);

  static TextStyle get label => GoogleFonts.inter(
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
  );

  /// Body-sized monospace, used by the hex viewer so columns line up.
  static TextStyle get mono => GoogleFonts.jetBrainsMono(
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  /// Maps the scale onto `material_ui`'s [TextTheme] so `material_ui`
  /// components pick up our type without each one being restyled.
  static TextTheme textTheme(SpectraColorScheme colors) {
    return TextTheme(
      displaySmall: display.copyWith(color: colors.textPrimary),
      headlineSmall: headline.copyWith(color: colors.textPrimary),
      titleMedium: title.copyWith(color: colors.textPrimary),
      bodyMedium: body.copyWith(color: colors.textPrimary),
      bodySmall: bodySmall.copyWith(color: colors.textSecondary),
      labelLarge: label.copyWith(color: colors.textPrimary),
    );
  }
}
