import 'dart:async';
import 'dart:typed_data';

import 'package:libserialport_plus/libserialport_plus.dart';

import '../host_platform.dart';
import 'serial_adapter.dart';
import 'serial_failure.dart';
import 'serial_ids.dart';

/// The only file in Spectra that imports `libserialport_plus` (1.0.4).
///
/// It is deliberately thin: everything worth testing lives above the seam,
/// and everything here needs a real device node.
///
/// hardware-validate: enumeration, the USB identity fields and the control
/// lines are checked against the device in H1 (`docs/hardware-checklist.md`);
/// Spike A (`docs/research/spikes.md`) exercised the same calls.
final class LibSerialPortAdapter implements SerialPortAdapter {
  LibSerialPortAdapter({HostPlatform? platform})
    : _platform = platform ?? currentHostPlatform();

  final HostPlatform _platform;

  SerialAdapterException _map(SerialPortException e) => SerialAdapterException(
    mapSerialError(e.code, e.message, _platform),
    e.message,
  );

  @override
  List<SerialPortDescriptor> listPorts() {
    final out = <SerialPortDescriptor>[];
    try {
      for (final name in SerialPort.getAvailablePorts()) {
        // Inside the guard: a port that vanished between enumeration and
        // lookup throws here, and must surface as a typed failure.
        final port = SerialPort(name);
        try {
          final info = port.getInfo();
          out.add(
            SerialPortDescriptor(
              path: info.name,
              description: info.description,
              vid: info.usbVid,
              pid: info.usbPid,
              manufacturer: info.usbManufacturer,
              product: info.usbProduct,
            ),
          );
        } on SerialPortException {
          // A port we cannot describe is still a port the user may pick by
          // hand; list it with what we have.
          out.add(SerialPortDescriptor(path: name, description: name));
        } finally {
          port.dispose();
        }
      }
    } on SerialPortException catch (e) {
      throw _map(e);
    }
    return out;
  }

  @override
  Future<SerialPortHandle> open(
    String path, {
    int baudRate = ChameleonUsbIds.baudRate,
    SerialControlLineMode controlLines = SerialControlLineMode.dtrOnly,
  }) async {
    SerialPort? port;
    try {
      port = SerialPort(path);
      port.open();
      port.setConfig(_configFor(baudRate, controlLines));
    } on SerialPortException catch (e) {
      port?.dispose();
      throw _map(e);
    }
    return _LibSerialPortHandle(port, _map);
  }

  /// 115200 8N1 (spec 5.2). `dtrOnly` asserts DTR and disables every flow
  /// control; `hardwareFlowControl` turns on RTS/CTS and DTR/DSR.
  ///
  /// hardware-validate: which mode the Chameleon needs is H1.
  SerialPortConfig _configFor(int baudRate, SerialControlLineMode mode) =>
      switch (mode) {
        SerialControlLineMode.dtrOnly => SerialPortConfig(
          baudRate: baudRate,
          bits: ChameleonUsbIds.dataBits,
          parity: SerialPortParity.none,
          stopBits: ChameleonUsbIds.stopBits,
          dtr: SerialPortDtr.on,
          dsr: SerialPortDsr.ignore,
          rts: SerialPortRts.off,
          cts: SerialPortCts.ignore,
          xonXoff: SerialPortXonXoff.disabled,
        ),
        SerialControlLineMode.hardwareFlowControl => SerialPortConfig(
          baudRate: baudRate,
          bits: ChameleonUsbIds.dataBits,
          parity: SerialPortParity.none,
          stopBits: ChameleonUsbIds.stopBits,
          dtr: SerialPortDtr.flowControl,
          dsr: SerialPortDsr.flowControl,
          rts: SerialPortRts.flowControl,
          cts: SerialPortCts.flowControl,
          xonXoff: SerialPortXonXoff.disabled,
        ),
      };
}

final class _LibSerialPortHandle implements SerialPortHandle {
  _LibSerialPortHandle(this._port, this._map)
    : _reader = SerialPortReader(_port) {
    _sub = _reader.stream.listen(
      _incoming.add,
      onError: (Object e, StackTrace s) {
        _incoming.addError(e is SerialPortException ? _map(e) : e, s);
      },
      // The reader's stream ends when its isolate stops, which after a read
      // failure means the link is gone; the transport hears that as a
      // disconnect rather than a silent end of stream.
      onDone: _linkGone,
    );
  }

  final SerialPort _port;
  final SerialPortReader _reader;
  final SerialAdapterException Function(SerialPortException) _map;
  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List>? _sub;
  bool _closed = false;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  void _linkGone() {
    if (_closed || _incoming.isClosed) return;
    _incoming.addError(
      const SerialAdapterException(
        SerialFailure.disconnected,
        'the port stopped delivering data',
      ),
    );
    unawaited(_incoming.close());
  }

  @override
  Future<void> write(Uint8List bytes) async {
    if (_closed) {
      throw const SerialAdapterException(
        SerialFailure.disconnected,
        'the port is closed',
      );
    }
    try {
      // libserialport's write is synchronous and returns the byte count.
      var offset = 0;
      while (offset < bytes.length) {
        final written = _port.write(Uint8List.sublistView(bytes, offset));
        if (written <= 0) {
          throw const SerialAdapterException(
            SerialFailure.disconnected,
            'the port accepted no bytes',
          );
        }
        offset += written;
      }
    } on SerialPortException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _sub?.cancel();
    await _reader.close();
    try {
      _port.close();
    } on SerialPortException {
      // Already gone; there is nothing left to release but the handle.
    } finally {
      _port.dispose();
    }
    if (!_incoming.isClosed) await _incoming.close();
  }
}
