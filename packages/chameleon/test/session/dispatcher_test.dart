import 'dart:async';
import 'dart:typed_data';

import 'package:chameleon/src/codec/frame.dart';
import 'package:chameleon/src/commands/device.dart';
import 'package:chameleon/src/fake/fake_device.dart';
import 'package:chameleon/src/fake/fake_firmware.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:chameleon/src/session/cancel_token.dart';
import 'package:chameleon/src/session/dispatcher.dart';
import 'package:chameleon/src/transport/frame_log.dart';
import 'package:chameleon/src/transport/transport.dart';
import 'package:test/test.dart';

const short = Duration(milliseconds: 40);
const patient = Duration(seconds: 1);

void main() {
  late FakeDevice device;
  late CommandDispatcher dispatcher;
  late List<Frame> unexpected;

  setUp(() async {
    device = FakeDevice();
    await device.open();
    dispatcher = CommandDispatcher(device);
    unexpected = [];
    dispatcher.unexpectedFrames.listen(unexpected.add);
  });

  tearDown(() => dispatcher.dispose());

  test('sends and receives one response', () async {
    final f = await dispatcher.send(
      const GetAppVersion().toFrame(),
      timeout: short,
    );
    expect(const GetAppVersion().parseResponse(f!).label, '2.2');
    expect(dispatcher.isIdle, isTrue);
  });

  test('serializes concurrent sends in order', () async {
    final results = await Future.wait([
      dispatcher.send(const GetAppVersion().toFrame(), timeout: short),
      dispatcher.send(const GetActiveSlot().toFrame(), timeout: short),
      dispatcher.send(const GetDeviceModel().toFrame(), timeout: short),
    ]);
    expect(results.map((f) => f!.command), [1000, 1018, 1033]);
    expect(device.received.map((f) => f.command), [1000, 1018, 1033]);
  });

  test('times out when the response is dropped', () async {
    device.dropNextResponse();
    await expectLater(
      dispatcher.send(const GetAppVersion().toFrame(), timeout: short),
      throwsA(isA<CommandTimeout>()),
    );
  });

  test('a late response is drained, not matched to the next command', () async {
    device.delayNextResponse(const Duration(milliseconds: 60));
    await expectLater(
      dispatcher.send(const GetActiveSlot().toFrame(), timeout: short),
      throwsA(isA<CommandTimeout>()),
    );
    device.firmware.activeSlot = 5;
    final f = await dispatcher.send(
      const GetActiveSlot().toFrame(),
      timeout: patient,
    );
    expect(const GetActiveSlot().parseResponse(f!), 5);
  });

  test(
    'a stale response to a timed-out command is dropped, not surfaced',
    () async {
      device.delayNextResponse(const Duration(milliseconds: 60));
      await expectLater(
        dispatcher.send(const GetActiveSlot().toFrame(), timeout: short),
        throwsA(isA<CommandTimeout>()),
      );
      // The drain window (40 ms after the timeout) outlasts the 60 ms delay,
      // so the stale frame is consumed silently.
      final watch = Stopwatch()..start();
      await dispatcher.send(const GetDeviceModel().toFrame(), timeout: patient);
      watch.stop();
      expect(unexpected, isEmpty);
      expect(watch.elapsedMilliseconds, lessThan(500));
    },
  );

  test('nothing is dispatched while draining', () async {
    device.dropNextResponse();
    final first = dispatcher.send(
      const GetAppVersion().toFrame(),
      timeout: short,
    );
    final second = dispatcher.send(
      const GetActiveSlot().toFrame(),
      timeout: patient,
    );
    await expectLater(first, throwsA(isA<CommandTimeout>()));
    expect(device.received.length, 1);
    await second;
    expect(device.received.length, 2);
  });

  test('cancelling a queued command rejects it without sending', () async {
    device.delayNextResponse(const Duration(milliseconds: 30));
    final first = dispatcher.send(
      const GetAppVersion().toFrame(),
      timeout: patient,
    );
    final token = CancelToken();
    final second = dispatcher.send(
      const GetActiveSlot().toFrame(),
      timeout: short,
      cancel: token,
    );
    token.cancel();
    await expectLater(second, throwsA(isA<CommandCancelled>()));
    await first;
    expect(device.received.map((f) => f.command), [1000]);
  });

  test(
    'cancelling the in-flight command drains before the next send',
    () async {
      device.delayNextResponse(const Duration(milliseconds: 60));
      final token = CancelToken();
      final first = dispatcher.send(
        const GetAppVersion().toFrame(),
        timeout: patient,
        cancel: token,
      );
      token.cancel();
      await expectLater(first, throwsA(isA<CommandCancelled>()));
      final f = await dispatcher.send(
        const GetActiveSlot().toFrame(),
        timeout: patient,
      );
      expect(f!.command, 1018);
    },
  );

  test(
    'a cancelled command\'s late response ends draining and is dropped',
    () async {
      device.delayNextResponse(const Duration(milliseconds: 60));
      final token = CancelToken();
      final first = dispatcher.send(
        const GetAppVersion().toFrame(),
        timeout: patient,
        cancel: token,
      );
      token.cancel();
      // The future is rejected immediately, well before the response arrives.
      await expectLater(first, throwsA(isA<CommandCancelled>()));
      expect(dispatcher.isIdle, isFalse, reason: 'still draining');

      // The late response ends the drain rather than waiting out the 1 s drain
      // timer, and never reaches unexpectedFrames.
      final watch = Stopwatch()..start();
      final f = await dispatcher.send(
        const GetActiveSlot().toFrame(),
        timeout: patient,
      );
      watch.stop();
      expect(f!.command, 1018);
      expect(unexpected, isEmpty);
      expect(watch.elapsedMilliseconds, lessThan(500));
    },
  );

  test('no-response commands complete with null immediately', () async {
    final f = await dispatcher.send(
      const EnterBootloader().toFrame(),
      timeout: short,
      expectsResponse: false,
    );
    expect(f, isNull);
  });

  test('link loss fails pending, queued and later commands', () async {
    device.dropNextResponse();
    final pending = dispatcher.send(
      const GetAppVersion().toFrame(),
      timeout: const Duration(seconds: 5),
    );
    final queued = dispatcher.send(
      const GetActiveSlot().toFrame(),
      timeout: const Duration(seconds: 5),
    );
    await device.simulateLinkLoss();
    await expectLater(pending, throwsA(isA<Disconnected>()));
    await expectLater(queued, throwsA(isA<Disconnected>()));
    await expectLater(
      dispatcher.send(const GetActiveSlot().toFrame(), timeout: short),
      throwsA(isA<Disconnected>()),
    );
  });

  test('records both directions in the frame log', () async {
    final log = FrameLog();
    final d = CommandDispatcher(device, log: log);
    await d.send(const GetAppVersion().toFrame(), timeout: short);
    expect(log.entries.map((e) => e.direction), [
      FrameDirection.sent,
      FrameDirection.received,
    ]);
    await d.dispose();
  });

  test('frames for no pending command go to unexpectedFrames', () async {
    await device.write(const GetActiveSlot().toFrame().encode());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(unexpected.map((f) => f.command), [1018]);
  });

  test('send after dispose fails with Disconnected', () async {
    await dispatcher.dispose();
    await expectLater(
      dispatcher.send(const GetAppVersion().toFrame(), timeout: short),
      throwsA(isA<Disconnected>()),
    );
  });

  test(
    'a write that never completes still times out, then dispatch resumes',
    () async {
      final t = _StubTransport();
      final d = CommandDispatcher(t);
      await expectLater(
        d.send(const GetAppVersion().toFrame(), timeout: short),
        throwsA(isA<CommandTimeout>()),
      );
      // The drain window elapses and the queue moves on even though the first
      // write never resolved.
      await expectLater(
        d.send(const GetActiveSlot().toFrame(), timeout: short),
        throwsA(isA<CommandTimeout>()),
      );
      expect(t.writes.length, 2);
      await d.dispose();
    },
  );

  test('a write error is forwarded unwrapped', () async {
    final t = _StubTransport(error: StateError('write refused'));
    final d = CommandDispatcher(t);
    Object? err;
    StackTrace? st;
    try {
      await d.send(const GetAppVersion().toFrame(), timeout: patient);
    } catch (e, s) {
      err = e;
      st = s;
    }
    expect(err, isA<StateError>());
    expect(st, isNotNull);
    await d.dispose();
  });

  test('an unopened transport fails sends until it opens', () async {
    final fresh = FakeDevice();
    final d = CommandDispatcher(fresh);
    await expectLater(
      d.send(const GetAppVersion().toFrame(), timeout: short),
      throwsA(isA<TransportError>()),
    );
    await fresh.open();
    await Future<void>.delayed(Duration.zero);
    final f = await d.send(const GetAppVersion().toFrame(), timeout: patient);
    expect(f!.command, 1000);
    await d.dispose();
  });

  test('a close superseded by a reopen does not fail later commands', () async {
    final t = _ManualTransport();
    final d = CommandDispatcher(t);
    await t.open();
    await Future<void>.delayed(Duration.zero);
    final pending = d.send(const GetAppVersion().toFrame(), timeout: patient);
    await Future<void>.delayed(Duration.zero);
    // A close queued before the reopen, delivered after it: the transport is
    // open now, so the stale event must not fail the command in flight.
    t.emit(const TransportClosed(CloseCause.linkLost));
    await Future<void>.delayed(Duration.zero);
    t.deliver(FakeFirmware().handle(const GetAppVersion().toFrame())!.encode());
    final f = await pending;
    expect(f!.command, 1000);
    expect(t.writes, hasLength(1));
    await d.dispose();
  });

  test('completed commands release their cancel registrations', () async {
    final token = CancelToken();
    for (var i = 0; i < 3; i++) {
      await dispatcher.send(
        const GetAppVersion().toFrame(),
        timeout: short,
        cancel: token,
      );
    }
    expect(token.listenerCount, 0);
    device.dropNextResponse();
    await expectLater(
      dispatcher.send(
        const GetActiveSlot().toFrame(),
        timeout: short,
        cancel: token,
      ),
      throwsA(isA<CommandTimeout>()),
    );
    expect(token.listenerCount, 0);
  });
}

