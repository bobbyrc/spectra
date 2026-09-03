import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/problem_view.dart';
import '../../../core/format/tag_labels.dart';
import '../../../core/routing/routes.dart';
import '../../../core/routing/sub_page_scaffold.dart';
import '../../../data/data.dart';
import '../../../l10n/app_localizations.dart';
import '../state/card_codec.dart';
import '../state/card_editor_controller.dart';
import '../state/card_import.dart';
import 'card_hex_editor.dart';
import 'save_card_sheet.dart';

/// The sector trailers of a MIFARE Classic, so the keys and access bits are
/// visible at a glance in the hex viewer. Empty for every other family:
/// Ultralight and EM410x have no trailer.
///
/// Spec 8.5's one-public-type rule is knowingly relaxed for this file
/// (Phase 6 ruling 17): this function and [CardDetailPage] are one
/// cohesive concern — the detail screen and the highlight it draws over its
/// own hex viewer — and splitting them would add a file without adding
/// clarity.
List<SpectraHexHighlight> trailerHighlights(TagType type, Color color) {
  if (type.family != TagFamily.mifareClassic) {
    return const <SpectraHexHighlight>[];
  }
  final int blockSize = chunkSizeFor(type);
  return <SpectraHexHighlight>[
    for (int sector = 0; sector < MifareGeometry.sectorCount(type); sector++)
      SpectraHexHighlight(
        start: MifareGeometry.trailerOf(sector) * blockSize,
        length: blockSize,
        color: color,
      ),
  ];
}

/// Spec 7.7 step 4: one saved card, its fields and its dump. Layout only —
/// every decision is in [CardEditor].
///
/// Task 7 landed the read-only half: fields, the hex viewer with the sector
/// trailers marked, validation problems, and delete. Task 8 adds editing
/// ([CardHexEditor], wired to [CardEditor.replaceChunk]/`save`/`discard`)
/// and an unsaved-changes [PopScope] guard on the way out; Task 10 adds
/// import/export actions here.
///
/// Phase 6 ruling 18: [PopScope]'s `canPop` only intercepts the back
/// gesture/button on this route. Leaving through the nav rail calls
/// `GoRouter.go` directly, which is not a pop, so switching tabs with
/// unsaved edits bypasses the guard entirely and the edits are silently
/// abandoned. The brief accepts this gap for v1 — closing it needs a
/// router-wide "confirm navigation" hook that does not exist yet.
class CardDetailPage extends ConsumerWidget {
  const CardDetailPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<CardEditState?> async = ref.watch(cardEditorProvider(id));
    final CardEditor editor = ref.read(cardEditorProvider(id).notifier);

