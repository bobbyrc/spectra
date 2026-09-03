import 'package:flutter/widgets.dart' show IconData;

/// Width at which the shell swaps a bottom bar for a navigation rail
/// (spec 6.2).
const double spectraNavigationRailBreakpoint = 600;

/// One top-level navigation target. A plain value so routing owns the route
/// table and the shell stays a dumb layout.
final class SpectraDestination {
  const SpectraDestination({
    required this.label,
    required this.icon,
    this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
}
