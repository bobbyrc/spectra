import 'dart:async';
import 'dart:typed_data';

import 'dfu_channel.dart';
import 'fake_bootloader.dart';

/// An in-memory [DfuChannel] wired to a [FakeBootloader].
///
/// Not final: FakeDevice extends it to reboot the device on close.
class FakeDfuChannel implements DfuChannel {
  FakeDfuChannel(
    this.bootloader, {
    this.maxDataWrite = 20,
    this.latency = Duration.zero,
    this.garbleFirstResponse = false,
  });

  final FakeBootloader bootloader;

  @override
  final int maxDataWrite;

  /// Delay applied to every write, so cancellation and timeouts have somewhere
  /// to happen.
  final Duration latency;

  /// Answers the first control request with a response for the wrong opcode,
  /// to exercise the client's response matching.
  final bool garbleFirstResponse;

  final StreamController<Uint8List> _responses =
      StreamController<Uint8List>.broadcast();
  bool _closed = false;
  int _drop = 0;
  bool _garbled = false;

  bool get isClosed => _closed;

  /// How many times [open] was called, so a test can prove the lifecycle
  /// was followed.
  int openCalls = 0;
  bool _open = false;

  @override
  Future<void> open() async {
    openCalls++;
    if (_open) return;
    if (_closed) throw StateError('channel closed');
    _open = true;
  }

  /// Swallows the next control response, so the client's timeout fires.
  void dropNextResponse() => _drop++;

  @override
  Stream<Uint8List> get responses => _responses.stream;

  @override
  Future<void> writeControl(Uint8List bytes) async {
    if (_closed) throw StateError('channel closed');
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final r = bootloader.handleControl(bytes);
    if (_drop > 0) {
      _drop--;
      return;
    }
    if (garbleFirstResponse && !_garbled) {
      _garbled = true;
      r[1] = (r[1] + 1) & 0xFF;
    }
    _responses.add(r);
  }

  @override
  Future<void> writeData(Uint8List bytes) async {
    if (_closed) throw StateError('channel closed');
    if (bytes.length > maxDataWrite) {
      throw StateError('write of ${bytes.length} exceeds maxDataWrite');
    }
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    bootloader.handleData(bytes);
  }

  @override
  Future<void> close() async {
    _closed = true;
    await _responses.close();
  }
}
