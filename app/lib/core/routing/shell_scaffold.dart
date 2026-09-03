import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../l10n/app_localizations.dart';
import 'app_sections.dart';

/// The adaptive frame around every tab. Layout only: which branch is showing
/// is go_router's business, and the destinations come from [appSections].
class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SpectraAppShell(
      destinations: <SpectraDestination>[
        for (final AppSection section in appSections)
          SpectraDestination(
            label: section.label(l10n),
            icon: section.icon,
            selectedIcon: section.selectedIcon,
          ),
      ],
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (int index) =>
          navigationShell.goBranch(index, initialLocation: false),
      title: appSections[navigationShell.currentIndex].label(l10n),
      child: navigationShell,
    );
  }
}
