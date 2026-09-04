import 'dart:typed_data';

import 'package:chameleon/src/dfu/dfu_package.dart';
import 'package:chameleon/src/dfu/protobuf_reader.dart';
import 'package:chameleon/src/model/enums.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:test/test.dart';

import 'proto_builder.dart';

void main() {
  final bin = Uint8List.fromList(List.generate(1000, (i) => i & 0xFF));

  test('ProtoReader decodes varints, tags and bytes', () {
    final r = ProtoReader(
      Uint8List.fromList([
        ...varintField(2, 300),
        ...bytesField(8, [1, 2]),
      ]),
    );
    expect(r.readTag(), (2, 0));
    expect(r.readVarint(), 300);
    expect(r.readTag(), (8, 2));
    expect(r.readBytes(), [1, 2]);
    expect(r.isAtEnd, isTrue);
  });

  test('ProtoReader skips unknown fields by wire type', () {
    final r = ProtoReader(
      Uint8List.fromList([
        ...varintField(1, 300), // varint
        ...field(2, 1, List.filled(8, 0xAA)), // 64-bit
        ...bytesField(3, [1, 2, 3]), // length-delimited
        ...field(4, 5, List.filled(4, 0xBB)), // 32-bit
        ...varintField(5, 42),
      ]),
    );
    for (var i = 0; i < 4; i++) {
      final (_, w) = r.readTag();
      r.skip(w);
    }
    expect(r.readTag(), (5, 0));
    expect(r.readVarint(), 42);
    expect(r.isAtEnd, isTrue);
  });

  test('ProtoReader throws DfuError, never RangeError, on truncated input', () {
    // Truncated varint: continuation bit set with no following byte.
    expect(
      () => ProtoReader(Uint8List.fromList([0x80])).readVarint(),
      throwsA(isA<DfuError>()),
    );
    // Length-delimited field claiming more bytes than remain.
    final bytes = ProtoReader(Uint8List.fromList([0x05, 1, 2]));
    expect(bytes.readBytes, throwsA(isA<DfuError>()));
    // Fixed-width skips past the end.
    expect(
      () => ProtoReader(Uint8List.fromList([1, 2, 3])).skip(1),
      throwsA(isA<DfuError>()),
    );
    expect(
      () => ProtoReader(Uint8List.fromList([1, 2, 3])).skip(5),
      throwsA(isA<DfuError>()),
    );
    // Unsupported wire type.
    expect(() => ProtoReader(Uint8List(0)).skip(6), throwsA(isA<DfuError>()));
  });

  test('InitPacket parses hw version, app size and hash', () {
    final p = InitPacket.parse(
      buildInitPacket(bin: bin, hwVersion: 1, fwVersion: 7),
    );
    expect(p.hwVersion, 1);
    expect(p.fwVersion, 7);
    expect(p.appSize, 1000);
    expect(p.hashType, 3);
    expect(p.hash.length, 32);
    expect(p.sdReq, [0x0100]);
    expect(p.type, 4);
  });

  test('InitPacket rejects a packet with no command', () {
    expect(
      () => InitPacket.parse(Uint8List.fromList(varintField(9, 1))),
      throwsA(isA<DfuError>()),
    );
  });

  test('DfuPackage reads a zip, verifies the hash and names the model', () {
    final pkg = DfuPackage.fromZip(
      buildZip(
        bin: bin,
        dat: buildInitPacket(bin: bin),
      ),
    );
    expect(pkg.images.single.kind, DfuImageKind.application);
    expect(pkg.images.single.bin, bin);
    expect(pkg.images.single.hashMatches, isTrue);
    expect(pkg.hardwareVersion, 0);
    expect(pkg.targetModel, DeviceModel.ultra);
  });

  test('a Lite package targets the Lite', () {
    final pkg = DfuPackage.fromZip(
      buildZip(
        bin: bin,
        dat: buildInitPacket(bin: bin, hwVersion: 1),
      ),
    );
    expect(pkg.targetModel, DeviceModel.lite);
  });

  test('an unknown hardware version has no target model', () {
    final pkg = DfuPackage.fromZip(
      buildZip(
        bin: bin,
        dat: buildInitPacket(bin: bin, hwVersion: 7),
      ),
    );
    expect(pkg.hardwareVersion, 7);
    expect(pkg.targetModel, isNull);
  });

  test('tampered firmware fails the hash check', () {
    final tampered = Uint8List.fromList(bin)..[10] ^= 1;
    final pkg = DfuPackage.fromZip(
      buildZip(
        bin: tampered,
        dat: buildInitPacket(bin: bin),
      ),
    );
    expect(pkg.images.single.hashMatches, isFalse);
  });

  test('a hash stored in natural order is not accepted', () {
    final pkg = DfuPackage.fromZip(
      buildZip(
        bin: bin,
        dat: buildInitPacket(bin: bin, reverseHash: false),
      ),
    );
    expect(pkg.images.single.hashMatches, isFalse);
  });

  test('missing manifest is a DfuError', () {
    expect(() => DfuPackage.fromZip(Uint8List(0)), throwsA(isA<DfuError>()));
    expect(
      () => DfuPackage.fromZip(buildZipWithoutManifest()),
      throwsA(isA<DfuError>()),
    );
  });

  test('a manifest naming a missing file is a DfuError', () {
    expect(
      () => DfuPackage.fromZip(
        buildZip(
          bin: bin,
          dat: buildInitPacket(bin: bin),
          includeBin: false,
        ),
      ),
      throwsA(isA<DfuError>()),
    );
  });

  test('an unknown manifest image key is a DfuError', () {
    expect(
      () => DfuPackage.fromZip(
        buildZip(
          bin: bin,
          dat: buildInitPacket(bin: bin),
          key: 'wingding',
        ),
      ),
      throwsA(isA<DfuError>()),
    );
  });
}
