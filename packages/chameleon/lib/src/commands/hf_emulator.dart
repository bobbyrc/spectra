import 'dart:typed_data';

import '../codec/bytes.dart';
import '../model/enums.dart';
import '../model/models.dart';
import '../protocol/command.dart';

abstract base class _GetBool extends Command<bool> {
  const _GetBool();
  @override
  bool get idempotent => true;
  @override
  bool decode(Uint8List data) => ByteReader(data).u8() != 0;
}

abstract base class _SetBool extends VoidCommand {
  const _SetBool(this.value);
  final bool value;
  @override
  Uint8List encode() => ByteWriter().u8(value ? 1 : 0).toBytes();
}

final class Mf1WriteEmuBlockData extends VoidCommand {
  Mf1WriteEmuBlockData(this.startBlock, this.data) {
    if (data.isEmpty || data.length % 16 != 0) {
      throw ArgumentError.value(
        data.length,
        'data',
        'must be a multiple of 16 bytes',
      );
    }
  }
  final int startBlock;
  final Uint8List data;
  @override
  int get id => 4000;
  @override
  Uint8List encode() => ByteWriter().u8(startBlock).bytes(data).toBytes();
}

final class Hf14aSetAntiCollData extends VoidCommand {
  const Hf14aSetAntiCollData({
    required this.uid,
    required this.atqa,
    required this.sak,
    required this.ats,
  });
  final Uint8List uid;
  final Uint8List atqa;
  final int sak;
  final Uint8List ats;
  @override
  int get id => 4001;
  @override
  Uint8List encode() => ByteWriter()
      .u8(uid.length)
      .bytes(uid)
      .bytes(atqa)
      .u8(sak)
      .u8(ats.length)
      .bytes(ats)
      .toBytes();
}

final class Mf1SetDetectionEnable extends _SetBool {
  const Mf1SetDetectionEnable(super.value);
  @override
  int get id => 4004;
}

final class Mf1GetDetectionCount extends Command<int> {
  const Mf1GetDetectionCount();
  @override
  int get id => 4005;
  @override
  bool get idempotent => true;
  @override
  int decode(Uint8List data) => ByteReader(data).u32();
}

/// hardware-validate: 18-byte entries (block, flags, uid, nt, nr, ar).
final class Mf1GetDetectionLog extends Command<List<DetectionLogEntry>> {
  const Mf1GetDetectionLog(this.startIndex);
  final int startIndex;
  @override
  int get id => 4006;
  @override
  bool get idempotent => true;
  @override
  Uint8List encode() => ByteWriter().u32(startIndex).toBytes();
  @override
  List<DetectionLogEntry> decode(Uint8List data) {
    final r = ByteReader(data);
    final out = <DetectionLogEntry>[];
    while (r.remaining >= 18) {
      final block = r.u8();
      final flags = r.u8();
      out.add(
        DetectionLogEntry(
          block: block,
          keyType: (flags & 0x01) != 0 ? KeyType.b : KeyType.a,
          isNested: (flags & 0x02) != 0,
          uid: r.bytes(4),
          nt: r.u32(),
          nr: r.u32(),
          ar: r.u32(),
        ),
      );
    }
    return out;
  }
}

final class Mf1GetDetectionEnable extends _GetBool {
  const Mf1GetDetectionEnable();
  @override
  int get id => 4007;
}

final class Mf1ReadEmuBlockData extends Command<Uint8List> {
  const Mf1ReadEmuBlockData(this.startBlock, this.count);
  final int startBlock;
  final int count;
  @override
  int get id => 4008;
  @override
  bool get idempotent => true;
  @override
  Uint8List encode() {
    if (count < 1 || count > 32) {
      throw ArgumentError.value(count, 'count', 'must be 1..32');
    }
    return ByteWriter().u8(startBlock).u8(count).toBytes();
  }

  @override
  Uint8List decode(Uint8List data) => ByteReader(data).bytes(count * 16);
}

final class Mf1GetEmulatorConfig extends Command<Mf1EmulatorConfig> {
  const Mf1GetEmulatorConfig();
  @override
  int get id => 4009;
  @override
  bool get idempotent => true;
  @override
  Mf1EmulatorConfig decode(Uint8List data) {
    final r = ByteReader(data);
    return Mf1EmulatorConfig(
      detectionEnabled: r.u8() != 0,
      gen1a: r.u8() != 0,
      gen2: r.u8() != 0,
      blockAntiColl: r.u8() != 0,
      writeMode: Mf1WriteMode.fromCode(r.u8()),
    );
  }
}

