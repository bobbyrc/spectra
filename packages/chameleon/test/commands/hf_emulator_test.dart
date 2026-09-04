import 'dart:typed_data';

import 'package:chameleon/src/codec/frame.dart';
import 'package:chameleon/src/commands/hf_emulator.dart';
import 'package:chameleon/src/model/enums.dart';
import 'package:test/test.dart';

Uint8List b(List<int> l) => Uint8List.fromList(l);
Frame ok(int cmd, List<int> data) =>
    Frame(command: cmd, status: 0x68, data: b(data));

void main() {
  test('Mf1WriteEmuBlockData encodes start block then 16-byte blocks', () {
    final c = Mf1WriteEmuBlockData(4, Uint8List(32));
    expect(c.encode().length, 33);
    expect(c.encode()[0], 4);
    expect(
      () => Mf1WriteEmuBlockData(0, Uint8List(20)).encode(),
      throwsArgumentError,
    );
  });

  test('Mf1ReadEmuBlockData caps count at 32', () {
    expect(const Mf1ReadEmuBlockData(0, 32).encode(), [0, 32]);
    expect(
      () => const Mf1ReadEmuBlockData(0, 33).encode(),
      throwsArgumentError,
    );
    expect(
      const Mf1ReadEmuBlockData(
        0,
        1,
      ).parseResponse(ok(4008, List.filled(16, 9))).length,
      16,
    );
  });

  test('Hf14aSetAntiCollData and GetAntiCollData round-trip', () {
    final c = Hf14aSetAntiCollData(
      uid: b([1, 2, 3, 4]),
      atqa: b([0x00, 0x04]),
      sak: 0x08,
      ats: b([]),
    );
    expect(c.encode(), [4, 1, 2, 3, 4, 0x00, 0x04, 0x08, 0]);
    final t = const Hf14aGetAntiCollData().parseResponse(ok(4018, c.encode()));
    expect(t.uidHex, '01020304');
    expect(t.sak, 0x08);
  });

  test('Mf1GetEmulatorConfig decodes five flags', () {
    final cfg = const Mf1GetEmulatorConfig().parseResponse(
      ok(4009, [1, 0, 1, 0, 3]),
    );
    expect(cfg.detectionEnabled, isTrue);
    expect(cfg.gen1a, isFalse);
    expect(cfg.gen2, isTrue);
    expect(cfg.writeMode, Mf1WriteMode.shadow);
  });

  test('detection count and log', () {
    expect(
      const Mf1GetDetectionCount().parseResponse(ok(4005, [0, 0, 0, 2])),
      2,
    );
    final entry = [
      3, 0x03, // block 3, key B, nested
      1, 2, 3, 4, // uid
      0xAA, 0xBB, 0xCC, 0xDD, // nt
      0x11, 0x22, 0x33, 0x44, // nr
      0x55, 0x66, 0x77, 0x88, // ar
    ];
    final log = const Mf1GetDetectionLog(0)
        .parseResponse(ok(4006, [...entry, ...entry]));
    expect(log.length, 2);
    expect(log[0].block, 3);
    expect(log[0].keyType, KeyType.b);
    expect(log[0].isNested, isTrue);
    expect(log[0].nt, 0xAABBCCDD);
    expect(const Mf1GetDetectionLog(7).encode(), [0, 0, 0, 7]);
  });

  test('boolean getters and setters', () {
    expect(const Mf1GetGen1aMode().parseResponse(ok(4010, [1])), isTrue);
    expect(const Mf1SetGen1aMode(true).encode(), [1]);
    expect(const Mf1SetWriteMode(Mf1WriteMode.deceive).encode(), [2]);
    expect(
      const Mf1GetWriteMode().parseResponse(ok(4016, [4])),
      Mf1WriteMode.shadowRequest,
    );
  });

  test('ultralight page commands', () {
    expect(const Mf0NtagReadEmuPageData(4, 2).encode(), [4, 2]);
    expect(Mf0NtagWriteEmuPageData(4, Uint8List(8)).encode().length, 10);
    expect(
      () => Mf0NtagWriteEmuPageData(4, Uint8List(5)).encode(),
      throwsArgumentError,
    );
    expect(const Mf0NtagGetPageCount().parseResponse(ok(4030, [135])), 135);
  });
}
