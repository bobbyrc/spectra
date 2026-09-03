import 'dart:typed_data';

import '../model/models.dart';

/// What one pass of `ReaderFacade.mf1ReadDump` got off a card.
///
/// [blocks] is always the card's full length, so block *n* is always at
/// `n * 16`; blocks that could not be read are left zero and marked false in
/// [readMask]. A partial dump is a normal outcome (a sector whose key is not
/// in the dictionary), which is why this is a result rather than an error.
final class Mf1DumpReadResult {
  Mf1DumpReadResult({
    required this.blocks,
    required this.readMask,
    required this.keys,
  }) {
    if (blocks.length != readMask.length * 16) {
      throw ArgumentError.value(
        blocks.length,
        'blocks',
        'must be 16 bytes per mask entry',
      );
    }
  }

  /// The card's memory, 16 bytes per block.
  ///
  /// The key bytes inside a sector trailer are not authoritative: a real card
  /// answers a read of its trailer with the keys blanked out (and only the
  /// access bits meaningful), so use [keys] for the keys that actually work.
  final Uint8List blocks;

  /// One flag per block: true when that block was actually read.
  final List<bool> readMask;

  /// The keys found for each sector, in sector order.
  final List<SectorKeys> keys;

  int get blockCount => readMask.length;

  int get readBlockCount => readMask.where((b) => b).length;

  bool get isComplete => readMask.every((b) => b);
}
