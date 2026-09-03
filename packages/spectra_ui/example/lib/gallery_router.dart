import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import 'gallery_entry.dart';

/// One route per component, all inside the adaptive shell. `/` redirects to
/// the first entry so the shell always has a selected destination.
GoRouter buildGalleryRouter() {
  return GoRouter(
    initialLocation: galleryEntries.first.path,
    routes: <RouteBase>[
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          final int index = galleryEntries.indexWhere(
            (GalleryEntry e) => e.path == state.uri.path,
          );
          return SpectraAppShell(
            destinations: <SpectraDestination>[
              for (final GalleryEntry e in galleryEntries)
                SpectraDestination(
                  label: e.title,
                  icon: Icons.widgets_outlined,
                ),
            ],
            selectedIndex: index < 0 ? 0 : index,
            onDestinationSelected: (int i) =>
                GoRouter.of(context).go(galleryEntries[i].path),
            title: index < 0
                ? galleryEntries.first.title
                : galleryEntries[index].title,
            child: child,
          );
        },
        routes: <RouteBase>[
          for (final GalleryEntry entry in galleryEntries)
            GoRoute(
              path: entry.path,
              builder: (BuildContext context, GoRouterState state) =>
                  entry.builder(context),
            ),
        ],
      ),
    ],
  );
}
