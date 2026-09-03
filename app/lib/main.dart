import 'package:flutter/widgets.dart';

void main() {
  runApp(const SpectraApp());
}

/// Placeholder root until Phase 4 builds the shell.
class SpectraApp extends StatelessWidget {
  const SpectraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Color(0xFFFFFFFF),
        child: Center(child: Text('Spectra')),
      ),
    );
  }
}
