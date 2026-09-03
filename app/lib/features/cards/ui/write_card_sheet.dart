import 'dart:async';
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/problem_view.dart';
import '../../../core/errors/warning_callout.dart';
import '../../../core/format/sector_list.dart';
import '../../../core/format/tag_labels.dart';
import '../../../core/routing/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../state/write_card_controller.dart';
import '../state/write_target.dart';

/// Spec 7.7 step 5: write [bytes] onto the card in the reader's field.
///
/// Resolves to true when a write finished — complete or partial, both are
/// outcomes the user acted on — and to null when the sheet was dismissed,
/// including a dismissal after an unsupported type, a cancellation or a
/// failure.
///
/// **`hardware-validate`: the sheet carries a standing notice, because
/// everything under it is proven against `FakeDevice` only.** Remove the
/// notice when the H3 checklist item for a physical write is reported
/// passing, not before.
Future<bool?> showWriteToCardSheet(
  BuildContext context, {
  required TagType type,
  required Uint8List bytes,
  required String name,
}) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return SpectraBottomSheet.show<bool>(
    context: context,
    title: l10n.cardsWriteTitle,
    builder: (BuildContext context) =>
        _WriteCardBody(type: type, bytes: bytes, name: name),
  );
}

class _WriteCardBody extends ConsumerStatefulWidget {
  const _WriteCardBody({
    required this.type,
    required this.bytes,
    required this.name,
  });

  final TagType type;
  final Uint8List bytes;
  final String name;

  @override
  ConsumerState<_WriteCardBody> createState() => _WriteCardBodyState();
}

class _WriteCardBodyState extends ConsumerState<_WriteCardBody> {
  /// Opt-in toggle for [CardWriter.write]'s `writeTrailers`, default off —
  /// the controller's own doc comment says the same: a saved dump's
  /// sector trailers only go onto the card when the caller explicitly
  /// opts in, because a *read* dump carries key A zeroed out in every
  /// trailer.
  bool _writeTrailers = false;

  @override
  void initState() {
    super.initState();
    // Ruling 5 (as `load_to_slot_sheet.dart`'s `_LoadToSlotBodyState`):
    // `cardWriterProvider` is a global autoDispose notifier whose terminal
    // state survives while any listener lives (this sheet, or a test's
    // `keepAlive`). Reset on open so a second write in one session starts
    // from the confirm card, not the previous write's outcome.
    //
    // Deferred a frame: riverpod refuses to modify a provider's state
    // while the widget tree is still building, and `initState` runs
    // inside that build.
    Future(() {
      if (mounted) ref.read(cardWriterProvider.notifier).reset();
    });
  }

