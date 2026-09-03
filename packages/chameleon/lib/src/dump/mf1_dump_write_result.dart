import '../model/models.dart';

/// What one `ReaderFacade.mf1WriteDump` run put onto the card.
///
/// Two masks, not one: a block can be *skipped* (block 0, and the sector
/// trailers unless the caller asked for them) or *attempted and refused*
/// (no key for that sector, or a card that would not take the write). Only
/// the second is a failure, so completeness is measured against what was
/// attempted rather than against the whole card.
final class Mf1DumpWriteResult {
  Mf1DumpWriteResult({
    required this.writeMask,
    required this.attemptMask,
    required this.keys,
  });

  /// One entry per block of the card, true when that block was written.
  final List<bool> writeMask;

  /// One entry per block, true when a write was attempted for it.
  final List<bool> attemptMask;

  /// The key found for each sector, in the shape `mf1ReadDump` reports.
  final List<SectorKeys> keys;

  int get blockCount => writeMask.length;
  int get writtenBlockCount => writeMask.where((bool b) => b).length;
  int get attemptedBlockCount => attemptMask.where((bool b) => b).length;
  int get failedBlockCount => attemptedBlockCount - writtenBlockCount;

  /// Every block that was attempted was written.
  bool get isComplete => failedBlockCount == 0;
}
