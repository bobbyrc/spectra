import 'dart:async';

import 'package:chameleon/src/codec/frame.dart';
import 'package:chameleon/src/codec/frame_decoder.dart';
import 'package:chameleon/src/commands/device.dart';
import 'package:chameleon/src/fake/fake_device.dart';
import 'package:chameleon/src/fake/fake_scanner.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:chameleon/src/session/dispatcher.dart';
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

  test('a corrupted response is rejected by the decoder, end to end', () async {
    // corruptNextResponse flips the LRC, so the frame must never reach a
    // caller: the dispatcher sees a diagnostic and the command times out.
    final d = FakeDevice();
    await d.open();
    final diagnostics = <DecodeDiagnostic>[];
    final dispatcher = CommandDispatcher(
      d,
      drainWindow: const Duration(milliseconds: 20),
      onDiagnostic: diagnostics.add,
    );
    d.corruptNextResponse();
    await expectLater(
      dispatcher.send(
        const GetAppVersion().toFrame(),
        timeout: const Duration(milliseconds: 60),
      ),
      throwsA(isA<CommandTimeout>()),
    );
    expect(diagnostics, isNotEmpty);
    // Only the next response is corrupted; the one after it is clean.
    final f = await dispatcher.send(
      const GetAppVersion().toFrame(),
      timeout: const Duration(seconds: 1),
    );
    expect(f!.command, 1000);
    await dispatcher.dispose();
    await d.close();
  });

  test('close closes the streams the device owns', () async {
    final d = FakeDevice();
    await d.open();
    final states = <TransportState>[];
    final bytes = <int>[];
    final stateDone = Completer<void>();
    final incomingDone = Completer<void>();
    d.state.listen(states.add, onDone: stateDone.complete);
    d.incoming.listen((c) => bytes.addAll(c), onDone: incomingDone.complete);
    await d.close();
    await stateDone.future.timeout(const Duration(seconds: 1));
    await incomingDone.future.timeout(const Duration(seconds: 1));
    expect(states.last, isA<TransportClosed>());
    expect(bytes, isEmpty);
  });

  test('a stalled write completes only once released', () async {
    final d = FakeDevice()..stallWrites();
    await d.open();
    var done = false;
    final write = d.write(const GetAppVersion().toFrame().encode());
    unawaited(write.then((_) => done = true));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(done, isFalse);
    expect(d.writes, hasLength(1));
    expect(d.received, isEmpty);
    d.releaseWrites();
    await write;
    expect(d.received.single.command, 1000);
    await d.close();
  });

  test('failNextWrite fails one write, then the link works again', () async {
    final d = FakeDevice()..failNextWrite();
    await d.open();
    await expectLater(
      d.write(const GetAppVersion().toFrame().encode()),
      throwsA(isA<PortBusy>()),
    );
    final resp = await roundTrip(d, const GetAppVersion().toFrame());
    expect(resp.command, 1000);
    await d.close();
  });
}
