import 'dart:typed_data';

import 'package:chameleon_flutter/src/ble/ble_chunking.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _bytes(int n) =>
    Uint8List.fromList(List<int>.generate(n, (i) => i & 0xff));

void main() {
  group('chunked', () {
    test('splits into full chunks plus a remainder', () {
      final chunks = chunked(_bytes(50), 20).toList();
      expect(chunks.map((c) => c.length).toList(), <int>[20, 20, 10]);
      expect(chunks.expand((c) => c).toList(), _bytes(50).toList());
    });

    test('an exact multiple produces no empty trailing chunk', () {
      expect(chunked(_bytes(40), 20).map((c) => c.length).toList(), <int>[
        20,
        20,
      ]);
    });

    test('a payload smaller than the chunk size is one chunk', () {
      final chunks = chunked(_bytes(7), 20).toList();
      expect(chunks, hasLength(1));
      expect(chunks.single, _bytes(7));
    });

    test('empty input yields nothing to write', () {
      expect(chunked(Uint8List(0), 20), isEmpty);
    });

    test('chunks are views that reflect the source, not copies', () {
      final source = _bytes(4);
      final chunk = chunked(source, 2).last;
      source[3] = 0xaa;
      expect(chunk[1], 0xaa);
    });

    test('a non-positive size is a programming error', () {
      expect(() => chunked(_bytes(4), 0).toList(), throwsArgumentError);
      expect(() => chunked(_bytes(4), -1).toList(), throwsArgumentError);
    });
  });

  group('mtuWriteLength', () {
    test('subtracts the ATT overhead from a reported MTU', () {
      expect(mtuWriteLength(247, floor: 20), 244);
      expect(mtuWriteLength(185, floor: 20), 182);
    });

    test('falls back to the floor when the platform reports nothing', () {
      expect(mtuWriteLength(null, floor: 20), 20);
    });

    test('never returns less than the floor', () {
      expect(mtuWriteLength(23, floor: 20), 20);
      expect(mtuWriteLength(0, floor: 20), 20);
      expect(mtuWriteLength(-5, floor: 20), 20);
    });

    test('an unusual ATT overhead is honoured', () {
      expect(mtuWriteLength(247, floor: 20, attOverhead: 4), 243);
    });
  });
}
