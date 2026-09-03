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
  });
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
