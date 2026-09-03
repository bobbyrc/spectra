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
  TransportState _current = const TransportClosed(CloseCause.requested);
  Future<void> _outbound = Future.value();
  int _dropNext = 0;
  Duration? _delayNext;
  bool _corruptNext = false;

  /// Every request frame the device has decoded, in order.
  List<Frame> get received => List.unmodifiable(_received);

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

  @override
  Future<void> close() async {
    if (_current is TransportOpen) {
      _setState(const TransportClosed(CloseCause.requested));
    }
  }

  @override
  Future<void> write(Uint8List bytes) async {
    if (_current is! TransportOpen) {
      throw const Disconnected('fake device not open');
    }
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
    _state.add(s);
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
