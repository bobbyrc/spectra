import 'dart:async';
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

/// A byte pipe standing in for an open serial link.
final class _LoopbackTransport implements Transport {
  _LoopbackTransport({this.maxWriteLength = 4105});

  final List<Uint8List> written = <Uint8List>[];
  final _incoming = StreamController<Uint8List>.broadcast();
  final _state = StreamController<TransportState>.broadcast();
  TransportState _current = const TransportOpen();
  bool closed = false;

  /// When set, [write] waits on this before recording the bytes, so a test
  /// can hold one write open and check that the next one queues behind it.
  Completer<void>? writeGate;

  void deliver(List<int> bytes) => _incoming.add(Uint8List.fromList(bytes));

  /// The cable came out, reported the way a conforming transport reports it
  /// (F32): on [state], with [incoming] left open and error-free.
  void dropLink([TransportError? error]) {
    _current = TransportClosed(
      CloseCause.linkLost,
      error: error ?? const Disconnected('the cable came out'),
    );
    _state.add(_current);
  }

  /// Deliberately breaks the [Transport] contract by putting an error on
  /// [incoming]. No real transport does this; the channel keeps a defensive
  /// path for it and these are the tests that exercise it.
  void fail(Object error) => _incoming.addError(error);

  Future<void> endIncoming() => _incoming.close();

  @override
  TransportKind get kind => TransportKind.usb;
  @override
  Stream<Uint8List> get incoming => _incoming.stream;
  @override
  Stream<TransportState> get state => _state.stream;
  @override
  TransportState get currentState => _current;
  @override
  final int maxWriteLength;
  @override
  Future<void> open() async {}
  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    _current = const TransportClosed(CloseCause.requested);
    if (!_state.isClosed) {
      _state.add(_current);
      await _state.close();
    }
    if (!_incoming.isClosed) await _incoming.close();
  }

  @override
  Future<void> write(Uint8List bytes) async {
    if (closed) throw const Disconnected('the loopback transport is closed');
    final gate = writeGate;
    if (gate != null) await gate.future;
    if (bytes.length > maxWriteLength) {
      throw ArgumentError.value(bytes.length, 'bytes.length', 'too long');
    }
    written.add(Uint8List.fromList(bytes));
  }
}

