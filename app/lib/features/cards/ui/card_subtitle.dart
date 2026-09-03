import '../../../core/format/tag_labels.dart';
import '../../../data/data.dart';
import '../../../l10n/app_localizations.dart';
import '../state/card_codec.dart';

/// A saved card's second line, wherever the library lists one: the cards
/// screen and the picker (Phase 6 ruling 20). Shared so the two never drift
/// on how a folderless card renders — `"MIFARE Classic 1K"`, never
/// `"MIFARE Classic 1K · "` with a dangling separator.
String cardSubtitle(SavedCard card, AppLocalizations l10n) {
  final String type = tagTypeLabel(tagTypeFromName(card.tagType), l10n);
  final String? folder = card.folder;
  return folder == null
      ? l10n.cardsSubtitleNoFolder(type)
      : l10n.cardsSubtitle(type, folder);
}