  void _write({bool confirmUnread = false}) {
    unawaited(
      ref
          .read(cardWriterProvider.notifier)
          .write(
            type: widget.type,
            bytes: widget.bytes,
            writeTrailers: _writeTrailers,
            confirmUnread: confirmUnread,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CardWriteState state = ref.watch(cardWriterProvider);
    // Ruling 30: the one screen that can leave a card mid-write must not
    // be dismissable while it is running — a swipe-down or the sheet's own
    // X (`SpectraBottomSheet`'s close icon goes through `maybePop`) is
    // refused, and only `Cancel` on the progress indicator can end the
    // write early.
    return PopScope(canPop: !state.busy, child: _body(context, state));
  }

  Widget _body(BuildContext context, CardWriteState state) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CardWriter writer = ref.read(cardWriterProvider.notifier);

    if (state.error case final Object error) {
      return ProblemView(
        error: error,
        onAction: writer.reset,
        // A Lite answers MF1_WRITE_ONE_BLOCK with `InvalidCommand`, whose
        // recovery is `update`. The sheet closes itself before routing:
        // `go` alone would open the update screen behind a sheet still
        // sitting on top of it (review I2).
        onUpdate: () {
          Navigator.of(context).pop();
          GoRouter.of(context).go(AppRoutes.update);
        },
        variant: SpectraButtonVariant.secondary,
      );
    }
    if (state.cancelled) {
      // Ruling 3: a terminal state with its own words, not `ProblemView` —
      // the user's own Cancel tap must never read as a failure on the one
      // screen that can leave a card half-written. The partial counts are
      // discarded on cancel (`CardWriteState.cancelled`'s doc), so the
      // copy does not guess at how much reached the card.
      return _Finished(
        message: l10n.cardsWriteCancelled,
        onClose: () => Navigator.of(context).pop(),
      );
    }
    if (state.busy) {
      // Ruling 14: `state.progress` counts sectors, `written`/`attempted`
      // count blocks. Never shown together — this is the only place
      // `progress` is rendered, and the done card below never repeats it.
      return SpectraProgressIndicator(
        label: l10n.cardsWriteProgress,
        value: state.progress,
        onCancel: writer.cancel,
      );
    }
    if (state.isDone) {
      return SpectraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.cardsWriteDone(state.written!, state.attempted!)),
            if (state.isPartial) ...<Widget>[
              const SizedBox(height: SpectraSpacing.sm),
              Text(l10n.cardsWritePartial),
            ],
            const SizedBox(height: SpectraSpacing.lg),
            SpectraButton(
              label: l10n.commonClose,
              variant: SpectraButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );
    }
    if (state.unsupported) {
      return _Finished(
        message: l10n.cardsWriteUnsupported,
        onClose: () => Navigator.of(context).pop(),
      );
    }
    // Ruling 23/27: an all-zero (or key-A-zeroed) sector trailer is not an
    // error — it is a saved dump whose keys were never recovered — so
    // writing it is confirmed explicitly, with a warning that doing so
    // puts a zero key on the card, rather than silently written.
    if (state.unreadSectors case final List<int> sectors
        when sectors.isNotEmpty) {
      return _UnreadSectorsWarning(
        sectors: sectors,
        onConfirm: () => _write(confirmUnread: true),
        // Back to the confirm card, where the trailers toggle — local
        // widget state, untouched by `reset()` — can be turned off
        // instead. A warning whose only button is "Write anyway" is a
        // one-way door (review I3).
        onBack: writer.reset,
      );
    }

    return SpectraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.cardsWritePrompt(widget.name)),
          const SizedBox(height: SpectraSpacing.sm),
          Text(tagTypeLabel(widget.type, l10n)),
          const SizedBox(height: SpectraSpacing.md),
          Text(l10n.cardsWriteNotice),
          const SizedBox(height: SpectraSpacing.md),
          // Sector trailers are a MIFARE Classic notion, and `CardWriter`
          // only passes `writeTrailers` down the Classic branch: on an
          // EM410x the toggle was a control that changed nothing (review
          // M2).
          if (writeMethodFor(widget.type) ==
              CardWriteMethod.mifareClassicBlocks) ...<Widget>[
            SpectraListTile(
              title: l10n.cardsWriteTrailersLabel,
              subtitle: l10n.cardsWriteTrailersWarning,
              trailing: Switch(
                value: _writeTrailers,
                onChanged: (bool next) => setState(() => _writeTrailers = next),
              ),
            ),
          ],
          const SizedBox(height: SpectraSpacing.lg),
          SpectraButton(
            label: l10n.cardsWriteConfirm,
            onPressed: () => _write(),
          ),
        ],
      ),
    );
  }
}

/// The terminal states with a single sentence and a way out: unsupported
/// and cancelled. The sheet does not pop itself from a provider listener —
/// both are worth reading before dismissing, and popping a modal route
/// while a listener could still fire is a flake this screen does not need.
class _Finished extends StatelessWidget {
  const _Finished({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SpectraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(message),
          const SizedBox(height: SpectraSpacing.lg),
          SpectraButton(
            label: l10n.commonClose,
            variant: SpectraButtonVariant.secondary,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// Ruling 23/27: names the sector trailers a dump has no recovered key for
/// and asks for an explicit yes before writing them onto the card — or a way
/// back to the confirm card, where the trailers toggle that caused the
/// warning can be turned off (review I3).
class _UnreadSectorsWarning extends StatelessWidget {
  const _UnreadSectorsWarning({
    required this.sectors,
    required this.onConfirm,
    required this.onBack,
  });

  final List<int> sectors;
  final VoidCallback onConfirm;

  /// Returns to the confirm card without writing anything.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SpectraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          WarningCallout(
            title: l10n.cardsWriteUnreadSectorsTitle,
            body: l10n.cardsWriteUnreadSectorsBody(
              sectors.length,
              formatSectorList(sectors),
            ),
          ),
          const SizedBox(height: SpectraSpacing.lg),
          SpectraButton(
            label: l10n.cardsWriteUnreadSectorsConfirm,
            variant: SpectraButtonVariant.secondary,
            onPressed: onConfirm,
          ),
          const SizedBox(height: SpectraSpacing.sm),
          SpectraButton(
            label: l10n.commonCancel,
            // The prominent one: going back and dealing with the missing
            // keys is the recommended action, not carrying on regardless.
            // (`spectra_ui` has no tertiary weight — spec 6.2 has three.)
            onPressed: onBack,
          ),
        ],
      ),
    );
  }
}
