import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../l10n/app_localizations.dart';

/// Placeholder until Task 16 builds the firmware update flow. Already takes
/// and stores [recoverTransportId] (spec 5.5's bootloader recovery entry);
/// Task 16 reads it to talk straight to the bootloader that sent it here.
class UpdatePage extends ConsumerWidget {
  const UpdatePage({this.recoverTransportId, super.key});

  final String? recoverTransportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(SpectraSpacing.lg),
      children: <Widget>[
        SpectraSectionHeader(title: l10n.updateTitle),
        SpectraCard(child: Text(l10n.comingSoonUpdate)),
      ],
    );
  }
}
