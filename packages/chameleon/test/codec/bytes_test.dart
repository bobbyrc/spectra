import 'dart:typed_data';

import 'package:chameleon/src/codec/bytes.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:test/test.dart';

void main() {
  test('reads big-endian integers in order', () {
    final r = ByteReader(
      Uint8List.fromList([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]),
    );
    expect(r.u8(), 0x01);
    expect(r.u16(), 0x0203);
    expect(r.u32(), 0x04050607);
    expect(r.isAtEnd, isTrue);
  });

  test('short read throws MalformedResponse', () {
    final r = ByteReader(Uint8List.fromList([0x01]));
    expect(() => r.u16(), throwsA(isA<MalformedResponse>()));
  });

  test('writer round-trips', () {
    final b = ByteWriter()
        .u8(1)
        .u16(0x0203)
        .u32(0x04050607)
        .utf8String('hi')
        .toBytes();
    expect(b, [1, 2, 3, 4, 5, 6, 7, 0x68, 0x69]);
  });
}
