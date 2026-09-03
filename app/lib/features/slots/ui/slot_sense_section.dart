import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../state/slot_editor_controller.dart';
import '../state/slot_labels.dart';
import '../state/slot_view.dart';

/// One side of a slot: its tag type, its enable switch, its name and the
/// actions that change them. Layout only.
///
/// A `ConsumerStatefulWidget` from the start: Task 7 adds the name field's
/// own editing state (a `TextEditingController` disposed with the widget)
/// and Task 8 the type/clear action buttons, both as additive edits to
/// [_SlotSenseSectionState] rather than a later rewrite from stateless.
class SlotSenseSection extends ConsumerStatefulWidget {
  const SlotSenseSection({
    required this.view,
    required this.sense,
    required this.busy,
    super.key,
  });

  final SlotView view;
  final Sense sense;

  /// True while a change to this slot is in flight: every control is
  /// disabled so a second tap cannot race the first.
  final bool busy;

  @override
  ConsumerState<SlotSenseSection> createState() => _SlotSenseSectionState();
}

class _SlotSenseSectionState extends ConsumerState<SlotSenseSection> {
  TagType get _type => widget.sense == Sense.lf
      ? widget.view.slot.lfType
      : widget.view.slot.hfType;

  bool get _enabled => widget.sense == Sense.lf
      ? widget.view.slot.lfEnabled
      : widget.view.slot.hfEnabled;

  // Task 7 wires this into the name field's initial value; kept here now
  // per ruling 12 so that task is an additive edit, not a rewrite.
  // ignore: unused_element
  String? get _deviceNick => widget.sense == Sense.lf
      ? widget.view.slot.lfNick
      : widget.view.slot.hfNick;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SlotEditor editor = ref.read(
      slotEditorProvider(widget.view.index).notifier,
    );

    return SpectraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SpectraSectionHeader(title: senseLabel(widget.sense, l10n)),
          SpectraListTile(
            title: l10n.slotEnabled,
            subtitle: tagTypeLabel(_type, l10n),
            trailing: Switch(
              value: _enabled,
              onChanged: widget.busy
                  ? null
                  : (bool next) => editor.setEnabled(widget.sense, next),
            ),
          ),
        ],
      ),
    );
  }
}
