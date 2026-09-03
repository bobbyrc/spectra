import 'dart:typed_data';

import 'package:chameleon/src/codec/frame.dart';
import 'package:test/test.dart';

void main() {
  test('encodes ENTER_BOOTLOADER exactly as documented', () {
    final bytes = Frame(command: 1010).encode();
    expect(bytes, [0x11, 0xEF, 0x03, 0xF2, 0x00, 0x00, 0x00, 0x00, 0x0B, 0x00]);
  });

  test('encodes payload with trailing LRC', () {
    final bytes = Frame(
      command: 1003,
      data: Uint8List.fromList([0x02]),
    ).encode();
    expect(bytes.length, 11);
    expect(bytes.sublist(2, 4), [0x03, 0xEB]);
    expect(bytes.sublist(6, 8), [0x00, 0x01]);
    expect(bytes[9], 0x02);
    expect(bytes[10], 0xFE);
  });

  test('frames with equal fields are equal', () {
    final a = Frame(command: 1, status: 2, data: Uint8List.fromList([3]));
    final b = Frame(command: 1, status: 2, data: Uint8List.fromList([3]));
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
