import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../state/slot_labels.dart';
import '../state/slot_view.dart';
import '../state/slot_views_provider.dart';

/// **The Slots feature's public API** (spec 8.3). Asks the user which of the
/// device's eight slots to use, and resolves to that slot's **wire index**
/// (0..7) — the same number `SlotsFacade` takes — or null if the sheet was
/// dismissed.
///
/// Contract for the features that call it (Phase 6 "save to slot", Phase 7
/// "load to slot"):
///
/// - Import it as `package:spectra/features/slots/slots.dart`. Never reach
///   into `features/slots/ui/…` or `features/slots/state/…` (spec 8.4).
/// - The returned index is a wire index, not a display number. Pass it
///   straight to `session.slots`; add one only when showing it to a person.
/// - It resolves to null on dismissal, and callers must handle that: it is
///   the normal way out of the sheet, not an error.
/// - [isSelectable] filters what may be chosen — an unselectable slot is
///   still shown, greyed and untappable, so the user can see why a slot is
///   not on offer. Pass, say, `(v) => v.slot.hfType.family ==
///   TagFamily.mifareClassic` to restrict a MIFARE Classic write target.
/// - With nothing connected the sheet shows the empty state and can only be
///   dismissed; it never opens a session of its own.
/// - It changes nothing on the device. Choosing a slot is a choice, not a
///   write — the caller does the write.
Future<int?> showSlotPicker(
  BuildContext context, {
  int? initialIndex,
  bool Function(SlotView slot)? isSelectable,
}) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return SpectraBottomSheet.show<int>(
    context: context,
    title: l10n.slotPickerTitle,
    builder: (BuildContext context) =>
        SlotPicker(initialIndex: initialIndex, isSelectable: isSelectable),
  );
}

/// The picker's body, for a caller that wants it inline rather than modal.
/// Pops the enclosing route with the chosen wire index.
class SlotPicker extends ConsumerWidget {
  const SlotPicker({this.initialIndex, this.isSelectable, super.key});

  final int? initialIndex;
  final bool Function(SlotView slot)? isSelectable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<SlotView> views = ref.watch(slotViewsProvider);
    if (views.isEmpty) return SpectraCard(child: Text(l10n.slotsEmpty));

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: views.length,
        separatorBuilder: (BuildContext context, int i) =>
            const SizedBox(height: SpectraSpacing.sm),
        itemBuilder: (BuildContext context, int i) {
          final SlotView view = views[i];
          final bool selectable = isSelectable?.call(view) ?? true;
          return SpectraSlotTile(
            number: view.number,
            enabled: view.isEnabled && selectable,
            nickname: view.nickname,
            tagTypes: slotTypeLabels(view, l10n),
            active: view.index == (initialIndex ?? -1) || view.isActive,
            onTap: selectable
                ? () => Navigator.of(context).pop(view.index)
                : null,
          );
        },
      ),
    );
  }
}
