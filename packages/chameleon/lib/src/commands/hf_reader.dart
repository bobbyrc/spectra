import 'dart:typed_data';

import '../codec/bytes.dart';
import '../model/enums.dart';
import '../model/models.dart';
import '../protocol/command.dart';

const Duration slowReaderTimeout = Duration(seconds: 30);
const Duration keyCheckTimeout = Duration(seconds: 60);

Uint8List _requireLength(Uint8List v, int n, String name) {
  if (v.length != n) {
    throw ArgumentError.value(v.length, name, 'must be $n bytes');
  }
  return v;
}

final class Hf14aScan extends Command<List<Hf14aTag>> {
  const Hf14aScan();
  @override
  int get id => 2000;
  @override
  bool get idempotent => true;
  @override
  List<Hf14aTag> decode(Uint8List data) {
    final r = ByteReader(data);
    final tags = <Hf14aTag>[];
    while (!r.isAtEnd) {
      final uid = r.bytes(r.u8());
      final atqa = r.bytes(2);
      final sak = r.u8();
      final ats = r.bytes(r.u8());
      tags.add(Hf14aTag(uid: uid, atqa: atqa, sak: sak, ats: ats));
    }
    return tags;
  }
}

/// Success status means the tag supports MIFARE Classic authentication.
final class Mf1DetectSupport extends VoidCommand {
  const Mf1DetectSupport();
  @override
  int get id => 2001;
}

final class Mf1DetectPrng extends Command<PrngType> {
  const Mf1DetectPrng();
  @override
  int get id => 2002;
  @override
  PrngType decode(Uint8List data) => PrngType.fromCode(ByteReader(data).u8());
}

final class Mf1AuthOneKeyBlock extends VoidCommand {
  Mf1AuthOneKeyBlock(this.keyType, this.block, Uint8List key)
    : key = _requireLength(key, 6, 'key');
  final KeyType keyType;
  final int block;
  final Uint8List key;
  @override
  int get id => 2007;
  @override
  Uint8List encode() =>
      ByteWriter().u8(keyType.code).u8(block).bytes(key).toBytes();
}

final class Mf1ReadOneBlock extends Command<Uint8List> {
  Mf1ReadOneBlock(this.keyType, this.block, Uint8List key)
    : key = _requireLength(key, 6, 'key');
  final KeyType keyType;
  final int block;
  final Uint8List key;
  @override
  int get id => 2008;
  @override
  bool get idempotent => true;
  @override
  Uint8List encode() =>
      ByteWriter().u8(keyType.code).u8(block).bytes(key).toBytes();
  @override
  Uint8List decode(Uint8List data) => ByteReader(data).bytes(16);
}

final class Mf1WriteOneBlock extends VoidCommand {
  Mf1WriteOneBlock(this.keyType, this.block, Uint8List key, Uint8List data)
    : key = _requireLength(key, 6, 'key'),
      data = _requireLength(data, 16, 'data');
  final KeyType keyType;
  final int block;
  final Uint8List key;
  final Uint8List data;
  @override
  int get id => 2009;
  @override
  Uint8List encode() =>
      ByteWriter().u8(keyType.code).u8(block).bytes(key).bytes(data).toBytes();
}

/// hardware-validate: option bit meanings follow the firmware's hf14a_raw.
final class Hf14aRaw extends Command<Uint8List> {
  const Hf14aRaw({
    required this.options,
    required this.timeoutMs,
    required this.bitLength,
    required this.data,
  });
  final int options;
  final int timeoutMs;
  final int bitLength;
  final Uint8List data;
  @override
  int get id => 2010;
  @override
  Uint8List encode() => ByteWriter()
      .u8(options)
      .u16(timeoutMs)
      .u16(bitLength)
      .bytes(data)
      .toBytes();
  @override
  Uint8List decode(Uint8List data) => data;
}

/// Bit i of the 10-byte mask (MSB first) is sector i ~/ 2, key A when i is
/// even and key B when odd. hardware-validate.
final class Mf1CheckKeysOfSectors extends Command<Mf1KeyCheckResult> {
  Mf1CheckKeysOfSectors({
    required this.sectors,
    required this.keyTypes,
    required List<Uint8List> keys,
  }) : keys = List.unmodifiable(keys) {
    if (keys.length > maxKeys) {
      throw ArgumentError.value(keys.length, 'keys', 'at most $maxKeys keys');
    }
    for (final k in keys) {
      _requireLength(k, 6, 'key');
    }
  }

  /// The most candidate keys one request can carry: the mask plus 83 keys
  /// is the largest payload the firmware accepts.
  static const int maxKeys = 83;

  /// This command's id, as a constant, so callers can ask the device's
  /// capabilities about it without building a request first.
  static const int commandId = 2012;

  final Set<int> sectors;
  final Set<KeyType> keyTypes;
  final List<Uint8List> keys;
  @override
  int get id => commandId;
  @override
  Duration get timeout => keyCheckTimeout;

  static int bitIndex(int sector, KeyType t) =>
      sector * 2 + (t == KeyType.a ? 0 : 1);

  @override
  Uint8List encode() {
    final mask = Uint8List(10);
    for (final s in sectors) {
      for (final t in keyTypes) {
        final i = bitIndex(s, t);
        mask[i ~/ 8] |= 0x80 >> (i % 8);
      }
    }
    final w = ByteWriter().bytes(mask);
    for (final k in keys) {
      w.bytes(k);
    }
    return w.toBytes();
  }

  @override
  Mf1KeyCheckResult decode(Uint8List data) {
    final r = ByteReader(data);
    final found = r.bytes(10);
    bool isSet(int i) => (found[i ~/ 8] & (0x80 >> (i % 8))) != 0;
    final out = <SectorKeys>[];
    for (var s = 0; s < 40; s++) {
      final a = r.bytes(6);
      final b = r.bytes(6);
      out.add(
        SectorKeys(
          sector: s,
          keyA: isSet(bitIndex(s, KeyType.a)) ? a : null,
          keyB: isSet(bitIndex(s, KeyType.b)) ? b : null,
        ),
      );
    }
    return Mf1KeyCheckResult(out);
  }
}
