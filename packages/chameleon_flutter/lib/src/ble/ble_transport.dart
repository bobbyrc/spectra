import 'dart:async';
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';

import '../guidance.dart';
import '../host_platform.dart';
import 'ble_adapter.dart';
import 'ble_chunking.dart';
import 'ble_failure.dart';
import 'ble_uuids.dart';

/// The whole of the largest frame the protocol defines: 4096 data bytes plus
/// the 9-byte header, length and LRCs. Mirrors the SDK's fake device, which
/// is the reference for what [Transport.maxWriteLength] means.
const int _maxFrameLength = 4105;

/// The Nordic UART link to a Chameleon in application mode (spec 5.1).
///
/// Retries connect up to [connectAttempts] times with exponential backoff,
/// subscribes to [NusUuids.notify], and writes to [NusUuids.write] with
/// response in chunks of [chunkSize] — the platform-reported maximum write
/// length. The firmware asks for MTU 247 but this class never assumes it: it
/// asks, and falls back to [fallbackMaxWrite] when the platform will not
/// answer.
///
/// Single use, like the SDK's `FakeDevice`: [close] closes the streams this
/// transport owns and a closed transport does not open again. Make a new one.
///
/// Failure rule, shared with `SerialTransport` (Task 9): a failed [open]
/// leaves the transport in [TransportClosed] with `CloseCause.linkLost` and a
/// typed `error` — or in the specific state ([TransportPermissionDenied],
/// [TransportAdapterOff], [TransportPairingRequired]) when that is the cause —
/// and throws the matching [TransportError].
///
/// hardware-validate: MTU negotiation, pairing prompts and device sleep are
/// not observable against a fake. See docs/hardware-checklist.md H1.
final class BleTransport implements Transport, GuidedTransport {
  BleTransport({
    required this.deviceId,
    required this.adapter,
    HostPlatform? platform,
    this.connectAttempts = 5,
    this.initialBackoff = const Duration(milliseconds: 250),
    this.maxBackoff = const Duration(seconds: 4),
    this.requestedMtu = 247,
    this.fallbackMaxWrite = 20,
  }) : _platform = platform ?? currentHostPlatform();

  final String deviceId;

  /// The seam over the native BLE stack this transport drives.
  final BleAdapter adapter;
  final HostPlatform _platform;
  final int connectAttempts;
  final Duration initialBackoff;
  final Duration maxBackoff;
  final int requestedMtu;
  final int fallbackMaxWrite;

  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();
  final StreamController<TransportState> _state =
      StreamController<TransportState>.broadcast();

  TransportState _current = const TransportClosed(CloseCause.requested);
  TransportGuidance? _guidance;
  StreamSubscription<Uint8List>? _notifySub;
  StreamSubscription<bool>? _connectionSub;
  int _chunkSize = 20;
  bool _disposed = false;
  Future<void>? _opening;

  /// The size a [write] is cut into: `mtuWriteLength(mtu, floor:
  /// fallbackMaxWrite)`, the platform write length. Valid after [open].
  int get chunkSize => _chunkSize;

  /// The largest single [write] this transport accepts. It fragments
  /// internally at [chunkSize], so the answer is the whole largest frame.
  @override
  int get maxWriteLength => _maxFrameLength;

  @override
  TransportKind get kind => TransportKind.ble;

  @override
  TransportGuidance? get guidance => _guidance;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  Stream<TransportState> get state => _state.stream;

  @override
  TransportState get currentState => _current;

  void _set(TransportState s) {
    _current = s;
    if (!_state.isClosed) _state.add(s);
  }

  @override
  Future<void> open() => _opening ??= _open().whenComplete(() {
    _opening = null;
  });

