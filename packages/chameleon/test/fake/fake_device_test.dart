import 'dart:async';

import 'package:chameleon/src/codec/frame.dart';
import 'package:chameleon/src/codec/frame_decoder.dart';
import 'package:chameleon/src/commands/device.dart';
import 'package:chameleon/src/fake/fake_device.dart';
import 'package:chameleon/src/fake/fake_scanner.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:chameleon/src/transport/transport.dart';
import 'package:test/test.dart';

Future<Frame> roundTrip(FakeDevice d, Frame req) async {
  final decoder = FrameDecoder();
  final done = Completer<Frame>();
  final sub = d.incoming.listen((chunk) {
    for (final f in decoder.feed(chunk)) {
      if (!done.isCompleted) done.complete(f);
    }
  });
  await d.write(req.encode());
  final f = await done.future.timeout(const Duration(seconds: 1));
  await sub.cancel();
  return f;
}

void main() {
  test('opens, answers in chunks, closes', () async {
    final d = FakeDevice(chunkSize: 3);
    final chunks = <int>[];
    d.incoming.listen((c) => chunks.add(c.length));
    await d.open();
    expect(d.currentState, isA<TransportOpen>());
    final resp = await roundTrip(d, const GetAppVersion().toFrame());
    expect(resp.command, 1000);
    expect(chunks.every((n) => n <= 3), isTrue);
    await d.close();
    expect(d.currentState, isA<TransportClosed>());
  });

  test('write before open throws Disconnected', () async {
    final d = FakeDevice();
    expect(
      () => d.write(const GetAppVersion().toFrame().encode()),
      throwsA(isA<Disconnected>()),
    );
  });

  test('open can fail with a transport error', () async {
    final d = FakeDevice(openError: const PermissionDenied());
    expect(d.open(), throwsA(isA<PermissionDenied>()));
  });

  test('dropNextResponse swallows exactly one response', () async {
    final d = FakeDevice();
    await d.open();
    d.dropNextResponse();
    await d.write(const GetAppVersion().toFrame().encode());
    expect(d.received.length, 1);
    final resp = await roundTrip(d, const GetActiveSlot().toFrame());
    expect(resp.command, 1018);
  });

  test('ENTER_BOOTLOADER causes an expected close, not link loss', () async {
    final d = FakeDevice();
    await d.open();
    final states = <TransportState>[];
    d.state.listen(states.add);
    await d.write(const EnterBootloader().toFrame().encode());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(
      states.last,
      isA<TransportClosed>().having(
        (s) => s.cause,
        'cause',
        CloseCause.expected,
      ),
    );
    expect(d.firmware.bootloaderRequested, isTrue);
    expect(
      () => d.write(const GetAppVersion().toFrame().encode()),
      throwsA(isA<Disconnected>()),
    );
  });

  test('a normal command before ENTER_BOOTLOADER does not close', () async {
    final d = FakeDevice();
    await d.open();
    await d.write(const GetAppVersion().toFrame().encode());
    expect(d.currentState, isA<TransportOpen>());
  });

  test('simulateLinkLoss closes with linkLost', () async {
    final d = FakeDevice();
    await d.open();
    await d.simulateLinkLoss();
    expect((d.currentState as TransportClosed).cause, CloseCause.linkLost);
  });

  test('FakeScanner lists the emulated Ultra once', () async {
    final lists = await FakeScanner().scan().toList();
    expect(lists.single, [FakeScanner.emulatedUltra]);
    expect(FakeScanner.emulatedUltra.kind, TransportKind.fake);
  });
}
