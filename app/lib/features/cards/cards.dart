/// The Cards feature's public API (spec 8.3): its screens, and the card
/// picker other features call to ask "which card?".
///
/// Nothing else in the app may import `features/cards/…` directly. The
/// picker's contract is on [showCardPicker].
library;

export 'state/card_codec.dart' show tagTypeFromName, tagTypeName;
export 'state/saved_cards_provider.dart' show cardColors, savedCardsProvider;
export 'ui/card_detail_page.dart';
export 'ui/card_import_sheet.dart';
export 'ui/card_picker.dart';
export 'ui/cards_page.dart';
export 'ui/read_page.dart';
