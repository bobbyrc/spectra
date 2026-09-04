import 'dart:convert';

import 'package:chameleon/src/dfu/crc32.dart';
import 'package:test/test.dart';

void main() {
  test('crc32 of "123456789" is 0xCBF43926', () {
    expect(crc32(utf8.encode('123456789')), 0xCBF43926);
  });

  test('crc32 is resumable with a seed', () {
    final a = utf8.encode('12345');
    final b = utf8.encode('6789');
    expect(crc32(b, crc32(a)), 0xCBF43926);
  });

  test('crc32 of nothing is 0', () {
    expect(crc32(const []), 0);
  });
}
