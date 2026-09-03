import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/problem_view.dart';
import '../../../data/data.dart';
import '../../../l10n/app_localizations.dart';
import '../state/saved_cards_provider.dart';
import 'card_subtitle.dart';

/// **The Cards feature's public API** (spec 8.3). Asks the user which saved
/// card to use, and resolves to that card — dump bytes and all — or null if
/// the sheet was dismissed.
///
/// Contract for the features that call it (published for a later phase: the
/// Phase 7 flows start from a card already on screen and do not open it):
///
/// - Import it as `package:spectra/features/cards/cards.dart`. Never reach
///   into `features/cards/ui/…` or `features/cards/state/…` (spec 8.4).
/// - The whole card comes back, so a caller needs no second lookup: the
///   returned card's `bytes` is the dump, and `tagTypeFromName(card.tagType)`
///   (exported from the same barrel) is its tag type — the SDK's `TagType`
///   enum, with `family` telling MIFARE Classic from Ultralight from LF.
/// - It resolves to null on dismissal, and callers must handle that: it is
///   the normal way out of the sheet, not an error.
/// - [isSelectable] filters what may be chosen — an unselectable card is
///   still listed, greyed and untappable, so the user can see why a card is
///   not on offer. Pass, say, `(c) => tagTypeFromName(c.tagType).family ==
///   TagFamily.mifareClassic` to restrict a MIFARE Classic write target.
/// - With an empty library the sheet shows the empty state and can only be
///   dismissed; it never reads a card of its own to fill itself.
/// - It changes nothing — not the device, not the library. Choosing a card
///   is a choice; the caller does the write.
Future<SavedCard?> showCardPicker(
  BuildContext context, {
  bool Function(SavedCard card)? isSelectable,
}) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return SpectraBottomSheet.show<SavedCard>(
    context: context,
    title: l10n.cardsPickerTitle,
    builder: (BuildContext context) => CardPicker(isSelectable: isSelectable),
  );
}

/// The picker's body, for a caller that wants it inline rather than modal.
/// Pops the enclosing route with the chosen card.
///
/// It lists the whole library newest-first — a picker is not the library
/// screen, so it deliberately carries no search, folder filter or sort.
class CardPicker extends ConsumerWidget {
  const CardPicker({this.isSelectable, super.key});

  final bool Function(SavedCard card)? isSelectable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<SavedCard>> library = ref.watch(savedCardsProvider);
    // R32: the same rule as the library screen — a broken stream is a
    // problem to report, not an empty library to apologise for.
    if (library.hasError) {
      return ProblemView(
        error: library.error!,
        variant: SpectraButtonVariant.secondary,
        onAction: () => ref.invalidate(savedCardsProvider),
      );
    }
    final List<SavedCard> cards = library.value ?? const <SavedCard>[];
    if (cards.isEmpty) return SpectraCard(child: Text(l10n.cardsEmpty));

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: cards.length,
        separatorBuilder: (BuildContext context, int i) =>
            const SizedBox(height: SpectraSpacing.sm),
        itemBuilder: (BuildContext context, int i) {
          final SavedCard card = cards[i];
          final bool selectable = isSelectable?.call(card) ?? true;
          // The tile reports the card as saved; being unselectable is this
          // caller's restriction, not the card's, so it costs the tile its
          // tap and nothing else.
          return SpectraListTile(
            title: card.name,
            subtitle: cardSubtitle(card, l10n),
            leading: Icon(
              Icons.circle,
              color: card.color == null
                  ? SpectraTheme.of(context).colors.border
                  : Color(card.color!),
            ),
            onTap: selectable ? () => Navigator.of(context).pop(card) : null,
          );
        },
      ),
    );
  }
}