  Future<void> _open() async {
    if (_current is TransportOpen) return;
    if (_disposed) {
      throw const Disconnected('this BLE transport was closed; make a new one');
    }
    _guidance = null;
    _set(const TransportOpening());

    switch (await adapter.availability()) {
      case BleAvailability.poweredOn:
        break;
      case BleAvailability.unauthorized:
        _guidance = _permissionGuidance();
        _finish(const TransportPermissionDenied());
        throw const PermissionDenied('Bluetooth permission was refused');
      case BleAvailability.poweredOff:
      case BleAvailability.unsupported:
      case BleAvailability.resetting:
      case BleAvailability.unknown:
        _guidance = TransportGuidance.bluetoothAdapterOff;
        _finish(const TransportAdapterOff());
        throw const AdapterOff('the Bluetooth adapter is not powered on');
    }

    await _connectWithRetry();

    try {
      _connectionSub = adapter.connectionChanges(deviceId).listen((connected) {
        if (!connected) _dropped();
      }, onError: (Object _) => _dropped());

      await adapter.discoverServices(deviceId);
      await _subscribeWithPairing();
      _chunkSize = await _negotiateWriteLength();
      _notifySub = adapter
          .notifications(
            deviceId,
            service: NusUuids.service,
            characteristic: NusUuids.notify,
          )
          .listen(
            (b) {
              if (!_incoming.isClosed) _incoming.add(b);
            },
            onError: (Object e, StackTrace s) {
              if (!_incoming.isClosed) _incoming.addError(e, s);
            },
          );
    } on BleAdapterException catch (e) {
      await _disconnectQuietly();
      _failOpen(e);
    } on TransportError {
      // Already mapped and reported by _failOpen; just let go of the link.
      await _disconnectQuietly();
      rethrow;
    }

    // The link can drop while the handshake is still running; _dropped() has
    // already closed us in that case and open must not paper over it.
    if (_current is! TransportOpening) {
      await _disconnectQuietly();
      throw const Disconnected('the BLE link dropped while opening');
    }
    _set(const TransportOpen());
  }

  void _dropped() {
    if (_current is TransportClosed) return;
    _finish(
      const TransportClosed(
        CloseCause.linkLost,
        error: Disconnected('the BLE link dropped'),
      ),
    );
  }

  Future<void> _connectWithRetry() async {
    var backoff = initialBackoff;
    for (var attempt = 1; attempt <= connectAttempts; attempt++) {
      try {
        await adapter.connect(deviceId);
        return;
      } on BleAdapterException catch (e) {
        if (_fatal(e.failure) || attempt == connectAttempts) _failOpen(e);
        await Future<void>.delayed(backoff);
        final next = backoff * 2;
        backoff = next > maxBackoff ? maxBackoff : next;
      }
    }
  }

  /// A refused permission, a dead adapter or a missing bond will not fix
  /// itself by trying again; everything else (not found, timeout, a dropped
  /// link) is worth another attempt.
  static bool _fatal(BleFailure failure) => switch (failure) {
    BleFailure.permissionDenied ||
    BleFailure.adapterOff ||
    BleFailure.insufficientAuthentication => true,
    _ => false,
  };

  Never _failOpen(BleAdapterException e) {
    switch (e.failure) {
      case BleFailure.permissionDenied:
        _guidance = _permissionGuidance();
        _finish(const TransportPermissionDenied());
        throw PermissionDenied(e.message);
      case BleFailure.adapterOff:
        _guidance = TransportGuidance.bluetoothAdapterOff;
        _finish(const TransportAdapterOff());
        throw AdapterOff(e.message);
      case BleFailure.insufficientAuthentication:
        _guidance = _pairingGuidance();
        _finish(const TransportPairingRequired());
        throw PairingRequired(e.message);
      case BleFailure.deviceNotFound:
      case BleFailure.timeout:
        _guidance = TransportGuidance.portNotFound;
        _finish(
          TransportClosed(
            CloseCause.linkLost,
            error: DeviceNotFound(e.message),
          ),
        );
        throw DeviceNotFound(e.message);
      case BleFailure.disconnected:
      case BleFailure.writeFailed:
      case BleFailure.unknown:
        _finish(
          TransportClosed(CloseCause.linkLost, error: Disconnected(e.message)),
        );
        throw Disconnected(e.message);
    }
  }

