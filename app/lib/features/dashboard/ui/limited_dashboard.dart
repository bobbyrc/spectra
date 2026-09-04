import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/error_catalog.dart';
import '../../../core/routing/routes.dart';
import '../../../l10n/app_localizations.dart';

/// Spec 7.2: a `limited` session can do exactly one thing, so this screen
/// offers exactly one action.
class LimitedDashboard extends ConsumerWidget {
  const LimitedDashboard({
    required this.state,
    required this.onDisconnect,
    super.key,
  });

  final SessionLimited state;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(SpectraSpacing.lg),
      children: <Widget>[
        SpectraSectionHeader(title: l10n.dashboardLimitedTitle),
        SpectraCard(
          child: Text(
            ErrorCatalog(l10n)
                .describe(UnsupportedFirmware(state.reason, 'limited'))
                .message,
          ),
        ),
        const SizedBox(height: SpectraSpacing.lg),
        SpectraButton(
          label: l10n.commonUpdateFirmware,
          onPressed: () => GoRouter.of(context).go(AppRoutes.update),
        ),
        const SizedBox(height: SpectraSpacing.md),
        SpectraButton(
          label: l10n.dashboardDisconnect,
          variant: SpectraButtonVariant.secondary,
          onPressed: onDisconnect,
        ),
      ],
    );
  }
}
