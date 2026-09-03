import 'dart:typed_data';

import '../model/enums.dart';

/// A card the fake reader can "see". Present one with `FakeFirmware.present`.
sealed class FakeCard {
  const FakeCard();
}

/// A MIFARE Classic card: blocks plus a key per sector and key type.
final class FakeMf1Card extends FakeCard {
  FakeMf1Card({
    required this.uid,
    required this.atqa,
    required this.sak,
    required this.ats,
    required this.blocks,
    required this.keys,
    this.prng = PrngType.weak,
  });

  /// A 1K card with FF FF FF FF FF FF on every sector and the UID in block 0.
  factory FakeMf1Card.classic1k({required Uint8List uid}) {
    final blocks = Uint8List(64 * 16);
    blocks.setRange(0, uid.length, uid);
    blocks[uid.length] = uid.fold<int>(0, (a, byte) => a ^ byte); // BCC
    blocks[5] = 0x08;
    blocks[6] = 0x04;
    blocks[7] = 0x00;
    final keys = <String, Uint8List>{};
    for (var s = 0; s < 16; s++) {
      keys[keyId(s, KeyType.a)] = defaultKey;
      keys[keyId(s, KeyType.b)] = defaultKey;
      final trailer = s * 4 + 3;
      blocks.setRange(trailer * 16, trailer * 16 + 6, defaultKey);
      blocks.setRange(trailer * 16 + 6, trailer * 16 + 10, const [
        0xFF,
        0x07,
        0x80,
        0x69,
      ]);
      blocks.setRange(trailer * 16 + 10, trailer * 16 + 16, defaultKey);
    }
    return FakeMf1Card(
      uid: uid,
      atqa: Uint8List.fromList([0x00, 0x04]),
      sak: 0x08,
      ats: Uint8List(0),
      blocks: blocks,
      keys: keys,
    );
  }

  /// The transport key every blank MIFARE Classic ships with.
  static final Uint8List defaultKey = Uint8List.fromList(List.filled(6, 0xFF));

  /// Key map id for one sector and key type, e.g. `12B`.
  static String keyId(int sector, KeyType t) =>
      '$sector${t == KeyType.a ? 'A' : 'B'}';

  final Uint8List uid;
  final Uint8List atqa;
  final int sak;
  final Uint8List ats;
  final Uint8List blocks;
  final Map<String, Uint8List> keys;
  final PrngType prng;

  int get blockCount => blocks.length ~/ 16;

  /// Sectors are four blocks up to block 128, sixteen blocks above it.
  static int sectorOf(int block) =>
      block < 128 ? block ~/ 4 : 32 + (block - 128) ~/ 16;

  bool authenticates(int block, KeyType type, Uint8List key) {
    if (block >= blockCount) return false;
    final expected = keys[keyId(sectorOf(block), type)];
    if (expected == null) return false;
    for (var i = 0; i < 6; i++) {
      if (expected[i] != key[i]) return false;
    }
    return true;
  }
}

/// An Ultralight/NTAG card: four-byte pages.
final class FakeUltralightCard extends FakeCard {
  FakeUltralightCard({required this.uid, required this.pages});
  final Uint8List uid;
  final Uint8List pages;
}

/// An LF card answering one scan command id (3000 EM410X, 3002 HID Prox,
/// 3004 Viking, 3014 PAC) with fixed id bytes.
final class FakeLfCard extends FakeCard {
  const FakeLfCard(this.scanCommandId, this.idBytes);
  final int scanCommandId;
  final Uint8List idBytes;
}
