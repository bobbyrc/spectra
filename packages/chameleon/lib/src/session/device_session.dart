import 'dart:async';

import 'package:meta/meta.dart';

import '../commands/device.dart';
import '../model/enums.dart';
import '../model/models.dart';
import '../protocol/command.dart';
import '../protocol/errors.dart';
import '../transport/frame_log.dart';
import '../transport/transport.dart';
import 'cancel_token.dart';
import 'connection_state.dart';
import 'dispatcher.dart';
import 'reader_lease.dart';
import 'state_stream.dart';

part 'session_handshake.dart';
part 'session_polling.dart';

/// Owns one connection: the state machine, the cached device state and the
/// one place commands are sent (spec 4.3).
///
/// The handshake and the tolerant background load live in the
/// `session_handshake.dart` part, and the reader lease, busy tracking and the
/// idle poll in `session_polling.dart`, so this file stays the state machine.
///
/// A terminal transport close (anything but the reboot an [SessionUpdating]
/// session asked for) releases the dispatcher and the transport subscription
/// on its own, but deliberately leaves the state streams open so the app can
/// still read the last known state. [close] is therefore mandatory for every
/// session, disconnected or not: it is the only thing that closes
/// [connectionState] and its siblings.
final class DeviceSession {
  DeviceSession(
    this.transport, {
    this.idlePollInterval = const Duration(seconds: 3),
    this.batteryDelay = const Duration(seconds: 5),
    FrameLog? frameLog,
  }) : frameLog = frameLog ?? FrameLog() {
    // One dispatcher for the life of the session: it survives a transport
    // that closes and opens again (a bootloader reboot), and is disposed
    // only by [close].
    _dispatcher = CommandDispatcher(transport, log: this.frameLog);
    _transportSub = transport.state.listen(_onTransportState);
  }

  static const int supportedMajor = 2;

  final Transport transport;
  final FrameLog frameLog;
  final Duration idlePollInterval;
  final Duration batteryDelay;

  final StateStream<ConnectionState> connectionState = StateStream(
    const SessionDisconnected(DisconnectCause.requested),
  );
  final StateStream<DeviceInfo?> deviceInfo = StateStream(null);
  final StateStream<List<Slot>> slotsState = StateStream(const []);
  final StateStream<int?> activeSlot = StateStream(null);
  final StateStream<DeviceSettings?> settingsState = StateStream(null);
  final StateStream<BatteryInfo?> battery = StateStream(null);
  final StateStream<DeviceMode?> mode = StateStream(null);

  final StreamController<ChameleonException> _backgroundErrors =
      StreamController.broadcast();

  /// Failures from the tolerant background load and the idle poll. A session
  /// is never refused because one of these failed.
  Stream<ChameleonException> get backgroundErrors => _backgroundErrors.stream;

  late final CommandDispatcher _dispatcher;
  StreamSubscription<TransportState>? _transportSub;
  DateTime? _readyAt;

  /// The in-flight [open], so a second call joins it rather than running a
  /// second handshake down the same transport.
  Future<void>? _opening;

  /// [close] was called; a session is not reopenable.
  bool _shutDown = false;

  // Owned by the `session_polling.dart` part: an extension cannot hold state,
  // so the lease count, the busy depth and the poll timer live here.
  Timer? _pollTimer;
  int _leases = 0;
  int _busy = 0;
  bool _polling = false;
  Future<void>? _modeSwitch;
  DeviceMode? _modeSwitchTarget;

  bool get isReady => connectionState.value is SessionReady;

  DeviceInfo get _requireInfo {
    final i = deviceInfo.value;
    if (i == null) throw const SessionNotReady('no device info');
    return i;
  }

  /// Opens the transport and runs the handshake. Throws, leaving the session
  /// disconnected, when either fails.
  ///
  /// Re-entrant calls join the open already in flight; opening a session that
  /// is already connected, or one that has been closed, is a programming
  /// error and throws [StateError].
  Future<void> open() async {
    final pending = _opening;
    if (pending != null) return pending;
    if (_shutDown) throw StateError('this session has been closed');
    final state = connectionState.value;
    if (state is! SessionDisconnected) {
      throw StateError('session is already ${state.runtimeType}');
    }
    final opening = _open();
    _opening = opening;
    try {
      await opening;
    } finally {
      _opening = null;
    }
  }

