import '../codec/bytes.dart';
import '../codec/frame.dart';
import '../commands/lf_emulator.dart' show emuLfIdLengths;
import '../model/enums.dart';
import '../model/models.dart';
import '../protocol/status.dart';
import 'fake_firmware.dart';

/// Emulator commands (4000-4999 HF, 5000-5999 LF). They read and write the
/// active slot, so switching slots switches the data underneath them.
extension FakeEmulatorHandlers on FakeFirmware {
  Frame handleHfEmulator(int cmd, ByteReader r) {
    switch (cmd) {
      case 4000:
        final start = r.u8();
        final data = r.rest();
        slot.mf1Blocks.setRange(start * 16, start * 16 + data.length, data);
        return okFrame(cmd);
      case 4001:
        final uid = r.bytes(r.u8());
        final atqa = r.bytes(2);
        final sak = r.u8();
        final ats = r.bytes(r.u8());
        slot.antiColl = Hf14aTag(uid: uid, atqa: atqa, sak: sak, ats: ats);
        return okFrame(cmd);
      case 4004:
        slot.mf1Config = slot.mf1Config.copyWith(detectionEnabled: r.u8() != 0);
        return okFrame(cmd);
      case 4005:
        return okFrame(
          cmd,
          ByteWriter().u32(slot.detectionLog.length).toBytes(),
        );
      case 4006:
        final idx = r.u32();
        final w = ByteWriter();
        for (final e in slot.detectionLog.skip(idx)) {
          w.bytes(e);
        }
        return okFrame(cmd, w.toBytes());
      case 4007:
        return okFrame(cmd, [slot.mf1Config.detectionEnabled ? 1 : 0]);
      case 4008:
        final start = r.u8();
        final count = r.u8();
        return okFrame(
          cmd,
          slot.mf1Blocks.sublist(start * 16, (start + count) * 16),
        );
      case 4009:
        final c = slot.mf1Config;
        return okFrame(cmd, [
          c.detectionEnabled ? 1 : 0,
          c.gen1a ? 1 : 0,
          c.gen2 ? 1 : 0,
          c.blockAntiColl ? 1 : 0,
          c.writeMode.code,
        ]);
      case 4010:
        return okFrame(cmd, [slot.mf1Config.gen1a ? 1 : 0]);
      case 4011:
        slot.mf1Config = slot.mf1Config.copyWith(gen1a: r.u8() != 0);
        return okFrame(cmd);
      case 4012:
        return okFrame(cmd, [slot.mf1Config.gen2 ? 1 : 0]);
      case 4013:
        slot.mf1Config = slot.mf1Config.copyWith(gen2: r.u8() != 0);
        return okFrame(cmd);
      case 4014:
        return okFrame(cmd, [slot.mf1Config.blockAntiColl ? 1 : 0]);
      case 4015:
        slot.mf1Config = slot.mf1Config.copyWith(blockAntiColl: r.u8() != 0);
        return okFrame(cmd);
      case 4016:
        return okFrame(cmd, [slot.mf1Config.writeMode.code]);
      case 4017:
        slot.mf1Config = slot.mf1Config.copyWith(
          writeMode: Mf1WriteMode.fromCode(r.u8()),
        );
        return okFrame(cmd);
      case 4018:
        final t = slot.antiColl;
        return okFrame(
          cmd,
          FakeFirmware.antiCollBytes(t.uid, t.atqa, t.sak, t.ats),
        );
      case 4019:
        return okFrame(cmd, [slot.uidMagic ? 1 : 0]);
      case 4020:
        slot.uidMagic = r.u8() != 0;
        return okFrame(cmd);
      case 4021:
        final page = r.u8();
        final count = r.u8();
        return okFrame(
          cmd,
          slot.ntagPages.sublist(page * 4, (page + count) * 4),
        );
      case 4022:
        final page = r.u8();
        final count = r.u8();
        final data = r.bytes(count * 4);
        slot.ntagPages.setRange(page * 4, page * 4 + data.length, data);
        return okFrame(cmd);
      case 4030:
        return okFrame(cmd, [slot.ntagPageCount]);
      default:
        return statusFrame(cmd, Status.notImplemented);
    }
  }

  /// LF emulator ids: even command sets, the next odd command gets.
  Frame handleLfEmulator(int cmd, ByteReader r) {
    if (cmd < 5000 || cmd > 5013) {
      return statusFrame(cmd, Status.notImplemented);
    }
    final setId = cmd.isEven ? cmd : cmd - 1;
    final len = emuLfIdLengths[setId];
    if (len == null) return statusFrame(cmd, Status.notImplemented);
    if (cmd.isEven) {
      slot.lfIds[setId] = r.bytes(len);
      return okFrame(cmd);
    }
    return okFrame(cmd, slot.lfIds[setId]!);
  }
}
