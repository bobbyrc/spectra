import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';

import '../support/fake_ble_adapter.dart';
import 'transport_contract.dart';

/// A [FakeBleAdapter] that answers a write the way a real Chameleon would:
/// decoded through the SDK's own [FrameDecoder] and dispatched to a
/// [FakeFirmware], with the response pushed back as a notification on
/// [NusUuids.notify].
///
/// [FakeBleAdapter] only records writes (it never answers them), and it
/// cannot be edited for this task — so this subclass drives it instead of
/// weakening the contract to skip the "bytes come back" behaviours. It only
/// overrides [write]; every other behaviour (scan, connect, subscribe,
/// pairing, MTU) is exactly the plain fake's.
base class _RespondingBleAdapter extends FakeBleAdapter {
  final FakeFirmware _firmware = FakeFirmware();
  final FrameDecoder _decoder = FrameDecoder();

  @override
  Future<void> write(
    String deviceId, {
    required String service,
    required String characteristic,
    required Uint8List value,
    bool withResponse = true,
  }) async {
    await super.write(
      deviceId,
      service: service,
      characteristic: characteristic,
      value: value,
      withResponse: withResponse,
    );
    for (final frame in _decoder.feed(value)) {
      final response = _firmware.handle(frame);
      if (response != null) {
        emitNotification(NusUuids.notify, response.encode());
      }
    }
  }
}

/// The adapter behind the transport the last [_build] or [_buildSmallMtu]
/// handed out, so the contract suite can stage a disconnect on it.
_RespondingBleAdapter? _lastAdapter;

void _drop(Transport _) => _lastAdapter!.emitDisconnect();

BleTransport _build() => BleTransport(
  deviceId: 'AA:BB:CC:DD:EE:FF',
  adapter: _lastAdapter = _RespondingBleAdapter(),
  platform: HostPlatform.macos,
  initialBackoff: const Duration(milliseconds: 1),
  maxBackoff: const Duration(milliseconds: 4),
);

/// A minimal-MTU peripheral: the 9-byte GET_APP_VERSION request still fits
/// in one write, but responses larger than ~20 bytes must fragment across
/// several notifications, exercising [BleTransport]'s chunking.
BleTransport _buildSmallMtu() => BleTransport(
  deviceId: 'AA:BB:CC:DD:EE:FF',
  adapter: _lastAdapter = _RespondingBleAdapter()..mtu = 23,
  platform: HostPlatform.macos,
  initialBackoff: const Duration(milliseconds: 1),
  maxBackoff: const Duration(milliseconds: 4),
);

void main() {
  transportContractTests(
    'BleTransport over FakeBleAdapter',
    _build,
    simulateLinkLoss: _drop,
  );
  transportContractTests(
    'BleTransport over FakeBleAdapter with mtu=23',
    _buildSmallMtu,
    simulateLinkLoss: _drop,
  );
}
