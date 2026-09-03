/// The Cards feature's public API (spec 8.3): its screens, and the card
/// picker other features call to ask "which card?".
///
/// Nothing else in the app may import `features/cards/…` directly. The
/// picker's contract is on [showCardPicker].
///
/// Everything is behind a `show` clause, like the slots barrel (R28): the
/// surface is the screens the router composes, the picker, and just enough
/// of the library's state to read a chosen card back — `tagTypeFromName` to turn a stored `tagType`
/// string into the SDK's enum (the picker's contract names it) and
/// `savedCardsProvider` to watch the library. The import sheet, the save
/// sheet, the colour palette and every controller stay inside the feature.
library;

export 'state/card_codec.dart' show tagTypeFromName;
export 'state/saved_cards_provider.dart' show savedCardsProvider;
// The router composes every feature from its barrel (`core/routing/
// app_sections.dart`); these three are that entry, not a cross-feature API.
export 'ui/card_detail_page.dart' show CardDetailPage;
export 'ui/card_picker.dart' show showCardPicker;
export 'ui/cards_page.dart' show CardsPage;
export 'ui/read_page.dart' show ReadPage;
