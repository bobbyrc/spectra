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

  test('an invalid escape byte poisons the frame until the next END', () {
    final decoder = SlipDecoder();
    // 1, ESC, 0x01 (not a valid escape target). nrfutil's decoder enters
    // SLIP_STATE_CLEARING_INVALID_PACKET and stays there until an END, so
    // nothing at all is emitted for this frame.
    expect(decoder.add(const [1, 0xDB, 0x01, 2, 0xC0]), isEmpty);
    // The END cleared the bad-frame state: the next frame decodes normally.
    expect(decoder.add(const [3, 4, 0xC0]).single, [3, 4]);
  });

  test('a bad frame split across chunks stays suppressed', () {
    final decoder = SlipDecoder();
    expect(decoder.add(const [1, 0xDB, 0x01]), isEmpty);
    expect(decoder.add(const [2, 3]), isEmpty);
    expect(decoder.add(const [0xC0, 9, 0xC0]).single, [9]);
  });

  test('an over-long frame is dropped and resynchronises on the next END', () {
    final decoder = SlipDecoder();
    expect(
      decoder.add(List<int>.filled(SlipDecoder.maxFrameLength + 1, 7)),
      isEmpty,
    );
    // Even the bytes that arrived before the cap are gone.
    expect(decoder.add(const [8, 0xC0]), isEmpty);
    expect(decoder.add(const [9, 0xC0]).single, [9]);
  });

  test('a frame exactly at the cap still decodes', () {
    final decoder = SlipDecoder();
    final payload = List<int>.filled(SlipDecoder.maxFrameLength, 7);
    expect(decoder.add(<int>[...payload, 0xC0]).single, payload);
  });

  test('reset clears the bad-frame state too', () {
    final decoder = SlipDecoder()..add(const [1, 0xDB, 0x01]);
    decoder.reset();
    expect(decoder.add(const [3, 0xC0]).single, [3]);
  });
}
