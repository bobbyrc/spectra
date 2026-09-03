import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/format/hex.dart';

void main() {
  group('toHex', () {
    test('is upper case with no separator by default', () {
      expect(toHex(<int>[0x0a, 0xff, 0x00]), '0AFF00');
    });

    test('honours a separator', () {
      expect(toHex(<int>[1, 2], separator: ' '), '01 02');
    });
  });

  group('parseHex', () {
    test('tolerates separators', () {
      expect(parseHex('AA:BB CC-DD_EE'), <int>[0xAA, 0xBB, 0xCC, 0xDD, 0xEE]);
    });

    test('rejects odd length and non-hex', () {
      expect(parseHex('ABC'), isNull);
      expect(parseHex('zz'), isNull);
    });
  });

  group('parseMifareKey', () {
    test('accepts twelve hex characters', () {
      final Uint8List? key = parseMifareKey('ffffffffffff');
      expect(key, isNotNull);
      expect(key!.length, mifareKeyLength);
      expect(toHex(key), 'FFFFFFFFFFFF');
    });

    test('accepts a spaced key, because a paste often carries spaces', () {
      expect(parseMifareKey('A0 A1 A2 A3 A4 A5'), isNotNull);
    });

    test('rejects any other length', () {
      expect(parseMifareKey('FFFFFFFFFF'), isNull);
      expect(parseMifareKey('FFFFFFFFFFFFFF'), isNull);
      expect(parseMifareKey(''), isNull);
    });

    test('rejects text that is not hex at all', () {
      expect(parseMifareKey('not a key!!!'), isNull);
    });
  });
}
