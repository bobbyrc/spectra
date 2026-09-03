import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spectra_ui/spectra_ui.dart';

import 'core/lifecycle/wakelock.dart';
import 'core/routing/router.dart';
import 'l10n/app_localizations.dart';

/// The application root: the design system's app widget, driven by
/// `routerProvider`. Task 11 wraps this in the lifecycle host.
class SpectraRoot extends ConsumerStatefulWidget {
  const SpectraRoot({super.key});

  @override
  ConsumerState<SpectraRoot> createState() => _SpectraRootState();
}

class _SpectraRootState extends ConsumerState<SpectraRoot> {
  @override
  void initState() {
    super.initState();
    // Task 11's AppLifecycleHost does not exist yet; this belongs in its
    // initState (after adding the lifecycle observer) once it lands. Reading
    // it once is enough: the provider is keepAlive and starts its own timer.
    // Deferred so the first frame is not blocked by a plugin call.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(wakelockProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SpectraApp(
      routerConfig: ref.watch(routerProvider),
      extraDelegates: const <LocalizationsDelegate<Object?>>[
        AppLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
