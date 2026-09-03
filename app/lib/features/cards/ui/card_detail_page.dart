import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/problem_view.dart';
import '../../../core/format/tag_labels.dart';
import '../../../core/routing/routes.dart';
import '../../../core/routing/sub_page_scaffold.dart';
import '../../../l10n/app_localizations.dart';
import '../state/card_codec.dart';
import '../state/card_editor_controller.dart';

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
  return <SpectraHexHighlight>[
    for (int sector = 0; sector < MifareGeometry.sectorCount(type); sector++)
      SpectraHexHighlight(
        start: MifareGeometry.trailerOf(sector) * 16,
        length: 16,
        color: color,
      ),
  ];
}

/// Spec 7.7 step 4: one saved card, its fields and its dump. Layout only —
/// every decision is in [CardEditor].
///
/// Task 7 lands the read-only half: fields, the hex viewer with the sector
/// trailers marked, validation problems, and delete. Task 8 adds editing on
/// top of the same [CardEditor] (`replaceChunk`, `save`, a dirty-state
/// guard on the way out); Task 10 adds import/export actions here.
class CardDetailPage extends ConsumerWidget {
  const CardDetailPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<CardEditState?> async = ref.watch(cardEditorProvider(id));
    final CardEditor editor = ref.read(cardEditorProvider(id).notifier);

    final Widget body = switch (async) {
      AsyncError<CardEditState?>(:final Object error) => ProblemView(
        error: error,
        variant: SpectraButtonVariant.secondary,
        onAction: () => unawaited(editor.discard()),
      ),
      AsyncData<CardEditState?>(value: null) => SpectraCard(
        child: Text(l10n.cardsDetailNotFound),
      ),
      AsyncData<CardEditState?>(:final CardEditState? value) => _Detail(
        state: value!,
        onDelete: () => _confirmDelete(context, ref, editor),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };

    return SubPageScaffold(
      title: async.value?.card.name ?? l10n.cardsTitle,
      body: ListView(
        padding: const EdgeInsets.all(SpectraSpacing.lg),
        children: <Widget>[body],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CardEditor editor,
  ) async {
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
    await editor.deleteCard();
    router.go(AppRoutes.cards);
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.state, required this.onDelete});

  final CardEditState state;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<String> problems = validateSavedCard(state.card);
    final String? folder = state.card.folder;
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
              ),
              if (folder != null) SpectraListTile(title: folder),
              for (final DumpField field in describeSavedCard(state.card))
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
        // Task 8's extension point: this card wraps a read-only
        // `SpectraHexViewer`. Editing swaps this for a tappable one wired
        // to `CardEditor.replaceChunk`, without touching anything above.
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
        SpectraButton(
          label: l10n.cardsDetailDelete,
          variant: SpectraButtonVariant.danger,
          onPressed: onDelete,
        ),
      ],
    );
  }
}
