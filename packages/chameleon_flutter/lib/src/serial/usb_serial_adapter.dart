import 'dart:async';
import 'dart:typed_data';

import 'package:usb_serial/usb_serial.dart';

import 'serial_adapter.dart';
import 'serial_failure.dart';
import 'serial_ids.dart';

/// The only file in Spectra that imports usb_serial (0.5.2). Android only
/// (spec 5.4).
///
/// usb_serial enumerates asynchronously, but [SerialPortAdapter.listPorts]
/// is synchronous because libserialport's is. The device list is therefore
/// refreshed by [refresh] — the scanner calls it before each enumeration —
/// and cached here.
///
/// Failure mapping (F10; usb_serial has no error codes, only exceptions and
/// booleans, so this is coarser than [mapSerialError]):
/// - `device.create()` returns null, or throws with a message that mentions
///   "permission" → [SerialFailure.permissionDenied] (the user declined the
///   Android USB permission dialog, or the OS refused it outright).
/// - `device.create()` throws for any other reason → [SerialFailure.unknown].
/// - The target [path] is not in the last [refresh]d device list →
///   [SerialFailure.notFound].
/// - `port.open()` returns `false` → [SerialFailure.unknown] (no message is
///   available to tell a busy port from anything else).
/// - `port.open()` throws with a message that mentions "busy" →
///   [SerialFailure.portBusy]; any other open exception → unknown.
/// - [SerialPortHandle.write] after [SerialPortHandle.close], or a write
///   that throws → [SerialFailure.disconnected].
final class UsbSerialAdapter implements SerialPortAdapter {
  UsbSerialAdapter();

  List<UsbDevice> _devices = const <UsbDevice>[];

  /// Re-reads the attached USB devices. Call before [listPorts].
  Future<void> refresh() async {
    _devices = await UsbSerial.listDevices();
  }

  @override
  List<SerialPortDescriptor> listPorts() => <SerialPortDescriptor>[
    for (final d in _devices)
      SerialPortDescriptor(
        path: d.deviceName,
        description: d.productName ?? d.deviceName,
        vid: d.vid,
        pid: d.pid,
        manufacturer: d.manufacturerName,
        product: d.productName,
      ),
  ];

  @override
  Future<SerialPortHandle> open(
    String path, {
    int baudRate = ChameleonUsbIds.baudRate,
    SerialControlLineMode controlLines = SerialControlLineMode.dtrOnly,
  }) async {
    if (_devices.isEmpty) await refresh();
    final device = _devices.where((d) => d.deviceName == path).firstOrNull;
    if (device == null) {
      throw SerialAdapterException(
        SerialFailure.notFound,
        'no device at $path',
      );
    }

    final UsbPort? port;
    try {
      port = await device.create();
    } catch (e) {
      final message = e.toString();
      throw SerialAdapterException(
        message.toLowerCase().contains('permission')
            ? SerialFailure.permissionDenied
            : SerialFailure.unknown,
        message,
      );
    }
    // A null port with no exception also means the user declined the
    // Android USB permission dialog.
    if (port == null) {
      throw const SerialAdapterException(
        SerialFailure.permissionDenied,
        'USB device permission was refused',
      );
    }

    final bool opened;
    try {
      opened = await port.open();
    } catch (e) {
      final message = e.toString();
      throw SerialAdapterException(
        message.toLowerCase().contains('busy')
            ? SerialFailure.portBusy
            : SerialFailure.unknown,
        message,
      );
    }
    if (!opened) {
      throw const SerialAdapterException(
        SerialFailure.unknown,
        'the USB device could not be opened',
      );
    }

    await port.setPortParameters(
      baudRate,
      UsbPort.DATABITS_8,
      UsbPort.STOPBITS_1,
      UsbPort.PARITY_NONE,
    );
    // usb_serial has no CTS/DSR hardware flow-control API (no
    // FLOW_CONTROL_RTS_CTS wiring to a status line the app can read), so
    // hardwareFlowControl only asserts both output lines; the real
    // flow-control behaviour is untested. hardware-validate: which control
    // lines the Chameleon needs is H1.
    await port.setDTR(true);
    await port.setRTS(
      controlLines == SerialControlLineMode.hardwareFlowControl,
    );
    return _UsbSerialHandle(port);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

final class _UsbSerialHandle implements SerialPortHandle {
  _UsbSerialHandle(this._port) {
    final input = _port.inputStream;
    if (input != null) {
      _sub = input.listen(_incoming.add, onError: _incoming.addError);
    }
  }

  final UsbPort _port;
  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List>? _sub;
  bool _closed = false;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  Future<void> write(Uint8List bytes) async {
    if (_closed) {
      throw const SerialAdapterException(
        SerialFailure.disconnected,
        'the port is closed',
      );
    }
    try {
      await _port.write(bytes);
    } catch (e) {
      throw SerialAdapterException(SerialFailure.disconnected, e.toString());
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _sub?.cancel();
    await _port.close();
    await _incoming.close();
  }
}
