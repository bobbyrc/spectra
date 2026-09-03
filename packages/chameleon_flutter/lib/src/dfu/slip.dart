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
/// the byte it escapes, so the partial frame, the pending-escape flag and
/// the bad-frame flag are all carried between calls.
///
/// Mirrors the three states of nrfutil's `Slip.decode_add_byte`
/// (`nordicsemi/dfu/dfu_transport_serial.py`): DECODING, ESC_RECEIVED and
/// CLEARING_INVALID_PACKET.
final class SlipDecoder {
  /// The largest frame this decoder will assemble. The Chameleon's USB CDC
  /// bootloader sizes its SLIP buffer at `2 * (1024 + 1) + 1` = 2051 bytes
  /// encoded, so a legitimate decoded frame never approaches this; anything
  /// longer is a desynchronised stream, and holding it would grow without
  /// bound.
  static const int maxFrameLength = 4096;

  final BytesBuilder _frame = BytesBuilder(copy: false);
  bool _escaped = false;
  bool _bad = false;

  /// Every complete frame in [chunk]. Empty frames (back-to-back ENDs, which
  /// Nordic's transport emits as padding) are dropped, and so is any frame
  /// that carried an invalid escape or overran [maxFrameLength]: like
  /// nrfutil's decoder, this one stays in the clearing state until the next
  /// END resynchronises it.
  Iterable<Uint8List> add(List<int> chunk) {
    final frames = <Uint8List>[];
    for (final b in chunk) {
      if (_bad) {
        // Discard everything up to and including the resynchronising END.
        if (b == Slip.end) _bad = false;
        continue;
      }
      if (_escaped) {
        _escaped = false;
        switch (b) {
          case Slip.escEnd:
            _frame.addByte(Slip.end);
          case Slip.escEsc:
            _frame.addByte(Slip.esc);
          default:
            // An invalid escape byte: the frame is corrupt. Drop what has
            // been collected and suppress the rest of it.
            _poison();
            continue;
        }
        if (_frame.length > maxFrameLength) _poison();
        continue;
      }
      switch (b) {
        case Slip.esc:
          _escaped = true;
        case Slip.end:
          if (_frame.isNotEmpty) frames.add(_frame.takeBytes());
        default:
          _frame.addByte(b);
          if (_frame.length > maxFrameLength) _poison();
      }
    }
    return frames;
  }

  void _poison() {
    _frame.clear();
    _escaped = false;
    _bad = true;
  }

  /// Drops any partially received frame and clears the bad-frame state, so
  /// the next bytes start a fresh frame.
  void reset() {
    _frame.clear();
    _escaped = false;
    _bad = false;
  }
}
