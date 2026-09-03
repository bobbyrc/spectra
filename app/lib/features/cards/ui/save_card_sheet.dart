import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/problem_view.dart';
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
    builder: (BuildContext context) => _SaveCardForm(
      type: type,
      bytes: bytes,
      suggestedName: suggestedName,
      unreadChunks: unreadChunks,
    ),
  );
}

class _SaveCardForm extends ConsumerStatefulWidget {
  const _SaveCardForm({
    required this.type,
    required this.bytes,
    this.suggestedName,
    this.unreadChunks,
  });

  final TagType type;
  final Uint8List bytes;
  final String? suggestedName;
  final int? unreadChunks;

  @override
  ConsumerState<_SaveCardForm> createState() => _SaveCardFormState();
}

class _SaveCardFormState extends ConsumerState<_SaveCardForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.suggestedName ?? '',
  );
  final TextEditingController _folder = TextEditingController();
  int _color = cardColors.first;
  bool _nameMissing = false;

  @override
  void dispose() {
    _name.dispose();
    _folder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameMissing = true);
      return;
    }
    final String? folder = _folder.text.trim().isEmpty
        ? null
        : _folder.text.trim();
    final String? id = await ref
        .read(cardLibraryProvider.notifier)
        .add(
          name: name,
          type: widget.type,
          bytes: widget.bytes,
          folder: folder,
          color: _color,
        );
    if (!mounted || id == null) return;
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
        // R33. A plain warning-coloured line rather than a component:
        // `spectra_ui` has no callout, and this phase does not add one.
        if (unread > 0) ...<Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.warning_amber_rounded,
                color: SpectraTheme.of(context).colors.warning,
                size: 20,
              ),
              const SizedBox(width: SpectraSpacing.sm),
              Expanded(
                child: Text(
                  l10n.cardsSavePartial(unread),
                  style: SpectraTypography.body.copyWith(
                    color: SpectraTheme.of(context).colors.warning,
                  ),
                ),
              ),
            ],
          ),
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
            for (final int value in cardColors)
              Padding(
                padding: const EdgeInsets.only(right: SpectraSpacing.sm),
                child: SpectraTappable(
                  onTap: () => setState(() => _color = value),
                  semanticsLabel: l10n.cardsSaveColour,
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
          label: l10n.cardsSaveConfirm,
          busy: busy,
          onPressed: busy ? null : _save,
        ),
      ],
    );
  }
}
