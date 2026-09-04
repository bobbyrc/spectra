import 'dart:typed_data';

import 'package:chameleon/src/dump/dump_format.dart';
import 'package:chameleon/src/dump/em410x.dart';
import 'package:chameleon/src/dump/mifare_classic.dart';
import 'package:chameleon/src/dump/ultralight.dart';
import 'package:chameleon/src/fake/fake_card.dart';
import 'package:chameleon/src/model/enums.dart';
import 'package:test/test.dart';

Uint8List b(List<int> l) => Uint8List.fromList(l);

void main() {
  test('registry finds a format per family', () {
    expect(DumpFormats.forType(TagType.mifare1k), isA<MifareClassicFormat>());
    expect(DumpFormats.forType(TagType.ntag215), isA<UltralightFormat>());
    expect(DumpFormats.forType(TagType.em410x), isA<Em410xFormat>());
    expect(DumpFormats.forType(TagType.seos), isNull);
  });

  test('MIFARE Classic dump exposes geometry and keys', () {
    final card = FakeMf1Card.classic1k(uid: b([1, 2, 3, 4]));
    final dump =
        DumpFormats.parse(card.blocks, TagType.mifare1k) as MifareClassicDump;
    expect(dump.blockCount, 64);
    expect(dump.sectorCount, 16);
    expect(dump.uid, [1, 2, 3, 4]);
    expect(dump.keyA(0), FakeMf1Card.defaultKey);
    expect(dump.keyB(15), FakeMf1Card.defaultKey);
    expect(dump.accessBits(0), [0xFF, 0x07, 0x80, 0x69]);
    expect(dump.toBytes(), card.blocks);
    expect(const MifareClassicFormat().validate(dump), isEmpty);
    final fields = const MifareClassicFormat().describe(dump);
    expect(
      fields.any((f) => f.label == 'UID' && f.value == '01020304'),
      isTrue,
    );
  });

  test('MIFARE Classic validation flags wrong length and bad BCC', () {
    final bad = MifareClassicDump(TagType.mifare1k, Uint8List(63 * 16));
    expect(
      const MifareClassicFormat().validate(bad),
      contains(contains('length')),
    );
    final card = FakeMf1Card.classic1k(uid: b([1, 2, 3, 4]));
    card.blocks[4] ^= 0xFF;
    final dump = MifareClassicDump(TagType.mifare1k, card.blocks);
    expect(
      const MifareClassicFormat().validate(dump),
      contains(contains('BCC')),
    );
  });

  test('Ultralight dump reads the 7-byte UID from pages 0 and 1', () {
    final pages = Uint8List(135 * 4);
    pages.setRange(0, 3, [0x04, 0xAA, 0xBB]);
    pages.setRange(4, 8, [0xCC, 0xDD, 0xEE, 0xFF]);
    final dump = DumpFormats.parse(pages, TagType.ntag215) as UltralightDump;
    expect(dump.pageCount, 135);
    expect(dump.uid, [0x04, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]);
    expect(const UltralightFormat().validate(dump), isEmpty);
    expect(
      const UltralightFormat().validate(
        UltralightDump(TagType.ntag213, Uint8List(8)),
      ),
      contains(contains('pages')),
    );
    expect(DumpFormats.ultralightPageCount(TagType.ntag216), 231);
  });

  test('EM410X dump is five bytes', () {
    final dump = DumpFormats.parse(
      b([0xDE, 0xAD, 0xBE, 0xEF, 0x01]),
      TagType.em410x,
    ) as Em410xDump;
    expect(dump.toBytes(), [0xDE, 0xAD, 0xBE, 0xEF, 0x01]);
    expect(const Em410xFormat().describe(dump).first.value, 'DEADBEEF01');
    expect(const Em410xFormat().validate(Em410xDump(b([1]))), isNotEmpty);
  });
}
