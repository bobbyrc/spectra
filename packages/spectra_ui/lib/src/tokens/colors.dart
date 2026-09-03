import 'package:flutter/widgets.dart' show Color;

import 'color_scheme.dart';

/// The raw palette and the two schemes derived from it (spec 6.1): one brand
/// accent, a twelve-step neutral scale and four semantic roles.
abstract final class SpectraColors {
  // Brand accent.
  static const Color accent = Color(0xFF3F5AE0);
  static const Color accentBright = Color(0xFF8DA2FF);

  // Neutral scale, light to dark.
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFF7F8FA);
  static const Color neutral100 = Color(0xFFEDEFF3);
  static const Color neutral200 = Color(0xFFDCE0E8);
  static const Color neutral300 = Color(0xFFB9C0CC);
  static const Color neutral400 = Color(0xFF8A93A3);
  static const Color neutral500 = Color(0xFF636C7C);
  static const Color neutral600 = Color(0xFF474F5C);
  static const Color neutral700 = Color(0xFF313846);
  static const Color neutral800 = Color(0xFF1E2430);
  static const Color neutral900 = Color(0xFF12161E);
  static const Color neutral1000 = Color(0xFF0A0D12);

  // Semantic roles, light then dark variant.
  static const Color success = Color(0xFF15794A);
  static const Color successDark = Color(0xFF4ED08C);
  static const Color warning = Color(0xFF8A5A00);
  static const Color warningDark = Color(0xFFE0A93C);
  static const Color danger = Color(0xFFB3261E);
  static const Color dangerDark = Color(0xFFFF8A80);
  static const Color connected = Color(0xFF0E7490);
  static const Color connectedDark = Color(0xFF4DD6F0);

  static const Color scrimLight = Color(0x66000000);
  static const Color scrimDark = Color(0x99000000);

  static const SpectraColorScheme light = SpectraColorScheme(
    accent: accent,
    onAccent: neutral0,
    background: neutral50,
    surface: neutral0,
    surfaceRaised: neutral100,
    border: neutral200,
    textPrimary: neutral900,
    textSecondary: neutral500,
    textDisabled: neutral400,
    success: success,
    warning: warning,
    danger: danger,
    connected: connected,
    scrim: scrimLight,
  );

  static const SpectraColorScheme dark = SpectraColorScheme(
    accent: accentBright,
    onAccent: neutral1000,
    background: neutral1000,
    surface: neutral900,
    surfaceRaised: neutral800,
    border: neutral700,
    textPrimary: neutral50,
    textSecondary: neutral300,
    textDisabled: neutral500,
    success: successDark,
    warning: warningDark,
    danger: dangerDark,
    connected: connectedDark,
    scrim: scrimDark,
  );
}
