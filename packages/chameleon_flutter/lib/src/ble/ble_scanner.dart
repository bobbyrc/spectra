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

/// Emits the list of Chameleons visible over BLE (spec 4.2).
///
/// The adapter-level filter is a hint only — platforms honour ScanFilter
/// inconsistently, and the bootloader advertises neither NUS nor the
/// application name — so [isChameleonAdvertisement] is the authority.
///
/// Stream behaviour, identical to [SerialScanner]'s so `mergedScan` can
/// treat the two alike:
///
/// * The first event is emitted on subscribe and is the empty list: an
///   answer the UI can render, rather than nothing until the radio reports.
/// * Every later event is the whole current list, never a delta, and an
///   unchanged list is not re-emitted.
/// * A device that has not advertised for [staleAfter] is dropped, so the
///   list reflects what is in range rather than everything ever seen.
/// * An adapter error ends the scan: the error is forwarded, the radio is
///   stopped and the stream closes. Restarting means calling [scan] again.
/// * Cancelling the subscription stops the radio.
final class BleScanner implements DeviceScanner {
  // The public parameter name is `adapter`, distinct from the private
  // field `_adapter`, per the brief's interface, so this can't be an
  // initializing formal.
  BleScanner({
    required BleAdapter adapter,
    this.staleAfter = const Duration(seconds: 10),
    // ignore: prefer_initializing_formals
  }) : _adapter = adapter;

  final BleAdapter _adapter;

  /// How long a device stays in the list after its last advertisement.
  ///
  /// Ten seconds by default: a Chameleon sleeps for roughly eight after a
  /// disconnect (spec 5.1) and stops advertising, so anything shorter would
  /// blink a device that is still there off the list.
  ///
  /// hardware-validate: the real advertising interval and the post-
  /// disconnect sleep. See docs/hardware-checklist.md.
  final Duration staleAfter;

  @override
  TransportKind get kind => TransportKind.ble;

  @override
  Stream<List<DiscoveredDevice>> scan() {
    // Keyed on transportId, but F24: DiscoveredDevice equality only covers
    // (kind, transportId), so a bootloader reboot that keeps the same id
    // but changes name/isBootloader would look unchanged to `==`. Track the
    // fields that matter for de-dup explicitly instead of relying on it.
    final found = <String, DiscoveredDevice>{};
    final lastSeen = <String, DateTime>{};
    final controller = StreamController<List<DiscoveredDevice>>();
    StreamSubscription<BleScanEntry>? sub;
    Timer? ageOut;
    var stopped = false;

    void emit() {
      if (!controller.isClosed) {
        controller.add(List<DiscoveredDevice>.unmodifiable(found.values));
      }
    }

    // Idempotent: `controller.close()` while a listener is still attached
    // triggers `onCancel` itself (closing implies cancelling), so the error
    // path below and this callback would otherwise call `close()` on each
    // other and deadlock. The flag makes calling it twice a no-op.
    Future<void> stopScanning() async {
      if (stopped) return;
      stopped = true;
      ageOut?.cancel();
      ageOut = null;
      await sub?.cancel();
      await _adapter.stopScan();
    }

    controller.onListen = () {
      // An answer straight away: "nothing yet", not silence.
      emit();
      // Only while somebody is listening; cancelled by stopScanning.
      final tick = Duration(
        microseconds: (staleAfter.inMicroseconds ~/ 2).clamp(
          1,
          staleAfter.inMicroseconds,
        ),
      );
      ageOut = Timer.periodic(tick, (_) {
        final deadline = DateTime.now().subtract(staleAfter);
        final gone = <String>[
          for (final e in lastSeen.entries)
            if (e.value.isBefore(deadline)) e.key,
        ];
        if (gone.isEmpty) return;
        for (final id in gone) {
          found.remove(id);
          lastSeen.remove(id);
        }
        emit();
      });
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
              // Every advertisement counts as a sighting, including one
              // that changes nothing: that is what keeps a device in range
              // from ageing out.
              lastSeen[entry.deviceId] = DateTime.now();
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
              emit();
            },
            onError: (Object error, StackTrace stackTrace) async {
              // A typed adapter error ends the scan outright: stop the
              // radio and close the stream rather than leaving it open for
              // a caller that may never cancel.
              await stopScanning();
              controller.addError(_mapError(error), stackTrace);
              await controller.close();
            },
          );
    };

    controller.onCancel = stopScanning;

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
