import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/problem_view.dart';
import '../../../core/errors/warning_callout.dart';
import '../../../data/data.dart';
import '../../../l10n/app_localizations.dart';
import '../state/saved_cards_provider.dart';

/// Collects the three things spec 7.3 stores beside the dump — name, folder,
/// colour — and writes the card. Resolves to true when a card was saved and
/// to null when the sheet was dismissed.
///
/// [unreadChunks] is how many blocks the reader could not get off the card
/// (`CardReadResult.totalChunks - readChunks` for a partial dump, null or
/// zero for a complete one). The sheet warns about them before the Save
/// button (R33): what lands in the library is a dump with those blocks
/// zero-filled, and nothing downstream — the detail screen, an export, a
/// Phase 7 write back onto a card — can tell a zeroed block from a block
/// that really is zero. The user has to know that at the moment they
/// decide to keep it.
Future<bool?> showSaveCardSheet(
  BuildContext context, {
  required TagType type,
  required Uint8List bytes,
  String? suggestedName,
  int? unreadChunks,
}) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return SpectraBottomSheet.show<bool>(
    context: context,
    title: l10n.cardsSaveTitle,
    builder: (BuildContext context) => _CardDetailsForm(
      confirmLabel: l10n.cardsSaveConfirm,
      initialName: suggestedName,
      unreadChunks: unreadChunks,
      onSubmit: (WidgetRef ref, String name, String? folder, int color) async =>
          await ref
              .read(cardLibraryProvider.notifier)
              .add(
                name: name,
                type: type,
                bytes: bytes,
                folder: folder,
                color: color,
              ) !=
          null,
    ),
  );
}

/// Edits what [showSaveCardSheet] collected — name, folder, colour — on a
/// card that is already in the library, and writes it back through
/// [CardLibrary.updateCard]. Resolves to true when the row was written and
/// to null when the sheet was dismissed (R34).
///
/// The same form as the save sheet, prefilled: those three fields were
/// write-once until this existed, so a card read under a placeholder name
/// could never be renamed. The dump is not touched here — the hex editor on
/// the detail page owns the bytes.
///
/// [card] must be a row the caller has just read (`CardDetailPage` refreshes
/// it immediately before calling this). Only the name, folder and colour
/// come from the form; everything else — id, tag type and **bytes** — is
/// copied straight off [card], so a stale [card] would write stale bytes
/// back over a hex edit that had just been saved.
Future<bool?> showEditCardDetailsSheet(
  BuildContext context, {
  required SavedCard card,
}) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return SpectraBottomSheet.show<bool>(
    context: context,
    title: l10n.cardsDetailEditTitle,
    builder: (BuildContext context) => _CardDetailsForm(
      confirmLabel: l10n.cardsSaveConfirm,
      initialName: card.name,
      initialFolder: card.folder,
      initialColor: card.color,
      // Merged onto the row the caller read, not onto anything this sheet
      // remembers: the three form fields are all that changes.
      onSubmit: (WidgetRef ref, String name, String? folder, int color) => ref
          .read(cardLibraryProvider.notifier)
          .updateCard(
            SavedCard(
              id: card.id,
              name: name,
              tagType: card.tagType,
              bytes: card.bytes,
              updatedAt: card.updatedAt,
              folder: folder,
              color: color,
            ),
          ),
    ),
  );
}

/// The name/folder/colour form both sheets show. One widget, because the
/// two flows differ only in what they do with the three values: a new card
/// goes through [CardLibrary.add], an existing one through
/// [CardLibrary.updateCard] (R34). [onSubmit] gets the form's own [WidgetRef]
/// and returns whether the write succeeded — false leaves the sheet open
/// with the failure showing.
class _CardDetailsForm extends ConsumerStatefulWidget {
  const _CardDetailsForm({
    required this.confirmLabel,
    required this.onSubmit,
    this.initialName,
    this.initialFolder,
    this.initialColor,
    this.unreadChunks,
  });

  final String confirmLabel;
  final Future<bool> Function(
    WidgetRef ref,
    String name,
    String? folder,
    int color,
  )
  onSubmit;
  final String? initialName;
  final String? initialFolder;
  final int? initialColor;
  final int? unreadChunks;

  @override
  ConsumerState<_CardDetailsForm> createState() => _CardDetailsFormState();
}

class _CardDetailsFormState extends ConsumerState<_CardDetailsForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName ?? '',
  );
  late final TextEditingController _folder = TextEditingController(
    text: widget.initialFolder ?? '',
  );
  late int _color = widget.initialColor ?? cardColors.first;
  bool _nameMissing = false;

  @override
  void dispose() {
    _name.dispose();
    _folder.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameMissing = true);
      return;
    }
    final String? folder = _folder.text.trim().isEmpty
        ? null
        : _folder.text.trim();
    final bool ok = await widget.onSubmit(ref, name, folder, _color);
    if (!mounted || !ok) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<void> library = ref.watch(cardLibraryProvider);
    final bool busy = library.isLoading;
    final int unread = widget.unreadChunks ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // R33, review M4: the shared callout the two write-path sheets use
        // for the same kind of "less than perfect, still your call" notice.
        if (unread > 0) ...<Widget>[
          WarningCallout(title: l10n.cardsSavePartial(unread)),
          const SizedBox(height: SpectraSpacing.md),
        ],
        SpectraTextField(
          label: l10n.cardsSaveName,
          controller: _name,
          errorText: _nameMissing ? l10n.cardsSaveNameRequired : null,
          onChanged: (String _) {
            if (_nameMissing) setState(() => _nameMissing = false);
          },
        ),
        const SizedBox(height: SpectraSpacing.md),
        SpectraTextField(
          label: l10n.cardsSaveFolder,
          controller: _folder,
          hint: l10n.cardsSaveFolderHint,
        ),
        const SizedBox(height: SpectraSpacing.md),
        Text(l10n.cardsSaveColour),
        const SizedBox(height: SpectraSpacing.sm),
        Row(
          children: <Widget>[
            for (final (int i, int value) in cardColors.indexed)
              Padding(
                padding: const EdgeInsets.only(right: SpectraSpacing.sm),
                child: SpectraTappable(
                  onTap: () => setState(() => _color = value),
                  // One label per swatch, and the chosen one says so:
                  // seven controls all announcing "Colour" told a screen
                  // reader user nothing about which is which, or which is
                  // on.
                  semanticsLabel: _color == value
                      ? l10n.cardsSaveColourSwatchSelected(i + 1)
                      : l10n.cardsSaveColourSwatch(i + 1),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(value),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: SpectraTheme.of(context).colors.borderStrong,
                        width: _color == value ? 3 : 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (library.hasError) ...<Widget>[
          const SizedBox(height: SpectraSpacing.lg),
          ProblemView(
            error: library.error!,
            onAction: () => ref.read(cardLibraryProvider.notifier).reset(),
            variant: SpectraButtonVariant.secondary,
          ),
        ],
        const SizedBox(height: SpectraSpacing.lg),
        SpectraButton(
          label: widget.confirmLabel,
          busy: busy,
          onPressed: busy ? null : _submit,
        ),
      ],
    );
  }
}
