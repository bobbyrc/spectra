import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spectra_ui/spectra_ui.dart';

import 'core/lifecycle/lifecycle_host.dart';
import 'core/routing/router.dart';
import 'l10n/app_localizations.dart';

/// The application root: the design system's app widget, driven by
/// `routerProvider`, wrapped in the lifecycle host (spec 7.4).
class SpectraRoot extends ConsumerWidget {
  const SpectraRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppLifecycleHost(
      child: SpectraApp(
        routerConfig: ref.watch(routerProvider),
        extraDelegates: const <LocalizationsDelegate<Object?>>[
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }
}
