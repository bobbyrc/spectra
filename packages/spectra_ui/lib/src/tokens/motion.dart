import 'package:flutter/widgets.dart' show Curve, Curves;

/// Three durations and two curves (spec 6.1), applied through flutter_animate.
abstract final class SpectraMotion {
  /// State flips: chip colour, checkbox, hover.
  static const Duration fast = Duration(milliseconds: 120);

  /// The default: disclosure expansion, sheet content, list reorder.
  static const Duration medium = Duration(milliseconds: 220);

  /// Full-surface changes: route transitions, sheet entry.
  static const Duration slow = Duration(milliseconds: 400);

  /// Everything that enters or settles.
  static const Curve standard = Curves.easeOutCubic;

  /// Anything that both leaves and arrives, such as a size change.
  static const Curve emphasized = Curves.easeInOutCubic;
}
