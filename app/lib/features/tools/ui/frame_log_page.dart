import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../l10n/app_localizations.dart';

/// Placeholder until Task 16 builds the frame log.
class FrameLogPage extends ConsumerWidget {
  const FrameLogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(SpectraSpacing.lg),
      children: <Widget>[SpectraSectionHeader(title: l10n.frameLogTitle)],
    );
  }
}
