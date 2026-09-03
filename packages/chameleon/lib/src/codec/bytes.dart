import 'dart:convert';
import 'dart:typed_data';

import '../protocol/errors.dart';

/// Sequential big-endian reader. Short reads throw [MalformedResponse].
final class ByteReader {
  ByteReader(this._data);
  final Uint8List _data;
  int _offset = 0;

  int get remaining => _data.length - _offset;
  bool get isAtEnd => remaining == 0;

  int u8() {
    _need(1);
    return _data[_offset++];
  }

  int u16() {
    _need(2);
    final v = (_data[_offset] << 8) | _data[_offset + 1];
    _offset += 2;
    return v;
  }

  int u32() {
    _need(4);
    final v =
        (_data[_offset] << 24) |
        (_data[_offset + 1] << 16) |
        (_data[_offset + 2] << 8) |
        _data[_offset + 3];
    _offset += 4;
    return v;
  }

  Uint8List bytes(int n) {
    _need(n);
    final out = Uint8List.fromList(_data.sublist(_offset, _offset + n));
    _offset += n;
    return out;
  }

  Uint8List rest() => bytes(remaining);

  String utf8String(int n) => utf8.decode(bytes(n), allowMalformed: true);

  void _need(int n) {
    if (remaining < n) {
      throw MalformedResponse('needed $n byte(s), had $remaining');
    }
  }
}

/// Chainable big-endian writer.
final class ByteWriter {
  final BytesBuilder _b = BytesBuilder(copy: false);

  ByteWriter u8(int v) {
    _b.addByte(v & 0xFF);
    return this;
  }

  ByteWriter u16(int v) => u8(v >> 8).u8(v);

  ByteWriter u32(int v) => u16(v >> 16).u16(v);

  ByteWriter bytes(List<int> v) {
    _b.add(v);
    return this;
  }

  ByteWriter utf8String(String s) => bytes(utf8.encode(s));

  Uint8List toBytes() => _b.toBytes();
}
