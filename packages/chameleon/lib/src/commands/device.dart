import 'dart:convert';
import 'dart:typed_data';

import '../codec/bytes.dart';
import '../model/enums.dart';
import '../model/models.dart';
import '../protocol/command.dart';

/// Marker for read-only device commands: idempotent by default.
abstract base class _Read<R> extends Command<R> {
  const _Read();
  @override
  bool get idempotent => true;
}

final class GetAppVersion extends _Read<FirmwareVersion> {
  const GetAppVersion();
  @override
  int get id => 1000;
  @override
  FirmwareVersion decode(Uint8List data) {
    final r = ByteReader(data);
    return FirmwareVersion(major: r.u8(), minor: r.u8());
  }
}

final class ChangeDeviceMode extends VoidCommand {
  const ChangeDeviceMode(this.mode);
  final DeviceMode mode;
  @override
  int get id => 1001;
  @override
  Uint8List encode() => ByteWriter().u8(mode.code).toBytes();
}

final class GetDeviceMode extends _Read<DeviceMode> {
  const GetDeviceMode();
  @override
  int get id => 1002;
  @override
  DeviceMode decode(Uint8List data) =>
      DeviceMode.fromCode(ByteReader(data).u8());
}

final class SetActiveSlot extends VoidCommand {
  const SetActiveSlot(this.slot);
  final int slot;
  @override
  int get id => 1003;
  @override
  Uint8List encode() => ByteWriter().u8(slot).toBytes();
}

final class SetSlotTagType extends VoidCommand {
  const SetSlotTagType(this.slot, this.type);
  final int slot;
  final TagType type;
  @override
  int get id => 1004;
  @override
  Uint8List encode() => ByteWriter().u8(slot).u16(type.code).toBytes();
}

final class SetSlotDataDefault extends VoidCommand {
  const SetSlotDataDefault(this.slot, this.type);
  final int slot;
  final TagType type;
  @override
  int get id => 1005;
  @override
  Uint8List encode() => ByteWriter().u8(slot).u16(type.code).toBytes();
}

final class SetSlotEnable extends VoidCommand {
  const SetSlotEnable(this.slot, this.sense, this.enabled);
  final int slot;
  final Sense sense;
  final bool enabled;
  @override
  int get id => 1006;
  @override
  Uint8List encode() =>
      ByteWriter().u8(slot).u8(sense.code).u8(enabled ? 1 : 0).toBytes();
}

const int maxNickBytes = 32;

final class SetSlotTagNick extends VoidCommand {
  const SetSlotTagNick(this.slot, this.sense, this.nick);
  final int slot;
  final Sense sense;
  final String nick;
  @override
  int get id => 1007;
  @override
  Uint8List encode() {
    final bytes = utf8.encode(nick);
    if (bytes.length > maxNickBytes) {
      throw ArgumentError.value(
        nick,
        'nick',
        'longer than $maxNickBytes bytes',
      );
    }
    return ByteWriter().u8(slot).u8(sense.code).bytes(bytes).toBytes();
  }
}

final class GetSlotTagNick extends _Read<String> {
  const GetSlotTagNick(this.slot, this.sense);
  final int slot;
  final Sense sense;
  @override
  int get id => 1008;
  @override
  Uint8List encode() => ByteWriter().u8(slot).u8(sense.code).toBytes();
  @override
  String decode(Uint8List data) => utf8.decode(data, allowMalformed: true);
}

final class SlotDataConfigSave extends VoidCommand {
  const SlotDataConfigSave();
  @override
  int get id => 1009;
}

/// The firmware reboots into the bootloader and never answers.
final class EnterBootloader extends VoidCommand {
  const EnterBootloader();
  @override
  int get id => 1010;
  @override
  bool get expectsResponse => false;
}

final class GetDeviceChipId extends _Read<String> {
  const GetDeviceChipId();
  @override
  int get id => 1011;
  @override
  String decode(Uint8List data) => hexOf(ByteReader(data).bytes(8));
}

