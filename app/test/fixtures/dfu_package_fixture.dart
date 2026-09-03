import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

/// Builds nrfutil-shaped DFU zips for the app's tests. Mirrors
/// `packages/chameleon/test/dfu/proto_builder.dart`; the init packet is a
/// dfu-cc.proto `SignedCommand` whose SHA-256 is stored byte-reversed, which
/// is the only order `DfuImage.hashMatches` accepts (hardware-validate, H2).
Uint8List buildBin(int size) =>
    Uint8List.fromList(List<int>.generate(size, (i) => i & 0xFF));

Uint8List _varint(int v) {
  final out = <int>[];
  var rest = v;
  while (rest >= 0x80) {
    out.add((rest & 0x7F) | 0x80);
    rest >>= 7;
  }
  out.add(rest);
  return Uint8List.fromList(out);
}

Uint8List _field(int number, int wire, List<int> payload) =>
    Uint8List.fromList(<int>[..._varint((number << 3) | wire), ...payload]);

Uint8List _varintField(int number, int v) => _field(number, 0, _varint(v));

Uint8List _bytesField(int number, List<int> b) =>
    _field(number, 2, <int>[..._varint(b.length), ...b]);

Uint8List buildInitPacket(
  Uint8List bin, {
  int hwVersion = 0,
  bool reverseHash = true,
}) {
  final digest = sha256.convert(bin).bytes;
  final hash = reverseHash ? digest.reversed.toList() : digest;
  final hashMsg = <int>[..._varintField(1, 3), ..._bytesField(2, hash)];
  final init = <int>[
    ..._varintField(1, 1),
    ..._varintField(2, hwVersion),
    ..._bytesField(3, _varint(0x0100)),
    ..._varintField(4, 4),
    ..._varintField(7, bin.length),
    ..._bytesField(8, hashMsg),
  ];
  final command = <int>[..._varintField(1, 1), ..._bytesField(2, init)];
  final signed = <int>[
    ..._bytesField(1, command),
    ..._varintField(2, 0),
    ..._bytesField(3, List<int>.filled(64, 0)),
  ];
  return _bytesField(2, signed);
}

/// A one-application-image package of [size] bytes for [hwVersion]
/// (0 Ultra, 1 Lite — `docs/research/chameleon-protocol.md`, "DFU").
Uint8List buildDfuZip({
  int size = 2048,
  int hwVersion = 0,
  bool reverseHash = true,
}) {
  final bin = buildBin(size);
  final manifest = jsonEncode(<String, Object>{
    'manifest': <String, Object>{
      'application': <String, String>{
        'bin_file': 'app.bin',
        'dat_file': 'app.dat',
      },
    },
  });
  final archive = Archive()
    ..add(
      ArchiveFile.bytes(
        'manifest.json',
        Uint8List.fromList(utf8.encode(manifest)),
      ),
    )
    ..add(ArchiveFile.bytes('app.bin', bin))
    ..add(
      ArchiveFile.bytes(
        'app.dat',
        buildInitPacket(bin, hwVersion: hwVersion, reverseHash: reverseHash),
      ),
    );
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}
