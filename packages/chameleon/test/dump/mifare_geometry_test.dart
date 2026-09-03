import 'package:chameleon/src/dump/mifare_geometry.dart';
import 'package:chameleon/src/model/enums.dart';
import 'package:test/test.dart';

void main() {
  test('sector counts per MIFARE Classic type', () {
    expect(MifareGeometry.sectorCount(TagType.mifareMini), 5);
    expect(MifareGeometry.sectorCount(TagType.mifare1k), 16);
    expect(MifareGeometry.sectorCount(TagType.mifare2k), 32);
    expect(MifareGeometry.sectorCount(TagType.mifare4k), 40);
  });

  test('block counts per MIFARE Classic type', () {
    expect(MifareGeometry.blockCount(TagType.mifareMini), 20);
    expect(MifareGeometry.blockCount(TagType.mifare1k), 64);
    expect(MifareGeometry.blockCount(TagType.mifare2k), 128);
    expect(MifareGeometry.blockCount(TagType.mifare4k), 256);
  });

  test('a non-Classic type has no geometry', () {
    expect(
      () => MifareGeometry.sectorCount(TagType.ntag215),
      throwsArgumentError,
    );
    expect(
      () => MifareGeometry.blockCount(TagType.em410x),
      throwsArgumentError,
    );
    expect(MifareGeometry.isClassic(TagType.mifare4k), isTrue);
    expect(MifareGeometry.isClassic(TagType.ntag215), isFalse);
  });

  test('sectors are four blocks below 32 and sixteen above', () {
    expect(MifareGeometry.blocksInSector(0), 4);
    expect(MifareGeometry.blocksInSector(31), 4);
    expect(MifareGeometry.blocksInSector(32), 16);
    expect(MifareGeometry.blocksInSector(39), 16);
  });

  test('first block of each sector', () {
    expect(MifareGeometry.firstBlockOf(0), 0);
    expect(MifareGeometry.firstBlockOf(1), 4);
    expect(MifareGeometry.firstBlockOf(31), 124);
    expect(MifareGeometry.firstBlockOf(32), 128);
    expect(MifareGeometry.firstBlockOf(39), 240);
  });

  test('sectorOf inverts firstBlockOf across the whole 4K', () {
    for (var s = 0; s < 40; s++) {
      final first = MifareGeometry.firstBlockOf(s);
      for (var b = first; b < first + MifareGeometry.blocksInSector(s); b++) {
        expect(MifareGeometry.sectorOf(b), s, reason: 'block $b');
      }
    }
    expect(MifareGeometry.sectorOf(255), 39);
  });

  test('trailers are the last block of their sector', () {
    expect(MifareGeometry.trailerOf(0), 3);
    expect(MifareGeometry.trailerOf(15), 63);
    expect(MifareGeometry.trailerOf(39), 255);
  });

  test('out-of-range sectors and blocks are rejected', () {
    expect(() => MifareGeometry.firstBlockOf(-1), throwsArgumentError);
    expect(() => MifareGeometry.firstBlockOf(40), throwsArgumentError);
    expect(() => MifareGeometry.blocksInSector(40), throwsArgumentError);
    expect(() => MifareGeometry.trailerOf(40), throwsArgumentError);
    expect(() => MifareGeometry.sectorOf(-1), throwsArgumentError);
    expect(() => MifareGeometry.sectorOf(256), throwsArgumentError);
  });
}
