import 'dart:typed_data';

import 'package:collection/collection.dart';

import 'lrc.dart';

const int frameSof = 0x11;
const int frameHeaderLength = 9;
const int frameMaxDataLength = 4096;

/// One protocol frame, either direction. Requests carry status 0.
final class Frame {
  Frame({required this.command, this.status = 0, Uint8List? data})
    : data = data ?? Uint8List(0);

  final int command;
  final int status;
  final Uint8List data;

  Uint8List encode() {
    final len = data.length;
    if (len > frameMaxDataLength) {
      throw ArgumentError.value(len, 'data', 'exceeds $frameMaxDataLength');
    }
    final out = Uint8List(frameHeaderLength + len + 1);
    out[0] = frameSof;
    out[1] = lrc(const [frameSof]);
    out[2] = (command >> 8) & 0xFF;
    out[3] = command & 0xFF;
    out[4] = (status >> 8) & 0xFF;
    out[5] = status & 0xFF;
    out[6] = (len >> 8) & 0xFF;
    out[7] = len & 0xFF;
    out[8] = lrc(out.sublist(2, 8));
    out.setRange(frameHeaderLength, frameHeaderLength + len, data);
    out[frameHeaderLength + len] = lrc(data);
    return out;
  }

  static const _eq = ListEquality<int>();

  @override
  bool operator ==(Object other) =>
      other is Frame &&
      other.command == command &&
      other.status == status &&
      _eq.equals(other.data, data);

  @override
  int get hashCode => Object.hash(command, status, _eq.hash(data));

  @override
  String toString() =>
      'Frame(cmd=$command status=0x${status.toRadixString(16)} len=${data.length})';
}
