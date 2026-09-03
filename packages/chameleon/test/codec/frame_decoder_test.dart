import 'dart:typed_data';

import 'package:chameleon/src/codec/frame.dart';
import 'package:chameleon/src/codec/frame_decoder.dart';
import 'package:chameleon/src/codec/lrc.dart';
import 'package:test/test.dart';

Uint8List bytes(List<int> l) => Uint8List.fromList(l);

void main() {
  final f1 = Frame(command: 1000, status: 0x68, data: bytes([2, 0]));
  final f2 = Frame(command: 1018, status: 0x68, data: bytes([3]));

  test('decodes one frame from one chunk', () {
    expect(FrameDecoder().feed(f1.encode()), [f1]);
  });

  test('decodes two frames from one chunk', () {
    expect(FrameDecoder().feed([...f1.encode(), ...f2.encode()]), [f1, f2]);
  });

  test('reassembles a frame fed one byte at a time', () {
    final d = FrameDecoder();
    final enc = f1.encode();
    final out = <Frame>[];
    for (final b in enc) {
      out.addAll(d.feed([b]));
    }
    expect(out, [f1]);
  });

  test('skips garbage before SOF and reports resync', () {
    final diags = <DecodeDiagnostic>[];
    final d = FrameDecoder(onDiagnostic: diags.add);
    expect(d.feed([0xAA, 0xBB, ...f1.encode()]), [f1]);
    expect(
      diags.single,
      isA<ResyncDiagnostic>().having((r) => r.droppedBytes, 'dropped', 2),
    );
  });

  test('recovers from a corrupted header LRC', () {
    final diags = <DecodeDiagnostic>[];
    final d = FrameDecoder(onDiagnostic: diags.add);
    final bad = f1.encode()..[8] ^= 0xFF;
    expect(d.feed([...bad, ...f2.encode()]), [f2]);
    expect(diags.whereType<BadLrcDiagnostic>(), isNotEmpty);
  });

  test('drops a frame with a bad data LRC', () {
    final d = FrameDecoder();
    final bad = f1.encode();
    bad[bad.length - 1] ^= 0x01;
    expect(d.feed([...bad, ...f2.encode()]), [f2]);
  });

  test('rejects oversized LEN and resyncs', () {
    final diags = <DecodeDiagnostic>[];
    final d = FrameDecoder(onDiagnostic: diags.add);
    final enc = f1.encode();
    enc[6] = 0x20; // LEN high byte set; low byte (2, from f1's data) is
    // untouched, so the encoded LEN is 0x2002, not a round 0x2000.
    enc[8] = lrc(enc.sublist(2, 8));
    expect(d.feed([...enc, ...f2.encode()]), [f2]);
    expect(diags.whereType<OversizedFrameDiagnostic>().single.length, 0x2002);
  });

  test('decodes a maximum-size payload', () {
    final big = Frame(command: 4008, status: 0x68, data: Uint8List(4096));
    expect(FrameDecoder().feed(big.encode()), [big]);
  });
}
