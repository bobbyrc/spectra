import 'dart:async';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

import 'ble_adapter.dart';
import 'ble_failure.dart';
import 'ble_uuids.dart';

/// The only file in Spectra that imports universal_ble (2.2.0).
///
/// Every call is wrapped so a `UniversalBleException` becomes a
/// [BleAdapterException]; the transport above never sees a plugin type.
/// Nothing here can be unit-tested — every call goes through a plugin
/// channel — so this class is deliberately thin and mechanical, and every
/// decision it would otherwise make lives in [bleFailureFromCode], which is
/// pure and tested.
///
/// hardware-validate: the whole class. Behaviour against a real radio,
/// notably MTU negotiation, `pair`/`isPaired` on Apple and Web (which need a
/// pairing command this adapter does not pass) and which error codes each
/// platform actually reports, can only be confirmed on a device.
final class UniversalBleAdapter implements BleAdapter {
  UniversalBleAdapter();

  /// universal_ble addresses everything by `deviceId`; `BleDevice` is just a
  /// handle carrying it, so one per id is kept and reused. Entries seen in a
  /// scan replace the synthesised ones so advertised data is not lost.
  final Map<String, BleDevice> _devices = <String, BleDevice>{};

  BleDevice _device(String deviceId) => _devices.putIfAbsent(
    deviceId,
    () => BleDevice(deviceId: deviceId, name: null),
  );

  /// Translates anything universal_ble throws into a [BleAdapterException].
  ///
  /// Accepting `Object` rather than `Exception` is deliberate: universal_ble
  /// throws non-`Exception` values in places (a bare `String` when a
  /// characteristic has no metadata, an `Error` subtype from its web layer),
  /// and letting those through the seam would defeat the point of having
  /// one. An exception that is already mapped passes through unchanged, so
  /// this is safe to apply twice.
  BleAdapterException _mapError(Object e) => switch (e) {
    BleAdapterException() => e,
    UniversalBleException() => BleAdapterException(
      bleFailureFromCode(e.code.name),
      e.toString(),
    ),
    _ => BleAdapterException(BleFailure.unknown, e.toString()),
  };

  /// [_mapError] for a future. The stream equivalent is `.handleError`.
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<BleAvailability> availability() => _guard(() async {
    final state = await UniversalBle.getBluetoothAvailabilityState();
    return switch (state) {
      AvailabilityState.poweredOn => BleAvailability.poweredOn,
      AvailabilityState.poweredOff => BleAvailability.poweredOff,
      AvailabilityState.unauthorized => BleAvailability.unauthorized,
      AvailabilityState.unsupported => BleAvailability.unsupported,
      AvailabilityState.resetting => BleAvailability.resetting,
      AvailabilityState.unknown => BleAvailability.unknown,
    };
  });

  @override
  Stream<BleScanEntry> scan({
    List<String> withServices = const <String>[],
    List<String> withNamePrefix = const <String>[],
  }) {
    final controller = StreamController<BleScanEntry>();
    StreamSubscription<BleDevice>? sub;
    // Listen before starting the radio: an advertisement that arrives
    // between startScan returning and the listener attaching would
    // otherwise be dropped.
    controller.onListen = () {
      sub = UniversalBle.scanStream.listen(
        (device) {
          _devices[device.deviceId] = device;
          controller.add(
            BleScanEntry(
              deviceId: device.deviceId,
              name: device.name,
              services: device.services
                  .map(normalizeUuid)
                  .toList(growable: false),
            ),
          );
        },
        onError: (Object e, StackTrace st) =>
            controller.addError(_mapError(e), st),
      );
      unawaited(
        _guard(
          () => UniversalBle.startScan(
            scanFilter: ScanFilter(
              withServices: withServices,
              withNamePrefix: withNamePrefix,
            ),
          ),
        ).catchError((Object e, StackTrace s) => controller.addError(e, s)),
      );
    };
    controller.onCancel = () async {
      await sub?.cancel();
      // Teardown is best-effort: a radio that errors while being told to
      // stop must not make cancelling a subscription throw at the call
      // site, and the stream still has to close either way.
      try {
        await stopScan();
      } on BleAdapterException {
        // Nothing useful to do; the scan is over as far as callers care.
      }
      await controller.close();
    };
    return controller.stream;
  }

  @override
  Future<void> stopScan() => _guard(UniversalBle.stopScan);

  @override
  Future<void> connect(String deviceId, {Duration? timeout}) =>
      _guard(() => _device(deviceId).connect(timeout: timeout));

  @override
  Future<void> disconnect(String deviceId) =>
      _guard(() => _device(deviceId).disconnect());

  @override
  Stream<bool> connectionChanges(String deviceId) =>
      _device(deviceId).connectionStream
          .handleError((Object e) => throw _mapError(e));

  @override
  Future<void> discoverServices(String deviceId) =>
      _guard(() => _device(deviceId).discoverServices());

  @override
  Future<int> requestMtu(String deviceId, int expectedMtu) =>
      _guard(() => _device(deviceId).requestMtu(expectedMtu));

  @override
  Future<void> subscribe(
    String deviceId, {
    required String service,
    required String characteristic,
  }) => _guard(() async {
    final c = await _device(deviceId)
        .getCharacteristic(characteristic, service: service);
    await c.notifications.subscribe();
  });

  @override
  Stream<Uint8List> notifications(
    String deviceId, {
    required String service,
    required String characteristic,
  }) => Stream<Uint8List>.multi((controller) async {
    // `Stream.multi` gives both properties the interface promises: the body
    // does not run until someone listens, so the characteristic lookup
    // cannot race ahead of the subscriber and drop notifications, and it
    // runs once per listener, so a second listener is allowed just as it is
    // on the fake. A lookup failure surfaces as a stream error rather than
    // a synchronous throw.
    try {
      final c = await _guard(
        () =>
            _device(deviceId)
                .getCharacteristic(characteristic, service: service),
      );
      await controller.addStream(
        c.onValueReceived.handleError((Object e) => throw _mapError(e)),
      );
    } catch (e, st) {
      controller.addError(_mapError(e), st);
    }
    await controller.close();
  }, isBroadcast: true);

  @override
  Future<void> write(
    String deviceId, {
    required String service,
    required String characteristic,
    required Uint8List value,
    bool withResponse = true,
  }) => _guard(() async {
    final c = await _device(deviceId)
        .getCharacteristic(characteristic, service: service);
    await c.write(value, withResponse: withResponse);
  });

  @override
  Future<void> pair(String deviceId) => _guard(() => _device(deviceId).pair());

  @override
  Future<bool?> isPaired(String deviceId) =>
      _guard(() => _device(deviceId).isPaired());
}
