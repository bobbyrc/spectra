import 'dart:typed_data';

import '../codec/bytes.dart';
import '../protocol/command.dart';

abstract base class _FixedScan extends Command<Uint8List> {
  const _FixedScan();
  int get length;
  @override
  bool get idempotent => true;
  @override
  Uint8List decode(Uint8List data) => ByteReader(data).bytes(length);
}

final class Em410xScan extends _FixedScan {
  const Em410xScan();
  @override
  int get id => 3000;
  @override
  int get length => 5;
}

final class Em410xWriteToT55xx extends VoidCommand {
  Em410xWriteToT55xx({
    required this.cardId,
    required this.newKey,
    required this.oldKeys,
  }) {
    if (cardId.length != 5) {
      throw ArgumentError.value(cardId.length, 'cardId', 'must be 5 bytes');
    }
    if (newKey.length != 4) {
      throw ArgumentError.value(newKey.length, 'newKey', 'must be 4 bytes');
    }
    for (final k in oldKeys) {
      if (k.length != 4) {
        throw ArgumentError.value(k.length, 'oldKeys', 'each 4 bytes');
      }
    }
  }
  final Uint8List cardId;
  final Uint8List newKey;
  final List<Uint8List> oldKeys;
  @override
  int get id => 3001;
  @override
  Uint8List encode() {
    final w = ByteWriter().bytes(cardId).bytes(newKey);
    for (final k in oldKeys) {
      w.bytes(k);
    }
    return w.toBytes();
  }
}

final class HidProxScan extends _FixedScan {
  const HidProxScan();
  @override
  int get id => 3002;
  @override
  int get length => 13;
}

final class VikingScan extends _FixedScan {
  const VikingScan();
  @override
  int get id => 3004;
  @override
  int get length => 4;
}

final class PacScan extends _FixedScan {
  const PacScan();
  @override
  int get id => 3014;
  @override
  int get length => 8;
}
