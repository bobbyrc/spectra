import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  runApp(SpectraUiGalleryApp(router: buildGalleryRouter()));
}

/// The two-route probe router. Both routes use go_router's default page
/// builder, which wraps each page in `material_ui`'s `MaterialPage`.
GoRouter buildGalleryRouter() {
  return GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => const GalleryPage(
          title: 'Spectra UI gallery',
          buttonLabel: 'Go to details',
          destination: '/details',
        ),
      ),
      GoRoute(
        path: '/details',
        builder: (_, _) => const GalleryPage(
          title: 'Details',
          buttonLabel: 'Back to gallery',
          destination: '/',
        ),
      ),
    ],
  );
}

/// Theme for the gallery shell, built with `material_ui`'s `ThemeData`.
ThemeData galleryTheme(Brightness brightness) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF3F5AE0),
      brightness: brightness,
    ),
  );
}

/// Placeholder root until the gallery grows real component demos.
class SpectraUiGalleryApp extends StatelessWidget {
  const SpectraUiGalleryApp({required this.router, super.key});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Spectra UI gallery',
      theme: galleryTheme(Brightness.light),
      darkTheme: galleryTheme(Brightness.dark),
      routerConfig: router,
    );
  }
}

/// One probe page: a themed `material_ui` button and text field.
class GalleryPage extends StatelessWidget {
  const GalleryPage({
    required this.title,
    required this.buttonLabel,
    required this.destination,
    super.key,
  });

  final String title;
  final String buttonLabel;
  final String destination;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: <Widget>[
            SizedBox(
              width: 280,
              child: TextField(
                decoration: InputDecoration(
                  labelText: '$title field',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => context.go(destination),
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
