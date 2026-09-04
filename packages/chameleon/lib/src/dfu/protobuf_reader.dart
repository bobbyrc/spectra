import 'dart:typed_data';

import '../protocol/errors.dart';

/// Minimal protobuf wire-format reader: enough for Nordic's dfu-cc.proto.
///
/// Every out-of-range read raises a [DfuError]; a truncated or hostile packet
/// must never surface as a raw `RangeError`.
final class ProtoReader {
  ProtoReader(this._d);
  final Uint8List _d;
  int _o = 0;

  bool get isAtEnd => _o >= _d.length;

  int readVarint() {
    var result = 0;
    var shift = 0;
    while (true) {
      if (_o >= _d.length) throw DfuError('truncated varint in init packet');
      final b = _d[_o++];
      result |= (b & 0x7F) << shift;
      if (b & 0x80 == 0) return result;
      shift += 7;
      if (shift > 63) throw DfuError('varint too long in init packet');
    }
  }

  (int, int) readTag() {
    final t = readVarint();
    return (t >> 3, t & 0x07);
  }

  Uint8List readBytes() {
    final n = readVarint();
    if (n < 0 || _o + n > _d.length) {
      throw DfuError('truncated bytes in init packet');
    }
    final out = Uint8List.fromList(_d.sublist(_o, _o + n));
    _o += n;
    return out;
  }

  /// Consumes the value of a field whose number we do not recognise.
  void skip(int wire) {
    switch (wire) {
      case 0:
        readVarint();
      case 1:
        _advance(8);
      case 2:
        readBytes();
      case 5:
        _advance(4);
      default:
        throw DfuError('unsupported wire type $wire');
    }
  }

  void _advance(int n) {
    if (_o + n > _d.length) throw DfuError('truncated field in init packet');
    _o += n;
  }
}
