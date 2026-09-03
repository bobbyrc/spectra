import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../l10n/app_localizations.dart';

/// Placeholder until Phase 5 builds the slot grid.
class SlotsPage extends StatelessWidget {
  const SlotsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(SpectraSpacing.lg),
      children: <Widget>[
        SpectraSectionHeader(title: l10n.navSlots),
        SpectraCard(child: Text(l10n.comingSoonSlots)),
      ],
    );
  }
}