final class Mf1GetGen1aMode extends _GetBool {
  const Mf1GetGen1aMode();
  @override
  int get id => 4010;
}

final class Mf1SetGen1aMode extends _SetBool {
  const Mf1SetGen1aMode(super.value);
  @override
  int get id => 4011;
}

final class Mf1GetGen2Mode extends _GetBool {
  const Mf1GetGen2Mode();
  @override
  int get id => 4012;
}

final class Mf1SetGen2Mode extends _SetBool {
  const Mf1SetGen2Mode(super.value);
  @override
  int get id => 4013;
}

final class Mf1GetBlockAntiCollMode extends _GetBool {
  const Mf1GetBlockAntiCollMode();
  @override
  int get id => 4014;
}

final class Mf1SetBlockAntiCollMode extends _SetBool {
  const Mf1SetBlockAntiCollMode(super.value);
  @override
  int get id => 4015;
}

final class Mf1GetWriteMode extends Command<Mf1WriteMode> {
  const Mf1GetWriteMode();
  @override
  int get id => 4016;
  @override
  bool get idempotent => true;
  @override
  Mf1WriteMode decode(Uint8List data) =>
      Mf1WriteMode.fromCode(ByteReader(data).u8());
}

final class Mf1SetWriteMode extends VoidCommand {
  const Mf1SetWriteMode(this.mode);
  final Mf1WriteMode mode;
  @override
  int get id => 4017;
  @override
  Uint8List encode() => ByteWriter().u8(mode.code).toBytes();
}

final class Hf14aGetAntiCollData extends Command<Hf14aTag> {
  const Hf14aGetAntiCollData();
  @override
  int get id => 4018;
  @override
  bool get idempotent => true;
  @override
  Hf14aTag decode(Uint8List data) {
    final r = ByteReader(data);
    final uid = r.bytes(r.u8());
    final atqa = r.bytes(2);
    final sak = r.u8();
    final ats = r.bytes(r.u8());
    return Hf14aTag(uid: uid, atqa: atqa, sak: sak, ats: ats);
  }
}

final class Mf0NtagGetUidMagicMode extends _GetBool {
  const Mf0NtagGetUidMagicMode();
  @override
  int get id => 4019;
}

final class Mf0NtagSetUidMagicMode extends _SetBool {
  const Mf0NtagSetUidMagicMode(super.value);
  @override
  int get id => 4020;
}

final class Mf0NtagReadEmuPageData extends Command<Uint8List> {
  const Mf0NtagReadEmuPageData(this.startPage, this.count);
  final int startPage;
  final int count;
  @override
  int get id => 4021;
  @override
  bool get idempotent => true;
  @override
  Uint8List encode() => ByteWriter().u8(startPage).u8(count).toBytes();
  @override
  Uint8List decode(Uint8List data) => ByteReader(data).bytes(count * 4);
}

final class Mf0NtagWriteEmuPageData extends VoidCommand {
  Mf0NtagWriteEmuPageData(this.startPage, this.data) {
    if (data.isEmpty || data.length % 4 != 0) {
      throw ArgumentError.value(
        data.length,
        'data',
        'must be a multiple of 4 bytes',
      );
    }
  }
  final int startPage;
  final Uint8List data;
  @override
  int get id => 4022;
  @override
  Uint8List encode() =>
      ByteWriter().u8(startPage).u8(data.length ~/ 4).bytes(data).toBytes();
}

final class Mf0NtagGetPageCount extends Command<int> {
  const Mf0NtagGetPageCount();
  @override
  int get id => 4030;
  @override
  bool get idempotent => true;
  @override
  int decode(Uint8List data) => ByteReader(data).u8();
}

// Commands 4023-4029 and 4031-4044 stay reachable through RawCommand and are
// hardware-validate; per docs/research/chameleon-protocol.md:
//
// | 4023/4024 | MF0_NTAG VERSION_DATA get/set   | 8 bytes |
// | 4025/4026 | MF0_NTAG SIGNATURE get/set      | 32 bytes |
// | 4027/4028 | MF0_NTAG COUNTER get/set        | counter payload |
// | 4029      | MF0_NTAG RESET_AUTH_CNT         | no payload |
// | 4031/4032 | MF0_NTAG WRITE_MODE get/set     | write mode byte |
// | 4033-4037 | MF0_NTAG detection/config       | see wire doc |
// | 4038/4039 | MF1 FIELD_OFF_DO_RESET get/set  | see wire doc |
// | 4040/4041 | MF1 PRNG_TYPE get/set           | see wire doc |
// | 4042-4044 | SEOS read/write emu data/keys   | undocumented (2.2.0) |
