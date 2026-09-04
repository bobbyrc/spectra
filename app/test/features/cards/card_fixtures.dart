/// The one shared MIFARE Classic 1K fixture for Phase 7's tests (ruling 8).
///
/// Built from the SDK's own [FakeMf1Card.classic1k] rather than hand-rolled
/// bytes, so a fixture is never merely "the right length": its UID, BCC and
/// (for [classic1kFilled]) sector trailers are exactly what
/// [MifareClassicFormat.validate] and a real card agree on.
library;

import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';

final Uint8List _uid = Uint8List.fromList(<int>[0xDE, 0xAD, 0xBE, 0xEF]);

/// A MIFARE Classic 1K dump with every sector trailer filled in: the
/// default transport key (`FF`×6) in key A and key B, and the default
/// access bits — the shape [FakeMf1Card.classic1k] presents a blank card
/// in, and what loading a fully-known card into a slot looks like.
Uint8List classic1kFilled({Uint8List? uid}) =>
    FakeMf1Card.classic1k(uid: uid ?? _uid).blocks;

/// A MIFARE Classic 1K dump as a *read* would carry it when its sector keys
/// were never recovered: the same UID and non-trailer data as
/// [classic1kFilled], but every sector trailer zeroed out — sixteen zero
/// bytes is never a real key or access-bits value, and is exactly what a
/// `CardReader` leaves behind for a sector it could not authenticate
/// (Phase 7 ruling 23).
Uint8List classic1kDataOnly({Uint8List? uid}) {
  final Uint8List blocks = Uint8List.fromList(classic1kFilled(uid: uid));
  final int sectors = MifareGeometry.sectorCount(TagType.mifare1k);
  for (int s = 0; s < sectors; s++) {
    final int trailerStart = MifareGeometry.trailerOf(s) * 16;
    blocks.fillRange(trailerStart, trailerStart + 16, 0);
  }
  return blocks;
}

/// A MIFARE Classic 1K dump as a real card's *read* actually carries it
/// (Phase 7 ruling 27): the same UID and non-trailer data as
/// [classic1kFilled], but every trailer's key A (the block's first six
/// bytes only) zeroed out, with key B and the access bits left as the real
/// recovered values. `ReaderFacade.mf1ReadDump`'s doc
/// (`packages/chameleon/lib/src/session/facades/reader.dart`) says a real
/// card never returns its keys, so this is what *every* trailer of an
/// actual read dump looks like — not [classic1kDataOnly]'s fully-zeroed
/// shape, which only a sector a read never authenticated leaves behind.
/// Both shapes must trip `write_target.dart`'s `unreadSectors`.
Uint8List classic1kKeyAZeroed({Uint8List? uid}) {
  final Uint8List blocks = Uint8List.fromList(classic1kFilled(uid: uid));
  final int sectors = MifareGeometry.sectorCount(TagType.mifare1k);
  for (int s = 0; s < sectors; s++) {
    final int trailerStart = MifareGeometry.trailerOf(s) * 16;
    blocks.fillRange(trailerStart, trailerStart + 6, 0);
  }
  return blocks;
}

/// An NTAG215 dump: 135 pages of four bytes, with a plausible page 0-2
/// header (the seven-byte UID and its two block-check bytes, then the
/// internal byte and the lock bytes) and a recognisable fill everywhere
/// else.
///
/// Length is what the load path actually checks — `expectedDumpLength`
/// resolves it through `DumpFormats.ultralightPageCount` — so this is built
/// from that same table rather than a literal 540, and a fixture that is
/// merely "long enough" can never sneak past.
Uint8List ntag215Pages() {
  final int pages = DumpFormats.ultralightPageCount(TagType.ntag215);
  final Uint8List bytes = Uint8List(pages * 4);
  bytes.setRange(0, 9, <int>[
    0x04, 0x11, 0x22, // UID bytes 0-2
    0x33, // BCC0
    0x44, 0x55, 0x66, 0x77, // UID bytes 3-6
    0x88, // BCC1
  ]);
  for (int page = 4; page < pages; page++) {
    bytes.fillRange(page * 4, page * 4 + 4, 0xA5);
  }
  return bytes;
}
