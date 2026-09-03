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
