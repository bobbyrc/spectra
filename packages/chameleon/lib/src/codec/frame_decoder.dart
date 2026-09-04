import 'dart:typed_data';

import 'frame.dart';
import 'lrc.dart';

sealed class DecodeDiagnostic {
  const DecodeDiagnostic();
}

final class ResyncDiagnostic extends DecodeDiagnostic {
  const ResyncDiagnostic(this.droppedBytes);
  final int droppedBytes;
}

final class BadLrcDiagnostic extends DecodeDiagnostic {
  const BadLrcDiagnostic(this.which);

  /// 'sof', 'header' or 'data'.
  final String which;
}

final class OversizedFrameDiagnostic extends DecodeDiagnostic {
  const OversizedFrameDiagnostic(this.length);
  final int length;
}

/// Byte-stream state machine. Feed it chunks of any size; it returns the
/// complete frames found so far and keeps the remainder. It never throws on
/// bad input: it drops bytes, reports a diagnostic and resyncs on SOF.
final class FrameDecoder {
  FrameDecoder({void Function(DecodeDiagnostic)? onDiagnostic})
    // ignore: prefer_initializing_formals
    : _onDiagnostic = onDiagnostic;

  final void Function(DecodeDiagnostic)? _onDiagnostic;
  final List<int> _buf = [];

  List<Frame> feed(List<int> bytes) {
    _buf.addAll(bytes);
    final frames = <Frame>[];
    while (true) {
      final sof = _buf.indexOf(frameSof);
      if (sof < 0) {
        if (_buf.isNotEmpty) {
          _report(ResyncDiagnostic(_buf.length));
          _buf.clear();
        }
        return frames;
      }
      if (sof > 0) {
        _report(ResyncDiagnostic(sof));
        _buf.removeRange(0, sof);
      }
      if (_buf.length < frameHeaderLength) return frames;
      if (_buf[1] != lrc(const [frameSof])) {
        _dropOne(const BadLrcDiagnostic('sof'));
        continue;
      }
      if (_buf[8] != lrc(_buf.sublist(2, 8))) {
        _dropOne(const BadLrcDiagnostic('header'));
        continue;
      }
      final len = (_buf[6] << 8) | _buf[7];
      if (len > frameMaxDataLength) {
        _dropOne(OversizedFrameDiagnostic(len));
        continue;
      }
      final total = frameHeaderLength + len + 1;
      if (_buf.length < total) return frames;
      final data = Uint8List.fromList(
        _buf.sublist(frameHeaderLength, frameHeaderLength + len),
      );
      if (_buf[frameHeaderLength + len] != lrc(data)) {
        _dropOne(const BadLrcDiagnostic('data'));
        continue;
      }
      frames.add(
        Frame(
          command: (_buf[2] << 8) | _buf[3],
          status: (_buf[4] << 8) | _buf[5],
          data: data,
        ),
      );
      _buf.removeRange(0, total);
    }
  }

  void _dropOne(DecodeDiagnostic why) {
    _report(why);
    _buf.removeAt(0);
  }

  void _report(DecodeDiagnostic d) => _onDiagnostic?.call(d);
}
