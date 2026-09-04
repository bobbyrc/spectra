import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import 'gallery_router.dart';

/// The gallery root. Owns the light/dark toggle so the whole kit can be seen
/// in both schemes without changing the host system setting.
class GalleryApp extends StatefulWidget {
  const GalleryApp({this.router, super.key});

  final GoRouter? router;

  @override
  State<GalleryApp> createState() => _GalleryAppState();
}

class _GalleryAppState extends State<GalleryApp> {
  late final GoRouter _router = widget.router ?? buildGalleryRouter();
  ThemeMode _mode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    // The toggle sits above `SpectraApp` in a `Stack` so it is reachable
    // from every route without the shell growing a gallery-only action.
    // `SpectraApp` installs its own `Directionality` via `MaterialApp`, but
    // that only applies below it in the tree; this `Stack` sits above it,
    // so it needs its own to satisfy the `Positioned`/text layout above.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: <Widget>[
          SpectraApp(
            title: 'Spectra UI gallery',
            themeMode: _mode,
            routerConfig: _router,
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Semantics(
              button: true,
              label: 'Toggle dark mode',
              child: GestureDetector(
                onTap: () => setState(
                  () => _mode = _mode == ThemeMode.light
                      ? ThemeMode.dark
                      : ThemeMode.light,
                ),
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.brightness_6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
