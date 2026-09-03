import 'package:chameleon/src/model/enums.dart';
import 'package:chameleon/src/model/models.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:chameleon/src/session/connection_state.dart';
import 'package:chameleon/src/transport/transport.dart';
import 'package:test/test.dart';

const _ready = SessionReady(
  DeviceInfo(
    model: DeviceModel.ultra,
    version: FirmwareVersion(major: 2, minor: 2),
    capabilities: Capabilities({}),
  ),
);

void main() {
  test('a requested close is a requested disconnect', () {
    for (final current in const <ConnectionState>[
      SessionConnecting(),
      _ready,
      SessionLimited(UnsupportedReason.preTwoPointZero),
      SessionUpdating(),
    ]) {
      final next = stateAfterClose(
        const TransportClosed(CloseCause.requested),
        current,
      );
      expect(
        next,
        isA<SessionDisconnected>().having(
          (d) => d.cause,
          'cause',
          DisconnectCause.requested,
        ),
        reason: 'from ${current.runtimeType}',
      );
    }
  });

  test('an expected close while updating keeps the session updating', () {
    const current = SessionUpdating();
    expect(
      stateAfterClose(const TransportClosed(CloseCause.expected), current),
      same(current),
    );
  });

  test('an expected close in any other state ends the session', () {
    for (final current in const <ConnectionState>[
      SessionConnecting(),
      _ready,
      SessionLimited(UnsupportedReason.preTwoPointZero),
    ]) {
      expect(
        stateAfterClose(const TransportClosed(CloseCause.expected), current),
        isA<SessionDisconnected>().having(
          (d) => d.cause,
          'cause',
          DisconnectCause.expected,
        ),
        reason: 'from ${current.runtimeType}',
      );
    }
  });

  test('a lost link is an unexpected disconnect, even while updating', () {
    for (final current in const <ConnectionState>[
      SessionConnecting(),
      _ready,
      SessionLimited(UnsupportedReason.preTwoPointZero),
      SessionUpdating(),
    ]) {
      expect(
        stateAfterClose(const TransportClosed(CloseCause.linkLost), current),
        isA<SessionDisconnected>().having(
          (d) => d.cause,
          'cause',
          DisconnectCause.unexpected,
        ),
        reason: 'from ${current.runtimeType}',
      );
    }
  });

  test('the transport error is carried onto the disconnect', () {
    final next = stateAfterClose(
      const TransportClosed(CloseCause.linkLost, error: PermissionDenied()),
      const SessionConnecting(),
    );
    expect((next as SessionDisconnected).error, isA<PermissionDenied>());
  });
}