void main() {
  test('control writes are SLIP-encoded verbatim', () async {
    final t = _LoopbackTransport();
    final channel = SlipSerialDfuChannel(t);
    await channel.writeControl(Uint8List.fromList(const [0x06, 0x01]));
    expect(t.written.single, Slip.encode(const [0x06, 0x01]));
  });

  test('data writes are the 0x08 opcode followed by the raw bytes', () async {
    final t = _LoopbackTransport();
    final channel = SlipSerialDfuChannel(t, maxDataWrite: 300);
    await channel.writeData(Uint8List.fromList(List<int>.filled(300, 0xAB)));
    // nrfutil's __stream_data prepends only the opcode: no length prefix,
    // the bootloader takes the length from the SLIP frame.
    expect(
      t.written.single,
      Slip.encode(<int>[0x08, ...List<int>.filled(300, 0xAB)]),
    );
  });

  test('writeData rejects a payload longer than maxDataWrite', () async {
    final t = _LoopbackTransport();
    final channel = SlipSerialDfuChannel(t, maxDataWrite: 8);
    expect(
      () => channel.writeData(Uint8List(9)),
      throwsA(isA<ArgumentError>()),
    );
    expect(t.written, isEmpty);
  });

  test('writeData rejects a frame the transport cannot carry', () async {
    // Every byte escapes to two, so 40 bytes of payload plus the opcode
    // becomes an 83-byte frame: past this transport's 32-byte limit.
    final t = _LoopbackTransport(maxWriteLength: 32);
    final channel = SlipSerialDfuChannel(t, maxDataWrite: 64);
    expect(
      () => channel.writeData(Uint8List.fromList(List<int>.filled(40, 0xC0))),
      throwsA(isA<ArgumentError>()),
    );
    expect(t.written, isEmpty);
  });

  test('a payload containing END survives the framing', () async {
    final t = _LoopbackTransport();
    final channel = SlipSerialDfuChannel(t);
    await channel.writeControl(Uint8List.fromList(const [0xC0, 0xDB]));
    expect(t.written.single, [0xDB, 0xDC, 0xDB, 0xDD, 0xC0]);
  });

  test('responses are decoded frames, reassembled across chunks', () async {
    final t = _LoopbackTransport();
    final channel = SlipSerialDfuChannel(t);
    final got = <List<int>>[];
    channel.responses.listen((f) => got.add(f.toList()));
    final wire = Slip.encode(const [0x60, 0x06, 0x01]);
    t.deliver(wire.sublist(0, 2));
    t.deliver(wire.sublist(2));
    await Future<void>.delayed(Duration.zero);
    expect(got, [
      [0x60, 0x06, 0x01],
    ]);
  });

  test('maxDataWrite defaults to 64 and is settable', () {
    expect(SlipSerialDfuChannel(_LoopbackTransport()).maxDataWrite, 64);
    expect(
      SlipSerialDfuChannel(
        _LoopbackTransport(),
        maxDataWrite: 128,
      ).maxDataWrite,
      128,
    );
  });

  test(
    'close leaves a borrowed transport open and closes an owned one',
    () async {
      final borrowed = _LoopbackTransport();
      await SlipSerialDfuChannel(borrowed).close();
      expect(borrowed.closed, isFalse);

      final owned = _LoopbackTransport();
      await SlipSerialDfuChannel(owned, ownsTransport: true).close();
      expect(owned.closed, isTrue);
    },
  );

  test('writing after close throws Disconnected', () async {
    final channel = SlipSerialDfuChannel(_LoopbackTransport());
    await channel.close();
    await expectLater(
      channel.writeControl(Uint8List.fromList(const [1])),
      throwsA(isA<Disconnected>()),
    );
  });

  test('a link loss on state ends responses with one Disconnected', () async {
    final t = _LoopbackTransport();
    final channel = SlipSerialDfuChannel(t);
    final events = <Object>[];
    var done = false;
    channel.responses.listen(
      events.add,
      onError: events.add,
      onDone: () => done = true,
    );

    // The real signal: `state` says the link is gone while `incoming` stays
    // open and silent, exactly as SerialTransport and BleTransport behave.
    t.dropLink();
    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(1));
    expect(events.single, isA<Disconnected>());
    expect(done, isTrue);
    await expectLater(
      channel.writeControl(Uint8List.fromList(const [1])),
      throwsA(isA<Disconnected>()),
    );
  });

  test('the channel closing its own transport reports no drop', () async {
    final t = _LoopbackTransport();
    final channel = SlipSerialDfuChannel(t, ownsTransport: true);
    final events = <Object>[];
    channel.responses.listen(events.add, onError: events.add);

    await channel.close();
    await Future<void>.delayed(Duration.zero);

    // close() puts TransportClosed(requested) on `state`; that is this
    // channel's own doing and must not surface as a link failure.
    expect(events, isEmpty);
  });

  test(
    'a non-conforming error on incoming ends responses with one Disconnected',
    () async {
      final t = _LoopbackTransport();
      final channel = SlipSerialDfuChannel(t);
      final events = <Object>[];
      var done = false;
      channel.responses.listen(
        events.add,
        onError: events.add,
        onDone: () => done = true,
      );

      t.fail(const Disconnected('the cable came out'));
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.single, isA<Disconnected>());
      expect(done, isTrue);
      await expectLater(
        channel.writeControl(Uint8List.fromList(const [1])),
        throwsA(isA<Disconnected>()),
      );
    },
  );

  test('a non-transport error surfaces as Disconnected', () async {
    final t = _LoopbackTransport();
    final channel = SlipSerialDfuChannel(t);
    final events = <Object>[];
    channel.responses.listen(events.add, onError: events.add);

    t.fail(StateError('the driver blew up'));
    await Future<void>.delayed(Duration.zero);

    expect(events.single, isA<Disconnected>());
  });

  test('an error on an owned transport still closes it on close()', () async {
    final t = _LoopbackTransport();
    final channel = SlipSerialDfuChannel(t, ownsTransport: true);
    channel.responses.listen(null, onError: (Object _) {});

    t.fail(const Disconnected('the cable came out'));
    await Future<void>.delayed(Duration.zero);
    expect(t.closed, isFalse, reason: 'the drop path must not close it early');

    await channel.close();
    expect(t.closed, isTrue, reason: 'the serial port handle would leak');
  });

  test('the incoming stream ending closes responses', () async {
    final t = _LoopbackTransport();
    final channel = SlipSerialDfuChannel(t);
    var done = false;
    channel.responses.listen(null, onDone: () => done = true);

    await t.endIncoming();
    await Future<void>.delayed(Duration.zero);

    expect(done, isTrue);
    await expectLater(
      channel.writeData(Uint8List.fromList(const [1])),
      throwsA(isA<Disconnected>()),
    );
  });

  test('open() raises maxDataWrite from the bootloader MTU', () async {
    final t = _LoopbackTransport();
    final channel = SlipSerialDfuChannel(t);
    expect(channel.maxDataWrite, 64);
    final opened = channel.open();
    await pumpEventQueue();
    // The channel asked, SLIP-framed, before anything else went out.
    expect(t.written.single, Slip.encode(<int>[0x07]));
    // 2051 = 0x0803, little-endian in the response payload.
    t.deliver(Slip.encode(<int>[0x60, 0x07, 0x01, 0x03, 0x08]));
    await opened;
    expect(channel.maxDataWrite, 1024);
    await channel.close();
  });

  test('a bootloader without the opcode keeps the fallback', () async {
    final t = _LoopbackTransport();
    final channel = SlipSerialDfuChannel(t);
    final opened = channel.open();
    await pumpEventQueue();
    t.deliver(Slip.encode(<int>[0x60, 0x07, 0x02]));
    await opened;
    expect(channel.maxDataWrite, 64);
    await channel.close();
  });

  test('a silent bootloader keeps the fallback and does not hang', () async {
    final t = _LoopbackTransport();
    final channel = SlipSerialDfuChannel(
      t,
      mtuTimeout: const Duration(milliseconds: 10),
    );
    await channel.open();
    expect(channel.maxDataWrite, 64);
    await channel.close();
  });

  test(
    'the negotiated size never outgrows the transport write limit',
    () async {
      // 2 * (payload + 1) + 1 <= maxWriteLength is the worst-case SLIP
      // frame, so a 261-byte limit caps the payload at 129 even though the
      // device offered 1024.
      final t = _LoopbackTransport(maxWriteLength: 261);
      final channel = SlipSerialDfuChannel(t);
      final opened = channel.open();
      await pumpEventQueue();
      t.deliver(Slip.encode(<int>[0x60, 0x07, 0x01, 0x03, 0x08]));
      await opened;
      expect(channel.maxDataWrite, 129);
      await channel.close();
    },
  );

  test('negotiateMtu: false writes nothing on open', () async {
    final t = _LoopbackTransport();
    final channel = SlipSerialDfuChannel(t, negotiateMtu: false);
    await channel.open();
    expect(t.written, isEmpty);
    expect(channel.maxDataWrite, 64);
    await channel.close();
  });

  test('concurrent writes are serialised in call order', () async {
    final t = _LoopbackTransport();
    final channel = SlipSerialDfuChannel(t);
    final gate = Completer<void>();
    t.writeGate = gate;

    final first = channel.writeControl(Uint8List.fromList(const [0x01]));
    final second = channel.writeData(Uint8List.fromList(const [0x02]));
    await Future<void>.delayed(Duration.zero);
    expect(t.written, isEmpty, reason: 'both writes wait on the gate');

    gate.complete();
    await Future.wait(<Future<void>>[first, second]);

    expect(t.written, <List<int>>[
      Slip.encode(const [0x01]),
      Slip.encode(const [0x08, 0x02]),
    ]);
  });
}
