import 'dart:typed_data';

import 'serial_ids.dart';

/// The two candidate control-line configurations. The research notes
/// disagree on which the Chameleon needs, so spec 5.2 says implement both
/// and let the transport pick.
///
/// hardware-validate: which mode works is decided by the user's H1 report;
/// see `docs/hardware-checklist.md`.
enum SerialControlLineMode {
  /// Assert DTR, ignore CTS/DSR, no hardware flow control. The default,
  /// matching `docs/research/chameleon-protocol.md` ("Assert DTR after
  /// open. No flow control.").
  dtrOnly,

  /// RTS/CTS and DTR/DSR hardware flow control, as the reference GUI's
  /// desktop path configures it.
  hardwareFlowControl,
}

/// One enumerated serial port.
final class SerialPortDescriptor {
  const SerialPortDescriptor({
    required this.path,
    required this.description,
    this.vid,
    this.pid,
    this.manufacturer,
    this.product,
  });

  /// The OS-specific name the port is opened by: `/dev/tty.usbmodem…`,
  /// `COM3`.
  final String path;
  final String description;

  /// USB identity, when the platform reports it — null for a port on a
  /// non-USB transport, or one we could not describe.
  final int? vid;
  final int? pid;
  final String? manufacturer;
  final String? product;

  /// By value, so a scan can de-duplicate the same port seen twice — and
  /// so a rescan that finds nothing new compares equal — without holding on
  /// to the instances it already emitted. Mirrors `BleScanEntry`.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SerialPortDescriptor &&
          other.path == path &&
          other.description == description &&
          other.vid == vid &&
          other.pid == pid &&
          other.manufacturer == manufacturer &&
          other.product == product;

  @override
  int get hashCode =>
      Object.hash(path, description, vid, pid, manufacturer, product);

  @override
  String toString() =>
      'SerialPortDescriptor($path, description: $description, '
      'vid: $vid, pid: $pid, manufacturer: $manufacturer, product: $product)';
}

/// An open port.
///
/// Every member fails with a `SerialAdapterException` and nothing else, so
/// transport logic never sees a `libserialport_plus` type.
abstract interface class SerialPortHandle {
  /// Bytes as they arrive, in chunks of whatever size the OS delivered.
  ///
  /// Broadcast: it may be listened to more than once, and it does not
  /// replay. A read failure, or the far end going away, arrives as a
  /// single `SerialAdapterException` — at most one error is ever emitted —
  /// after which the stream closes. A listener therefore sees either one
  /// error then done, or (after [close]) done alone.
  Stream<Uint8List> get incoming;

  /// Writes every byte of [bytes]. Throws
  /// `SerialAdapterException(SerialFailure.disconnected)` after [close].
  Future<void> write(Uint8List bytes);

  /// Idempotent.
  Future<void> close();
}

/// The seam over the native serial stack: libserialport_plus on desktop,
/// usb_serial on Android.
abstract interface class SerialPortAdapter {
  /// Every port the OS reports. Throws `SerialAdapterException`.
  List<SerialPortDescriptor> listPorts();

  /// Opens [path] at [baudRate] with 8 data bits, no parity, 1 stop bit
  /// (spec 5.2) and the control lines [controlLines] describes.
  Future<SerialPortHandle> open(
    String path, {
    int baudRate = ChameleonUsbIds.baudRate,
    SerialControlLineMode controlLines = SerialControlLineMode.dtrOnly,
  });
}
