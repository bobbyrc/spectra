import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

Uint8List varint(int v) {
  final out = <int>[];
  var rest = v;
  while (rest >= 0x80) {
    out.add((rest & 0x7F) | 0x80);
    rest >>= 7;
  }
  out.add(rest);
  return Uint8List.fromList(out);
}

Uint8List field(int number, int wire, List<int> payload) =>
    Uint8List.fromList([...varint((number << 3) | wire), ...payload]);

Uint8List varintField(int number, int v) => field(number, 0, varint(v));

Uint8List bytesField(int number, List<int> b) =>
    field(number, 2, [...varint(b.length), ...b]);

/// Builds a .dat init packet the way nrfutil does (hash stored reversed).
///
/// Set [reverseHash] to false to build a (non-nrfutil) packet that stores the
/// digest in natural order, which the SDK must reject.
Uint8List buildInitPacket({
  required Uint8List bin,
  int hwVersion = 0,
  int fwVersion = 1,
  int type = 4,
  bool reverseHash = true,
}) {
  final digest = sha256.convert(bin).bytes;
  final hash = reverseHash ? digest.reversed.toList() : digest;
  final hashMsg = [...varintField(1, 3), ...bytesField(2, hash)];
  final init = [
    ...varintField(1, fwVersion),
    ...varintField(2, hwVersion),
    ...bytesField(3, varint(0x0100)), // sd_req packed
    ...varintField(4, type),
    ...varintField(7, bin.length),
    ...bytesField(8, hashMsg),
  ];
  final command = [...varintField(1, 1), ...bytesField(2, init)];
  final signed = [
    ...bytesField(1, command),
    ...varintField(2, 0),
    ...bytesField(3, List.filled(64, 0)),
  ];
  return bytesField(2, signed);
}

Uint8List buildZip({
  required Uint8List bin,
  required Uint8List dat,
  String binName = 'app.bin',
  String datName = 'app.dat',
  String key = 'application',
  bool includeBin = true,
}) {
  final manifest = jsonEncode({
    'manifest': {
      key: {'bin_file': binName, 'dat_file': datName},
    },
  });
  final archive = Archive()
    ..add(
      ArchiveFile.bytes(
        'manifest.json',
        Uint8List.fromList(utf8.encode(manifest)),
      ),
    );
  if (includeBin) archive.add(ArchiveFile.bytes(binName, bin));
  archive.add(ArchiveFile.bytes(datName, dat));
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}

/// A zip whose only entry is a stray file: no manifest.json.
Uint8List buildZipWithoutManifest() {
  final archive = Archive()..add(ArchiveFile.bytes('app.bin', Uint8List(4)));
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}