  Future<void> _open() async {
    connectionState.set(const SessionConnecting());
    try {
      await transport.open();
    } on ChameleonException catch (e) {
      connectionState.set(
        SessionDisconnected(DisconnectCause.unexpected, error: e),
      );
      rethrow;
    }
    try {
      await _handshake();
    } on ChameleonException catch (e) {
      connectionState.set(
        SessionDisconnected(DisconnectCause.unexpected, error: e),
      );
      await transport.close();
      rethrow;
    }
  }

  /// Sends a command. Internal to the SDK; app code uses the facades.
  ///
  /// Refused unless the session is ready (or updating, where the DFU path
  /// still talks to the device). A limited session opts in explicitly with
  /// [allowLimited], which is how ENTER_BOOTLOADER stays reachable on
  /// firmware too old to support anything else.
  @internal
  Future<R> send<R>(
    Command<R> command, {
    CancelToken? cancel,
    bool allowLimited = false,
  }) async {
    final state = connectionState.value;
    final ok =
        state is SessionReady ||
        state is SessionUpdating ||
        (allowLimited && state is SessionLimited);
    if (!ok) throw SessionNotReady('session is ${state.runtimeType}');
    return _sendRaw(command, cancel: cancel);
  }

  /// [send] without the state check, for the handshake. One retry on timeout,
  /// and only for idempotent reads: re-sending a write after a timeout could
  /// apply it twice.
  Future<R> _sendRaw<R>(Command<R> command, {CancelToken? cancel}) async {
    try {
      return await _dispatch(command, cancel: cancel);
    } on CommandTimeout {
      if (!command.idempotent) rethrow;
      return _dispatch(command, cancel: cancel);
    }
  }

  Future<R> _dispatch<R>(Command<R> command, {CancelToken? cancel}) async {
    final frame = await _dispatcher.send(
      command.toFrame(),
      timeout: command.timeout,
      expectsResponse: command.expectsResponse,
      cancel: cancel,
    );
    // Only a VoidCommand may skip its response, so R is void here.
    if (frame == null) return null as R;
    return command.parseResponse(frame);
  }

  /// Closes the transport and shuts the session down for good: every state
  /// stream and the error stream are closed and the dispatcher is disposed.
  Future<void> close() async {
    _stopPolling();
    _forgetLeases();
    await transport.close();
    if (connectionState.value is! SessionDisconnected) {
      connectionState.set(const SessionDisconnected(DisconnectCause.requested));
    }
    _shutDown = true;
    await _releaseTransport();
    await _closeStreams();
  }

  void _onTransportState(TransportState s) {
    if (s is! TransportClosed) return;
    // Nothing to poll once the link is gone, whatever the session state
    // becomes: an updating session is waiting for the device to come back.
    _stopPolling();
    final current = connectionState.value;
    final next = stateAfterClose(s, current);
    if (identical(next, current)) return;
    if (current is! SessionDisconnected) connectionState.set(next);
    // Terminal: nothing more will come down this link. Whatever the device's
    // mode was, no lease means anything now. Release the dispatcher and the
    // subscription too, but leave the state streams to [close].
    _forgetLeases();
    unawaited(_releaseTransport());
  }

  /// Drops everything tied to the transport. Idempotent.
  Future<void> _releaseTransport() async {
    await _transportSub?.cancel();
    _transportSub = null;
    await _dispatcher.dispose();
  }

  void _reportBackground(ChameleonException e) {
    if (!_backgroundErrors.isClosed) _backgroundErrors.add(e);
  }

  Future<void> _closeStreams() async {
    await Future.wait([
      connectionState.close(),
      deviceInfo.close(),
      slotsState.close(),
      activeSlot.close(),
      settingsState.close(),
      battery.close(),
      mode.close(),
      if (!_backgroundErrors.isClosed) _backgroundErrors.close(),
    ]);
  }
}
