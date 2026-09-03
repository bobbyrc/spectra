import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';

import '../support/fake_serial_adapter.dart';
import 'transport_contract.dart';

/// A [SerialPortHandle] that answers a write the way a real Chameleon would:
/// decoded through the SDK's own [FrameDecoder] and dispatched to a
/// [FakeFirmware], with the response pushed back on [incoming].
///
/// Delegates every other behaviour to the real [FakeSerialHandle] that
/// [FakeSerialAdapter.open] hands out, so nothing in `fake_serial_adapter.dart`
/// needs editing: this decorates the interface rather than extending the
/// (final) handle class.
final class _RespondingSerialHandle implements SerialPortHandle {
  _RespondingSerialHandle(this._inner, this._firmware, this._decoder);

  final FakeSerialHandle _inner;
  final FakeFirmware _firmware;
  final FrameDecoder _decoder;

  @override
  Stream<Uint8List> get incoming => _inner.incoming;

  @override
  Future<void> write(Uint8List bytes) async {
    await _inner.write(bytes);
    for (final frame in _decoder.feed(bytes)) {
      final response = _firmware.handle(frame);
      if (response != null) _inner.emit(response.encode());
    }
  }

  @override
  Future<void> close() => _inner.close();
}

/// A [FakeSerialAdapter] whose opened handle answers writes as a real
/// device would (see [_RespondingSerialHandle]). Everything else — open
/// failures, port bookkeeping — is exactly the plain fake's.
base class _RespondingSerialAdapter extends FakeSerialAdapter {
  final FakeFirmware _firmware = FakeFirmware();
  final FrameDecoder _decoder = FrameDecoder();

  @override
  Future<SerialPortHandle> open(
    String path, {
    int baudRate = ChameleonUsbIds.baudRate,
    SerialControlLineMode controlLines = SerialControlLineMode.dtrOnly,
  }) async {
    final inner = await super.open(
      path,
      baudRate: baudRate,
      controlLines: controlLines,
    ) as FakeSerialHandle;
    return _RespondingSerialHandle(inner, _firmware, _decoder);
  }
}

SerialTransport _build() => SerialTransport(
  path: '/dev/cu.usbmodem1',
  adapter: _RespondingSerialAdapter(),
  platform: HostPlatform.macos,
);

void main() {
  transportContractTests('SerialTransport over FakeSerialAdapter', _build);
}
