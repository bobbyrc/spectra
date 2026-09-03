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
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color success;
  final Color warning;
  final Color danger;
  final Color connected;
  final Color scrim;
}
