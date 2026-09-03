import 'dart:typed_data';

import 'ble_failure.dart';

/// Mirrors universal_ble's `AvailabilityState`, so nothing above this seam
/// needs the plugin's enum.
enum BleAvailability {
  unknown,
  resetting,
  unsupported,
  unauthorized,
  poweredOff,
  poweredOn,
}

/// One advertisement seen during a scan.
final class BleScanEntry {
  const BleScanEntry({
    required this.deviceId,
    required this.name,
    this.services = const <String>[],
  });

  final String deviceId;
  final String? name;

  /// Advertised service UUIDs, already run through `normalizeUuid`.
  final List<String> services;
}

/// The seam over the native BLE stack.
///
/// Every method throws [BleAdapterException] on failure and nothing else, so
/// transport logic never sees a plugin type. `universal_ble` is imported by
/// exactly one implementation of this interface.
abstract interface class BleAdapter {
  Future<BleAvailability> availability();

  /// Advertisements matching the filters. Cancelling the subscription is
  /// not enough to stop the radio: call [stopScan].
  Stream<BleScanEntry> scan({
    List<String> withServices = const <String>[],
    List<String> withNamePrefix = const <String>[],
  });

  Future<void> stopScan();

  Future<void> connect(String deviceId, {Duration? timeout});

  Future<void> disconnect(String deviceId);

  /// true on connect, false on disconnect, for the life of the adapter.
  Stream<bool> connectionChanges(String deviceId);

  Future<void> discoverServices(String deviceId);

  /// The negotiated ATT MTU. Throws if the platform will not report one.
  Future<int> requestMtu(String deviceId, int expectedMtu);

  Future<void> subscribe(
    String deviceId, {
    required String service,
    required String characteristic,
  });

  Stream<Uint8List> notifications(
    String deviceId, {
    required String service,
    required String characteristic,
  });

  Future<void> write(
    String deviceId, {
    required String service,
    required String characteristic,
    required Uint8List value,
    bool withResponse = true,
  });

  Future<void> pair(String deviceId);

  Future<bool?> isPaired(String deviceId);
}
