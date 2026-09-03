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

  final StreamController<Uint8List> _responses =
      StreamController<Uint8List>.broadcast();

  StreamSubscription<Uint8List>? _notifySub;
  Future<void> _writeTail = Future<void>.value();
  int _maxDataWrite = 20;
  bool _open = false;
  bool _closed = false;

  @override
  int get maxDataWrite => _maxDataWrite;

  @override
  Stream<Uint8List> get responses => _responses.stream;

  /// Connects, discovers, subscribes to the control point and settles the
  /// write size. Must be awaited before any write. A single attempt — the
  /// orchestrator already scanned and retries are its business.
  Future<void> open() async {
    if (_open) return;
    if (_closed) {
      throw const Disconnected('this DFU channel was closed; make a new one');
    }
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
      await _disconnectQuietly();
      throw error;
    }

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
      throw _mapFailure(e);
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
