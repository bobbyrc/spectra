import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../state/slot_labels.dart';
import '../state/slot_view.dart';
import '../state/slot_views_provider.dart';

/// Spec 7.7 step 2: the grid of eight. Layout only — the state is
/// `slotViewsProvider` and every mutation lives in the detail screen.
class SlotsPage extends ConsumerWidget {
  const SlotsPage({super.key});

  /// Wide enough for a nickname plus two type labels, narrow enough that a
  /// phone gets one column and a desktop window gets three or four.
  static const double _tileMaxWidth = 320;
  static const double _tileHeight = 132;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<SlotView> views = ref.watch(slotViewsProvider);

    if (views.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(SpectraSpacing.lg),
        children: <Widget>[SpectraCard(child: Text(l10n.slotsEmpty))],
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(SpectraSpacing.lg),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _tileMaxWidth,
        mainAxisExtent: _tileHeight,
        crossAxisSpacing: SpectraSpacing.md,
        mainAxisSpacing: SpectraSpacing.md,
      ),
      itemCount: views.length,
      itemBuilder: (BuildContext context, int i) {
        final SlotView view = views[i];
        return SpectraSlotTile(
          number: view.number,
          enabled: view.isEnabled,
          nickname: view.nickname,
          tagTypes: slotTypeLabels(view, l10n),
          active: view.isActive,
        );
      },
    );
  }
}
