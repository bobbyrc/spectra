import 'dart:async';
import 'dart:typed_data';

import '../codec/frame.dart';
import '../codec/frame_decoder.dart';
import '../dfu/fake_bootloader.dart';
import '../dfu/fake_dfu_channel.dart';
import '../model/enums.dart';
import '../protocol/errors.dart';
import '../transport/transport.dart';
import 'fake_firmware.dart';

/// A [Transport] around [FakeFirmware] that fragments responses, adds
/// latency and can misbehave on demand. The only fake transport in the SDK.
///
/// The request command ENTER_BOOTLOADER (1010) is treated specially: it
/// closes the transport with [CloseCause.expected] rather than
/// [CloseCause.linkLost], because the session asked for the reboot. This is
/// detected from the decoded request frame's command id, not from
/// [FakeFirmware.bootloaderRequested] (which stays sticky for callers that
/// want to assert the firmware saw the request).
///
/// That same request puts the device in bootloader mode: [inBootloader] is
/// set, [bootloader] answers Secure DFU through [openDfuChannel], and
/// `FakeScanner.forDevice` lists the device as a bootloader until the flash
/// completes or [leaveBootloader] is called. A whole update — reboot,
/// transfer, reboot back into the application — therefore runs against this
/// one fake, with no hardware.
final class FakeDevice implements Transport {
  FakeDevice({
    FakeFirmware? firmware,
    this.latency = Duration.zero,
    this.chunkSize = 20,
    this.openError,
  }) : firmware = firmware ?? FakeFirmware();

  static const int _enterBootloaderCommand = 1010;

  final FakeFirmware firmware;
  Duration latency;
  int chunkSize;
  TransportError? openError;

  final FrameDecoder _decoder = FrameDecoder();
  final StreamController<Uint8List> _incoming = StreamController.broadcast();
  final StreamController<TransportState> _state = StreamController.broadcast();
  final List<Frame> _received = [];
  final List<Uint8List> _writes = [];
  TransportState _current = const TransportClosed(CloseCause.requested);
  Future<void> _outbound = Future.value();
  int _dropNext = 0;
  Duration? _delayNext;
  bool _corruptNext = false;
  Object? _failNextWrite;
  Completer<void>? _writeGate;

  /// Every request frame the device has decoded, in order.
  List<Frame> get received => List.unmodifiable(_received);

  /// The raw bytes of every [write] the device was asked to make, including
  /// the ones it stalled or failed and therefore never decoded.
  List<Uint8List> get writes => List.unmodifiable(_writes);

  @override
  TransportKind get kind => TransportKind.fake;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  Stream<TransportState> get state => _state.stream;

  @override
  TransportState get currentState => _current;

  /// Swallows the next response the firmware would otherwise send.
  void dropNextResponse() => _dropNext++;

  /// Delays only the next response by [d], instead of [latency].
  void delayNextResponse(Duration d) => _delayNext = d;

  /// Flips the last byte of the next response's LRC, corrupting it.
  void corruptNextResponse() => _corruptNext = true;

  /// Makes the next [write] fail with [error] while the link stays up: a
  /// driver that refuses a write, not a disconnect.
  void failNextWrite([Object error = const PortBusy('write refused')]) =>
      _failNextWrite = error;

  /// Makes every [write] from now on hang until [releaseWrites]. This is the
  /// stalled BLE write the dispatcher's write-bounded timeout exists for.
  void stallWrites() => _writeGate ??= Completer<void>();

