import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/problem_view.dart';
import '../../../core/format/tag_labels.dart';
import '../../../core/routing/sub_page_scaffold.dart';
import '../../../l10n/app_localizations.dart';
import '../../slots/slots.dart' show showSlotPicker;
import '../state/read_controller.dart';
import '../state/read_state.dart';
import '../state/write_target.dart';
import 'load_to_slot_sheet.dart';
import 'save_card_sheet.dart';

/// Spec 7.7 step 3. Layout only: every decision is in [CardReader].
///
/// Task 5 replaces the disabled "Save to library" button's `onPressed` with
/// the save sheet; it is present here so the finished screen is one widget
/// tree rather than two.
class ReadPage extends ConsumerWidget {
  const ReadPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ReadState state = ref.watch(cardReaderProvider);
    final CardReader reader = ref.read(cardReaderProvider.notifier);

    return SubPageScaffold(
      title: l10n.cardsReadTitle,
      body: ListView(
        padding: const EdgeInsets.all(SpectraSpacing.lg),
        children: <Widget>[
          if (state.error != null) ...<Widget>[
            ProblemView(
              error: state.error!,
              onAction: reader.reset,
              variant: SpectraButtonVariant.secondary,
            ),
            const SizedBox(height: SpectraSpacing.lg),
          ],
          if (state.busy)
            SpectraProgressIndicator(
              label: state.progress == null
                  ? l10n.cardsReadScanning
                  : l10n.cardsReadDumping,
              value: state.progress,
              onCancel: reader.cancel,
            )
          else if (state.result != null)
            _Result(result: state.result!, onReadAgain: reader.reset)
          else
            _Idle(onHf: reader.readHf, onLf: reader.readLf),
        ],
      ),
    );
  }
}

class _Idle extends StatelessWidget {
  const _Idle({required this.onHf, required this.onLf});

  final VoidCallback onHf;
  final VoidCallback onLf;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SpectraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.cardsReadHint),
          const SizedBox(height: SpectraSpacing.lg),
          SpectraButton(label: l10n.cardsReadHf, onPressed: onHf),
          const SizedBox(height: SpectraSpacing.md),
          SpectraButton(
            label: l10n.cardsReadLf,
            variant: SpectraButtonVariant.secondary,
            onPressed: onLf,
          ),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.result, required this.onReadAgain});

  final CardReadResult result;
  final VoidCallback onReadAgain;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SpectraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(tagTypeLabel(result.tagType, l10n)),
              const SizedBox(height: SpectraSpacing.sm),
              for (final DumpField field in result.fields)
                SpectraListTile(title: field.label, subtitle: field.value),
              if (result.keysFound != null) ...<Widget>[
                const SizedBox(height: SpectraSpacing.sm),
                Text(l10n.cardsReadKeysFound(result.keysFound!)),
              ],
              if (result.isPartial) ...<Widget>[
                const SizedBox(height: SpectraSpacing.sm),
                Text(
                  l10n.cardsReadPartial(
                    result.readChunks!,
                    result.totalChunks!,
                  ),
                ),
              ],
              if (!result.canSave) ...<Widget>[
                const SizedBox(height: SpectraSpacing.sm),
                Text(l10n.cardsReadIdentityOnly),
              ],
            ],
          ),
        ),
        const SizedBox(height: SpectraSpacing.lg),
        SpectraButton(
          label: l10n.cardsSaveToLibrary,
          onPressed: result.canSave
              ? () async {
                  final bool? saved = await showSaveCardSheet(
                    context,
                    type: result.tagType,
                    bytes: result.bytes,
                    // R33: what the reader could not get, in the same
                    // unit `readChunks`/`totalChunks` count (blocks for a
                    // MIFARE Classic — ruling 23).
                    unreadChunks: result.isPartial
                        ? result.totalChunks! - result.readChunks!
                        : null,
                  );
                  if (saved != true || !context.mounted) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(l10n.cardsSaved)));
                }
              : null,
        ),
        if (slotLoadMethodFor(result.tagType) != SlotLoadMethod.unsupported &&
            result.bytes.isNotEmpty) ...<Widget>[
          const SizedBox(height: SpectraSpacing.md),
          SpectraButton(
            label: l10n.cardsEmulateThis,
            variant: SpectraButtonVariant.secondary,
            onPressed: () => _emulate(context, l10n),
          ),
        ],
        const SizedBox(height: SpectraSpacing.md),
        SpectraButton(
          label: l10n.cardsReadAgain,
          variant: SpectraButtonVariant.secondary,
          onPressed: onReadAgain,
        ),
      ],
    );
  }

  /// Spec 7.7 step 5, quick emulate: the card that was just read goes into a
  /// slot without being saved first. It has no name of its own yet, so the
  /// slot is named after its tag type — a name the user can change in the
  /// slot editor, and one that is never empty.
  Future<void> _emulate(BuildContext context, AppLocalizations l10n) async {
    final int? slotIndex = await showSlotPicker(context);
    if (slotIndex == null || !context.mounted) return;
    await showLoadToSlotSheet(
      context,
      slotIndex: slotIndex,
      type: result.tagType,
      bytes: result.bytes,
      name: tagTypeLabel(result.tagType, l10n),
    );
  }
}
