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

  /// Funnels every plugin failure into [BleAdapterException].
  ///
  /// The bare `catch` is deliberate: universal_ble throws non-`Exception`
  /// values in places (a bare `String` when a characteristic has no
  /// metadata, an `Error` subtype from its web layer), and letting those
  /// through the seam would defeat the point of having one.
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on UniversalBleException catch (e) {
      throw BleAdapterException(bleFailureFromCode(e.code.name), e.toString());
    } catch (e) {
      throw BleAdapterException(BleFailure.unknown, e.toString());
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
      sub = UniversalBle.scanStream.listen((device) {
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
      }, onError: controller.addError);
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
      await stopScan();
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
      _device(deviceId).connectionStream;

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
  }) async* {
    // An `async*` body does not run until the stream is listened to, so the
    // characteristic lookup cannot race ahead of the subscriber and drop
    // notifications, and a lookup failure surfaces as a stream error.
    final c = await _guard(
      () =>
          _device(deviceId).getCharacteristic(characteristic, service: service),
    );
    yield* c.onValueReceived;
  }

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
