import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

void main() {
  testWidgets('SpectraTheme.of returns the resolved dark scheme', (
    tester,
  ) async {
    late SpectraTheme theme;
    await tester.pumpWidget(
      SpectraTheme(
        colors: SpectraColors.dark,
        brightness: Brightness.dark,
        child: Builder(
          builder: (context) {
            theme = SpectraTheme.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(theme.brightness, Brightness.dark);
    expect(theme.colors.accent, SpectraColors.dark.accent);
  });

  testWidgets('SpectraTheme.maybeOf is null outside a theme', (tester) async {
    SpectraTheme? theme;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          theme = SpectraTheme.maybeOf(context);
          return const SizedBox.shrink();
        },
      ),
    );
    expect(theme, isNull);
  });

  test('spectraThemeData maps our tokens onto material_ui', () {
    final data = spectraThemeData(SpectraColors.light, Brightness.light);
    expect(data.brightness, Brightness.light);
    expect(data.colorScheme.primary, SpectraColors.light.accent);
    expect(data.colorScheme.error, SpectraColors.light.danger);
    expect(data.scaffoldBackgroundColor, SpectraColors.light.background);
    expect(data.textTheme.bodyMedium!.color, SpectraColors.light.textPrimary);
  });

  test('spectraThemeData fills every ColorScheme role from a token', () {
    for (final (SpectraColorScheme colors, Brightness brightness)
        in <(SpectraColorScheme, Brightness)>[
          (SpectraColors.light, Brightness.light),
          (SpectraColors.dark, Brightness.dark),
        ]) {
      final ColorScheme scheme = spectraThemeData(
        colors,
        brightness,
      ).colorScheme;
      // The roles that used to fall back to a Material default.
      expect(scheme.outline, colors.borderStrong);
      expect(scheme.outlineVariant, colors.border);
      expect(scheme.secondaryContainer, colors.surfaceRaised);
      expect(scheme.onSecondaryContainer, colors.textPrimary);
      expect(scheme.onSurfaceVariant, colors.textSecondary);
      expect(scheme.scrim, colors.scrim);
      expect(scheme.surfaceTint, colors.surface);
      expect(scheme.surfaceTint, isNot(scheme.primary));
      expect(scheme.surfaceContainer, colors.surfaceRaised);
      expect(scheme.surfaceContainerHighest, colors.surfaceRaised);
      expect(scheme.outline, isNot(scheme.onSurface));
    }
  });

  test('spectraThemeData styles the surfaces material_ui paints itself', () {
    const SpectraColorScheme colors = SpectraColors.light;
    final ThemeData data = spectraThemeData(colors, Brightness.light);

    final InputDecorationThemeData input = data.inputDecorationTheme;
    expect(input.filled, isTrue);
    expect(input.fillColor, colors.surface);
    expect(
      (input.enabledBorder! as OutlineInputBorder).borderSide.color,
      colors.borderStrong,
    );
    expect(
      (input.focusedBorder! as OutlineInputBorder).borderSide.color,
      colors.accent,
    );

    expect(data.dialogTheme.backgroundColor, colors.surface);
    expect(data.dialogTheme.barrierColor, colors.scrim);
    expect(data.dialogTheme.shape, isA<RoundedRectangleBorder>());

    expect(data.bottomSheetTheme.backgroundColor, colors.surface);
    expect(data.bottomSheetTheme.modalBarrierColor, colors.scrim);
    expect(
      (data.bottomSheetTheme.shape! as RoundedRectangleBorder).borderRadius,
      const BorderRadius.vertical(top: Radius.circular(SpectraSpacing.lg)),
    );

    expect(data.appBarTheme.backgroundColor, colors.surface);
    expect(data.appBarTheme.scrolledUnderElevation, 0);
    expect(data.appBarTheme.surfaceTintColor!.a, 0);
    expect(
      data.appBarTheme.titleTextStyle!.fontFamily,
      contains(SpectraTypography.sansFamily),
    );
    expect(data.appBarTheme.titleTextStyle!.fontSize, 20);
  });

  testWidgets('SpectraApp themes material_ui widgets and installs l10n', (
    tester,
  ) async {
    late BuildContext inner;
    await tester.pumpWidget(
      SpectraApp(
        themeMode: ThemeMode.light,
        routerConfig: RouterConfig<Object>(
          routerDelegate: _SingleRouteDelegate((context) {
            inner = context;
            return const Scaffold(body: SizedBox.shrink());
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(Theme.of(inner).colorScheme.primary, SpectraColors.light.accent);
    expect(SpectraTheme.of(inner).colors.accent, SpectraColors.light.accent);
    expect(SpectraUiLocalizations.of(inner).cancel, 'Cancel');
    expect(
      Localizations.of<MaterialLocalizations>(inner, MaterialLocalizations),
      isNotNull,
    );
  });

  testWidgets('SpectraApp installs extra delegates, a locale and a messenger', (
    tester,
  ) async {
    late BuildContext inner;
    final GlobalKey<ScaffoldMessengerState> messengerKey =
        GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(
      SpectraApp(
        themeMode: ThemeMode.light,
        scaffoldMessengerKey: messengerKey,
        locale: const Locale('en'),
        supportedLocales: const <Locale>[Locale('en')],
        extraDelegates: const <LocalizationsDelegate<Object?>>[
          _GreetingDelegate(),
        ],
        routerConfig: RouterConfig<Object>(
          routerDelegate: _SingleRouteDelegate((context) {
            inner = context;
            return const Scaffold(body: SizedBox.shrink());
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(Localizations.of<_Greeting>(inner, _Greeting)!.hello, 'hello');
    // The kit's own delegates are still installed alongside the extra one.
    expect(SpectraUiLocalizations.of(inner).cancel, 'Cancel');
    expect(messengerKey.currentState, isNotNull);
    expect(Localizations.localeOf(inner), const Locale('en'));
  });
}

/// A stand-in for an app-supplied localization bundle.
class _Greeting {
  const _Greeting(this.hello);
  final String hello;
}

class _GreetingDelegate extends LocalizationsDelegate<_Greeting> {
  const _GreetingDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<_Greeting> load(Locale locale) async => const _Greeting('hello');

  @override
  bool shouldReload(_GreetingDelegate old) => false;
}

/// Minimal router that always builds one page, so the test needs no go_router.
class _SingleRouteDelegate extends RouterDelegate<Object>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<Object> {
  _SingleRouteDelegate(this.builder);

  final WidgetBuilder builder;

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: <Page<Object?>>[
        MaterialPage<Object?>(child: Builder(builder: builder)),
      ],
      onDidRemovePage: (_) {},
    );
  }

  @override
  Future<void> setNewRoutePath(Object configuration) async {}
}
