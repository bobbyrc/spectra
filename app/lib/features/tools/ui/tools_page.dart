import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/routing/routes.dart';
import '../../../l10n/app_localizations.dart';

/// A real list from the start: Task 16 only fills in the pages behind it.
class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(SpectraSpacing.lg),
      children: <Widget>[
        SpectraSectionHeader(title: l10n.toolsTitle),
        SpectraListTile(
          title: l10n.toolsFrameLog,
          subtitle: l10n.toolsFrameLogSubtitle,
          leading: const Icon(Icons.receipt_long_outlined),
          onTap: () => GoRouter.of(context).go(AppRoutes.frameLog),
        ),
        SpectraListTile(
          title: l10n.toolsDictionaries,
          subtitle: l10n.toolsDictionariesSubtitle,
          leading: const Icon(Icons.key_outlined),
          onTap: () => GoRouter.of(context).go(AppRoutes.dictionaries),
        ),
        SpectraListTile(
          title: l10n.toolsUpdate,
          leading: const Icon(Icons.system_update_alt),
          onTap: () => GoRouter.of(context).go(AppRoutes.update),
        ),
      ],
    );
  }
}
