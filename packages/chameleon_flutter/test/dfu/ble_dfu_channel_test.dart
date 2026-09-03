import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_ble_adapter.dart';

BleDfuChannel build(
  FakeBleAdapter adapter, {
  HostPlatform platform = HostPlatform.linux,
}) => BleDfuChannel(
  deviceId: 'AA:BB:CC:DD:EE:FF',
  adapter: adapter,
  platform: platform,
);

void main() {
  test(
    'open connects, discovers and subscribes to the control point',
    () async {
      final adapter = FakeBleAdapter();
      final channel = build(adapter);
      await channel.open();
      expect(adapter.connectAttempts, 1);
      expect(adapter.discovered, isTrue);
      await channel.close();
      await adapter.dispose();
    },
  );

  test('iOS and macOS write 20 bytes whatever the MTU says', () async {
    for (final p in const [HostPlatform.ios, HostPlatform.macos]) {
      final adapter = FakeBleAdapter(mtu: 247);
      final channel = build(adapter, platform: p);
      await channel.open();
      expect(channel.maxDataWrite, 20, reason: p.name);
      await channel.close();
      await adapter.dispose();
    }
  });

  test('elsewhere the write size is the negotiated MTU minus three', () async {
    final adapter = FakeBleAdapter(mtu: 247);
    final channel = build(adapter, platform: HostPlatform.android);
    await channel.open();
    expect(channel.maxDataWrite, 244);
    await channel.close();
    await adapter.dispose();
  });

  test('control writes go to 8EC90001 with response, unchunked', () async {
    final adapter = FakeBleAdapter(mtu: 23);
    final channel = build(adapter);
    await channel.open();
    await channel.writeControl(Uint8List.fromList(const [0x06, 0x01]));
    expect(adapter.writtenCharacteristics.single, NordicDfuUuids.controlPoint);
    expect(adapter.writes.single, [0x06, 0x01]);
    expect(adapter.writeWithResponse.single, isTrue);
    await channel.close();
    await adapter.dispose();
  });

  test(
    'data writes go to 8EC90002 without response, as a single packet',
    () async {
      final adapter = FakeBleAdapter(mtu: 23); // -> 20 bytes
      final channel = build(adapter);
      await channel.open();
      final payload = Uint8List.fromList(List<int>.generate(20, (i) => i));
      await channel.writeData(payload);
      expect(adapter.writtenCharacteristics.single, NordicDfuUuids.packet);
      expect(adapter.writes.single, payload);
      expect(adapter.writeWithResponse.single, isFalse);
      await channel.close();
      await adapter.dispose();
    },
  );

  test('writeData rejects a payload larger than maxDataWrite', () async {
    final adapter = FakeBleAdapter(mtu: 23); // -> 20 bytes
    final channel = build(adapter);
    await channel.open();
    expect(
      () => channel.writeData(
        Uint8List.fromList(List<int>.generate(21, (i) => i)),
      ),
      throwsArgumentError,
    );
    expect(adapter.writes, isEmpty);
    await channel.close();
    await adapter.dispose();
  });

  test('notifications from the control point become responses', () async {
    final adapter = FakeBleAdapter();
    final channel = build(adapter);
    final got = <List<int>>[];
    channel.responses.listen((f) => got.add(f.toList()));
    await channel.open();
    adapter.emitNotification(NordicDfuUuids.controlPoint, const [
      0x60,
      0x06,
      0x01,
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(got, [
      [0x60, 0x06, 0x01],
    ]);
    await channel.close();
    await adapter.dispose();
  });

  test('a write before open, or after close, throws Disconnected', () async {
    final adapter = FakeBleAdapter();
    final channel = build(adapter);
    await expectLater(
      channel.writeControl(Uint8List.fromList(const [1])),
      throwsA(isA<Disconnected>()),
    );
    await channel.open();
    await channel.close();
    await expectLater(
      channel.writeData(Uint8List.fromList(const [1])),
      throwsA(isA<Disconnected>()),
    );
    await adapter.dispose();
  });

  test('close disconnects the device', () async {
    final adapter = FakeBleAdapter();
    final channel = build(adapter);
    await channel.open();
    await channel.close();
    expect(adapter.disconnected, isTrue);
    await adapter.dispose();
  });

  test('a connection drop after open surfaces as Disconnected on responses, '
      'then the stream closes', () async {
    final adapter = FakeBleAdapter();
    final channel = build(adapter);
    await channel.open();
    final errors = <Object>[];
    var done = false;
    channel.responses.listen(
      (_) {},
      onError: errors.add,
      onDone: () => done = true,
    );
    adapter.emitDisconnect();
    await Future<void>.delayed(Duration.zero);
    expect(errors, [isA<Disconnected>()]);
    expect(done, isTrue);
    await expectLater(
      channel.writeControl(Uint8List.fromList(const [1])),
      throwsA(isA<Disconnected>()),
    );
    await adapter.dispose();
  });

  group('open() maps every BleFailure and disconnects quietly first', () {
    const cases = <BleFailure, Type>{
      BleFailure.permissionDenied: PermissionDenied,
      BleFailure.adapterOff: AdapterOff,
      BleFailure.insufficientAuthentication: PairingRequired,
      BleFailure.deviceNotFound: DeviceNotFound,
      BleFailure.timeout: DeviceNotFound,
      BleFailure.disconnected: Disconnected,
      BleFailure.writeFailed: Disconnected,
      BleFailure.unknown: Disconnected,
    };

    for (final entry in cases.entries) {
      test('${entry.key.name} -> ${entry.value}', () async {
        final adapter = FakeBleAdapter()..failDiscoverWith = entry.key;
        final channel = build(adapter);
        await expectLater(
          channel.open(),
          throwsA(
            isA<TransportError>().having(
              (e) => e.runtimeType,
              'runtimeType',
              entry.value,
            ),
          ),
        );
        // _mapFailure ran and open() disconnected quietly before the
        // error surfaced — mirrors BleTransport's `_reportFailure` then
        // `_disconnectQuietly` ordering.
        expect(adapter.disconnected, isTrue);
        await channel.close();
        await adapter.dispose();
      });
    }
  });

  test(
    'a writeControl failure maps the error and closes the channel quietly',
    () async {
      final adapter = FakeBleAdapter()..failWriteWith = BleFailure.writeFailed;
      final channel = build(adapter);
      await channel.open();
      final errors = <Object>[];
      var done = false;
      channel.responses.listen(
        (_) {},
        onError: errors.add,
        onDone: () => done = true,
      );
      await expectLater(
        channel.writeControl(Uint8List.fromList(const [1])),
        throwsA(isA<Disconnected>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(errors, [isA<Disconnected>()]);
      expect(done, isTrue);
      // The channel is closed, not merely the one failed write.
      await expectLater(
        channel.writeData(Uint8List.fromList(const [1])),
        throwsA(isA<Disconnected>()),
      );
      await adapter.dispose();
    },
  );

  test(
    'a writeData failure maps the error and closes the channel quietly',
    () async {
      final adapter =
          FakeBleAdapter(mtu: 23) // -> 20 bytes
            ..failWriteWith = BleFailure.insufficientAuthentication;
      final channel = build(adapter);
      await channel.open();
      final errors = <Object>[];
      var done = false;
      channel.responses.listen(
        (_) {},
        onError: errors.add,
        onDone: () => done = true,
      );
      await expectLater(
        channel.writeData(Uint8List.fromList(const [1])),
        throwsA(isA<PairingRequired>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(errors, [isA<PairingRequired>()]);
      expect(done, isTrue);
      await expectLater(
        channel.writeControl(Uint8List.fromList(const [1])),
        throwsA(isA<Disconnected>()),
      );
      await adapter.dispose();
    },
  );

  test(
    'a link that drops while open() is still connecting fails with '
    'Disconnected, disconnects quietly and leaves no subscriptions behind',
    () async {
      final adapter = _DropsDuringConnect();
      final channel = build(adapter);
      final errors = <Object>[];
      var done = false;
      channel.responses.listen(
        (_) {},
        onError: errors.add,
        onDone: () => done = true,
      );
      await expectLater(channel.open(), throwsA(isA<Disconnected>()));
      await Future<void>.delayed(Duration.zero);
      expect(errors, [isA<Disconnected>()]);
      expect(done, isTrue);
      expect(adapter.disconnected, isTrue);
      // Nothing may still be feeding responses after open gave up.
      adapter.emitNotification(NordicDfuUuids.controlPoint, const [9, 9]);
      await Future<void>.delayed(Duration.zero);
      await channel.close();
      await adapter.dispose();
    },
  );

  test(
    'a link that drops mid-handshake fails open with Disconnected',
    () async {
      final adapter = _DropsOnSubscribe();
      final channel = build(adapter);
      final errors = <Object>[];
      var done = false;
      channel.responses.listen(
        (_) {},
        onError: errors.add,
        onDone: () => done = true,
      );
      await expectLater(channel.open(), throwsA(isA<Disconnected>()));
      await Future<void>.delayed(Duration.zero);
      expect(errors, [isA<Disconnected>()]);
      expect(done, isTrue);
      await channel.close();
      await adapter.dispose();
    },
  );
}

/// Drops the link the instant [connect] is called, before it resolves —
/// only catchable because [BleDfuChannel.open] subscribes to
/// [FakeBleAdapter.connectionChanges] before calling [connect], exactly as
/// [BleTransport] does.
base class _DropsDuringConnect extends FakeBleAdapter {
  @override
  Future<void> connect(String deviceId, {Duration? timeout}) async {
    emitDisconnect();
    await Future<void>.delayed(Duration.zero);
    return super.connect(deviceId, timeout: timeout);
  }
}

/// Drops the link while the handshake is still running, which no scripted
/// field on the fake can express.
base class _DropsOnSubscribe extends FakeBleAdapter {
  @override
  Future<void> subscribe(
    String deviceId, {
    required String service,
    required String characteristic,
  }) async {
    emitDisconnect();
    await Future<void>.delayed(Duration.zero);
    return super.subscribe(
      deviceId,
      service: service,
      characteristic: characteristic,
    );
  }
}
