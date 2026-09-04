import 'package:material_ui/material_ui.dart';

import '../tokens/color_scheme.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Builds `material_ui`'s [ThemeData] from Spectra tokens, so `material_ui`
/// components inherit our palette and type instead of a seeded default.
///
/// Every [ColorScheme] role `material_ui` reads is filled from a token: a
/// role left unset falls back to a Material default (outlines to `onSurface`,
/// `secondaryContainer` to a seeded lavender, `surfaceTint` to `primary`),
/// which shows up as an off-palette navigation indicator or a tinted app bar
/// on scroll. The sub-themes below cover the surfaces `material_ui` paints
/// itself — inputs, dialogs, sheets, the app bar — so a screen that uses a
/// stock `material_ui` widget still looks like Spectra.
///
/// This is deliberately not a bridge to the in-SDK `ThemeData`: Spike B found
/// nothing in the dependency set needs one.
ThemeData spectraThemeData(SpectraColorScheme colors, Brightness brightness) {
  final ColorScheme scheme = ColorScheme(
    brightness: brightness,
    primary: colors.accent,
    onPrimary: colors.onAccent,
    primaryContainer: colors.surfaceRaised,
    onPrimaryContainer: colors.textPrimary,
    secondary: colors.connected,
    onSecondary: colors.onAccent,
    secondaryContainer: colors.surfaceRaised,
    onSecondaryContainer: colors.textPrimary,
    tertiary: colors.connected,
    onTertiary: colors.onAccent,
    error: colors.danger,
    onError: colors.onAccent,
    errorContainer: colors.surfaceRaised,
    onErrorContainer: colors.danger,
    surface: colors.surface,
    onSurface: colors.textPrimary,
    surfaceDim: colors.background,
    surfaceBright: colors.surface,
    surfaceContainerLowest: colors.surface,
    surfaceContainerLow: colors.background,
    surfaceContainer: colors.surfaceRaised,
    surfaceContainerHigh: colors.surfaceRaised,
    surfaceContainerHighest: colors.surfaceRaised,
    onSurfaceVariant: colors.textSecondary,
    outline: colors.borderStrong,
    outlineVariant: colors.border,
    surfaceTint: colors.surface,
    scrim: colors.scrim,
    inverseSurface: colors.textPrimary,
    onInverseSurface: colors.surface,
    inversePrimary: colors.accent,
    shadow: colors.scrim,
  );
  final TextTheme textTheme = SpectraTypography.textTheme(colors);
  final OutlineInputBorder inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(SpectraSpacing.sm),
    borderSide: BorderSide(color: colors.borderStrong),
  );
  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.background,
    canvasColor: colors.background,
    dividerColor: colors.border,
    textTheme: textTheme,
    dividerTheme: DividerThemeData(
      color: colors.border,
      space: 1,
      thickness: 1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      foregroundColor: colors.textPrimary,
      surfaceTintColor: const Color(0x00000000),
      scrolledUnderElevation: 0,
      elevation: 0,
      titleTextStyle: textTheme.titleLarge,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: colors.surface,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colors.accent, width: 2),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colors.danger),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colors.danger, width: 2),
      ),
      disabledBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colors.border),
      ),
      labelStyle: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
      hintStyle: textTheme.bodyMedium?.copyWith(color: colors.textDisabled),
      errorStyle: textTheme.bodySmall?.copyWith(color: colors.danger),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: const Color(0x00000000),
      barrierColor: colors.scrim,
      titleTextStyle: textTheme.titleMedium,
      contentTextStyle: textTheme.bodyMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SpectraSpacing.md),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: const Color(0x00000000),
      modalBarrierColor: colors.scrim,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SpectraSpacing.lg),
        ),
      ),
    ),
  );
}
