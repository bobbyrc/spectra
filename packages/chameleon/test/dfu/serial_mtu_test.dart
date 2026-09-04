import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:test/test.dart';

void main() {
  test('the request is the bare opcode', () {
    expect(DfuSerialMtu.request(), <int>[0x07]);
  });

  test('parses a little-endian uint16 out of a success response', () {
    // [0x60 response, 0x07 opcode, 0x01 success, mtu lo, mtu hi] — nrfutil's
    // DfuTransportSerial.__get_mtu reads the payload after the three-byte
    // header as '<H'. 2051 = 0x0803.
    final r = Uint8List.fromList(<int>[0x60, 0x07, 0x01, 0x03, 0x08]);
    expect(DfuSerialMtu.parse(r), 2051);
  });

  test('returns null for an unsupported or mismatched response', () {
    expect(
      DfuSerialMtu.parse(Uint8List.fromList(<int>[0x60, 0x07, 0x02])),
      isNull,
    );
    expect(
      DfuSerialMtu.parse(Uint8List.fromList(<int>[0x60, 0x06, 0x01, 3, 8])),
      isNull,
    );
    expect(DfuSerialMtu.parse(Uint8List.fromList(<int>[0x60])), isNull);
  });

  test('chunk size follows nrfutil: (mtu - 1) // 2 - 1', () {
    expect(DfuSerialMtu.chunkSize(2051), 1024);
    expect(DfuSerialMtu.chunkSize(131), 64);
  });

  test('the fake bootloader answers GetSerialMTU', () {
    final b = FakeBootloader()..serialMtu = 2051;
    final r = b.handleControl(DfuSerialMtu.request());
    expect(DfuSerialMtu.parse(r), 2051);
  });

  test('a bootloader without the opcode answers not-supported', () {
    final b = FakeBootloader()..supportsSerialMtu = false;
    final r = b.handleControl(DfuSerialMtu.request());
    expect(r[2], 0x02); // NRF_DFU_RES_CODE_OP_CODE_NOT_SUPPORTED
    expect(DfuSerialMtu.parse(r), isNull);
  });
}
