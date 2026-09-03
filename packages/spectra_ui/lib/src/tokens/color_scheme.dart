import 'package:flutter/widgets.dart' show Color;

/// The colour roles resolved for one brightness.
///
/// Both schemes are derived from the raw palette in [SpectraColors]; nothing
/// in the kit reads a raw palette entry directly.
final class SpectraColorScheme {
  const SpectraColorScheme({
    required this.accent,
    required this.onAccent,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.success,
    required this.warning,
    required this.danger,
    required this.connected,
    required this.scrim,
  });

  final Color accent;
  final Color onAccent;
  final Color background;
  final Color surface;
  final Color surfaceRaised;

  /// Decorative separators and container edges. Not guaranteed to clear the
  /// 3:1 non-text contrast bar; never use it to outline something tappable.
  final Color border;

  /// The outline of an interactive boundary (secondary button, text field).
  /// At least 3:1 against [surface], [surfaceRaised] and [background], so it
  /// meets WCAG 1.4.11 non-text contrast.
  final Color borderStrong;

  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color success;
  final Color warning;
  final Color danger;
  final Color connected;
  final Color scrim;
}
