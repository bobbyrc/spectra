import 'dart:async';

import 'package:chameleon/chameleon.dart';

import 'serial_adapter.dart';
import 'serial_failure.dart';
import 'serial_ids.dart';
import 'usb_serial_adapter.dart';

/// Spec 5.5: the Nordic bootloader enumerates as VID 0x1915 / PID 0x521F.
bool isBootloaderPort(SerialPortDescriptor port) =>
    port.vid == ChameleonUsbIds.bootloaderVid &&
    port.pid == ChameleonUsbIds.bootloaderPid;

/// Spec 5.2: filter on VID 0x6868 / PID 0x8686 and manufacturer
/// "Proxgrind" (case-insensitive, for a re-flashed device that reports the
/// string differently across OSes). The bootloader counts too so a device
/// stuck in DFU still shows up (spec 5.5). A descriptor with no vid/pid and
/// no manufacturer is ignored — manual port entry covers it.
bool isChameleonPort(SerialPortDescriptor port) {
  if (isBootloaderPort(port)) return true;
  if (port.vid == ChameleonUsbIds.applicationVid &&
      port.pid == ChameleonUsbIds.applicationPid) {
    return true;
  }
  final manufacturer = port.manufacturer;
  if (manufacturer == null) return false;
  return manufacturer.toLowerCase() ==
      ChameleonUsbIds.manufacturer.toLowerCase();
}

/// Polls the serial ports and reports the Chameleons among them (spec 4.2).
///
/// Serial has no attach/detach event on desktop, so this polls rather than
/// subscribing to one. [pollInterval] defaults to two seconds.
///
/// Stream behaviour, identical to [BleScanner]'s so `mergedScan` can treat
/// the two alike:
///
/// * The first event is the first poll's result, emitted as soon as that
///   enumeration finishes — the empty list when nothing is attached, so
///   the UI always has something to render.
/// * Every later event is the whole current list, never a delta, and an
///   unchanged list is not re-emitted.
/// * A port that has gone is dropped on the next poll: this list is what
///   is attached now, not everything ever seen (the counterpart of
///   [BleScanner.staleAfter]).
/// * An enumeration failure ends the scan: the error is forwarded, polling
///   stops and the stream closes. Restarting means calling [scan] again.
/// * Cancelling the subscription stops the polling.
final class SerialScanner implements DeviceScanner {
  // The public parameter name is `adapter`, distinct from the private
  // field `_adapter`, per the brief's interface, so this can't be an
  // initializing formal.
  SerialScanner({
    required SerialPortAdapter adapter,
    this.pollInterval = const Duration(seconds: 2),
    // ignore: prefer_initializing_formals
  }) : _adapter = adapter;

  final SerialPortAdapter _adapter;
  final Duration pollInterval;

  @override
  TransportKind get kind => TransportKind.usb;

  /// One enumeration pass, for a manual refresh button. Throws a
  /// [TransportError] if the adapter's `listPorts` fails.
  Future<List<DiscoveredDevice>> enumerate() async {
    try {
      // usb_serial enumerates asynchronously and UsbSerialAdapter caches
      // the result, so Android never discovers anything unless the cache
      // is refreshed before every enumeration (see UsbSerialAdapter's
      // doc). Desktop's libserialport-backed adapter enumerates
      // synchronously in listPorts() and has no refresh step.
      final adapter = _adapter;
      if (adapter is UsbSerialAdapter) await adapter.refresh();
      return <DiscoveredDevice>[
        for (final port in _adapter.listPorts())
          if (isChameleonPort(port))
            DiscoveredDevice(
              name: port.product ?? port.description,
              kind: TransportKind.usb,
              transportId: port.path,
              isBootloader: isBootloaderPort(port),
            ),
      ];
    } on Object catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Stream<List<DiscoveredDevice>> scan() {
    Timer? timer;
    // The (transportId, name, isBootloader) triple per device, sorted so a
    // re-ordered listPorts() result compares equal — de-dup per ruling
    // F24, since DiscoveredDevice equality only covers (kind, transportId).
    List<String>? previousKey;
    final controller = StreamController<List<DiscoveredDevice>>();

    Future<void> poll() async {
      final List<DiscoveredDevice> devices;
      try {
        devices = await enumerate();
      } on Object catch (error, stackTrace) {
        timer?.cancel();
        timer = null;
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
          await controller.close();
        }
        return;
      }
      final key = <String>[
        for (final d in devices) '${d.transportId} ${d.name} ${d.isBootloader}',
      ]..sort();
      if (previousKey != null && _sameList(previousKey!, key)) return;
      previousKey = key;
      if (!controller.isClosed) {
        controller.add(List<DiscoveredDevice>.unmodifiable(devices));
      }
    }

    controller.onListen = () {
      unawaited(poll());
      timer = Timer.periodic(pollInterval, (_) => unawaited(poll()));
    };
    controller.onCancel = () async {
      timer?.cancel();
      timer = null;
      if (!controller.isClosed) await controller.close();
    };
    return controller.stream;
  }

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static TransportError _mapError(Object error) {
    if (error is! SerialAdapterException) {
      return Disconnected(error.toString());
    }
    return switch (error.failure) {
      SerialFailure.permissionDenied => PermissionDenied(error.message),
      SerialFailure.portBusy => PortBusy(error.message),
      SerialFailure.notFound => DeviceNotFound(error.message),
      SerialFailure.disconnected ||
      SerialFailure.unknown => Disconnected(error.message),
    };
  }
}
