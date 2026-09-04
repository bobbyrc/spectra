import 'dart:async';
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';

import '../guidance.dart';
import '../host_platform.dart';
import 'serial_adapter.dart';
import 'serial_adapter_factory.dart';
import 'serial_failure.dart';
import 'serial_guidance.dart';
import 'serial_ids.dart';

/// The whole of the largest frame the protocol defines: 4096 data bytes plus
/// the 9-byte header, length and LRCs.
///
/// Copied rather than imported, for the same reason `BleTransport` copies it:
/// the SDK has the parts but its barrel exports them with `show Frame`.
const int _maxFrameLength = 4096 + 9;

/// The CDC-ACM link to a Chameleon over USB (spec 5.2).
///
/// One class for all four serial platforms: the platform difference lives
/// behind [SerialPortAdapter] (libserialport_plus on desktop, usb_serial on
/// Android). Opens at [baudRate] with 8 data bits, no parity, one stop bit
/// and the control lines [controlLines] names.
///
/// Unlike BLE there is no chunking: a serial port takes a whole frame in one
/// write, so [maxWriteLength] is the largest frame and [write] hands the
/// bytes to the handle unsplit. Writes are still serialised on a tail
/// future, so two callers can never interleave halves of a frame on the
/// wire.
///
/// Single use, like [BleTransport] and the SDK's `FakeDevice`: [close]
/// closes the streams this transport owns and a closed transport does not
/// open again. Make a new one.
///
/// Failure rule, the same rule as `BleTransport`: a failed [open] leaves the
/// transport in [TransportClosed] with `CloseCause.linkLost` and a typed
/// `error` — or in the specific state ([TransportPermissionDenied]) when
/// that is the cause — and throws the matching [TransportError]. The advice
/// that goes with the failure is [serialGuidance], a pure function of the
/// failure and the platform.
///
/// hardware-validate: whether the device needs DTR only or RTS/CTS plus
/// DTR/DSR is unresolved in the research notes and is decided by the user's
/// H1 report. See `docs/hardware-checklist.md`.
final class SerialTransport implements Transport, GuidedTransport {
  SerialTransport({
    required this.path,
    required this.adapter,
    this.controlLines = SerialControlLineMode.dtrOnly,
    this.baudRate = ChameleonUsbIds.baudRate,
    HostPlatform? platform,
  }) : _platform = platform ?? currentHostPlatform();

  /// Manual port entry (spec 5.2): the user types a path the scanner did not
  /// offer. Uses the platform's own adapter, and throws [DeviceNotFound]
  /// where the platform has no serial stack at all (iOS).
  factory SerialTransport.fromPath(
    String path, {
    SerialControlLineMode controlLines = SerialControlLineMode.dtrOnly,
    HostPlatform? platform,
  }) {
    final resolved = platform ?? currentHostPlatform();
    final adapter = defaultSerialPortAdapter(platform: resolved);
    if (adapter == null) {
      throw const DeviceNotFound('this platform has no serial transport');
    }
    return SerialTransport(
      path: path,
      adapter: adapter,
      controlLines: controlLines,
      platform: resolved,
    );
  }

  /// The OS name of the port: `/dev/cu.usbmodem…`, `COM3`.
  final String path;
  final SerialControlLineMode controlLines;
  final int baudRate;

  /// The seam over the native serial stack this transport drives.
  final SerialPortAdapter adapter;
  final HostPlatform _platform;

  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();
  final StreamController<TransportState> _state =
      StreamController<TransportState>.broadcast();

  TransportState _current = const TransportClosed(CloseCause.requested);
  TransportGuidance? _guidance;
  SerialPortHandle? _handle;
  StreamSubscription<Uint8List>? _sub;
  Future<void> _writeTail = Future<void>.value();
  bool _disposed = false;
  Future<void>? _opening;

  @override
  TransportKind get kind => TransportKind.usb;

  /// The largest single [write] this transport accepts. The link needs no
  /// fragmenting, so the answer is the whole largest frame.
  @override
  int get maxWriteLength => _maxFrameLength;

  @override
  TransportGuidance? get guidance => _guidance;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  Stream<TransportState> get state => _state.stream;

  @override
  TransportState get currentState => _current;

  void _set(TransportState s) {
    _current = s;
    if (!_state.isClosed) _state.add(s);
  }

  @override
  Future<void> open() => _opening ??= _open().whenComplete(() {
    _opening = null;
  });

