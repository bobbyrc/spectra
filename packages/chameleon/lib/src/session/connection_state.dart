import '../model/models.dart';
import '../protocol/errors.dart';
import '../transport/transport.dart';

enum DisconnectCause { requested, expected, unexpected }

sealed class ConnectionState {
  const ConnectionState();
}

final class SessionConnecting extends ConnectionState {
  const SessionConnecting();
}

final class SessionReady extends ConnectionState {
  const SessionReady(this.info);
  final DeviceInfo info;
}

/// Transport open, firmware unsupported. Only ENTER_BOOTLOADER is allowed.
final class SessionLimited extends ConnectionState {
  const SessionLimited(this.reason, {this.version});
  final UnsupportedReason reason;
  final FirmwareVersion? version;
}

/// ENTER_BOOTLOADER was sent on purpose; the coming close is expected.
final class SessionUpdating extends ConnectionState {
  const SessionUpdating();
}

final class SessionDisconnected extends ConnectionState {
  const SessionDisconnected(this.cause, {this.error});
  final DisconnectCause cause;
  final ChameleonException? error;
}

/// The session state a transport close produces, given the state the session
/// was in when the link went away (spec 4.3).
///
/// [CloseCause.expected] is the firmware rebooting because we asked it to: it
/// only means "not a disconnect" while the session is actually [SessionUpdating]
/// — the same close arriving in any other state is still the end of the
/// session, just not a surprise one.
ConnectionState stateAfterClose(
  TransportClosed closed,
  ConnectionState current,
) {
  if (closed.cause == CloseCause.expected && current is SessionUpdating) {
    return current;
  }
  final cause = switch (closed.cause) {
    CloseCause.requested => DisconnectCause.requested,
    CloseCause.expected => DisconnectCause.expected,
    CloseCause.linkLost => DisconnectCause.unexpected,
  };
  return SessionDisconnected(cause, error: closed.error);
}
