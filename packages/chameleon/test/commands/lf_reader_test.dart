import 'dart:typed_data';

import 'package:chameleon/src/codec/frame.dart';
import 'package:chameleon/src/commands/lf_reader.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:test/test.dart';

Uint8List b(List<int> l) => Uint8List.fromList(l);
Frame lfOk(int cmd, List<int> data) =>
    Frame(command: cmd, status: 0x40, data: b(data));

void main() {
  test('Em410xScan returns five id bytes', () {
    expect(const Em410xScan().parseResponse(lfOk(3000, [1, 2, 3, 4, 5])), [
      1,
      2,
      3,
      4,
      5,
    ]);
  });

  test('Em410xScan maps no-tag status to LfTagNotFound', () {
    expect(
      () =>
          const Em410xScan().parseResponse(Frame(command: 3000, status: 0x41)),
      throwsA(isA<LfTagNotFound>()),
    );
  });

  test('Em410xWriteToT55xx encodes id, new key and old keys', () {
    final c = Em410xWriteToT55xx(
      cardId: b([1, 2, 3, 4, 5]),
      newKey: b([0x51, 0x24, 0x36, 0x48]),
      oldKeys: [
        b([0x51, 0x24, 0x36, 0x48]),
        b([0x19, 0x92, 0x04, 0x27]),
      ],
    );
    expect(c.encode().length, 5 + 4 + 8);
  });

  test('fixed-length scans check their lengths', () {
    expect(
      const HidProxScan().parseResponse(lfOk(3002, List.filled(13, 7))).length,
      13,
    );
    expect(
      const VikingScan().parseResponse(lfOk(3004, [1, 2, 3, 4])).length,
      4,
    );
    expect(
      const PacScan().parseResponse(lfOk(3014, List.filled(8, 1))).length,
      8,
    );
    expect(
      () => const VikingScan().parseResponse(lfOk(3004, [1])),
      throwsA(isA<MalformedResponse>()),
    );
  });
}
