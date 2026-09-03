import 'dart:async';
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/src/dfu/slip.dart';
import 'package:chameleon_flutter/src/dfu/slip_serial_dfu_channel.dart';
import 'package:flutter_test/flutter_test.dart';

/// A byte pipe standing in for an open serial link.
final class _LoopbackTransport implements Transport {
  final List<Uint8List> written = <Uint8List>[];
  final _incoming = StreamController<Uint8List>.broadcast();
  bool closed = false;

  void deliver(List<int> bytes) => _incoming.add(Uint8List.fromList(bytes));

  @override
  TransportKind get kind => TransportKind.usb;
  @override
  Stream<Uint8List> get incoming => _incoming.stream;
  @override
  Stream<TransportState> get state => const Stream<TransportState>.empty();
  @override
  TransportState get currentState => const TransportOpen();
  @override
  int get maxWriteLength => 4105;
  @override
  Future<void> open() async {}
  @override
  Future<void> close() async {
    closed = true;
    await _incoming.close();
  }

  @override
  Future<void> write(Uint8List bytes) async =>
      written.add(Uint8List.fromList(bytes));
}

void main() {
  test('control writes are SLIP-encoded verbatim', () async {
    final t = _LoopbackTransport();
    final channel = SlipSerialDfuChannel(t);
    await channel.writeControl(Uint8List.fromList(const [0x06, 0x01]));
    expect(t.written.single, Slip.encode(const [0x06, 0x01]));
  });

  test(
    'data writes carry the 0x08 opcode and a little-endian length',
    () async {
      final t = _LoopbackTransport();
      final channel = SlipSerialDfuChannel(t);
      await channel.writeData(Uint8List.fromList(List<int>.filled(300, 0xAB)));
      // 300 = 0x012C -> 0x2C, 0x01.
      expect(
        t.written.single,
        Slip.encode(<int>[0x08, 0x2C, 0x01, ...List<int>.filled(300, 0xAB)]),
      );
    },
  );

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
}
