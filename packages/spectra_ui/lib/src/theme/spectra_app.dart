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
    this.onGenerateTitle,
    this.themeMode = ThemeMode.system,
    this.extraDelegates = const <LocalizationsDelegate<Object?>>[],
    this.supportedLocales,
    this.locale,
    this.scaffoldMessengerKey,
    super.key,
  });

  final RouterConfig<Object> routerConfig;

  /// The window/task-switcher title. [onGenerateTitle] wins when given.
  final String title;

  /// A localized title, built under the app's own [Localizations] — which
  /// [title] cannot be, since it is read above them.
  final String Function(BuildContext)? onGenerateTitle;
  final ThemeMode themeMode;

  /// Delegates the app adds on top of the kit's own — a feature package's
  /// generated localizations, say. They are installed before the kit's, so
  /// an app delegate wins for a type the kit also resolves.
  final List<LocalizationsDelegate<Object?>> extraDelegates;

  /// Overrides the locales the kit ships with. Null keeps
  /// [SpectraUiLocalizations.supportedLocales].
  final Iterable<Locale>? supportedLocales;

  /// Pins the app to one locale, ignoring the platform's. Null follows the
  /// device.
  final Locale? locale;

  /// Lets code outside the widget tree (a background operation reporting a
  /// failure, for instance) show a snack bar.
  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: title,
      onGenerateTitle: onGenerateTitle,
      debugShowCheckedModeBanner: false,
      theme: spectraThemeData(SpectraColors.light, Brightness.light),
      darkTheme: spectraThemeData(SpectraColors.dark, Brightness.dark),
      themeMode: themeMode,
      routerConfig: routerConfig,
      scaffoldMessengerKey: scaffoldMessengerKey,
      locale: locale,
      localizationsDelegates: <LocalizationsDelegate<Object?>>[
        ...extraDelegates,
        ...SpectraUiLocalizations.localizationsDelegates,
      ],
      supportedLocales:
          supportedLocales ?? SpectraUiLocalizations.supportedLocales,
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
