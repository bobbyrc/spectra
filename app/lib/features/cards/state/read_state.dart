import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';

import '../../../core/format/hex.dart';

/// What one read got off the card.
///
/// [bytes] is the dump in the layout the matching `DumpFormat` expects
/// (16 bytes per MIFARE Classic block, 4 per Ultralight page, the 5 id bytes
/// for EM410x), so saving is `SavedCard(bytes: result.bytes, …)` with no
/// re-encoding.
final class CardReadResult {
  const CardReadResult({
    required this.tagType,
    required this.bytes,
    required this.fields,
    this.readChunks,
    this.totalChunks,
    this.keysFound,
  });

  /// A tag that answered the anti-collision but whose memory this SDK cannot
  /// read: the identity is worth showing, but there is nothing to save.
  ///
  /// Ultralight is here today. `ReaderFacade` (spec 8.1) has no Ultralight
  /// read operation — `EmulatorFacade.readNtagPages` reads the *device's*
  /// emulation memory, not a card in the field — so a physical NTAG shows its
  /// UID and nothing more until that reader operation is added (spec 8.2's
  /// extension point: one command plus one facade method).
  factory CardReadResult.identity(Hf14aTag tag) => CardReadResult(
    tagType: TagType.hf14a4,
    bytes: Uint8List(0),
    fields: <DumpField>[
      DumpField('UID', toHex(tag.uid)),
      DumpField('ATQA', toHex(tag.atqa)),
      DumpField('SAK', toHex(<int>[tag.sak])),
      if (tag.ats.isNotEmpty) DumpField('ATS', toHex(tag.ats)),
    ],
  );

  final TagType tagType;
  final Uint8List bytes;

  /// Headline fields, from the SDK's `DumpFormat.describe` where there is a
  /// format and from the anti-collision answer otherwise. Labels are the
  /// SDK's technical field names, exempt from localization — the same
  /// exemption `core/format/tag_labels.dart`'s doc comment records for tag
  /// type product names (Phase 6 ruling 6).
  final List<DumpField> fields;

  /// Blocks or pages actually read, and how many the card has. Null for a
  /// read with no per-chunk notion (an LF id, an identity-only result).
  final int? readChunks;
  final int? totalChunks;

  /// Sectors a working key was found for, for the MIFARE Classic summary.
  final int? keysFound;

  /// Whether this result can go into the library: there is a dump, and the
  /// type has a `DumpFormat` to read it back with.
  bool get canSave => bytes.isNotEmpty && DumpFormats.forType(tagType) != null;

  /// True when some of the card could not be read — a sector whose key is
  /// not in the dictionary. A normal outcome, not an error (spec 3.5's
  /// `Mf1DumpReadResult` contract).
  bool get isPartial {
    final int? read = readChunks;
    final int? total = totalChunks;
    return read != null && total != null && read < total;
  }
}

/// The read screen's whole state. Deliberately without a `copyWith`: every
/// transition builds a complete new value, so there is no "unchanged versus
/// explicitly null" sentinel to get wrong.
final class ReadState {
  const ReadState({this.busy = false, this.progress, this.result, this.error});

  /// True from the first command until the operation ends, however it ends.
  final bool busy;

  /// A fraction of the sectors done, not the blocks: `ReaderFacade
  /// .mf1ReadDump`'s `onProgress(done, total)` counts sectors (16 for a
  /// MIFARE Classic 1K), while [CardReadResult.readChunks] and
  /// [CardReadResult.totalChunks] count blocks (64 for the same card) —
  /// both are correct, they just count different units (Phase 6 ruling 23).
  /// Null while scanning, before any sector has been attempted.
  final double? progress;

  final CardReadResult? result;

  /// The typed error the last read ended with, rendered through the spec 9
  /// catalog. Never a string.
  final Object? error;
}

/// The MIFARE Classic type a SAK byte names.
///
/// Bit 3 (0x08) is the "MIFARE Classic compliant" bit and bit 6 (0x40) plus
/// the cascade bit 0x04 carry UID-length and ISO14443-4 information that says
/// nothing about capacity, so the low nibble decides. Anything that is not
/// one of the five known values is [TagType.undefined]; the caller then falls
/// back on `detectMf1Support()` (see `read_controller.dart`).
TagType classicTypeForSak(int sak) => switch (sak & 0x1F) {
  0x09 => TagType.mifareMini,
  0x08 => TagType.mifare1k,
  0x19 => TagType.mifare2k,
  0x18 => TagType.mifare4k,
  _ => TagType.undefined,
};
