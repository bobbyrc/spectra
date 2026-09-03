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
import 'state_stream.dart';

part 'session_handshake.dart';

/// Owns one connection: the state machine, the cached device state and the
/// one place commands are sent (spec 4.3).
///
/// The handshake and the tolerant background load live in the
/// `session_handshake.dart` part, so this file stays the state machine.
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

  // Filled in by the polling task; the hooks exist here so the state machine
  // can stop the poll from one place.
  Timer? _pollTimer;

  bool get isReady => connectionState.value is SessionReady;

  DeviceInfo get _requireInfo {
    final i = deviceInfo.value;
    if (i == null) throw const SessionNotReady('no device info');
    return i;
  }

  /// Opens the transport and runs the handshake. Throws, leaving the session
  /// disconnected, when either fails.
  Future<void> open() async {
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
    await transport.close();
    if (connectionState.value is! SessionDisconnected) {
      connectionState.set(const SessionDisconnected(DisconnectCause.requested));
    }
    await _transportSub?.cancel();
    _transportSub = null;
    await _dispatcher.dispose();
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

  void _startPolling() {}

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}
