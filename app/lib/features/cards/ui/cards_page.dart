import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/routing/routes.dart';
import '../../../l10n/app_localizations.dart';

/// The card library. Task 6 fills in the list; this is the read entry point.
class CardsPage extends StatelessWidget {
  const CardsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(SpectraSpacing.lg),
      children: <Widget>[
        SpectraButton(
          label: l10n.cardsReadAction,
          icon: Icons.nfc,
          onPressed: () => GoRouter.of(context).go(AppRoutes.cardRead),
        ),
      ],
    );
  }
}
