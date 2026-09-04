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
  ///
  /// All fifteen roles are filled, not just the six the scale names: a role
  /// left null falls back to Material's Roboto defaults, and `material_ui`
  /// reads several of them internally (`bodyLarge` for input text,
  /// `labelMedium` for navigation labels, `titleLarge` for the app bar), so a
  /// gap shows up as a stray typeface rather than as a missing style.
  static TextTheme textTheme(SpectraColorScheme colors) {
    final Color primary = colors.textPrimary;
    final Color secondary = colors.textSecondary;
    return TextTheme(
      displayLarge: display.copyWith(color: primary, fontSize: 44),
      displayMedium: display.copyWith(color: primary, fontSize: 38),
      displaySmall: display.copyWith(color: primary),
      headlineLarge: headline.copyWith(color: primary, fontSize: 28),
      headlineMedium: headline.copyWith(color: primary, fontSize: 26),
      headlineSmall: headline.copyWith(color: primary),
      titleLarge: title.copyWith(color: primary, fontSize: 20),
      titleMedium: title.copyWith(color: primary),
      titleSmall: title.copyWith(color: primary, fontSize: 16),
      bodyLarge: body.copyWith(color: primary, fontSize: 16),
      bodyMedium: body.copyWith(color: primary),
      bodySmall: bodySmall.copyWith(color: secondary),
      labelLarge: label.copyWith(color: primary),
      labelMedium: label.copyWith(color: secondary, fontSize: 11),
      labelSmall: label.copyWith(color: secondary, fontSize: 10),
    );
  }
}
