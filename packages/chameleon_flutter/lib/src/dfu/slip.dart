import 'dart:typed_data';

/// RFC 1055 SLIP framing, as nrfutil's serial DFU transport uses it
/// (`nordicsemi.dfu.dfu_transport_serial`, which frames every request and
/// response as one SLIP packet) and as spec 5.3 describes for Spectra's
/// serial DFU channel. Frames are terminated, not delimited: a frame ends
/// with END.
abstract final class Slip {
  static const int end = 0xC0;
  static const int esc = 0xDB;
  static const int escEnd = 0xDC;
  static const int escEsc = 0xDD;

  /// [payload] with END and ESC escaped, followed by a terminating END.
  static Uint8List encode(List<int> payload) {
    final out = BytesBuilder(copy: false);
    for (final b in payload) {
      switch (b) {
        case end:
          out.addByte(esc);
          out.addByte(escEnd);
        case esc:
          out.addByte(esc);
          out.addByte(escEsc);
        default:
          out.addByte(b);
      }
    }
    out.addByte(end);
    return out.toBytes();
  }
}

/// Feeds arbitrary byte chunks in, gets whole SLIP frames out.
///
/// A serial read can split a frame anywhere, including between an ESC and
/// the byte it escapes, so both the partial frame and the pending-escape
/// flag are carried between calls.
final class SlipDecoder {
  final BytesBuilder _frame = BytesBuilder(copy: false);
  bool _escaped = false;

  /// Every complete frame in [chunk]. Empty frames (back-to-back ENDs, which
  /// Nordic's transport emits as padding) are dropped.
  Iterable<Uint8List> add(List<int> chunk) {
    final frames = <Uint8List>[];
    for (final b in chunk) {
      if (_escaped) {
        _escaped = false;
        switch (b) {
          case Slip.escEnd:
            _frame.addByte(Slip.end);
          case Slip.escEsc:
            _frame.addByte(Slip.esc);
          default:
            // An invalid escape byte: the frame is corrupt, drop it and
            // resynchronise on the next END.
            _frame.clear();
        }
        continue;
      }
      switch (b) {
        case Slip.esc:
          _escaped = true;
        case Slip.end:
          if (_frame.isNotEmpty) frames.add(_frame.takeBytes());
        default:
          _frame.addByte(b);
      }
    }
    return frames;
  }

  /// Drops any partially received frame.
  void reset() {
    _frame.clear();
    _escaped = false;
  }
}
