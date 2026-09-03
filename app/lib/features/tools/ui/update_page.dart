import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/flags/feature_flags.dart';
import '../../../core/routing/sub_page_scaffold.dart';
import '../../../l10n/app_localizations.dart';

/// Phase 8 fills this in. What exists now is the seam it needs: the
/// recovery target from the connect screen (spec 5.5) and the
/// `dfuOverBleEnabled` notice the roadmap requires while the flag is off.
class UpdatePage extends ConsumerWidget {
  const UpdatePage({this.recoverTransportId, super.key});

  /// The bootloader a "Recover" action named, from `?recover=`.
  final String? recoverTransportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final FeatureFlags flags = ref.watch(featureFlagsProvider);
    final String? target = recoverTransportId;

    return SubPageScaffold(
      title: l10n.updateTitle,
      body: ListView(
        padding: const EdgeInsets.all(SpectraSpacing.lg),
        children: <Widget>[
          SpectraSectionHeader(title: l10n.updateTitle),
          if (target != null) ...<Widget>[
            SpectraCard(child: Text(l10n.updateRecoverTarget(target))),
            const SizedBox(height: SpectraSpacing.md),
            SpectraCard(child: Text(l10n.updateRecoverInstructions)),
            const SizedBox(height: SpectraSpacing.md),
          ],
          if (!flags.dfuOverBleEnabled)
            SpectraCard(child: Text(l10n.updateBleNotice)),
          const SizedBox(height: SpectraSpacing.md),
          SpectraCard(child: Text(l10n.updateNoTarget)),
        ],
      ),
    );
  }
}
