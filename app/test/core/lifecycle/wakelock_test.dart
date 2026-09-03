import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/lifecycle/wakelock.dart';

final class RecordingGateway implements WakelockGateway {
  final List<bool> calls = <bool>[];
  @override
  Future<void> enable() async => calls.add(true);
  @override
  Future<void> disable() async => calls.add(false);
}

void main() {
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
