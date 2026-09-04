import 'package:chameleon/src/codec/lrc.dart';
import 'package:test/test.dart';

void main() {
  test('lrc of SOF is 0xEF', () => expect(lrc([0x11]), 0xEF));
  test('lrc of empty is 0x00', () => expect(lrc([]), 0x00));
  test('lrc of enter-bootloader header is 0x0B', () {
    expect(lrc([0x03, 0xF2, 0x00, 0x00, 0x00, 0x00]), 0x0B);
  });
  test('lrc wraps sums above 0xFF', () => expect(lrc([0xFF, 0x02]), 0xFF));
}
