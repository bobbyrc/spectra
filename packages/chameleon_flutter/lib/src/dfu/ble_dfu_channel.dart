import 'dart:async';
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';

import '../ble/ble_adapter.dart';
import '../ble/ble_chunking.dart';
import '../ble/ble_failure.dart';
import '../ble/ble_uuids.dart';
import '../host_platform.dart';

/// Nordic Secure DFU over BLE (spec 5.3): service FE59, control point
/// 8EC90001 (written with response, notified) and packet 8EC90002 (written
/// without response).
///
/// No chunking happens here: [SecureDfu] already streams firmware data in
/// [maxDataWrite]-sized pieces, so [writeData] writes exactly what it is
/// given as one ATT write and throws [ArgumentError] if that would exceed
/// [maxDataWrite]. [maxDataWrite] is 20 bytes on iOS and macOS — where
/// CoreBluetooth does not reliably report a write-without-response limit —
/// and the negotiated MTU minus three everywhere else, floored at 20.
///
/// Single use, like [BleTransport]: a closed channel does not reopen; make
/// a new one. Writes are serialised, one at a time, in call order.
///
/// [responses] is a broadcast stream: subscribe before the first write, as
/// [SecureDfu]'s `ResponseQueue` does, or notifications sent before the
/// subscription is in place are lost.
///
/// hardware-validate: the real DFU characteristics, the 20-byte Apple
/// limit and the bootloader's response to [BleAdapter.requestMtu]. Gated
/// behind the `dfuOverBleEnabled` flag until hardware handoff H2 passes.
/// See docs/hardware-checklist.md.
final class BleDfuChannel implements DfuChannel {
  BleDfuChannel({
    required this.deviceId,
    required BleAdapter adapter,
    HostPlatform? platform,
    this.requestedMtu = 247,
    this.appleMaxWrite = 20,
  }) : // `adapter` is exposed publicly by name but stored privately, so
       // an initializing formal (which would require the field itself to
       // be named `adapter`) does not apply.
       // ignore: prefer_initializing_formals
       _adapter = adapter,
       _platform = platform ?? currentHostPlatform();

  final String deviceId;
  final BleAdapter _adapter;
  final HostPlatform _platform;
  final int requestedMtu;
  final int appleMaxWrite;

  /// Broadcast: subscribe before the first write, exactly as
  /// [SecureDfu]'s `ResponseQueue` does. A late subscriber misses whatever
  /// notifications already arrived.
  @override
  Stream<Uint8List> get responses => _responses.stream;

  final StreamController<Uint8List> _responses =
      StreamController<Uint8List>.broadcast();

  StreamSubscription<Uint8List>? _notifySub;
  StreamSubscription<bool>? _connectionSub;
  Future<void> _writeTail = Future<void>.value();
  int _maxDataWrite = 20;
  bool _open = false;
  bool _closed = false;

  @override
  int get maxDataWrite => _maxDataWrite;

  /// Connects, discovers, subscribes to the control point and settles the
  /// write size. Must be awaited before any write. A single attempt — the
  /// orchestrator already scanned and retries are its business.
  Future<void> open() async {
    if (_open) return;
    if (_closed) {
      throw const Disconnected('this DFU channel was closed; make a new one');
    }
    // Watch the link before asking for it, so a drop during the handshake
    // is never missed. hardware-validate: universal_ble must deliver
    // connection changes for a device that is not connected yet.
    _connectionSub = _adapter.connectionChanges(deviceId).listen((connected) {
      if (!connected) _dropped();
    }, onError: (Object _) => _dropped());
    try {
      await _adapter.connect(deviceId);
      await _adapter.discoverServices(deviceId);
      await _adapter.subscribe(
        deviceId,
        service: NordicDfuUuids.service,
        characteristic: NordicDfuUuids.controlPoint,
      );
      _maxDataWrite = await _resolveWriteSize();
    } on BleAdapterException catch (e) {
      final error = _mapFailure(e);
      unawaited(_connectionSub?.cancel());
      _connectionSub = null;
      await _disconnectQuietly();
      throw error;
    }

    // The link can drop while the handshake is still running; _dropped()
    // has already closed us in that case and open must not paper over it,
    // nor leave a notify subscription feeding a closed channel.
    if (_closed) await _abortOpen();

    _notifySub = _adapter
        .notifications(
          deviceId,
          service: NordicDfuUuids.service,
          characteristic: NordicDfuUuids.controlPoint,
        )
        .listen(
          (b) {
            if (!_responses.isClosed) _responses.add(b);
          },
          onError: (Object e, StackTrace s) {
            if (!_responses.isClosed) {
              _responses.addError(
                e is BleAdapterException ? _mapFailure(e) : e,
                s,
              );
            }
          },
        );
    _open = true;
  }

