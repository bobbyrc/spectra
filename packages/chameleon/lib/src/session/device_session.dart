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
import 'facades/device.dart';
import 'facades/emulator.dart';
import 'facades/firmware.dart';
import 'facades/reader.dart';
import 'facades/settings.dart';
import 'facades/slots.dart';
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

  /// Timeout for the two handshake probes (1035 and 1000), which are sent to
  /// a device that may not answer them at all. A silent pre-2.0 device must
  /// reach [SessionLimited] in seconds, not in two full command timeouts
  /// with a retry each.
  static const Duration probeTimeout = Duration(seconds: 1);

  /// The firmware has eight emulation slots, fixed by the protocol.
  static const int slotCount = 8;

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

  /// The app-facing API. [send] is internal to the SDK: everything an app
  /// does to the device goes through one of these, so the write-through of
  /// the caches above lives in one place per feature.
  late final DeviceFacade device = DeviceFacade(this);
  late final SlotsFacade slots = SlotsFacade(this);
  late final SettingsFacade settings = SettingsFacade(this);
  late final EmulatorFacade emulator = EmulatorFacade(this);
  late final ReaderFacade reader = ReaderFacade(this);
  late final FirmwareFacade firmware = FirmwareFacade(this);

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

  /// The dispatcher has been released, so this session can never talk to a
  /// device again — see [open].
  bool _spent = false;

  /// A transport state that explains why the current [open] cannot succeed
  /// (pairing, permission, adapter), if one arrived during it.
  TransportError? _connectFailure;

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
  /// Re-entrant calls join the open already in flight. Opening a session that
  /// is already connected, one that has been closed, or one that is spent —
  /// its transport released after a disconnect — is a programming error and
  /// throws [StateError]; reconnecting means a new [DeviceSession].
  Future<void> open() async {
    final pending = _opening;
    if (pending != null) return pending;
    if (_shutDown) throw StateError('this session has been closed');
    if (_spent) {
      throw StateError('this session is spent; create a new DeviceSession');
    }
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
    _connectFailure = null;
    connectionState.set(const SessionConnecting());
    try {
      await transport.open();
    } on ChameleonException catch (e) {
      throw _failOpen(_connectFailure ?? e);
    }
    final early = _connectFailure;
    if (early != null) {
      await transport.close();
      throw _failOpen(early);
    }
    try {
      await _handshake();
    } on ChameleonException catch (e) {
      // A transport that reported pairing, permission or adapter trouble
      // while the handshake was in flight explains the failure better than
      // the Disconnected the in-flight command saw.
      final failure = _failOpen(_connectFailure ?? e);
      await transport.close();
      throw failure;
    }
  }

  /// Records [e] as the reason this session is not connected, unless a
  /// transport state event has already landed the session on one. Returns
  /// the error [open] should throw.
  ChameleonException _failOpen(ChameleonException e) {
    if (connectionState.value is! SessionDisconnected) {
      connectionState.set(
        SessionDisconnected(DisconnectCause.unexpected, error: e),
      );
    }
    return e;
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
    if (!ok) {
      // A limited session is refused for a reason the app can act on: the
      // firmware is too old, too new, or the legacy build. SessionNotReady
      // stays for the states that are only a matter of timing.
      if (state is SessionLimited) {
        throw UnsupportedFirmware(
          state.reason,
          'firmware ${state.version?.label ?? 'unknown'} is not supported '
          '(${state.reason.name})',
        );
      }
      throw SessionNotReady('session is ${state.runtimeType}');
    }
    return _sendRaw(command, cancel: cancel);
  }

  /// [send] without the state check, for the handshake. One retry on timeout,
  /// and only for idempotent reads: re-sending a write after a timeout could
  /// apply it twice.
  Future<R> _sendRaw<R>(
    Command<R> command, {
    CancelToken? cancel,
    Duration? timeout,
    bool retry = true,
  }) async {
    try {
      return await _dispatch(command, cancel: cancel, timeout: timeout);
    } on CommandTimeout {
      if (!retry || !command.idempotent) rethrow;
      return _dispatch(command, cancel: cancel, timeout: timeout);
    }
  }

  Future<R> _dispatch<R>(
    Command<R> command, {
    CancelToken? cancel,
    Duration? timeout,
  }) async {
    final frame = await _dispatcher.send(
      command.toFrame(),
      timeout: timeout ?? command.timeout,
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
    // Pairing, permission and adapter states are not closes, but they mean
    // the same thing to a session: this link will carry nothing. They are
    // mapped to a disconnect carrying the matching typed error so the app
    // can show the right step (spec 5.1).
    final failure = _transportFailure(s);
    if (failure != null) _connectFailure = failure;
    final closed = failure == null
        ? s
        : TransportClosed(CloseCause.linkLost, error: failure);
    if (closed is! TransportClosed) return;
    // Nothing to poll once the link is gone, whatever the session state
    // becomes: an updating session is waiting for the device to come back.
    _stopPolling();
    final current = connectionState.value;
    final next = stateAfterClose(closed, current);
    if (identical(next, current)) return;
    if (current is! SessionDisconnected) connectionState.set(next);
    // Terminal: nothing more will come down this link. Whatever the device's
    // mode was, no lease means anything now. Release the dispatcher and the
    // subscription too, but leave the state streams to [close].
    _forgetLeases();
    unawaited(_releaseTransport());
  }

  /// Drops everything tied to the transport. Idempotent.
  static TransportError? _transportFailure(TransportState s) => switch (s) {
    TransportPairingRequired() => const PairingRequired(),
    TransportPermissionDenied() => const PermissionDenied(),
    TransportAdapterOff() => const AdapterOff(),
    _ => null,
  };

  Future<void> _releaseTransport() async {
    _spent = true;
    // Not awaited: a StreamSubscription's cancel() removes the listener
    // synchronously, but the Future it returns is only for any async work an
    // `onCancel` callback does (there is none here). Awaiting it anyway is
    // harmless in production, but under a virtual clock — the FakeAsync zone
    // flutter_test's widget tests run in — that Future never completes for
    // *any* controller, broadcast or single-subscription (a
    // dart:async/fake_async interaction with StreamSubscription.cancel(),
    // not a logic bug), which would hang every close() a widget test runs
    // after a failed connect.
    unawaited(_transportSub?.cancel());
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
