import 'dart:async';
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';

import 'slip.dart';

/// Nordic Secure DFU over a serial link (spec 5.3): desktop USB and Android
/// USB. Every message in both directions is one SLIP frame.
///
/// The wire layout is assumed from nrfutil's source
/// (`nordicsemi/dfu/dfu_transport_serial.py`, `DFUAdapter.send_message` and
/// `DfuTransportSerial.__stream_data`) and cross-checked against the
/// bootloader side the Chameleon ships
/// (`components/libraries/bootloader/serial_dfu/nrf_dfu_serial.c`,
/// `nrf_dfu_serial_on_packet_received`):
///
/// * A control request is its opcode followed by its parameters, SLIP-framed
///   with nothing added — `send_message` encodes exactly the bytes it is
///   given.
/// * A data write is the WriteObject opcode `0x08` followed by the raw data,
///   with **no** length prefix: `__stream_data` builds
///   `struct.pack('B', OP_CODE['WriteObject']) + to_transmit`, and the
///   bootloader takes `payload_len = length - NRF_SERIAL_OPCODE_SIZE` from
///   the length of the decoded frame.
///
/// [maxDataWrite] defaults to 64, which is nrfutil's chunk arithmetic
/// `(mtu - 1) // 2 - 1` applied to the nRF5 SDK's UART serial transport MTU
/// (`UART_SLIP_MTU = 2 * (64 + 1) + 1 = 131`), the smaller of the two serial
/// transports; the halving is what makes a worst-case all-escapes payload
/// still fit the bootloader's SLIP buffer. nrfutil does not carry a static
/// default: `DfuTransportSerial.open` asks the device with the
/// `GetSerialMTU` opcode `0x07` and computes from the answer. The Chameleon's
/// USB CDC bootloader reports `SLIP_MTU = 2 * (1024 + 1) + 1 = 2051`, which
/// would yield 1024 — roughly a sixteen-fold speed-up.
///
/// Follow-up: `SecureDfu` has no GetSerialMTU request yet, so the MTU cannot
/// be negotiated and this default stays conservative. Adding it is the way
/// to grow [maxDataWrite] on USB.
///
/// hardware-validate: the serial DFU framing here is assumed from nrfutil's
/// source and exercised only against the fake bootloader in tests. Real
/// bootloader behaviour is hardware handoff H2; see
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
          _responses.addError(
            e is TransportError
                ? e
                : const Disconnected('the serial link dropped'),
            s,
          );
        }
        unawaited(_finish());
      },
      onDone: () => unawaited(_finish()),
    );
    // The authoritative drop signal: a real transport reports link loss on
    // `state` and never on `incoming` (see the contract on [Transport]), so
    // the subscription above is only a secondary path. A close this channel
    // asked for is not a drop — [_closed] is already set by then.
    _stateSub = _transport.state.listen((s) {
      if (s is TransportClosed) _linkClosed(s);
    });
  }

  /// The serial DFU WriteObject opcode. The frame is `[0x08, ...payload]`.
  static const int _writeObjectOpcode = 0x08;

  final Transport _transport;
  final bool _ownsTransport;
  final SlipDecoder _decoder = SlipDecoder();
  final StreamController<Uint8List> _responses =
      StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List>? _sub;
  StreamSubscription<TransportState>? _stateSub;
  Future<void> _writeTail = Future<void>.value();
  bool _closed = false;
  bool _transportClosed = false;

  @override
  final int maxDataWrite;

  /// Decoded SLIP frames from the transport, in order. A broadcast stream:
  /// subscribe before writing, since nothing is buffered for a late
  /// listener. Closes when the transport's [Transport.incoming] ends or the
  /// channel closes; a link loss — reported on the transport's
  /// [Transport.state] as a [TransportClosed] this channel did not ask for
  /// — surfaces as one error event here first, then the stream closes.
  @override
  Stream<Uint8List> get responses => _responses.stream;

  @override
  Future<void> writeControl(Uint8List bytes) {
    final frame = _frame(bytes);
    return _enqueue(() => _send(frame));
  }

  /// Writes [bytes] as a single WriteObject frame. [SecureDfu] already
  /// chunks firmware data to [maxDataWrite]; this never re-chunks.
  ///
  /// Throws [ArgumentError] if [bytes] is longer than [maxDataWrite], or if
  /// the SLIP-encoded frame would exceed the transport's
  /// [Transport.maxWriteLength] (escaping can double a payload's size).
  @override
  Future<void> writeData(Uint8List bytes) {
    if (bytes.length > maxDataWrite) {
      throw ArgumentError.value(
        bytes.length,
        'bytes.length',
        'exceeds maxDataWrite ($maxDataWrite)',
      );
    }
    final frame = _frame(
      Uint8List.fromList(<int>[_writeObjectOpcode, ...bytes]),
    );
    return _enqueue(() => _send(frame));
  }

  /// SLIP-encodes [payload] and checks it against the transport's write
  /// limit before any of it reaches the wire.
  Uint8List _frame(Uint8List payload) {
    final frame = Slip.encode(payload);
    if (frame.length > _transport.maxWriteLength) {
      throw ArgumentError.value(
        frame.length,
        'frame.length',
        'the SLIP-encoded frame exceeds the transport write limit '
            '(${_transport.maxWriteLength})',
      );
    }
    return frame;
  }

  /// Serialises writes: each call waits for the previous one, success or
  /// failure, so two callers never interleave their bytes on the wire.
  /// Mirrors `BleDfuChannel._enqueue`.
  Future<void> _enqueue(Future<void> Function() body) {
    final result = _writeTail.then((_) => body());
    _writeTail = result.catchError((Object _) {});
    return result;
  }

  Future<void> _send(Uint8List frame) async {
    if (_closed) {
      throw const Disconnected('the DFU channel is closed');
    }
    await _transport.write(frame);
  }

  /// The transport reported it is closed and this channel did not ask for
  /// it: one error on [responses], then the channel is done.
  void _linkClosed(TransportClosed closed) {
    if (_closed) return;
    if (!_responses.isClosed) {
      _responses.addError(
        closed.error ?? const Disconnected('the serial link dropped'),
      );
    }
    unawaited(_finish());
  }

  /// Tears down the channel's own state. Never touches the transport: the
  /// drop paths (an [Transport.incoming] error or its end) run through here
  /// too, and closing an owned transport is [close]'s job so the handle is
  /// released exactly once, whichever path got here first.
  Future<void> _finish() async {
    if (_closed) return;
    _closed = true;
    await _sub?.cancel();
    _sub = null;
    await _stateSub?.cancel();
    _stateSub = null;
    if (!_responses.isClosed) await _responses.close();
  }

  @override
  Future<void> close() async {
    await _finish();
    if (_ownsTransport && !_transportClosed) {
      _transportClosed = true;
      await _transport.close();
    }
  }
}
