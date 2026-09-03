import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';

/// The application root. Everything above it is `ProviderScope`; everything
/// below it comes from `routerProvider` once Task 10 lands.
///
/// This is a deliberately throwaway shell: `spectra_ui`'s `SpectraApp` needs
/// a `routerConfig` that does not exist until Task 10, and a bare `Scaffold`
/// without a `MediaQuery` ancestor throws in `pumpWidget`. So this renders
/// the minimum `Localizations` + `Directionality` + `MediaQuery` stack a
/// widget test needs, with nothing but the app title on screen.
class SpectraRoot extends ConsumerWidget {
  const SpectraRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Localizations(
      locale: const Locale('en'),
      delegates: const <LocalizationsDelegate<Object?>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(data: MediaQueryData(), child: _AppTitle()),
      ),
    );
  }
}

class _AppTitle extends StatelessWidget {
  const _AppTitle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        AppLocalizations.of(context).appTitle,
        textDirection: TextDirection.ltr,
      ),
    );
  }
}
