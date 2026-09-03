import 'package:material_ui/material_ui.dart';

import '../theme/spectra_theme.dart';
import '../tokens/typography.dart';
import 'destination.dart';

/// The adaptive application frame: a bottom bar under
/// [spectraNavigationRailBreakpoint], a navigation rail at or above it.
class SpectraAppShell extends StatelessWidget {
  const SpectraAppShell({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
    this.title,
    this.actions = const <Widget>[],
    super.key,
  });

  final List<SpectraDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;
  final String? title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    final String? shellTitle = title;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide =
            constraints.maxWidth >= spectraNavigationRailBreakpoint;
        return Scaffold(
          backgroundColor: theme.colors.background,
          appBar: shellTitle == null
              ? null
              : AppBar(
                  backgroundColor: theme.colors.surface,
                  title: Text(
                    shellTitle,
                    style: SpectraTypography.title.copyWith(
                      color: theme.colors.textPrimary,
                    ),
                  ),
                  actions: actions,
                ),
          body: wide
              ? Row(
                  children: <Widget>[
                    NavigationRail(
                      backgroundColor: theme.colors.surface,
                      selectedIndex: selectedIndex,
                      onDestinationSelected: onDestinationSelected,
                      labelType: NavigationRailLabelType.all,
                      destinations: <NavigationRailDestination>[
                        for (final SpectraDestination d in destinations)
                          NavigationRailDestination(
                            icon: Icon(d.icon),
                            selectedIcon: Icon(d.selectedIcon ?? d.icon),
                            label: Text(d.label),
                          ),
                      ],
                    ),
                    VerticalDivider(width: 1, color: theme.colors.border),
                    Expanded(child: child),
                  ],
                )
              : child,
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  backgroundColor: theme.colors.surface,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  destinations: <NavigationDestination>[
                    for (final SpectraDestination d in destinations)
                      NavigationDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon ?? d.icon),
                        label: d.label,
                      ),
                  ],
                ),
        );
      },
    );
  }
}
