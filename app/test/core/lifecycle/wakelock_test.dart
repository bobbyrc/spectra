import 'package:chameleon/chameleon.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/lifecycle/wakelock.dart';

final class RecordingGateway implements WakelockGateway {
  final List<bool> calls = <bool>[];
  @override
  Future<void> enable() async => calls.add(true);
  @override
  Future<void> disable() async => calls.add(false);
}

/// A gateway with no plugin behind it, like a widget test's binding.
final class _ThrowingGateway implements WakelockGateway {
  @override
  Future<void> enable() async => throw MissingPluginException('no plugin');
  @override
  Future<void> disable() async => throw MissingPluginException('no plugin');
}

void main() {
  test('a gateway with no plugin behind it does not escape poll', () async {
    final controller = WakelockController(
      gateway: _ThrowingGateway(),
      shouldHold: () => true,
    );

    // An escaping error here would be an unhandled async error off the
    // poll timer, which fails the app (and this test) outright.
    await controller.poll();

    expect(controller.held, isTrue);
    controller.stop();
  });

  test('holds while asked to and releases once when no longer asked', () async {
    var wanted = false;
    final gateway = RecordingGateway();
    final controller = WakelockController(
      gateway: gateway,
      shouldHold: () => wanted,
    );

    await controller.poll();
    expect(gateway.calls, isEmpty, reason: 'nothing to hold yet');

    wanted = true;
    await controller.poll();
    await controller.poll();
    expect(gateway.calls, <bool>[true], reason: 'enabled exactly once');
    expect(controller.held, isTrue);

    wanted = false;
    await controller.poll();
    await controller.poll();
    expect(gateway.calls, <bool>[true, false]);
    expect(controller.held, isFalse);
  });

  test('a reader lease asks for the wakelock', () async {
    final session = DeviceSession(FakeDevice());
    await session.open();

    expect(
      sessionNeedsWakelock(session, session.connectionState.value),
      isFalse,
    );

    final lease = await session.acquireReaderMode();
    expect(
      sessionNeedsWakelock(session, session.connectionState.value),
      isTrue,
    );
    await lease.release();
    expect(
      sessionNeedsWakelock(session, session.connectionState.value),
      isFalse,
    );

    await session.close();
  });

  test('an updating session asks for the wakelock', () {
    expect(sessionNeedsWakelock(null, const SessionUpdating()), isTrue);
  });

  test('no session asks for nothing', () {
    expect(
      sessionNeedsWakelock(
        null,
        const SessionDisconnected(DisconnectCause.requested),
      ),
      isFalse,
    );
  });
}
