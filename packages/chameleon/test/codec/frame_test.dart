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

  test('constructor copies the data array', () {
    final source = Uint8List.fromList([1, 2, 3]);
    final frame = Frame(command: 1, data: source);
    final before = Frame(command: 1, data: Uint8List.fromList([1, 2, 3]));
    source[0] = 0xFF;
    expect(frame.data, [1, 2, 3]);
    expect(frame, before);
  });

  test('encode throws when data exceeds the max length', () {
    final frame = Frame(command: 1, data: Uint8List(4097));
    expect(() => frame.encode(), throwsArgumentError);
  });

  test('encode succeeds at exactly the max length', () {
    final bytes = Frame(command: 1, data: Uint8List(4096)).encode();
    expect(bytes.length, frameHeaderLength + 4096 + 1);
  });
}
