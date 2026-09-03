import 'package:flutter/widgets.dart';

void main() {
  runApp(const SpectraUiGalleryApp());
}

/// Placeholder root until the gallery grows real component demos.
class SpectraUiGalleryApp extends StatelessWidget {
  const SpectraUiGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: Text('Spectra UI gallery')),
    );
  }
}
