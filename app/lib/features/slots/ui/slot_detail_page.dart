import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/routing/sub_page_scaffold.dart';
import '../../../l10n/app_localizations.dart';
import '../state/slot_view.dart';
import '../state/slot_views_provider.dart';

/// Spec 7.7 step 2's editor: everything one slot can be changed to. Layout
/// only — every mutation goes through `slotEditorProvider` (Task 5).
class SlotDetailPage extends ConsumerWidget {
  const SlotDetailPage({required this.index, super.key});

  /// The wire index, 0..7. `-1` when the route named something that is not
  /// an index at all.
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<SlotView> views = ref.watch(slotViewsProvider);
    final SlotView? view = views
        .where((SlotView v) => v.index == index)
        .firstOrNull;

    if (view == null) {
      return SubPageScaffold(
        title: l10n.slotsTitle,
        body: Padding(
          padding: const EdgeInsets.all(SpectraSpacing.lg),
          child: SpectraCard(child: Text(l10n.slotNotFound)),
        ),
      );
    }

    return SubPageScaffold(
      title: l10n.slotDetailTitle(view.number),
      body: ListView(
        padding: const EdgeInsets.all(SpectraSpacing.lg),
        children: const <Widget>[
          // Tasks 6-8 add the HF section, the LF section and the nickname
          // field here, each reading and writing through
          // `slotEditorProvider(index)`.
        ],
      ),
    );
  }
}