  /// Spec 5.1: `pairingRequired` is detected from an insufficient-
  /// authentication error on subscribe. Windows will not pair on its own, so
  /// there the bond is established up front; every other platform prompts by
  /// itself and only needs the retry after [BleAdapter.pair].
  Future<void> _subscribeWithPairing() async {
    if (_platform == HostPlatform.windows &&
        await adapter.isPaired(deviceId) == false) {
      await _pairOrFail();
    }
    try {
      await adapter.subscribe(
        deviceId,
        service: NusUuids.service,
        characteristic: NusUuids.notify,
      );
      return;
    } on BleAdapterException catch (e) {
      if (e.failure != BleFailure.insufficientAuthentication) rethrow;
    }
    await _pairOrFail();
    await adapter.subscribe(
      deviceId,
      service: NusUuids.service,
      characteristic: NusUuids.notify,
    );
  }

  Future<void> _pairOrFail() async {
    try {
      await adapter.pair(deviceId);
    } on BleAdapterException catch (e) {
      await _disconnectQuietly();
      _guidance = _pairingGuidance();
      _finish(const TransportPairingRequired());
      throw PairingRequired(e.message);
    }
  }

  Future<int> _negotiateWriteLength() async {
    try {
      final mtu = await adapter.requestMtu(deviceId, requestedMtu);
      return mtuWriteLength(mtu, floor: fallbackMaxWrite);
    } on BleAdapterException {
      // The platform declined to report one; the 20-byte default is safe.
      return mtuWriteLength(null, floor: fallbackMaxWrite);
    }
  }

  TransportGuidance? _permissionGuidance() => switch (_platform) {
    HostPlatform.android => TransportGuidance.androidBluetoothPermission,
    HostPlatform.ios ||
    HostPlatform.macos => TransportGuidance.applePermissionSettings,
    _ => null,
  };

  TransportGuidance? _pairingGuidance() => switch (_platform) {
    HostPlatform.ios ||
    HostPlatform.macos => TransportGuidance.applePairingPrompt,
    HostPlatform.windows => TransportGuidance.windowsPairDevice,
    HostPlatform.linux => TransportGuidance.linuxPairFromSettings,
    // Android prompts for the bond itself; there is nothing to tell the user.
    _ => null,
  };

  @override
  Future<void> write(Uint8List bytes) async {
    if (_current is! TransportOpen) {
      throw const Disconnected('the BLE transport is not open');
    }
    for (final chunk in chunked(bytes, _chunkSize)) {
      try {
        await adapter.write(
          deviceId,
          service: NusUuids.service,
          characteristic: NusUuids.write,
          value: chunk,
          withResponse: true,
        );
      } on BleAdapterException catch (e) {
        if (e.failure == BleFailure.insufficientAuthentication) {
          _guidance = _pairingGuidance();
          _set(const TransportPairingRequired());
          _finish(
            TransportClosed(
              CloseCause.linkLost,
              error: PairingRequired(e.message),
            ),
          );
          throw PairingRequired(e.message);
        }
        _finish(
          TransportClosed(CloseCause.linkLost, error: Disconnected(e.message)),
        );
        throw Disconnected(e.message);
      }
    }
  }

  @override
  Future<void> close() async {
    if (_disposed) return;
    _disposed = true;
    if (_current is! TransportClosed) {
      _finish(const TransportClosed(CloseCause.requested));
    } else {
      _cancelSubscriptions();
    }
    await _disconnectQuietly();
    if (!_incoming.isClosed) await _incoming.close();
    if (!_state.isClosed) await _state.close();
  }

  Future<void> _disconnectQuietly() async {
    try {
      await adapter.disconnect(deviceId);
    } on BleAdapterException {
      // Already gone; the state is what matters.
    }
  }

  void _cancelSubscriptions() {
    unawaited(_notifySub?.cancel());
    _notifySub = null;
    unawaited(_connectionSub?.cancel());
    _connectionSub = null;
  }

  void _finish(TransportState closed) {
    _cancelSubscriptions();
    _set(closed);
  }
}
