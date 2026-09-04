import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/format/tag_labels.dart';
import '../../../l10n/app_localizations.dart';
import '../state/slot_editor_controller.dart';
import '../state/slot_nickname.dart';
import '../state/slot_view.dart';
import 'tag_type_sheet.dart';

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
  late final TextEditingController _name = TextEditingController(
    text: _deviceNick,
  );

  TagType get _type => widget.sense == Sense.lf
      ? widget.view.slot.lfType
      : widget.view.slot.hfType;

  bool get _enabled => widget.sense == Sense.lf
      ? widget.view.slot.lfEnabled
      : widget.view.slot.hfEnabled;

  String get _deviceNick => widget.sense == Sense.lf
      ? widget.view.slot.lfNick
      : widget.view.slot.hfNick;

  @override
  void didUpdateWidget(SlotSenseSection old) {
    super.didUpdateWidget(old);
    // The device's own nickname changed (a save landed, or a refresh): pick
    // it up, unless the user is part-way through typing a different one.
    final String previous = old.sense == Sense.lf
        ? old.view.slot.lfNick
        : old.view.slot.hfNick;
    if (previous != _deviceNick && _name.text == previous) {
      _name.text = _deviceNick;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SlotEditor editor = ref.read(
      slotEditorProvider(widget.view.index).notifier,
    );
    final SlotNicknameError? nameError = validateSlotNickname(_name.text);
    final bool canSave =
        !widget.busy && nameError == null && _name.text != _deviceNick;

    return SpectraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SpectraSectionHeader(title: senseLabel(widget.sense, l10n)),
          // The type gets its own labelled row: as a bare subtitle under
          // "Enabled" it read as a caption on the switch rather than as
          // what this side of the slot actually is.
          SpectraListTile(
            title: l10n.slotTagType,
            subtitle: tagTypeLabel(_type, l10n),
          ),
          SpectraListTile(
            title: l10n.slotEnabled,
            trailing: Switch(
              value: _enabled,
              onChanged: widget.busy
                  ? null
                  : (bool next) =>
                        unawaited(editor.setEnabled(widget.sense, next)),
            ),
          ),
          const SizedBox(height: SpectraSpacing.md),
          SpectraTextField(
            label: l10n.slotNameLabel,
            controller: _name,
            enabled: !widget.busy,
            errorText: switch (nameError) {
              SlotNicknameError.tooLong => l10n.slotNicknameTooLong,
              null => null,
            },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: SpectraSpacing.md),
          SpectraButton(
            label: l10n.slotSaveName,
            variant: SpectraButtonVariant.secondary,
            onPressed: canSave
                ? () => unawaited(editor.rename(widget.sense, _name.text))
                : null,
          ),
          const SizedBox(height: SpectraSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: SpectraButton(
                  label: l10n.slotChangeType,
                  variant: SpectraButtonVariant.secondary,
                  onPressed: widget.busy
                      ? null
                      : () => unawaited(_changeType()),
                ),
              ),
              const SizedBox(width: SpectraSpacing.sm),
              Expanded(
                child: SpectraButton(
                  label: l10n.slotClear,
                  variant: SpectraButtonVariant.danger,
                  onPressed: widget.busy || _type == TagType.undefined
                      ? null
                      : () => unawaited(_clear()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _changeType() async {
    final TagType? chosen = await showTagTypeSheet(
      context,
      sense: widget.sense,
      current: _type,
    );
    if (chosen == null || !mounted) return;
    await ref
        .read(slotEditorProvider(widget.view.index).notifier)
        .setTagType(chosen);
  }

  Future<void> _clear() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? confirmed = await SpectraDialog.show<bool>(
      context: context,
      title: l10n.slotClearTitle,
      content: Text(l10n.slotClearBody(senseLabel(widget.sense, l10n))),
      actions: (BuildContext context) => <Widget>[
        SpectraButton(
          label: l10n.commonCancel,
          variant: SpectraButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        SpectraButton(
          label: l10n.slotClear,
          variant: SpectraButtonVariant.danger,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    await ref
        .read(slotEditorProvider(widget.view.index).notifier)
        .clearSense(widget.sense);
  }
}
