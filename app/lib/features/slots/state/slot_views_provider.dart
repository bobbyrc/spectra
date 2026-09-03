import 'package:chameleon/chameleon.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/session/session_streams.dart';
import 'slot_view.dart';

part 'slot_views_provider.g.dart';

/// The eight slots, ready to render. Empty while nothing is connected —
/// `slotsProvider` yields `const []` in that case, so no screen has to
/// special-case "no session" a second time.
///
/// `.value` (never `valueOrNull`, which riverpod 3 does not have) because a
/// stream provider's first frame is `AsyncLoading` and an empty grid is the
/// right thing to show for that one frame.
@riverpod
List<SlotView> slotViews(Ref ref) {
  final List<Slot> slots = ref.watch(slotsProvider).value ?? const <Slot>[];
  final int? active = ref.watch(activeSlotProvider).value;
  return buildSlotViews(slots, active);
}
