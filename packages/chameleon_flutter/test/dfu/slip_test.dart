import 'package:chameleon_flutter/src/dfu/slip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a plain payload is the bytes plus END', () {
    expect(Slip.encode(const [1, 2, 3]), [1, 2, 3, 0xC0]);
  });

  test('END and ESC inside the payload are escaped', () {
    expect(Slip.encode(const [0xC0]), [0xDB, 0xDC, 0xC0]);
    expect(Slip.encode(const [0xDB]), [0xDB, 0xDD, 0xC0]);
    expect(Slip.encode(const [1, 0xC0, 2, 0xDB, 3]), [
      1,
      0xDB,
      0xDC,
      2,
      0xDB,
      0xDD,
      3,
      0xC0,
    ]);
  });

  test('an empty payload is a bare END', () {
    expect(Slip.encode(const []), [0xC0]);
  });

  test('the decoder round-trips every payload', () {
    final decoder = SlipDecoder();
    const payloads = [
      <int>[1, 2, 3],
      <int>[0xC0, 0xDB, 0xC0],
      <int>[0],
    ];
    final wire = <int>[for (final p in payloads) ...Slip.encode(p)];
    expect(decoder.add(wire).map((f) => f.toList()).toList(), payloads);
  });

  test('a frame split across chunks is reassembled', () {
    final decoder = SlipDecoder();
    final wire = Slip.encode(const [1, 0xC0, 2]);
    expect(decoder.add(wire.sublist(0, 2)), isEmpty);
    expect(decoder.add(wire.sublist(2, 3)), isEmpty);
    expect(decoder.add(wire.sublist(3)).single, [1, 0xC0, 2]);
  });

  test('an escape split across chunks is still decoded', () {
    final decoder = SlipDecoder();
    expect(decoder.add(const [1, 0xDB]), isEmpty);
    expect(decoder.add(const [0xDC, 0xC0]).single, [1, 0xC0]);
  });

  test('empty frames from back-to-back ENDs are dropped', () {
    expect(SlipDecoder().add(const [0xC0, 0xC0, 1, 0xC0]).single, [1]);
  });

  test('reset drops a partial frame', () {
    final decoder = SlipDecoder()..add(const [1, 2]);
    decoder.reset();
    expect(decoder.add(const [3, 0xC0]).single, [3]);
  });

  test('an invalid escape byte resets the frame', () {
    final decoder = SlipDecoder();
    // 1, ESC, 0x01 (not a valid escape target): the bytes before the bad
    // escape are dropped, not kept, so only the byte after it survives to
    // the next END.
    expect(decoder.add(const [1, 0xDB, 0x01, 2, 0xC0]).single, [2]);
  });
}
