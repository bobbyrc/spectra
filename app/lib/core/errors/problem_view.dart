import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../l10n/app_localizations.dart';
import '../routing/routes.dart';
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
/// `ErrorRecovery.update` is the one recovery that names a destination, so
/// it does not go through [onAction]: the button opens the update screen,
/// either by calling [onUpdate] (what a bottom sheet passes, so it can close
/// itself on the way) or, when that is null, by routing there directly. It
/// used to share [onAction] with the rest, which on both card sheets meant
/// a button reading "Update firmware" that reset the sheet and went nowhere
/// — reachable, since a Chameleon Lite answers `MF1_WRITE_ONE_BLOCK` with
/// `InvalidCommand` (review I2).
///
/// [variant] is the button's weight: the connect screen's retry is the
/// primary action on an otherwise idle screen, while a failed slot change
/// is a dismissal sitting above the controls that are still on offer, so it
/// asks for [SpectraButtonVariant.secondary].
class ProblemView extends StatelessWidget {
  const ProblemView({
    required this.error,
    required this.onAction,
    this.onUpdate,
    this.instructions,
    this.variant,
    super.key,
  });

  final Object error;

  /// Runs the recovery the button offers — retry, dismiss, whatever the
  /// screen means by "that failed, move on".
  final VoidCallback onAction;

  /// Opens the update screen for `ErrorRecovery.update`. Null routes there
  /// directly, which is right for a full-page problem card; a sheet passes
  /// one that pops itself first, since `go` under a modal route would leave
  /// the sheet sitting on top of the screen it just opened.
  final VoidCallback? onUpdate;

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
          // One switch decides both whether there is an action and what it
          // says: `none` returning null is the single source of "no button
          // here", instead of an `if` above and a dead `none => 'Try again'`
          // arm below it that no build could ever reach (review M1).
          if (_actionLabel(l10n, p.recovery) case final String label) ...[
            const SizedBox(height: SpectraSpacing.md),
            SpectraButton(
              label: label,
              variant: variant ?? SpectraButtonVariant.primary,
              onPressed: p.recovery == ErrorRecovery.update
                  ? (onUpdate ??
                        () => GoRouter.of(context).go(AppRoutes.update))
                  : onAction,
            ),
          ],
        ],
      ),
    );
  }
}

/// The recovery button's label, or null when this recovery offers none.
String? _actionLabel(AppLocalizations l10n, ErrorRecovery recovery) =>
    switch (recovery) {
      ErrorRecovery.none => null,
      ErrorRecovery.openSettings => l10n.commonOpenSettings,
      ErrorRecovery.update => l10n.commonUpdateFirmware,
      ErrorRecovery.retry ||
      ErrorRecovery.platformInstructions ||
      ErrorRecovery.reconnect => l10n.commonRetry,
    };
