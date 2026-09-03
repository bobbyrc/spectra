import 'package:material_ui/material_ui.dart';

import '../../l10n/spectra_ui_localizations.dart';
import '../tokens/colors.dart';
import 'spectra_theme.dart';
import 'theme_data.dart';

/// The application root: `material_ui`'s router app, themed from Spectra
/// tokens, with the kit's localization delegate installed and a [SpectraTheme]
/// wrapped around every route.
class SpectraApp extends StatelessWidget {
  const SpectraApp({
    required this.routerConfig,
    this.title = 'Spectra',
    this.themeMode = ThemeMode.system,
    super.key,
  });

  final RouterConfig<Object> routerConfig;
  final String title;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: title,
      debugShowCheckedModeBanner: false,
      theme: spectraThemeData(SpectraColors.light, Brightness.light),
      darkTheme: spectraThemeData(SpectraColors.dark, Brightness.dark),
      themeMode: themeMode,
      routerConfig: routerConfig,
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        SpectraUiLocalizations.delegate,
      ],
      supportedLocales: SpectraUiLocalizations.supportedLocales,
      builder: (BuildContext context, Widget? child) {
        final Brightness brightness = Theme.of(context).brightness;
        return SpectraTheme(
          colors: brightness == Brightness.dark
              ? SpectraColors.dark
              : SpectraColors.light,
          brightness: brightness,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
