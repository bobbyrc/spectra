import 'package:alchemist/alchemist.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

/// Hosts one component under the Spectra theme and the kit's localizations.
///
/// A fixed [width]/[height] keeps golden scenarios bounded; `material_ui`'s
/// `MaterialApp` supplies every delegate the components need. [SpectraTheme]
/// is installed through `MaterialApp(builder:)`, mirroring `SpectraApp`, so
/// it also wraps content pushed on the root navigator (dialogs, bottom
/// sheets) rather than just `home`.
Widget spectraHarness({
  required Widget child,
  Brightness brightness = Brightness.light,
  double? width,
  double? height,
}) {
  final SpectraColorScheme colors = brightness == Brightness.dark
      ? SpectraColors.dark
      : SpectraColors.light;
  return SizedBox(
    width: width,
    height: height,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: spectraThemeData(colors, brightness),
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        SpectraUiLocalizations.delegate,
      ],
      supportedLocales: SpectraUiLocalizations.supportedLocales,
      builder: (BuildContext context, Widget? routedChild) {
        return SpectraTheme(
          colors: colors,
          brightness: brightness,
          child: routedChild ?? const SizedBox.shrink(),
        );
      },
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(SpectraSpacing.lg),
            child: child,
          ),
        ),
      ),
    ),
  );
}

/// One alchemist scenario wrapped in [spectraHarness].
GoldenTestScenario spectraScenario({
  required String name,
  required Widget child,
  Brightness brightness = Brightness.light,
  double width = 360,
  double height = 160,
}) {
  return GoldenTestScenario(
    name: name,
    child: spectraHarness(
      brightness: brightness,
      width: width,
      height: height,
      child: child,
    ),
  );
}
