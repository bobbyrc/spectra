import 'dart:async';
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/app_failures.dart';
import '../../../core/errors/error_catalog.dart';
import '../../../core/errors/problem_view.dart';
import '../../../core/errors/warning_callout.dart';
import '../../../core/format/sector_list.dart';
import '../../../core/format/tag_labels.dart';
import '../../../core/routing/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../slots/slots.dart' show SlotView, slotViewsProvider;
import '../state/load_to_slot_controller.dart';

/// Spec 7.7 step 5, spec 8.5: pick a target (the caller already did, via
/// `showSlotPicker`), confirm, run the load with progress, and land on a
/// typed outcome — done, an unsupported type, or a failure through the
/// shared [ProblemView].
///
/// [slotIndex] is a **wire index**, 0..7 — what `showSlotPicker`
/// (`features/slots/slots.dart`) resolves to and what `SlotsFacade` takes.
/// One is added only when a number is shown to a person.
///
/// Resolves to true when the slot was loaded and the read-back agreed, and
/// to null when the sheet was dismissed — including a dismissal after an
/// unsupported type or a failure, both of which are "nothing was loaded".
Future<bool?> showLoadToSlotSheet(
  BuildContext context, {
  required int slotIndex,
  required TagType type,
  required Uint8List bytes,
  required String name,
}) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return SpectraBottomSheet.show<bool>(
    context: context,
    title: l10n.cardsLoadTitle(slotIndex + 1),
    builder: (BuildContext context) => _LoadToSlotBody(
      slotIndex: slotIndex,
      type: type,
      bytes: bytes,
      name: name,
    ),
  );
}

class _LoadToSlotBody extends ConsumerStatefulWidget {
  const _LoadToSlotBody({
    required this.slotIndex,
    required this.type,
    required this.bytes,
    required this.name,
  });

  final int slotIndex;
  final TagType type;
  final Uint8List bytes;
  final String name;

  @override
  ConsumerState<_LoadToSlotBody> createState() => _LoadToSlotBodyState();
}

class _LoadToSlotBodyState extends ConsumerState<_LoadToSlotBody> {
  @override
  void initState() {
    super.initState();
    // Ruling 5: `slotLoaderProvider` is a global autoDispose notifier whose
    // terminal state survives while any listener lives (this sheet, or a
    // test's `keepAlive`). Reset on open so a second load in one session
    // starts from the confirm card, not the previous load's outcome.
    //
    // Deferred a frame: riverpod refuses to modify a provider's state while
    // the widget tree is still building, and `initState` runs inside that
    // build.
    Future(() {
      if (mounted) ref.read(slotLoaderProvider.notifier).reset();
    });
  }

