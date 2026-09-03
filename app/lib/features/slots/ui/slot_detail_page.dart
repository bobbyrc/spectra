import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/routing/sub_page_scaffold.dart';
import '../../../l10n/app_localizations.dart';
import '../state/slot_editor_controller.dart';
import '../state/slot_view.dart';
import '../state/slot_views_provider.dart';
import 'slot_sense_section.dart';

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

    final AsyncValue<void> editing = ref.watch(slotEditorProvider(index));
    final bool busy = editing.isLoading;

    return SubPageScaffold(
      title: l10n.slotDetailTitle(view.number),
      body: ListView(
        padding: const EdgeInsets.all(SpectraSpacing.lg),
        children: <Widget>[
          SpectraCard(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    view.isActive ? l10n.slotActive : l10n.slotInactive,
                  ),
                ),
                if (!view.isActive)
                  SpectraButton(
                    label: l10n.slotMakeActive,
                    variant: SpectraButtonVariant.secondary,
                    onPressed: busy
                        ? null
                        : () {
                            unawaited(
                              ref
                                  .read(slotEditorProvider(index).notifier)
                                  .makeActive(),
                            );
                          },
                  ),
              ],
            ),
          ),
          const SizedBox(height: SpectraSpacing.md),
          SlotSenseSection(view: view, sense: Sense.hf, busy: busy),
          const SizedBox(height: SpectraSpacing.md),
          SlotSenseSection(view: view, sense: Sense.lf, busy: busy),
        ],
      ),
    );
  }
}
