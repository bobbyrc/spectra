import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';

import '../model/enums.dart';
import '../protocol/errors.dart';
import 'protobuf_reader.dart';

/// Decoded dfu-cc.proto InitCommand.
final class InitPacket {
  const InitPacket({
    required this.fwVersion,
    required this.hwVersion,
    required this.sdReq,
    required this.type,
    required this.sdSize,
    required this.blSize,
    required this.appSize,
    required this.hashType,
    required this.hash,
    required this.isDebug,
  });

  final int fwVersion;
  final int hwVersion;
  final List<int> sdReq;
  final int type;
  final int sdSize;
  final int blSize;
  final int appSize;
  final int hashType;
  final Uint8List hash;
  final bool isDebug;

  static const int hashTypeSha256 = 3;

  static InitPacket parse(Uint8List dat) {
    // Packet { command = 1; signed_command = 2 }
    Uint8List? command;
    final packet = ProtoReader(dat);
    while (!packet.isAtEnd) {
      final (f, w) = packet.readTag();
      if (f == 1 && w == 2) {
        command = packet.readBytes();
      } else if (f == 2 && w == 2) {
        // SignedCommand { command = 1; signature_type = 2; signature = 3 }
        final signed = ProtoReader(packet.readBytes());
        while (!signed.isAtEnd) {
          final (sf, sw) = signed.readTag();
          if (sf == 1 && sw == 2) {
            command = signed.readBytes();
          } else {
            signed.skip(sw);
          }
        }
      } else {
        packet.skip(w);
      }
    }
    if (command == null) throw DfuError('init packet has no command');
    // Command { op_code = 1; init = 2 }
    Uint8List? init;
    final cmd = ProtoReader(command);
    while (!cmd.isAtEnd) {
      final (f, w) = cmd.readTag();
      if (f == 2 && w == 2) {
        init = cmd.readBytes();
      } else {
        cmd.skip(w);
      }
    }
    if (init == null) throw DfuError('init packet has no InitCommand');
    var fw = 0,
        hw = 0,
        type = 0,
        sdSize = 0,
        blSize = 0,
        appSize = 0,
        hashType = 0;
    var isDebug = false;
    final sdReq = <int>[];
    var hash = Uint8List(0);
    final r = ProtoReader(init);
    while (!r.isAtEnd) {
      final (f, w) = r.readTag();
      switch (f) {
        case 1:
          fw = r.readVarint();
        case 2:
          hw = r.readVarint();
        case 3:
          if (w == 2) {
            final packed = ProtoReader(r.readBytes());
            while (!packed.isAtEnd) {
              sdReq.add(packed.readVarint());
            }
          } else {
            sdReq.add(r.readVarint());
          }
        case 4:
          type = r.readVarint();
        case 5:
          sdSize = r.readVarint();
        case 6:
          blSize = r.readVarint();
        case 7:
          appSize = r.readVarint();
        case 8:
          final h = ProtoReader(r.readBytes());
          while (!h.isAtEnd) {
            final (hf, hw2) = h.readTag();
            if (hf == 1) {
              hashType = h.readVarint();
            } else if (hf == 2) {
              hash = h.readBytes();
            } else {
              h.skip(hw2);
            }
          }
        case 9:
          isDebug = r.readVarint() != 0;
        default:
          r.skip(w);
      }
    }
    return InitPacket(
      fwVersion: fw,
      hwVersion: hw,
      sdReq: sdReq,
      type: type,
      sdSize: sdSize,
      blSize: blSize,
      appSize: appSize,
      hashType: hashType,
      hash: hash,
      isDebug: isDebug,
    );
  }
}

enum DfuImageKind { softdeviceBootloader, softdevice, bootloader, application }

final class DfuImage {
  DfuImage({required this.kind, required this.bin, required this.dat})
    : init = InitPacket.parse(dat);

  final DfuImageKind kind;
  final Uint8List bin;
  final Uint8List dat;
  final InitPacket init;

  /// hardware-validate: this assumes nrfutil stores the SHA-256 of the image
  /// byte-reversed in the init packet, which is the only order accepted here.
  /// Confirm against a real Chameleon release package before shipping DFU.
  bool get hashMatches {
    if (init.hashType != InitPacket.hashTypeSha256) return false;
    final digest = sha256.convert(bin).bytes;
    const eq = ListEquality<int>();
    return eq.equals(digest.reversed.toList(), init.hash);
  }
}

/// An nrfutil zip: manifest.json plus .bin and .dat per image.
final class DfuPackage {
  DfuPackage(this.images);

  final List<DfuImage> images;

  /// The hardware version the package was built for, from the application
  /// image's init packet (or the first image's, if there is no application).
  int get hardwareVersion =>
      (images.firstWhereOrNull((i) => i.kind == DfuImageKind.application) ??
              images.first)
          .init
          .hwVersion;

  DeviceModel? get targetModel => switch (hardwareVersion) {
    0 => DeviceModel.ultra,
    1 => DeviceModel.lite,
    _ => null,
  };

  static const _manifestOrder = [
    ('softdevice_bootloader', DfuImageKind.softdeviceBootloader),
    ('softdevice', DfuImageKind.softdevice),
    ('bootloader', DfuImageKind.bootloader),
    ('application', DfuImageKind.application),
  ];

  static DfuPackage fromZip(Uint8List zip) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zip);
    } catch (e) {
      throw DfuError('not a zip file: $e');
    }
    Uint8List? file(String name) {
      final f = archive.files.firstWhereOrNull((f) => f.name == name);
      return f == null ? null : Uint8List.fromList(f.readBytes()!);
    }

    final manifestBytes = file('manifest.json');
    if (manifestBytes == null) throw DfuError('manifest.json missing');
    final Object? root;
    try {
      root = jsonDecode(utf8.decode(manifestBytes));
    } catch (e) {
      throw DfuError('manifest.json is not valid JSON: $e');
    }
    if (root is! Map<String, dynamic>) {
      throw DfuError('manifest.json is not an object');
    }
    final manifest = root['manifest'];
    if (manifest is! Map<String, dynamic>) {
      throw DfuError('manifest has no "manifest" object');
    }
    final known = {for (final (key, _) in _manifestOrder) key};
    final unknown = manifest.keys.where((k) => !known.contains(k)).toList();
    if (unknown.isNotEmpty) {
      throw DfuError('manifest has unknown image ${unknown.join(', ')}');
    }
    final images = <DfuImage>[];
    for (final (key, kind) in _manifestOrder) {
      final entry = manifest[key];
      if (entry == null) continue;
      if (entry is! Map<String, dynamic>) {
        throw DfuError('manifest entry "$key" is not an object');
      }
      final binName = entry['bin_file'];
      final datName = entry['dat_file'];
      if (binName is! String || datName is! String) {
        throw DfuError('manifest entry "$key" names no bin_file/dat_file');
      }
      final bin = file(binName);
      final dat = file(datName);
      if (bin == null || dat == null) {
        throw DfuError('$key files missing from zip');
      }
      images.add(DfuImage(kind: kind, bin: bin, dat: dat));
    }
    if (images.isEmpty) throw DfuError('manifest lists no images');
    return DfuPackage(images);
  }
}
