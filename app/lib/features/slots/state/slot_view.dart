import 'package:chameleon/chameleon.dart';

/// One slot as the UI sees it: the SDK's [Slot] plus the one fact that
/// lives outside it, and the display decisions made once so no widget makes
/// them twice.
final class SlotView {
  const SlotView({required this.slot, required this.isActive});

  final Slot slot;

  /// True for the slot the device is emulating right now
  /// (`DeviceSession.activeSlot`).
  final bool isActive;

  int get index => slot.index;

  /// The device labels its slots 1..8; the wire indexes them 0..7.
  int get number => slot.index + 1;

  bool get isEnabled => slot.hfEnabled || slot.lfEnabled;

  /// One name per slot in list contexts: the HF nickname if there is one,
  /// otherwise the LF one, otherwise nothing (the tile then shows its own
  /// "empty" placeholder).
  String? get nickname {
    if (slot.hfNick.isNotEmpty) return slot.hfNick;
    if (slot.lfNick.isNotEmpty) return slot.lfNick;
    return null;
  }

  /// The types actually set on this slot, HF first.
  List<TagType> get presentTypes => <TagType>[
    if (slot.hfType != TagType.undefined) slot.hfType,
    if (slot.lfType != TagType.undefined) slot.lfType,
  ];
}

/// Pairs each slot with whether it is the active one. Pure, so the rule is
/// tested without a session.
List<SlotView> buildSlotViews(List<Slot> slots, int? activeIndex) => <SlotView>[
  for (final Slot slot in slots)
    SlotView(slot: slot, isActive: slot.index == activeIndex),
];
