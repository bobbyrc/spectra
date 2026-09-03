import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../l10n/app_localizations.dart';
import 'error_catalog.dart';
import 'error_presentation.dart';

/// A failure, in the shape spec 9 asks for: one plain sentence, a recovery
/// action, and the raw line one tap away.
///
/// One widget for every screen. The connect screen and the slot editor each
/// grew their own copy of this card — same catalog lookup, same disclosure,
/// same `ErrorRecovery` label switch — which is exactly one place for the
/// wording of a recovery action to drift out of step with the other.
///
/// `ErrorRecovery.openSettings` still wires its button to [onAction]:
/// opening system settings is a platform call no phase owns yet, and
/// [instructions] (when given) already tells the user where to go by hand.
///
/// [instructions] is supplied by the caller that knows more than the
/// catalog does: `ConnectPage` fills it in from the failed transport's
/// `GuidedTransport.guidance` through `ErrorCatalog.guidance()`. It falls
/// back to `ErrorPresentation.instructions` (the catalog's own guidance,
/// when it has any) so a catalog value that fills that field is not
/// silently dropped because the caller passed nothing.
///
/// [variant] is the button's weight: the connect screen's retry is the
/// primary action on an otherwise idle screen, while a failed slot change
/// is a dismissal sitting above the controls that are still on offer, so it
/// asks for [SpectraButtonVariant.secondary].
class ProblemView extends StatelessWidget {
  const ProblemView({
    required this.error,
    required this.onAction,
    this.instructions,
    this.variant,
    super.key,
  });

  final Object error;

  /// Runs the recovery the button offers — retry, dismiss, whatever the
  /// screen means by "that failed, move on".
  final VoidCallback onAction;

  final String? instructions;

  /// Defaults to [SpectraButtonVariant.primary], as `SpectraButton` does.
  final SpectraButtonVariant? variant;

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
          if (p.recovery != ErrorRecovery.none) ...<Widget>[
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
              variant: variant ?? SpectraButtonVariant.primary,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}
