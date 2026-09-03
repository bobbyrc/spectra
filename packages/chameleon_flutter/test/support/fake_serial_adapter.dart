import 'dart:async';
import 'dart:typed_data';

import 'package:chameleon_flutter/src/serial/serial_adapter.dart';
import 'package:chameleon_flutter/src/serial/serial_failure.dart';
import 'package:chameleon_flutter/src/serial/serial_ids.dart';

/// A [SerialPortAdapter] whose every outcome is set by the test.
///
/// Nothing here touches a device node: it exists so the serial transport's
/// framing, error mapping and close logic can be proved without hardware.
///
/// `base` rather than `final` so a test that needs one more behaviour — the
/// scanner suite throws from [listPorts] — can extend it instead of
/// reimplementing the interface.
base class FakeSerialAdapter implements SerialPortAdapter {
  FakeSerialAdapter({this.ports = const <SerialPortDescriptor>[]});

  /// What [listPorts] returns; mutable so a test can hot-plug a port.
  List<SerialPortDescriptor> ports;

  /// Thrown by every [open] while it is set.
  SerialFailure? failOpenWith;

  int openCalls = 0;
  String? lastPath;
  int? lastBaudRate;

  /// The mode the last [open] was asked for, so a test can assert which
  /// control-line configuration the transport chose (spec 5.2).
  SerialControlLineMode? lastControlLines;

  /// The handle the last successful [open] returned.
  FakeSerialHandle? handle;

  @override
  List<SerialPortDescriptor> listPorts() => ports;

  @override
  Future<SerialPortHandle> open(
    String path, {
    int baudRate = ChameleonUsbIds.baudRate,
    SerialControlLineMode controlLines = SerialControlLineMode.dtrOnly,
  }) async {
    openCalls++;
    lastPath = path;
    lastBaudRate = baudRate;
    lastControlLines = controlLines;
    final failure = failOpenWith;
    if (failure != null) {
      throw SerialAdapterException(failure, 'scripted open failure');
    }
    return handle = FakeSerialHandle();
  }
}

/// The port [FakeSerialAdapter.open] hands back.
final class FakeSerialHandle implements SerialPortHandle {
  /// Every write, in order and by value.
  final List<Uint8List> writes = <Uint8List>[];

  bool closed = false;

  /// Fails the next [write] and is then cleared; set it with
  /// [failNextWrite].
  SerialFailure? failWriteWith;

  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  /// Bytes the device "sent".
  void emit(List<int> bytes) => _incoming.add(Uint8List.fromList(bytes));

  bool _errored = false;

  /// The cable was pulled: the reader errors out, as the real handle's
  /// incoming stream does. At most one error is ever emitted, which is the
  /// contract `SerialPortHandle.incoming` states.
  void dropLink() {
    if (_errored || _incoming.isClosed) return;
    _errored = true;
    _incoming.addError(
      const SerialAdapterException(SerialFailure.disconnected, 'cable pulled'),
    );
  }

  /// [dropLink] followed by end-of-stream — what the real handle does when
  /// the reader stops delivering.
  void disconnect() {
    dropLink();
    if (!_incoming.isClosed) unawaited(_incoming.close());
  }

  void failNextWrite(SerialFailure failure) => failWriteWith = failure;

  @override
  Future<void> write(Uint8List bytes) async {
    if (closed) {
      throw const SerialAdapterException(
        SerialFailure.disconnected,
        'the port is closed',
      );
    }
    final failure = failWriteWith;
    if (failure != null) {
      failWriteWith = null;
      throw SerialAdapterException(failure, 'scripted write failure');
    }
    writes.add(Uint8List.fromList(bytes));
  }

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    await _incoming.close();
  }
}