  void _load({bool confirmUnread = false}) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    unawaited(
      ref
          .read(slotLoaderProvider.notifier)
          .load(
            slotIndex: widget.slotIndex,
            type: widget.type,
            bytes: widget.bytes,
            name: widget.name,
            // Ruling 26: the sheet resolves the tag-type label; the
            // controller stays pure state with no `AppLocalizations`.
            fallbackLabel: tagTypeLabel(widget.type, l10n),
            confirmUnread: confirmUnread,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SlotLoadState state = ref.watch(slotLoaderProvider);
    // Ruling 30: a load is a sequence of writes — set active, reset the
    // sense, write the data, rename, enable — and a slot dismissed between
    // two of them is left half-configured. The sheet is therefore not
    // dismissable while it runs: a swipe-down or `SpectraBottomSheet`'s own
    // X (both go through `Navigator.maybePop`) is refused. There is no
    // Cancel here, unlike the write sheet: `EmulatorFacade` takes no
    // `CancelToken` on these calls and there is no safe point to stop at
    // between them, so the honest affordance is none at all.
    return PopScope(canPop: !state.busy, child: _body(context, state));
  }

  Widget _body(BuildContext context, SlotLoadState state) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SlotLoader loader = ref.read(slotLoaderProvider.notifier);

    if (state.error case final Object error) {
      // `CardDumpLengthMismatch` carries `ErrorRecovery.none`: the stored
      // dump's length will not change on a retry, so `ProblemView`'s
      // "Try again" label (which it shows for `none` too — a pre-existing
      // choice this sheet does not own) is replaced with a plain close
      // rather than offered.
      if (error is CardDumpLengthMismatch) {
        return _Finished(
          message: ErrorCatalog(l10n).describe(error).message,
          onClose: () => Navigator.of(context).pop(),
        );
      }
      return ProblemView(
        error: error,
        onAction: loader.reset,
        // The sheet is a modal route over the shell, so it closes itself
        // before routing: `go` alone would open the update screen behind a
        // sheet still sitting on top of it (review I2).
        onUpdate: () {
          Navigator.of(context).pop();
          GoRouter.of(context).go(AppRoutes.update);
        },
        variant: SpectraButtonVariant.secondary,
      );
    }
    if (state.busy) {
      return SpectraProgressIndicator(
        label: (state.progress ?? 0) >= 0.9
            ? l10n.cardsLoadVerifying
            : l10n.cardsLoadProgress,
        value: state.progress,
      );
    }
    if (state.done) {
      return _Finished(
        message: l10n.cardsLoadDone(widget.slotIndex + 1),
        onClose: () => Navigator.of(context).pop(true),
      );
    }
    if (state.unsupported) {
      return _Finished(
        message: l10n.cardsLoadUnsupported,
        onClose: () => Navigator.of(context).pop(),
      );
    }
    // Ruling 23: an all-zero sector trailer is not an error — it is a saved
    // dump whose keys were never recovered — so it is confirmed explicitly
    // rather than silently loaded.
    if (state.unreadSectors case final List<int> sectors
        when sectors.isNotEmpty) {
      return _UnreadSectorsWarning(
        sectors: sectors,
        onConfirm: () => _load(confirmUnread: true),
        // Back to the confirm card rather than only forward: a warning
        // whose one button is "Load anyway" is a one-way door (review I3).
        onBack: loader.reset,
      );
    }
    // The loader always makes the target slot the active one (it does not
    // restore whichever was active before), and — since `resetToDefault`
    // touches only the sense being loaded — leaves the *other* sense's tag
    // live if that sense already had one enabled. Both are worth saying
    // before the button is pressed, not after.
    final SlotView? target = _slotView(
      ref.watch(slotViewsProvider),
      widget.slotIndex,
    );
    final bool otherSenseEnabled = widget.type.sense == Sense.hf
        ? (target?.slot.lfEnabled ?? false)
        : (target?.slot.hfEnabled ?? false);
    final TagType otherType = widget.type.sense == Sense.hf
        ? (target?.slot.lfType ?? TagType.undefined)
        : (target?.slot.hfType ?? TagType.undefined);
    final Sense otherSense = widget.type.sense == Sense.hf
        ? Sense.lf
        : Sense.hf;

    return SpectraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.cardsLoadPrompt(
              widget.name,
              widget.slotIndex + 1,
              senseLabel(widget.type.sense, l10n),
            ),
          ),
          const SizedBox(height: SpectraSpacing.sm),
          Text(tagTypeLabel(widget.type, l10n)),
          const SizedBox(height: SpectraSpacing.sm),
          Text(l10n.cardsLoadActivates(widget.slotIndex + 1)),
          if (otherSenseEnabled) ...<Widget>[
            const SizedBox(height: SpectraSpacing.sm),
            Text(
              l10n.cardsLoadOtherSenseStaysLive(
                widget.slotIndex + 1,
                senseLabel(otherSense, l10n),
                tagTypeLabel(otherType, l10n),
              ),
            ),
          ],
          const SizedBox(height: SpectraSpacing.lg),
          SpectraButton(label: l10n.cardsLoadConfirm, onPressed: () => _load()),
        ],
      ),
    );
  }
}

/// The view for [slotIndex] out of [views], or null when the list has not
/// loaded one yet (the sheet only opens while connected, so this is
/// defensive rather than an expected path).
SlotView? _slotView(List<SlotView> views, int slotIndex) {
  for (final SlotView view in views) {
    if (view.index == slotIndex) return view;
  }
  return null;
}

/// The terminal states: one sentence and a way out. The sheet does not pop
/// itself from a provider listener — a load is worth reading the outcome
/// of, and popping a modal route while it is still settling is a flake
/// this screen does not need.
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

/// Ruling 23: names the sector trailers a dump has no recovered key for and
/// asks for an explicit yes before loading them blank — or a way back to the
/// confirm card (review I3).
class _UnreadSectorsWarning extends StatelessWidget {
  const _UnreadSectorsWarning({
    required this.sectors,
    required this.onConfirm,
    required this.onBack,
  });

  final List<int> sectors;
  final VoidCallback onConfirm;

  /// Returns to the confirm card without loading anything.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SpectraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          WarningCallout(
            title: l10n.cardsLoadUnreadSectorsTitle,
            body: l10n.cardsLoadUnreadSectorsBody(
              sectors.length,
              formatSectorList(sectors),
            ),
          ),
          const SizedBox(height: SpectraSpacing.lg),
          SpectraButton(
            label: l10n.cardsLoadUnreadSectorsConfirm,
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