  /// The link dropped while [open] was still connecting, discovering or
  /// subscribing: mirrors [BleTransport]'s `_abortOpen`. [_dropped] has
  /// already cancelled the subscriptions and failed [responses]; this only
  /// lets go of the half-open link and turns the drop into the error [open]
  /// throws.
  Future<Never> _abortOpen() async {
    await _disconnectQuietly();
    throw const Disconnected('the BLE link dropped while opening');
  }

  /// The link dropped after [open] succeeded: surfaces as a [Disconnected]
  /// error on [responses], then the stream closes. Mirrors [BleTransport]'s
  /// `_dropped`, minus the state machine this channel has none of.
  void _dropped() {
    if (_closed) return;
    _fail(const Disconnected('the BLE link dropped'));
  }

  /// Reports [error] on [responses], then closes the channel quietly:
  /// mirrors [BleTransport]'s write-failure path (`_reportFailure`/
  /// `_finish`, without a further disconnect — the failure already means
  /// the link is gone). Idempotent; a caller past the first failure gets
  /// [Disconnected] from the closed-channel guards.
  void _fail(TransportError error) {
    if (_closed) return;
    _closed = true;
    _open = false;
    unawaited(_notifySub?.cancel());
    _notifySub = null;
    unawaited(_connectionSub?.cancel());
    _connectionSub = null;
    if (!_responses.isClosed) {
      _responses.addError(error);
      unawaited(_responses.close());
    }
  }

  Future<int> _resolveWriteSize() async {
    if (_platform == HostPlatform.ios || _platform == HostPlatform.macos) {
      return appleMaxWrite;
    }
    try {
      final mtu = await _adapter.requestMtu(deviceId, requestedMtu);
      return mtuWriteLength(mtu, floor: appleMaxWrite);
    } on BleAdapterException {
      // The platform declined to report one; the floor is safe.
      return mtuWriteLength(null, floor: appleMaxWrite);
    }
  }

  @override
  Future<void> writeControl(Uint8List bytes) => _enqueue(
    () => _write(NordicDfuUuids.controlPoint, bytes, withResponse: true),
  );

  /// Writes [bytes] as a single ATT write without response. [SecureDfu]
  /// already chunks firmware data to [maxDataWrite]; this never re-chunks.
  ///
  /// Throws [ArgumentError] if [bytes] is longer than [maxDataWrite].
  @override
  Future<void> writeData(Uint8List bytes) {
    if (bytes.length > _maxDataWrite) {
      throw ArgumentError.value(
        bytes.length,
        'bytes.length',
        'exceeds maxDataWrite ($_maxDataWrite)',
      );
    }
    return _enqueue(
      () => _write(NordicDfuUuids.packet, bytes, withResponse: false),
    );
  }

  /// Serialises writes the same way [BleTransport] does: each call waits
  /// for the previous one, success or failure, so two callers never
  /// interleave their bytes on the wire.
  Future<void> _enqueue(Future<void> Function() body) {
    final result = _writeTail.then((_) => body());
    _writeTail = result.catchError((Object _) {});
    return result;
  }

  Future<void> _write(
    String characteristic,
    Uint8List value, {
    required bool withResponse,
  }) async {
    if (!_open || _closed) {
      throw const Disconnected('this DFU channel is not open');
    }
    try {
      await _adapter.write(
        deviceId,
        service: NordicDfuUuids.service,
        characteristic: characteristic,
        value: value,
        withResponse: withResponse,
      );
    } on BleAdapterException catch (e) {
      final error = _mapFailure(e);
      _fail(error);
      throw error;
    }
  }

  /// Mirrors [BleTransport]'s `_reportFailure` mapping, minus the state
  /// publishing this channel has none of: every [BleFailure] becomes the
  /// matching typed [TransportError].
  TransportError _mapFailure(BleAdapterException e) => switch (e.failure) {
    BleFailure.permissionDenied => PermissionDenied(e.message),
    BleFailure.adapterOff => AdapterOff(e.message),
    BleFailure.insufficientAuthentication => PairingRequired(e.message),
    BleFailure.deviceNotFound ||
    BleFailure.timeout => DeviceNotFound(e.message),
    BleFailure.disconnected ||
    BleFailure.writeFailed ||
    BleFailure.unknown => Disconnected(e.message),
  };

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _open = false;
    await _notifySub?.cancel();
    _notifySub = null;
    await _connectionSub?.cancel();
    _connectionSub = null;
    if (!_responses.isClosed) await _responses.close();
    await _disconnectQuietly();
  }

  Future<void> _disconnectQuietly() async {
    try {
      await _adapter.disconnect(deviceId);
    } on BleAdapterException {
      // Already gone; nothing more to report.
    }
  }
}