  Future<void> _open() async {
    if (_current is TransportOpen) return;
    if (_disposed) {
      throw const Disconnected(
        'this serial transport was closed; make a new one',
      );
    }
    _guidance = null;
    _set(const TransportOpening());

    final SerialPortHandle handle;
    try {
      handle = await adapter.open(
        path,
        baudRate: baudRate,
        controlLines: controlLines,
      );
    } on SerialAdapterException catch (e) {
      _failOpen(e);
    }

    if (_disposed) {
      // close() landed while the port was still opening: hand the port back
      // rather than leaking an OS handle nothing is listening to.
      await _closeQuietly(handle);
      throw const Disconnected('the serial transport closed while opening');
    }

    _handle = handle;
    // The handle promises at most one error, then done. Either arrival means
    // the port is gone, so both land the same single linkLost close.
    _sub = handle.incoming.listen(
      (b) {
        if (!_incoming.isClosed) _incoming.add(b);
      },
      onError: (Object e) =>
          _dropped(e is SerialAdapterException ? e.message : '$e'),
      onDone: () => _dropped('the serial port closed'),
    );
    _set(const TransportOpen());
  }

  /// Publishes the state and guidance [e] calls for, then throws the matching
  /// error. The same rule as `BleTransport._reportFailure`.
  Never _failOpen(SerialAdapterException e) {
    _guidance = serialGuidance(e.failure, _platform);
    switch (e.failure) {
      case SerialFailure.permissionDenied:
        _finish(const TransportPermissionDenied());
        throw PermissionDenied(e.message);
      case SerialFailure.portBusy:
        _finish(
          TransportClosed(CloseCause.linkLost, error: PortBusy(e.message)),
        );
        throw PortBusy(e.message);
      case SerialFailure.notFound:
        _finish(
          TransportClosed(
            CloseCause.linkLost,
            error: DeviceNotFound(e.message),
          ),
        );
        throw DeviceNotFound(e.message);
      case SerialFailure.disconnected:
      case SerialFailure.unknown:
        _finish(
          TransportClosed(CloseCause.linkLost, error: Disconnected(e.message)),
        );
        throw Disconnected(e.message);
    }
  }

  /// The cable was pulled, or the reader stopped. Closes exactly once, and
  /// lets go of the port so the OS handle is not leaked while the app
  /// decides what to do.
  void _dropped(String message) {
    if (_current is TransportClosed) return;
    final handle = _handle;
    _finish(TransportClosed(CloseCause.linkLost, error: Disconnected(message)));
    unawaited(_closeQuietly(handle));
  }

  /// Bytes reach the port in call order and never interleave with another
  /// caller's: each call waits on the previous one, whether that one
  /// succeeded or failed. The dispatcher's timeout path can start a second
  /// write while the first is still draining, and a half-written frame would
  /// desynchronise the device.
  @override
  Future<void> write(Uint8List bytes) {
    final result = _writeTail.then((_) => _writeOnce(bytes));
    _writeTail = result.catchError((Object _) {});
    return result;
  }

  Future<void> _writeOnce(Uint8List bytes) async {
    final handle = _handle;
    if (handle == null || _current is! TransportOpen) {
      throw const Disconnected('the serial transport is not open');
    }
    try {
      await handle.write(bytes);
    } on SerialAdapterException catch (e) {
      // A write that failed means the port is no longer usable, whatever the
      // reason: close as a lost link and let go of the handle.
      _guidance = serialGuidance(e.failure, _platform);
      _finish(
        TransportClosed(CloseCause.linkLost, error: Disconnected(e.message)),
      );
      unawaited(_closeQuietly(handle));
      throw Disconnected(e.message);
    }
  }

  @override
  Future<void> close() async {
    if (_disposed) return;
    _disposed = true;
    final handle = _handle;
    if (_current is! TransportClosed) {
      _finish(const TransportClosed(CloseCause.requested));
    } else {
      _cancelSubscription();
    }
    await _closeQuietly(handle);
    if (!_incoming.isClosed) await _incoming.close();
    if (!_state.isClosed) await _state.close();
  }

  Future<void> _closeQuietly(SerialPortHandle? handle) async {
    try {
      await handle?.close();
    } on SerialAdapterException {
      // Already gone; the state is what matters.
    }
  }

  void _cancelSubscription() {
    unawaited(_sub?.cancel());
    _sub = null;
  }

  void _finish(TransportState closed) {
    _cancelSubscription();
    _handle = null;
    _set(closed);
  }
}
