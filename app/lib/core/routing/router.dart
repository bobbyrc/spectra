import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/connect/connect.dart';
import '../session/session_streams.dart';
import 'app_sections.dart';
import 'redirect.dart';
import 'routes.dart';
import 'shell_scaffold.dart';

part 'router.g.dart';

/// Wakes go_router whenever the connection state changes, so [redirectFor]
/// runs again (spec 7.2).
final class RouterRefresh extends ChangeNotifier {
  RouterRefresh(Ref ref) {
    ref.listen(connectionStatusProvider, (_, _) => notifyListeners());
  }
}

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final refresh = RouterRefresh(ref);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: AppRoutes.connect,
    refreshListenable: refresh,
    redirect: (context, state) => redirectFor(
      state: ref.read(connectionStatusProvider),
      location: state.uri.path,
    ),
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.connect,
        builder: (context, state) => const ConnectPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScaffold(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          for (final AppSection section in appSections)
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: section.path,
                  builder: section.builder,
                  routes: section.subRoutes,
                ),
              ],
            ),
        ],
      ),
    ],
  );
}
