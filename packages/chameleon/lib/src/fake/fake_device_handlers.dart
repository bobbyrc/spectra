import 'dart:convert';
import 'dart:typed_data';

import '../codec/bytes.dart';
import '../codec/frame.dart';
import '../model/enums.dart';
import '../protocol/status.dart';
import 'fake_firmware.dart';

/// Device and settings commands (1000-1040). ENTER_BOOTLOADER (1010) never
/// reaches here: the firmware reboots without answering.
extension FakeDeviceHandlers on FakeFirmware {
  Frame handleDevice(int cmd, ByteReader r) {
    switch (cmd) {
      case 1000:
        return okFrame(cmd, [config.version.major, config.version.minor]);
      case 1001:
        final m = DeviceMode.fromCode(r.u8());
        if (m == DeviceMode.reader && config.model == DeviceModel.lite) {
          return statusFrame(cmd, Status.notImplemented);
        }
        mode = m;
        return okFrame(cmd);
      case 1002:
        return okFrame(cmd, [mode.code]);
      case 1003:
        activeSlot = slotIndex(r.u8());
        return okFrame(cmd);
      case 1004:
        final s = slots[slotIndex(r.u8())];
        final t = TagType.fromCode(r.u16());
        if (t.sense == Sense.lf) {
          s.lfType = t;
        } else {
          s.hfType = t;
        }
        slotsSaved = false;
        return okFrame(cmd);
      case 1005:
        final s = slots[slotIndex(r.u8())];
        final t = TagType.fromCode(r.u16());
        if (t.sense == Sense.lf) {
          s.lfType = t;
          s.lfIds.updateAll((k, v) => Uint8List(v.length));
        } else {
          s.hfType = t;
          s.mf1Blocks.fillRange(0, s.mf1Blocks.length, 0);
          s.ntagPages.fillRange(0, s.ntagPages.length, 0);
        }
        slotsSaved = false;
        return okFrame(cmd);
      case 1006:
        final s = slots[slotIndex(r.u8())];
        final sense = Sense.fromCode(r.u8());
        final en = r.u8() != 0;
        if (sense == Sense.lf) {
          s.lfEnabled = en;
        } else {
          s.hfEnabled = en;
        }
        slotsSaved = false;
        return okFrame(cmd);
      case 1007:
        final s = slots[slotIndex(r.u8())];
        final sense = Sense.fromCode(r.u8());
        final nick = utf8.decode(r.rest(), allowMalformed: true);
        if (sense == Sense.lf) {
          s.lfNick = nick;
        } else {
          s.hfNick = nick;
        }
        slotsSaved = false;
        return okFrame(cmd);
      case 1008:
        final s = slots[slotIndex(r.u8())];
        final sense = Sense.fromCode(r.u8());
        return okFrame(
          cmd,
          utf8.encode(sense == Sense.lf ? s.lfNick : s.hfNick),
        );
      case 1009:
        slotsSaved = true;
        return okFrame(cmd);
      case 1011:
        return okFrame(cmd, _hexToBytes(config.chipId));
      case 1012:
        return okFrame(cmd, _hexToBytes(config.address.replaceAll(':', '')));
      case 1013:
        savedSettings = settings;
        return okFrame(cmd);
      case 1014:
        settings = FakeFirmware.defaultSettings(config.settingsVersion);
        savedSettings = settings;
        return okFrame(cmd);
      case 1015:
        settings = settings.copyWith(animation: AnimationMode.fromCode(r.u8()));
        return okFrame(cmd);
      case 1016:
        return okFrame(cmd, [settings.animation.code]);
      case 1017:
        return okFrame(cmd, utf8.encode(config.gitVersion));
      case 1018:
        return okFrame(cmd, [activeSlot]);
      case 1019:
        final w = ByteWriter();
        for (final s in slots) {
          w.u16(s.hfType.code).u16(s.lfType.code);
        }
        return okFrame(cmd, w.toBytes());
      case 1020:
        for (final s in slots) {
          s.hfType = TagType.undefined;
          s.lfType = TagType.undefined;
          s.hfEnabled = false;
          s.lfEnabled = false;
          s.hfNick = '';
          s.lfNick = '';
        }
        return okFrame(cmd);
      case 1021:
        final s = slots[slotIndex(r.u8())];
        if (Sense.fromCode(r.u8()) == Sense.lf) {
          s.lfNick = '';
        } else {
          s.hfNick = '';
        }
        slotsSaved = false;
        return okFrame(cmd);
      case 1023:
        final w = ByteWriter();
        for (final s in slots) {
          w.u8(s.hfEnabled ? 1 : 0).u8(s.lfEnabled ? 1 : 0);
        }
        return okFrame(cmd, w.toBytes());
      case 1024:
        final s = slots[slotIndex(r.u8())];
        if (Sense.fromCode(r.u8()) == Sense.lf) {
          s.lfType = TagType.undefined;
          s.lfEnabled = false;
        } else {
          s.hfType = TagType.undefined;
          s.hfEnabled = false;
        }
        slotsSaved = false;
        return okFrame(cmd);
      case 1025:
        return okFrame(
          cmd,
          ByteWriter().u16(battery.millivolts).u8(battery.percent).toBytes(),
        );
      case 1026:
        final btn = r.u8();
        final fn = btn == DeviceButton.a.code
            ? settings.buttonA
            : settings.buttonB;
        return okFrame(cmd, [fn.code]);
      case 1027:
        final btn = r.u8();
        final fn = ButtonFunction.fromCode(r.u8());
        settings = btn == DeviceButton.a.code
            ? settings.copyWith(buttonA: fn)
            : settings.copyWith(buttonB: fn);
        return okFrame(cmd);
      case 1028:
        final btn = r.u8();
        final fn = btn == DeviceButton.a.code
            ? settings.longButtonA
            : settings.longButtonB;
        return okFrame(cmd, [fn.code]);
      case 1029:
        final btn = r.u8();
        final fn = ButtonFunction.fromCode(r.u8());
        settings = btn == DeviceButton.a.code
            ? settings.copyWith(longButtonA: fn)
            : settings.copyWith(longButtonB: fn);
        return okFrame(cmd);
      case 1030:
        settings = settings.copyWith(blePairingKey: r.utf8String(6));
        return okFrame(cmd);
      case 1031:
        return okFrame(cmd, utf8.encode(settings.blePairingKey));
      case 1032:
        return okFrame(cmd);
      case 1033:
        return okFrame(cmd, [config.model.code]);
      case 1034:
        return okFrame(cmd, _settingsBytes());
      case 1035:
        final w = ByteWriter();
        for (final id in config.effectiveCapabilities.toList()..sort()) {
          w.u16(id);
        }
        return okFrame(cmd, w.toBytes());
      case 1036:
        return okFrame(cmd, [settings.blePairingEnabled ? 1 : 0]);
      case 1037:
        settings = settings.copyWith(blePairingEnabled: r.u8() != 0);
        return okFrame(cmd);
      case 1038:
        final w = ByteWriter();
        for (final s in slots) {
          final hf = utf8.encode(s.hfNick);
          final lf = utf8.encode(s.lfNick);
          w.u8(hf.length).bytes(hf).u8(lf.length).bytes(lf);
        }
        return okFrame(cmd, w.toBytes());
      case 1039:
        return okFrame(cmd, [settings.sleepTimeoutSeconds ?? 8]);
      case 1040:
        settings = settings.copyWith(sleepTimeoutSeconds: r.u8());
        return okFrame(cmd);
      default:
        return statusFrame(cmd, Status.notImplemented);
    }
  }

  /// GET_DEVICE_SETTINGS payload. Settings v5 stops before the sleep timeout.
  Uint8List _settingsBytes() {
    final w = ByteWriter()
        .u8(settings.version)
        .u8(settings.animation.code)
        .u8(settings.buttonA.code)
        .u8(settings.buttonB.code)
        .u8(settings.longButtonA.code)
        .u8(settings.longButtonB.code)
        .u8(settings.blePairingEnabled ? 1 : 0)
        .utf8String(settings.blePairingKey);
    if (config.settingsVersion >= 6) {
      w.u8(settings.sleepTimeoutSeconds ?? 8);
    }
    return w.toBytes();
  }
}

List<int> _hexToBytes(String hex) => [
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
];
