import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/error_catalog.dart';
import '../../../core/errors/error_presentation.dart';
import '../../../l10n/app_localizations.dart';

/// A slot change that failed, in the shape spec 9 asks for: one plain
/// sentence, a recovery action, and the raw line one tap away.
///
/// Unlike the connect screen's version (`ConnectProblemView`), the only
/// action here is "dismiss and try again" — a slot change has nothing to
/// reconnect or re-scan, and the controls that produced the failure are
/// still on screen. The recovery enum still chooses the button's words so
/// the copy stays consistent with the rest of the app.
class SlotProblemView extends StatelessWidget {
  const SlotProblemView({
    required this.error,
    required this.onDismiss,
    super.key,
  });

  final Object error;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ErrorPresentation p = ErrorCatalog(l10n).describe(error);
    return SpectraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(p.message),
          const SizedBox(height: SpectraSpacing.md),
          SpectraDisclosure(
            summary: Text(l10n.commonDetails),
            detail: Text(p.detail),
          ),
          const SizedBox(height: SpectraSpacing.md),
          SpectraButton(
            label: switch (p.recovery) {
              ErrorRecovery.openSettings => l10n.commonOpenSettings,
              ErrorRecovery.update => l10n.commonUpdateFirmware,
              ErrorRecovery.retry ||
              ErrorRecovery.platformInstructions ||
              ErrorRecovery.reconnect ||
              ErrorRecovery.none => l10n.commonRetry,
            },
            variant: SpectraButtonVariant.secondary,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