final class GetDeviceAddress extends _Read<String> {
  const GetDeviceAddress();
  @override
  int get id => 1012;
  @override
  String decode(Uint8List data) =>
      ByteReader(data)
          .bytes(6)
          .map((x) => x.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(':');
}

final class SaveSettings extends VoidCommand {
  const SaveSettings();
  @override
  int get id => 1013;
}

final class ResetSettings extends VoidCommand {
  const ResetSettings();
  @override
  int get id => 1014;
}

final class SetAnimationMode extends VoidCommand {
  const SetAnimationMode(this.mode);
  final AnimationMode mode;
  @override
  int get id => 1015;
  @override
  Uint8List encode() => ByteWriter().u8(mode.code).toBytes();
}

final class GetAnimationMode extends _Read<AnimationMode> {
  const GetAnimationMode();
  @override
  int get id => 1016;
  @override
  AnimationMode decode(Uint8List data) =>
      AnimationMode.fromCode(ByteReader(data).u8());
}

final class GetGitVersion extends _Read<String> {
  const GetGitVersion();
  @override
  int get id => 1017;
  @override
  String decode(Uint8List data) => utf8.decode(data, allowMalformed: true);
}

final class GetActiveSlot extends _Read<int> {
  const GetActiveSlot();
  @override
  int get id => 1018;
  @override
  int decode(Uint8List data) => ByteReader(data).u8();
}

final class SlotTypes {
  const SlotTypes(this.hf, this.lf);
  final TagType hf;
  final TagType lf;
  @override
  bool operator ==(Object other) =>
      other is SlotTypes && other.hf == hf && other.lf == lf;
  @override
  int get hashCode => Object.hash(hf, lf);
}

final class GetSlotInfo extends _Read<List<SlotTypes>> {
  const GetSlotInfo();
  @override
  int get id => 1019;
  @override
  List<SlotTypes> decode(Uint8List data) {
    final r = ByteReader(data);
    return List.generate(
      8,
      (_) => SlotTypes(TagType.fromCode(r.u16()), TagType.fromCode(r.u16())),
    );
  }
}

final class WipeFds extends VoidCommand {
  const WipeFds();
  @override
  int get id => 1020;
}

final class DeleteSlotTagNick extends VoidCommand {
  const DeleteSlotTagNick(this.slot, this.sense);
  final int slot;
  final Sense sense;
  @override
  int get id => 1021;
  @override
  Uint8List encode() => ByteWriter().u8(slot).u8(sense.code).toBytes();
}

final class SlotEnabled {
  const SlotEnabled(this.hf, this.lf);
  final bool hf;
  final bool lf;
  @override
  bool operator ==(Object other) =>
      other is SlotEnabled && other.hf == hf && other.lf == lf;
  @override
  int get hashCode => Object.hash(hf, lf);
}

final class GetEnabledSlots extends _Read<List<SlotEnabled>> {
  const GetEnabledSlots();
  @override
  int get id => 1023;
  @override
  List<SlotEnabled> decode(Uint8List data) {
    final r = ByteReader(data);
    return List.generate(8, (_) => SlotEnabled(r.u8() != 0, r.u8() != 0));
  }
}

final class DeleteSlotSenseType extends VoidCommand {
  const DeleteSlotSenseType(this.slot, this.sense);
  final int slot;
  final Sense sense;
  @override
  int get id => 1024;
  @override
  Uint8List encode() => ByteWriter().u8(slot).u8(sense.code).toBytes();
}

final class GetBatteryInfo extends _Read<BatteryInfo> {
  const GetBatteryInfo();
  @override
  int get id => 1025;
  @override
  BatteryInfo decode(Uint8List data) {
    final r = ByteReader(data);
    return BatteryInfo(millivolts: r.u16(), percent: r.u8());
  }
}

final class GetButtonPressConfig extends _Read<ButtonFunction> {
  const GetButtonPressConfig(this.button);
  final DeviceButton button;
  @override
  int get id => 1026;
  @override
  Uint8List encode() => ByteWriter().u8(button.code).toBytes();
  @override
  ButtonFunction decode(Uint8List data) =>
      ButtonFunction.fromCode(ByteReader(data).u8());
}

final class SetButtonPressConfig extends VoidCommand {
  const SetButtonPressConfig(this.button, this.function);
  final DeviceButton button;
  final ButtonFunction function;
  @override
  int get id => 1027;
  @override
  Uint8List encode() =>
      ByteWriter().u8(button.code).u8(function.code).toBytes();
}

final class GetLongButtonPressConfig extends _Read<ButtonFunction> {
  const GetLongButtonPressConfig(this.button);
  final DeviceButton button;
  @override
  int get id => 1028;
  @override
  Uint8List encode() => ByteWriter().u8(button.code).toBytes();
  @override
  ButtonFunction decode(Uint8List data) =>
      ButtonFunction.fromCode(ByteReader(data).u8());
}

final class SetLongButtonPressConfig extends VoidCommand {
  const SetLongButtonPressConfig(this.button, this.function);
  final DeviceButton button;
  final ButtonFunction function;
  @override
  int get id => 1029;
  @override
  Uint8List encode() =>
      ByteWriter().u8(button.code).u8(function.code).toBytes();
}

final class SetBlePairingKey extends VoidCommand {
  const SetBlePairingKey(this.key);
  final String key;
  @override
  int get id => 1030;
  @override
  Uint8List encode() {
    if (!RegExp(r'^\d{6}$').hasMatch(key)) {
      throw ArgumentError.value(key, 'key', 'must be six ASCII digits');
    }
    return ByteWriter().utf8String(key).toBytes();
  }
}

final class GetBlePairingKey extends _Read<String> {
  const GetBlePairingKey();
  @override
  int get id => 1031;
  @override
  String decode(Uint8List data) => ByteReader(data).utf8String(6);
}

final class DeleteAllBleBonds extends VoidCommand {
  const DeleteAllBleBonds();
  @override
  int get id => 1032;
}

final class GetDeviceModel extends _Read<DeviceModel> {
  const GetDeviceModel();
  @override
  int get id => 1033;
  @override
  DeviceModel decode(Uint8List data) =>
      DeviceModel.fromCode(ByteReader(data).u8());
}

/// hardware-validate: the settings payload length differs between firmware
/// versions. Decoded by the leading version byte: v5 carries no sleep
/// timeout, v6 adds one trailing sleep-timeout byte. An unrecognised version
/// byte falls back to detecting the sleep-timeout byte by remaining length.
/// Unknown trailing bytes beyond that are ignored.
final class GetDeviceSettings extends _Read<DeviceSettings> {
  const GetDeviceSettings();
  @override
  int get id => 1034;
  @override
  DeviceSettings decode(Uint8List data) {
    final r = ByteReader(data);
    final version = r.u8();
    final animation = AnimationMode.fromCode(r.u8());
    final a = ButtonFunction.fromCode(r.u8());
    final b = ButtonFunction.fromCode(r.u8());
    final la = ButtonFunction.fromCode(r.u8());
    final lb = ButtonFunction.fromCode(r.u8());
    final pairing = r.u8() != 0;
    final key = r.utf8String(6);
    final int? sleep;
    switch (version) {
      case 5:
        // v5 layout: no sleep-timeout field.
        sleep = null;
      case 6:
        // v6 layout: one trailing sleep-timeout byte, if present.
        sleep = r.remaining >= 1 ? r.u8() : null;
      default:
        // Unrecognised version: fall back to length-based detection.
        sleep = r.remaining >= 1 ? r.u8() : null;
    }
    return DeviceSettings(
      version: version,
      animation: animation,
      buttonA: a,
      buttonB: b,
      longButtonA: la,
      longButtonB: lb,
      blePairingEnabled: pairing,
      blePairingKey: key,
      sleepTimeoutSeconds: sleep,
    );
  }
}

final class GetDeviceCapabilities extends _Read<Capabilities> {
  const GetDeviceCapabilities();
  @override
  int get id => 1035;
  @override
  Capabilities decode(Uint8List data) {
    final r = ByteReader(data);
    final ids = <int>{};
    while (r.remaining >= 2) {
      ids.add(r.u16());
    }
    return Capabilities(ids);
  }
}

final class GetBlePairingEnable extends _Read<bool> {
  const GetBlePairingEnable();
  @override
  int get id => 1036;
  @override
  bool decode(Uint8List data) => ByteReader(data).u8() != 0;
}

final class SetBlePairingEnable extends VoidCommand {
  const SetBlePairingEnable(this.enabled);
  final bool enabled;
  @override
  int get id => 1037;
  @override
  Uint8List encode() => ByteWriter().u8(enabled ? 1 : 0).toBytes();
}

final class SlotNicks {
  const SlotNicks(this.hf, this.lf);
  final String hf;
  final String lf;
  @override
  bool operator ==(Object other) =>
      other is SlotNicks && other.hf == hf && other.lf == lf;
  @override
  int get hashCode => Object.hash(hf, lf);
}

final class GetAllSlotNicks extends _Read<List<SlotNicks>> {
  const GetAllSlotNicks();
  @override
  int get id => 1038;
  @override
  List<SlotNicks> decode(Uint8List data) {
    final r = ByteReader(data);
    return List.generate(8, (_) {
      final hf = r.utf8String(r.u8());
      final lf = r.utf8String(r.u8());
      return SlotNicks(hf, lf);
    });
  }
}

final class GetSleepTimeout extends _Read<int> {
  const GetSleepTimeout();
  @override
  int get id => 1039;
  @override
  int decode(Uint8List data) => ByteReader(data).u8();
}

final class SetSleepTimeout extends VoidCommand {
  const SetSleepTimeout(this.seconds);
  final int seconds;
  @override
  int get id => 1040;
  @override
  Uint8List encode() {
    if (seconds < 5 || seconds > 60) {
      throw ArgumentError.value(seconds, 'seconds', 'must be 5..60');
    }
    return ByteWriter().u8(seconds).toBytes();
  }
}
