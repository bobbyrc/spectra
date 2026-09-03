import 'dart:async';
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';

import 'slip.dart';

/// Nordic Secure DFU over a serial link (spec 5.3): desktop USB and Android
/// USB. Every message in both directions is one SLIP frame.
///
/// Control messages go on the wire as-is. Data goes out under the serial
/// transport's write opcode 0x08 followed by a little-endian uint16 length,
/// which is how nrfutil's serial DFU transport
/// (`nordicsemi.dfu.dfu_transport_serial`) frames a data packet.
///
/// hardware-validate: the serial DFU framing here is confirmed against
/// nrfutil's source and exercised only against the fake bootloader in
/// tests. Real bootloader behaviour is hardware handoff H2; see
/// docs/hardware-checklist.md.
final class SlipSerialDfuChannel implements DfuChannel {
  SlipSerialDfuChannel(
    this._transport, {
    this.maxDataWrite = 64,
    this._ownsTransport = false,
  }) {
    _sub = _transport.incoming.listen(
      (chunk) {
        for (final frame in _decoder.add(chunk)) {
          if (!_responses.isClosed) _responses.add(frame);
        }
      },
      onError: (Object e, StackTrace s) {
        if (!_responses.isClosed) {
          _responses.addError(const Disconnected('the serial link dropped'));
        }
        unawaited(_finish());
      },
      onDone: () => unawaited(_finish()),
    );
  }

  /// The serial DFU write opcode: `[0x08, len_lo, len_hi, ...payload]`.
  static const int _writeObjectOpcode = 0x08;

  final Transport _transport;
  final bool _ownsTransport;
  final SlipDecoder _decoder = SlipDecoder();
  final StreamController<Uint8List> _responses =
      StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List>? _sub;
  Future<void> _writeTail = Future<void>.value();
  bool _closed = false;

  @override
  final int maxDataWrite;

  /// Decoded SLIP frames from the transport, in order. A broadcast stream:
  /// subscribe before writing, since nothing is buffered for a late
  /// listener. Closes when the transport's [Transport.incoming] ends or the
  /// channel closes; a transport error surfaces as one [Disconnected] event
  /// here first.
  @override
  Stream<Uint8List> get responses => _responses.stream;

  @override
  Future<void> writeControl(Uint8List bytes) => _enqueue(() => _send(bytes));

  @override
  Future<void> writeData(Uint8List bytes) => _enqueue(
    () => _send(
      Uint8List.fromList(<int>[
        _writeObjectOpcode,
        bytes.length & 0xFF,
        (bytes.length >> 8) & 0xFF,
        ...bytes,
      ]),
    ),
  );

  /// Serialises writes: each call waits for the previous one, success or
  /// failure, so two callers never interleave their bytes on the wire.
  /// Mirrors `BleDfuChannel._enqueue`.
  Future<void> _enqueue(Future<void> Function() body) {
    final result = _writeTail.then((_) => body());
    _writeTail = result.catchError((Object _) {});
    return result;
  }

  Future<void> _send(Uint8List payload) async {
    if (_closed) {
      throw const Disconnected('the DFU channel is closed');
    }
    await _transport.write(Slip.encode(payload));
  }

  Future<void> _finish() async {
    if (_closed) return;
    _closed = true;
    await _sub?.cancel();
    _sub = null;
    if (!_responses.isClosed) await _responses.close();
  }

  @override
  Future<void> close() async {
    final alreadyClosed = _closed;
    await _finish();
    if (_ownsTransport && !alreadyClosed) await _transport.close();
  }
}
