import 'dart:async';

import 'package:chameleon/chameleon.dart';

import 'ble_adapter.dart';
import 'ble_failure.dart';
import 'ble_uuids.dart';

/// Spec 5.5: the bootloader advertises as `CU` or `CL` and exposes the
/// Nordic DFU service. Either signal is enough.
bool isBootloaderAdvertisement(BleScanEntry entry) {
  final name = entry.name;
  if (name != null && ChameleonBleNames.bootloaderNames.contains(name)) {
    return true;
  }
  return entry.services
      .map(normalizeUuid)
      .contains(normalizeUuid(NordicDfuUuids.service));
}

/// Spec 5.1: match on the Nordic UART service or an application name
/// prefix; spec 5.5 adds the bootloader.
bool isChameleonAdvertisement(BleScanEntry entry) {
  if (isBootloaderAdvertisement(entry)) return true;
  if (entry.services
      .map(normalizeUuid)
      .contains(normalizeUuid(NusUuids.service))) {
    return true;
  }
  final name = entry.name;
  if (name == null) return false;
  return ChameleonBleNames.applicationPrefixes.any(name.startsWith);
}

/// Emits the growing list of Chameleons visible over BLE (spec 4.2).
///
/// The adapter-level filter is a hint only — platforms honour ScanFilter
/// inconsistently, and the bootloader advertises neither NUS nor the
/// application name — so [isChameleonAdvertisement] is the authority.
final class BleScanner implements DeviceScanner {
  // The public parameter name is `adapter`, distinct from the private
  // field `_adapter`, per the brief's interface, so this can't be an
  // initializing formal.
  // ignore: prefer_initializing_formals
  BleScanner({required BleAdapter adapter}) : _adapter = adapter;

  final BleAdapter _adapter;

  @override
  TransportKind get kind => TransportKind.ble;

  @override
  Stream<List<DiscoveredDevice>> scan() {
    // Keyed on transportId, but F24: DiscoveredDevice equality only covers
    // (kind, transportId), so a bootloader reboot that keeps the same id
    // but changes name/isBootloader would look unchanged to `==`. Track the
    // fields that matter for de-dup explicitly instead of relying on it.
    final found = <String, DiscoveredDevice>{};
    final controller = StreamController<List<DiscoveredDevice>>();
    StreamSubscription<BleScanEntry>? sub;

    controller.onListen = () {
      sub = _adapter
          .scan(
            withServices: <String>[NusUuids.service, NordicDfuUuids.service],
            withNamePrefix: <String>[
              ...ChameleonBleNames.applicationPrefixes,
              ...ChameleonBleNames.bootloaderNames,
            ],
          )
          .listen(
            (entry) {
              if (!isChameleonAdvertisement(entry)) return;
              final device = DiscoveredDevice(
                name: entry.name ?? entry.deviceId,
                kind: TransportKind.ble,
                transportId: entry.deviceId,
                isBootloader: isBootloaderAdvertisement(entry),
              );
              final existing = found[entry.deviceId];
              if (existing != null &&
                  existing.name == device.name &&
                  existing.isBootloader == device.isBootloader) {
                return;
              }
              found[entry.deviceId] = device;
              controller.add(List<DiscoveredDevice>.unmodifiable(found.values));
            },
            onError: (Object error, StackTrace stackTrace) {
              controller.addError(_mapError(error), stackTrace);
            },
          );
    };

    controller.onCancel = () async {
      await sub?.cancel();
      await _adapter.stopScan();
      await controller.close();
    };

    return controller.stream;
  }

  static TransportError _mapError(Object error) {
    if (error is! BleAdapterException) {
      return Disconnected(error.toString());
    }
    return switch (error.failure) {
      BleFailure.permissionDenied => PermissionDenied(error.message),
      BleFailure.adapterOff => AdapterOff(error.message),
      BleFailure.deviceNotFound => DeviceNotFound(error.message),
      BleFailure.insufficientAuthentication ||
      BleFailure.disconnected ||
      BleFailure.timeout ||
      BleFailure.writeFailed ||
      BleFailure.unknown => Disconnected(error.message),
    };
  }
}
