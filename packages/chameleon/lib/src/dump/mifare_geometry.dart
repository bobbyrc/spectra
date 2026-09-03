import '../model/enums.dart';

/// MIFARE Classic block and sector geometry, in one place.
///
/// Every layout below 4K is a prefix of the 4K layout: sectors 0-31 are four
/// blocks each, sectors 32-39 are sixteen. So the type only fixes how many
/// sectors exist, and the per-sector helpers need no type at all.
///
/// | type | sectors | blocks |
/// | ---- | ------- | ------ |
/// | Mini | 5       | 20     |
/// | 1K   | 16      | 64     |
/// | 2K   | 32      | 128    |
/// | 4K   | 40      | 256    |
abstract final class MifareGeometry {
  /// Sectors of four blocks; above this a sector is [_largeSectorBlocks].
  static const int _smallSectors = 32;
  static const int _smallSectorBlocks = 4;
  static const int _largeSectorBlocks = 16;

  /// The most sectors any MIFARE Classic has (4K).
  static const int maxSectors = 40;

  /// The most blocks any MIFARE Classic has (4K).
  static const int maxBlocks = 256;

  static const Map<TagType, int> _sectors = {
    TagType.mifareMini: 5,
    TagType.mifare1k: 16,
    TagType.mifare2k: 32,
    TagType.mifare4k: 40,
  };

  static bool isClassic(TagType t) => _sectors.containsKey(t);

  /// Sectors on a card of [t]. Throws [ArgumentError] for anything that is
  /// not a MIFARE Classic type.
  static int sectorCount(TagType t) {
    final n = _sectors[t];
    if (n == null) {
      throw ArgumentError.value(t, 'type', 'not MIFARE Classic');
    }
    return n;
  }

  /// Blocks on a card of [t], trailers included.
  static int blockCount(TagType t) {
    final n = sectorCount(t);
    return firstBlockOf(n - 1) + blocksInSector(n - 1);
  }

  static int blocksInSector(int sector) => _checkSector(sector) < _smallSectors
      ? _smallSectorBlocks
      : _largeSectorBlocks;

  static int firstBlockOf(int sector) => _checkSector(sector) < _smallSectors
      ? sector * _smallSectorBlocks
      : _smallSectors * _smallSectorBlocks +
            (sector - _smallSectors) * _largeSectorBlocks;

  /// The sector trailer of [sector]: its last block, holding both keys and
  /// the access bits.
  static int trailerOf(int sector) =>
      firstBlockOf(sector) + blocksInSector(sector) - 1;

  /// The sector [block] belongs to; the inverse of [firstBlockOf].
  static int sectorOf(int block) {
    const boundary = _smallSectors * _smallSectorBlocks;
    if (block < 0 || block >= maxBlocks) {
      throw ArgumentError.value(block, 'block', 'must be 0..${maxBlocks - 1}');
    }
    return block < boundary
        ? block ~/ _smallSectorBlocks
        : _smallSectors + (block - boundary) ~/ _largeSectorBlocks;
  }

  static int _checkSector(int sector) {
    if (sector < 0 || sector >= maxSectors) {
      throw ArgumentError.value(
        sector,
        'sector',
        'must be 0..${maxSectors - 1}',
      );
    }
    return sector;
  }
}
