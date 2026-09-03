import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/format/hex.dart';
import '../../../l10n/app_localizations.dart';
import '../state/card_editor_controller.dart';

/// The message for a chunk that cannot be applied, or null when [text] is a
/// valid hex run of exactly [chunkSize] bytes. Pure, so the rule is one
/// place and the widget only renders it.
///
/// [unit] is the lower-case name of the edit unit — [chunkUnit] — so the
/// length complaint says "bytes per page" on an Ultralight, matching the
/// field's own "Page" label instead of always saying "block".
String? chunkHexError(
  String text,
  int chunkSize,
  String unit,
  AppLocalizations l10n,
) {
  final Uint8List? bytes = parseHex(text);
  if (bytes == null) return l10n.cardsEditBadHex;
  if (bytes.length != chunkSize) {
    return l10n.cardsEditBadLength(chunkSize, unit);
  }
  return null;
}

/// The edit unit's name mid-sentence, for [chunkHexError]. The capitalised
/// field label is the switch just below, in `_CardHexEditorState`.
String chunkUnit(TagFamily family, AppLocalizations l10n) => switch (family) {
  TagFamily.ultralight => l10n.cardsEditChunkUnitPage,
  TagFamily.lf => l10n.cardsEditChunkUnitId,
  _ => l10n.cardsEditChunkUnitBlock,
};

/// Edits one block, page or id at a time (spec 7.7 step 4).
///
/// Edits land in [CardEditor]'s working copy, not the database: "Apply"
/// changes the dump on screen, "Save changes" writes it. That split is what
/// makes an unsaved-changes guard meaningful, and it means a mistyped block
/// costs a Discard rather than a corrupted row.
class CardHexEditor extends ConsumerStatefulWidget {
  const CardHexEditor({required this.id, required this.state, super.key});

  final String id;
  final CardEditState state;

  @override
  ConsumerState<CardHexEditor> createState() => _CardHexEditorState();
}

class _CardHexEditorState extends ConsumerState<CardHexEditor> {
  final TextEditingController _index = TextEditingController(text: '0');
  final TextEditingController _value = TextEditingController();
  String? _indexError;
  String? _valueError;

  @override
  void dispose() {
    _index.dispose();
    _value.dispose();
    super.dispose();
  }

  String _chunkLabel(AppLocalizations l10n) =>
      switch (widget.state.tagType.family) {
        TagFamily.ultralight => l10n.cardsEditChunkLabelPage,
        TagFamily.lf => l10n.cardsEditChunkLabelId,
        _ => l10n.cardsEditChunkLabelBlock,
      };

  void _apply(AppLocalizations l10n) {
    final int last = widget.state.chunkCount - 1;
    final int? index = int.tryParse(_index.text.trim());
    final String? indexError = index == null || index < 0 || index > last
        ? l10n.cardsEditBadIndex(last)
        : null;
    final String? valueError = chunkHexError(
      _value.text,
      widget.state.chunkSize,
      chunkUnit(widget.state.tagType.family, l10n),
      l10n,
    );
    setState(() {
      _indexError = indexError;
      _valueError = valueError;
    });
    if (indexError != null || valueError != null) return;
    ref
        .read(cardEditorProvider(widget.id).notifier)
        .replaceChunk(index!, parseHex(_value.text)!);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CardEditState state = widget.state;
    final bool loading = ref.watch(
      cardEditorProvider(widget.id)
          .select((AsyncValue<CardEditState?> v) => v.value?.busy ?? false),
    );
    if (state.chunkSize == 0) {
      return SpectraCard(child: Text(l10n.cardsEditNotEditable));
    }
    return SpectraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SpectraSectionHeader(title: l10n.cardsEditTitle),
          SpectraTextField(
            key: const Key('cardEditIndex'),
            label: _chunkLabel(l10n),
            controller: _index,
            errorText: _indexError,
            enabled: !loading,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: SpectraSpacing.md),
          SpectraTextField(
            key: const Key('cardEditValue'),
            label: l10n.cardsEditValue,
            controller: _value,
            errorText: _valueError,
            enabled: !loading,
          ),
          const SizedBox(height: SpectraSpacing.md),
          SpectraButton(
            label: l10n.cardsEditApply,
            variant: SpectraButtonVariant.secondary,
            onPressed: loading ? null : () => _apply(l10n),
          ),
          if (state.dirty) ...<Widget>[
            const SizedBox(height: SpectraSpacing.lg),
            SpectraButton(
              label: l10n.cardsEditSave,
              onPressed: loading
                  ? null
                  : ref.read(cardEditorProvider(widget.id).notifier).save,
            ),
            const SizedBox(height: SpectraSpacing.md),
            SpectraButton(
              label: l10n.cardsEditDiscard,
              variant: SpectraButtonVariant.danger,
              onPressed: loading
                  ? null
                  : ref.read(cardEditorProvider(widget.id).notifier).discard,
            ),
          ],
        ],
      ),
    );
  }
}