    // `save`/`discard`/`deleteCard` keep `state` an `AsyncData` throughout
    // (see `CardEditState.busy`), so the page keeps showing the card and
    // only disables its controls, rather than blanking to a spinner and
    // resetting the title.
    final CardEditState? value = async.hasValue ? async.value : null;
    final Widget body = switch (async) {
      _ when value != null => _Detail(
        id: id,
        state: value,
        loading: value.busy,
        onDelete: () => _confirmDelete(context, editor),
        onEditDetails: () => _editDetails(context, editor, value.card),
        onRetrySave: () => unawaited(editor.save()),
      ),
      AsyncError<CardEditState?>(:final Object error) => ProblemView(
        error: error,
        variant: SpectraButtonVariant.secondary,
        onAction: () => unawaited(editor.discard()),
      ),
      _ when async.hasValue => SpectraCard(
        child: Text(l10n.cardsDetailNotFound),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };

    final bool dirty = async.value?.dirty ?? false;
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop || !dirty) return;
        final bool? leave = await SpectraDialog.show<bool>(
          context: context,
          title: l10n.cardsEditUnsavedTitle,
          content: Text(l10n.cardsEditUnsavedBody),
          actions: (BuildContext context) => <Widget>[
            SpectraButton(
              label: l10n.commonCancel,
              variant: SpectraButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            SpectraButton(
              label: l10n.cardsEditDiscard,
              variant: SpectraButtonVariant.danger,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
        if (leave == true && context.mounted) {
          GoRouter.of(context).go(AppRoutes.cards);
        }
      },
      child: SubPageScaffold(
        title: async.value?.card.name ?? l10n.cardsTitle,
        body: ListView(
          padding: const EdgeInsets.all(SpectraSpacing.lg),
          children: <Widget>[body],
        ),
      ),
    );
  }

  /// Opens the save sheet's form on the stored row (R34). The sheet does
  /// the write through `CardLibrary.updateCard`; the editor is then told
  /// what changed so the title, the tile and a later "Save changes" all
  /// carry the new details — without reloading, which would throw away
  /// unsaved hex edits.
  Future<void> _editDetails(
    BuildContext context,
    CardEditor editor,
    SavedCard card,
  ) async {
    final bool? saved = await showEditCardDetailsSheet(context, card: card);
    if (saved != true) return;
    await editor.refreshDetails();
  }

  Future<void> _confirmDelete(BuildContext context, CardEditor editor) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final GoRouter router = GoRouter.of(context);
    final bool? confirmed = await SpectraDialog.show<bool>(
      context: context,
      title: l10n.cardsDetailDeleteTitle,
      content: Text(l10n.cardsDetailDeleteBody),
      actions: (BuildContext context) => <Widget>[
        SpectraButton(
          label: l10n.commonCancel,
          variant: SpectraButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        SpectraButton(
          label: l10n.cardsDetailDelete,
          variant: SpectraButtonVariant.danger,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true) return;
    // Navigate away first: `deleteCard` sets the working state to null,
    // which this page renders as "not found" for a frame if it is still
    // mounted to see it. Leaving first means nobody sees that flash.
    router.go(AppRoutes.cards);
    await editor.deleteCard();
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.id,
    required this.state,
    required this.loading,
    required this.onDelete,
    required this.onEditDetails,
    required this.onRetrySave,
  });

  final String id;
  final CardEditState state;

  /// True while `save`/`discard`/`deleteCard` is in flight: the fields keep
  /// showing (see the doc comment above [CardDetailPage.build]), only the
  /// controls disable.
  final bool loading;
  final VoidCallback onDelete;

  /// Opens the name/folder/colour sheet (R34).
  final VoidCallback onEditDetails;

  /// [ProblemView]'s action when [CardEditState.error] is set (Phase 6
  /// ruling 29 item 1): re-invokes `CardEditor.save`, not `discard` — the
  /// edits are still on screen and "Try again" means try the same write
  /// again, not throw the edits away.
  final VoidCallback onRetrySave;

  /// Copies what is on screen — the working copy, unsaved edits included —
  /// not the stored row. The alternative (export the row, and disable the
  /// button while dirty) makes the user save before they can copy; this way
  /// the export always matches the hex above it, which is the thing they
  /// are looking at when they press it.
  Future<void> _export(BuildContext context, SavedCard card) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String text = exportCardsJson(<SavedCard>[card]);
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.cardsExported)));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // Ruling 29 item 2: the working copy, not the stored row — an edit that
    // has not been saved yet must show its own problems, not the last
    // saved dump's.
    final List<String> problems = validateSavedCard(state.workingCard);
    final String? folder = state.card.folder;
    final int? colorValue = state.card.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SpectraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SpectraListTile(
                title: state.card.name,
                subtitle: tagTypeLabel(state.tagType, l10n),
                leading: Icon(
                  Icons.circle,
                  color: colorValue == null
                      ? SpectraTheme.of(context).colors.border
                      : Color(colorValue),
                ),
              ),
              if (folder != null) SpectraListTile(title: folder),
              // The working copy, like the problems banner above: an
              // unsaved edit to block 0 changes the UID this describes,
              // and showing the stored row's UID next to the edited hex
              // would be two different cards on one screen.
              for (final DumpField field in describeSavedCard(
                state.workingCard,
              ))
                SpectraListTile(title: field.label, subtitle: field.value),
              SpectraListTile(title: l10n.cardsDetailBytes(state.bytes.length)),
              if (problems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpectraSpacing.md,
                  ),
                  child: Text(l10n.cardsDetailProblems(problems.join(', '))),
                ),
            ],
          ),
        ),
        const SizedBox(height: SpectraSpacing.lg),
        // The read-only view of the whole dump; CardHexEditor below edits
        // it one chunk at a time and writes back through CardEditor.
        SpectraCard(
          child: SpectraHexViewer(
            bytes: state.bytes,
            highlights: trailerHighlights(
              state.tagType,
              SpectraTheme.of(context).colors.warning,
            ),
          ),
        ),
        const SizedBox(height: SpectraSpacing.lg),
        if (state.error != null) ...<Widget>[
          ProblemView(
            error: state.error!,
            variant: SpectraButtonVariant.secondary,
            onAction: onRetrySave,
          ),
          const SizedBox(height: SpectraSpacing.lg),
        ],
        CardHexEditor(id: id, state: state),
        const SizedBox(height: SpectraSpacing.lg),
        // Spec 7.3's export: the clipboard, not a file dialog — see
        // `card_import_sheet.dart`'s doc comment for why a native save
        // dialog is a deliberate v1 gap that Phase 9 revisits.
        SpectraButton(
          label: l10n.cardsExport,
          variant: SpectraButtonVariant.secondary,
          onPressed: loading ? null : () => _export(context, state.workingCard),
        ),
        const SizedBox(height: SpectraSpacing.md),
        SpectraButton(
          label: l10n.cardsDetailEdit,
          variant: SpectraButtonVariant.secondary,
          onPressed: loading ? null : onEditDetails,
        ),
        const SizedBox(height: SpectraSpacing.md),
        SpectraButton(
          label: l10n.cardsDetailDelete,
          variant: SpectraButtonVariant.danger,
          onPressed: loading ? null : onDelete,
        ),
      ],
    );
  }
}
