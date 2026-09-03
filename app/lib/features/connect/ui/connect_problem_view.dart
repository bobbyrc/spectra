import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/error_catalog.dart';
import '../../../core/errors/error_presentation.dart';
import '../../../l10n/app_localizations.dart';

/// A failure, in the shape spec 9 asks for: one plain sentence, a recovery
/// action, and the raw line one tap away.
///
/// `ErrorRecovery.openSettings` still wires its button to [onRetry]: opening
/// system settings is a platform call this phase does not own, and
/// [instructions] (when given) already tells the user where to go by hand.
///
/// [instructions] is supplied by the caller: `ConnectPage` fills it in from
/// the failed transport's `GuidedTransport.guidance` (kept by `Sessions` as
/// `SessionsState.lastFailureGuidance`) through `ErrorCatalog.guidance()` —
/// this widget has no transport of its own to ask. Falls back to
/// `ErrorPresentation.instructions` (the catalog's own guidance, when it has
/// any) so a future catalog value that fills that field is not silently
/// dropped just because the caller passed nothing.
class ConnectProblemView extends StatelessWidget {
  const ConnectProblemView({
    required this.error,
    required this.onRetry,
    this.instructions,
    super.key,
  });

  final Object error;
  final VoidCallback onRetry;
  final String? instructions;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ErrorPresentation p = ErrorCatalog(l10n).describe(error);
    return SpectraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(p.message),
          if ((instructions ?? p.instructions)
              case final String shown) ...<Widget>[
            const SizedBox(height: SpectraSpacing.sm),
            Text(shown),
          ],
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
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
