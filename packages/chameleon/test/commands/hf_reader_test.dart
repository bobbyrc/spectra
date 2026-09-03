import 'dart:typed_data';

import 'package:chameleon/src/codec/frame.dart';
import 'package:chameleon/src/commands/hf_reader.dart';
import 'package:chameleon/src/commands/raw.dart';
import 'package:chameleon/src/model/enums.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:test/test.dart';

Uint8List b(List<int> l) => Uint8List.fromList(l);
Frame hfOk(int cmd, List<int> data) =>
    Frame(command: cmd, status: 0x00, data: b(data));

final key = b([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);

void main() {
  test('Hf14aScan decodes two tags', () {
    final tags = const Hf14aScan().parseResponse(
      hfOk(2000, [
        4,
        1,
        2,
        3,
        4,
        0x00,
        0x04,
        0x08,
        0,
        7,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        0x00,
        0x44,
        0x00,
        2,
        0x75,
        0x77,
      ]),
    );
    expect(tags.length, 2);
    expect(tags[0].uidHex, '01020304');
    expect(tags[0].sak, 0x08);
    expect(tags[1].uid.length, 7);
    expect(tags[1].ats, [0x75, 0x77]);
  });

  test('Hf14aScan maps no-tag status to HfTagNotFound', () {
    expect(
      () => const Hf14aScan().parseResponse(Frame(command: 2000, status: 0x01)),
      throwsA(isA<HfTagNotFound>()),
    );
  });

  test('Mf1DetectPrng', () {
    expect(const Mf1DetectPrng().parseResponse(hfOk(2002, [1])), PrngType.weak);
  });

  test('Mf1AuthOneKeyBlock encodes type, block, key', () {
    expect(Mf1AuthOneKeyBlock(KeyType.a, 4, key).encode(), [0x60, 4, ...key]);
  });

  test('Mf1ReadOneBlock returns 16 bytes', () {
    final data = List<int>.generate(16, (i) => i);
    expect(
      Mf1ReadOneBlock(KeyType.b, 1, key).parseResponse(hfOk(2008, data)),
      data,
    );
    expect(Mf1ReadOneBlock(KeyType.b, 1, key).encode(), [0x61, 1, ...key]);
  });

  test('Mf1WriteOneBlock encodes 16 data bytes', () {
    final data = Uint8List(16);
    expect(Mf1WriteOneBlock(KeyType.a, 2, key, data).encode().length, 24);
    expect(
      () => Mf1WriteOneBlock(KeyType.a, 2, key, Uint8List(3)).encode(),
      throwsArgumentError,
    );
  });

  test('Hf14aRaw encodes options, timeout, bit length', () {
    final c = Hf14aRaw(
      options: 0x81,
      timeoutMs: 100,
      bitLength: 8,
      data: b([0x26]),
    );
    expect(c.encode(), [0x81, 0x00, 0x64, 0x00, 0x08, 0x26]);
  }, tags: ['hardware-validate']);

  test(
    'Mf1CheckKeysOfSectors encodes mask and keys and decodes found keys',
    () {
      final c = Mf1CheckKeysOfSectors(
        sectors: {0, 1},
        keyTypes: {KeyType.a},
        keys: [key],
      );
      final enc = c.encode();
      expect(enc.length, 10 + 6);
      expect(enc[0], 0xA0); // sector0 A, sector1 A -> bits 7 and 5
      final resp = List<int>.filled(490, 0)..[0] = 0x80;
      for (var i = 0; i < 6; i++) {
        resp[10 + i] = 0xAA;
      }
      final result = c.parseResponse(hfOk(2012, resp));
      expect(result.sectors.length, 40);
      expect(result.sectors[0].keyA, List.filled(6, 0xAA));
      expect(result.sectors[0].keyB, isNull);
      expect(c.timeout, greaterThan(const Duration(seconds: 10)));
    },
    tags: ['hardware-validate'],
  );

  test('RawCommand passes bytes through', () {
    final c = RawCommand(2100, Uint8List(0));
    expect(c.id, 2100);
    expect(c.parseResponse(hfOk(2100, [1, 2])), [1, 2]);
  });
}
