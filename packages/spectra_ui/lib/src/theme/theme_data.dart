import 'package:material_ui/material_ui.dart';

import '../tokens/color_scheme.dart';
import '../tokens/typography.dart';

/// Builds `material_ui`'s [ThemeData] from Spectra tokens, so `material_ui`
/// components inherit our palette and type instead of a seeded default.
///
/// This is deliberately not a bridge to the in-SDK `ThemeData`: Spike B found
/// nothing in the dependency set needs one.
ThemeData spectraThemeData(SpectraColorScheme colors, Brightness brightness) {
  final ColorScheme scheme = ColorScheme(
    brightness: brightness,
    primary: colors.accent,
    onPrimary: colors.onAccent,
    secondary: colors.connected,
    onSecondary: colors.onAccent,
    error: colors.danger,
    onError: colors.onAccent,
    surface: colors.surface,
    onSurface: colors.textPrimary,
  );
  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.background,
    canvasColor: colors.background,
    dividerColor: colors.border,
    textTheme: SpectraTypography.textTheme(colors),
  );
}
