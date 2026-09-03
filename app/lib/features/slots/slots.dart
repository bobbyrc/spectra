/// The Slots feature's public API (spec 8.3): its screens, and the slot
/// picker other features call to ask "which slot?".
///
/// Nothing else in the app may import `features/slots/…` directly. The
/// picker's contract is on [showSlotPicker].
library;

export 'state/slot_labels.dart' show senseLabel, tagTypeLabel;
export 'state/slot_view.dart' show SlotView;
export 'state/slot_views_provider.dart' show slotViewsProvider;
export 'ui/slot_detail_page.dart';
export 'ui/slot_picker.dart';
export 'ui/slots_page.dart';
