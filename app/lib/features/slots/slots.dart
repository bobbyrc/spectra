/// The Slots feature's public API (spec 8.3): its screens, and the slot
/// picker other features call to ask "which slot?".
///
/// Nothing else in the app may import `features/slots/…` directly. The
/// picker's contract is on [showSlotPicker]. Everything is behind a `show`
/// clause: the surface another feature may build against is exactly the
/// picker, the slot it resolves to, and the list the picker draws from —
/// how a tag type is spelled is core's `format/tag_labels.dart`, not this
/// feature's to hand out (R28).
library;

export 'state/slot_view.dart' show SlotView;
export 'state/slot_views_provider.dart' show slotViewsProvider;
// The router composes every feature from its barrel (`core/routing/
// app_sections.dart`); these two are that entry, not a cross-feature API.
export 'ui/slot_detail_page.dart' show SlotDetailPage;
export 'ui/slot_picker.dart' show showSlotPicker;
export 'ui/slots_page.dart' show SlotsPage;
