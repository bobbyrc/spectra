import '../../commands/device.dart';
import '../../model/enums.dart';
import '../../model/models.dart';
import '../device_session.dart';

/// The eight emulation slots (spec 8.1).
///
/// Every mutation is one method that ends with SLOT_DATA_CONFIG_SAVE, so the
/// device never holds slot state that a power cycle would lose, and writes
/// the change through to the cache from what it just sent — no re-read.
/// [save] exists for callers that batch raw edits of their own.
final class SlotsFacade {
  SlotsFacade(this._s);
  final DeviceSession _s;

  List<Slot> get current => _s.slotsState.value;
  int? get active => _s.activeSlot.value;

  /// Re-reads every slot from the device (types, enabled flags, nicknames).
  /// Several commands, so it runs as one busy operation.
  Future<List<Slot>> refresh() => _s.busy(_s.refreshSlots);

  Future<void> setActive(int index) async {
    await _s.send(SetActiveSlot(index));
    _s.activeSlot.setIfChanged(index);
  }

  Future<void> setEnabled(int index, Sense sense, bool enabled) =>
      _s.busy(() async {
        await _s.send(SetSlotEnable(index, sense, enabled));
        _update(
          index,
          (s) => sense == Sense.lf
              ? s.copyWith(lfEnabled: enabled)
              : s.copyWith(hfEnabled: enabled),
        );
        await save();
      });

  Future<void> rename(int index, Sense sense, String nick) => _s.busy(() async {
    await _s.send(SetSlotTagNick(index, sense, nick));
    _update(
      index,
      (s) => sense == Sense.lf
          ? s.copyWith(lfNick: nick)
          : s.copyWith(hfNick: nick),
    );
    await save();
  });

  Future<void> setTagType(int index, TagType type) => _s.busy(() async {
    await _s.send(SetSlotTagType(index, type));
    _update(index, (s) => _withType(s, type));
    await save();
  });

  /// Sets the type and resets that sense's emulator data to defaults.
  Future<void> resetToDefault(int index, TagType type) => _s.busy(() async {
    await _s.send(SetSlotDataDefault(index, type));
    _update(index, (s) => _withType(s, type));
    await save();
  });

  Future<void> deleteSense(int index, Sense sense) => _s.busy(() async {
    await _s.send(DeleteSlotSenseType(index, sense));
    _update(
      index,
      (s) => sense == Sense.lf
          ? s.copyWith(lfType: TagType.undefined, lfEnabled: false)
          : s.copyWith(hfType: TagType.undefined, hfEnabled: false),
    );
    await save();
  });

  /// Persists the slot configuration. Every mutation here already does this;
  /// call it after raw edits made outside the facade.
  Future<void> save() => _s.send(const SlotDataConfigSave());

  /// The request names a type, not a sense, so an undefined type clears both
  /// senses the way the firmware does.
  Slot _withType(Slot slot, TagType type) => switch (type.sense) {
    Sense.lf => slot.copyWith(lfType: type),
    Sense.hf => slot.copyWith(hfType: type),
    Sense.none => slot.copyWith(hfType: type, lfType: type),
  };

  void _update(int index, Slot Function(Slot) f) {
    final list = List<Slot>.of(current);
    if (index < 0 || index >= list.length) return;
    list[index] = f(list[index]);
    _s.slotsState.set(list);
  }
}
