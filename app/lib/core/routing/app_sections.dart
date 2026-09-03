import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/cards/cards.dart';
import '../../features/dashboard/dashboard.dart';
import '../../features/settings/settings.dart';
import '../../features/slots/slots.dart';
import '../../features/tools/tools.dart';
import '../../l10n/app_localizations.dart';
import 'routes.dart';

/// One top-level destination and the routes behind it. Spec 8.2: the shell
/// is assembled from two plain lists — this one, and the destinations
/// derived from it. Adding a feature is one entry here.
final class AppSection {
  const AppSection({
    required this.path,
    required this.label,
    required this.icon,
    required this.builder,
    this.selectedIcon,
    this.subRoutes = const <RouteBase>[],
  });

  final String path;
  final String Function(AppLocalizations l10n) label;
  final IconData icon;
  final IconData? selectedIcon;
  final Widget Function(BuildContext context, GoRouterState state) builder;

  /// Deep routes that push on top of this tab (spec 7.2).
  final List<RouteBase> subRoutes;
}

final List<AppSection> appSections = <AppSection>[
  AppSection(
    path: AppRoutes.device,
    label: (l10n) => l10n.navDevice,
    icon: Icons.memory_outlined,
    selectedIcon: Icons.memory,
    builder: (context, state) => const DashboardPage(),
  ),
  AppSection(
    path: AppRoutes.slots,
    label: (l10n) => l10n.navSlots,
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    builder: (context, state) => const SlotsPage(),
  ),
  AppSection(
    path: AppRoutes.cards,
    label: (l10n) => l10n.navCards,
    icon: Icons.style_outlined,
    selectedIcon: Icons.style,
    builder: (context, state) => const CardsPage(),
  ),
  AppSection(
    path: AppRoutes.tools,
    label: (l10n) => l10n.navTools,
    icon: Icons.build_outlined,
    selectedIcon: Icons.build,
    builder: (context, state) => const ToolsPage(),
    subRoutes: <RouteBase>[
      GoRoute(
        path: 'frame-log',
        builder: (context, state) => const FrameLogPage(),
      ),
      GoRoute(
        path: 'update',
        builder: (context, state) => UpdatePage(
          recoverTransportId: state.uri.queryParameters['recover'],
        ),
      ),
    ],
  ),
  AppSection(
    path: AppRoutes.settings,
    label: (l10n) => l10n.navSettings,
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    builder: (context, state) => const SettingsPage(),
  ),
];