/// A transport that is always open and whose write either never completes or
/// fails, for the paths [FakeDevice] cannot reach.
final class _StubTransport implements Transport {
  _StubTransport({this.error});

  final Object? error;
  final List<Uint8List> writes = [];
  final StreamController<Uint8List> _incoming = StreamController.broadcast();
  final StreamController<TransportState> _state = StreamController.broadcast();

  @override
  TransportKind get kind => TransportKind.fake;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  Stream<TransportState> get state => _state.stream;

  @override
  TransportState get currentState => const TransportOpen();

  @override
  Future<void> open() async {}

  @override
  Future<void> close() async {
    await _incoming.close();
    await _state.close();
  }

  @override
  Future<void> write(Uint8List bytes) {
    writes.add(bytes);
    final e = error;
    if (e != null) return Future.error(e, StackTrace.current);
    // Never completes.
    return Completer<void>().future;
  }
}

/// A transport whose state stream and current state are driven by hand, so a
/// test can deliver a state event the transport has already moved past.
final class _ManualTransport implements Transport {
  final StreamController<Uint8List> _incoming = StreamController.broadcast();
  final StreamController<TransportState> _state = StreamController.broadcast();
  final List<Uint8List> writes = [];
  TransportState _current = const TransportClosed(CloseCause.requested);

  void emit(TransportState s) => _state.add(s);

  void deliver(Uint8List bytes) => _incoming.add(bytes);

  @override
  TransportKind get kind => TransportKind.fake;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  Stream<TransportState> get state => _state.stream;

  @override
  TransportState get currentState => _current;

  @override
  Future<void> open() async {
    _current = const TransportOpen();
    emit(_current);
  }

  @override
  Future<void> close() async {
    _current = const TransportClosed(CloseCause.requested);
    emit(_current);
  }

  @override
  Future<void> write(Uint8List bytes) async => writes.add(bytes);
}