  /// Lets the writes [stallWrites] held through, in order.
  void releaseWrites() {
    final gate = _writeGate;
    _writeGate = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  /// The bootloader this device presents while [inBootloader]. Its expected
  /// hardware version follows the configured model, so a package built for
  /// the other model is refused at execute time, exactly as a real one is.
  late final FakeBootloader bootloader = FakeBootloader(
    expectedHwVersion: firmware.config.model == DeviceModel.lite ? 1 : 0,
  );

  /// True from the moment ENTER_BOOTLOADER is decoded until
  /// [leaveBootloader]. While it is set the device answers DFU, not the
  /// Chameleon protocol.
  bool get inBootloader => firmware.bootloaderRequested;

  /// A DFU channel to this device's [bootloader]. Closing it after a finished
  /// flash reboots the device into the application; closing it after a failed
  /// or cancelled transfer leaves the device in the bootloader, which is what
  /// makes a failed update retryable.
  ///
  /// The flashed image is never parsed, so the version this device reports
  /// after an update is still its [FakeFirmwareConfig]'s.
  FakeDfuChannel openDfuChannel({
    int maxDataWrite = 20,
    Duration latency = Duration.zero,
  }) {
    if (!inBootloader) {
      throw const DeviceNotFound('device is not in the bootloader');
    }
    return _RebootingChannel(this, maxDataWrite, latency);
  }

  /// Returns the device to application mode: a fresh [open] and handshake
  /// work again afterwards.
  void leaveBootloader() => firmware.bootloaderRequested = false;

  /// Pushes [s] onto the state stream, for the states no fake can reach on
  /// its own: pairing required, permission denied, adapter off.
  ///
  /// With [setCurrent] false the event is emitted without moving
  /// [currentState], which is how a test delivers a state the transport has
  /// already moved past.
  void emitState(TransportState s, {bool setCurrent = true}) {
    if (setCurrent) {
      _setState(s);
    } else if (!_state.isClosed) {
      _state.add(s);
    }
  }

  /// Simulates an unexpected disconnect: cable pulled, out of range.
  Future<void> simulateLinkLoss() async =>
      _setState(const TransportClosed(CloseCause.linkLost));

  @override
  Future<void> open() async {
    _setState(const TransportOpening());
    await Future<void>.delayed(latency);
    final err = openError;
    if (err != null) {
      _setState(TransportClosed(CloseCause.linkLost, error: err));
      throw err;
    }
    _setState(const TransportOpen());
  }

  /// Closes the link and, with it, this device for good: the streams it owns
  /// are closed, so nothing can leak past a test that forgot to tear down.
  /// A closed [FakeDevice] does not open again; make a new one.
  @override
  Future<void> close() async {
    if (_current is TransportOpen) {
      _setState(const TransportClosed(CloseCause.requested));
    }
    releaseWrites();
    if (!_incoming.isClosed) await _incoming.close();
    if (!_state.isClosed) await _state.close();
  }

  /// The whole of the largest frame the protocol defines: 4096 data bytes
  /// plus the 9-byte header, length and LRCs.
  @override
  int get maxWriteLength => 4105;

  @override
  Future<void> write(Uint8List bytes) async {
    if (_current is! TransportOpen) {
      throw const Disconnected('fake device not open');
    }
    _writes.add(bytes);
    final failure = _failNextWrite;
    if (failure != null) {
      _failNextWrite = null;
      throw failure;
    }
    // A stalled write never completes, so nothing after this is reached
    // until releaseWrites().
    final gate = _writeGate;
    if (gate != null) await gate.future;
    for (final frame in _decoder.feed(bytes)) {
      _received.add(frame);
      final response = firmware.handle(frame);
      if (frame.command == _enterBootloaderCommand) {
        _outbound = _outbound.then((_) async {
          await Future<void>.delayed(latency);
          _setState(const TransportClosed(CloseCause.expected));
        });
        return;
      }
      if (response == null) continue;
      if (_dropNext > 0) {
        _dropNext--;
        continue;
      }
      final delay = _delayNext ?? latency;
      _delayNext = null;
      var encoded = response.encode();
      if (_corruptNext) {
        _corruptNext = false;
        encoded = Uint8List.fromList(encoded)..[encoded.length - 1] ^= 0xFF;
      }
      _outbound = _outbound.then((_) async {
        await Future<void>.delayed(delay);
        if (_current is! TransportOpen) return;
        if (_incoming.isClosed) return;
        for (var i = 0; i < encoded.length; i += chunkSize) {
          final end = i + chunkSize > encoded.length
              ? encoded.length
              : i + chunkSize;
          _incoming.add(Uint8List.sublistView(encoded, i, end));
        }
      });
    }
  }

  void _setState(TransportState s) {
    _current = s;
    if (!_state.isClosed) _state.add(s);
  }
}

/// The channel [FakeDevice.openDfuChannel] hands out: a [FakeDfuChannel] that
/// reboots the device into the application on close, but only once the
/// bootloader reports the image is complete.
final class _RebootingChannel extends FakeDfuChannel {
  _RebootingChannel(this._device, int maxDataWrite, Duration latency)
    : super(_device.bootloader, maxDataWrite: maxDataWrite, latency: latency);

  final FakeDevice _device;

  @override
  Future<void> close() async {
    await super.close();
    if (bootloader.completed) _device.leaveBootloader();
  }
}
