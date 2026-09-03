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
/// still fit the bootloader's SLIP buffer. That default is now only the
/// fallback: [open] asks the device with the `GetSerialMTU` opcode `0x07`
/// and raises [maxDataWrite] from the answer. The Chameleon's USB CDC
/// bootloader reports `SLIP_MTU = 2 * (1024 + 1) + 1 = 2051`, which yields
/// 1024 — roughly a sixteen-fold speed-up.
///
/// hardware-validate: the serial DFU framing here is assumed from nrfutil's
/// source and exercised only against the fake bootloader in tests. Real
/// bootloader behaviour is hardware handoff H2; see
/// docs/hardware-checklist.md.
final class SlipSerialDfuChannel implements DfuChannel {
  SlipSerialDfuChannel(
    this._transport, {
    this._maxDataWrite = 64,
    this.negotiateMtu = true,
    this.mtuTimeout = const Duration(seconds: 2),
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

  /// Ask the bootloader for its SLIP MTU in [open] and size the writes from
  /// the answer. False keeps the fallback and writes nothing on open — for
  /// a test driving the channel by hand.
  final bool negotiateMtu;

  /// How long the MTU answer is waited for. A bootloader that never replies
  /// is not an error: the fallback stands and the first real request is the
  /// gate that reports a dead link.
  final Duration mtuTimeout;

  int _maxDataWrite;
  bool _negotiated = false;

  /// Largest payload one WriteObject frame carries: the constructor's
  /// fallback until [open] negotiates, then nrfutil's
  /// `(mtu - 1) // 2 - 1` for the MTU the bootloader reported, capped so
  /// the worst-case SLIP-escaped frame still fits [Transport.maxWriteLength].
  @override
  int get maxDataWrite => _maxDataWrite;

  /// Decoded SLIP frames from the transport, in order. A broadcast stream:
  /// subscribe before writing, since nothing is buffered for a late
  /// listener. Closes when the transport's [Transport.incoming] ends or the
  /// channel closes; a link loss — reported on the transport's
  /// [Transport.state] as a [TransportClosed] this channel did not ask for
  /// — surfaces as one error event here first, then the stream closes.
  @override
  Stream<Uint8List> get responses => _responses.stream;

  /// Negotiates the write size and nothing else: the transport is already
  /// open when the channel is built, and the constructor has done the
  /// wiring. Idempotent (the negotiation runs once); throws once the
  /// channel is closed. Part of the [DfuChannel] lifecycle (ruling F33) so
  /// every caller can open, write and close the same way.
  ///
  /// Every failure here is swallowed on purpose: a bootloader that answers
  /// "opcode not supported", answers nothing, or drops the link leaves the
  /// conservative fallback in place, and the first real DFU request is what
  /// reports a link that is actually gone.
  @override
  Future<void> open() async {
    if (_closed) {
      throw const Disconnected('the DFU channel is closed');
    }
    if (!negotiateMtu || _negotiated) return;
    _negotiated = true;
    // Subscribe before writing: `responses` is broadcast and buffers
    // nothing for a late listener.
    final reply = responses.first;
    try {
      await writeControl(DfuSerialMtu.request());
      final mtu = DfuSerialMtu.parse(await reply.timeout(mtuTimeout));
      if (mtu == null) return;
      final chunk = DfuSerialMtu.chunkSize(mtu);
      if (chunk <= 0) return;
      _maxDataWrite = chunk < _transportChunkLimit
          ? chunk
          : _transportChunkLimit;
    } on Object {
      // Deliberately ignored; see the doc comment.
    }
  }

  /// The largest payload whose worst-case SLIP frame — every byte escaped,
  /// plus the WriteObject opcode and the terminating END:
  /// `2 * (payload + 1) + 1` — still fits the transport's write limit.
  int get _transportChunkLimit => (_transport.maxWriteLength - 1) ~/ 2 - 1;

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
