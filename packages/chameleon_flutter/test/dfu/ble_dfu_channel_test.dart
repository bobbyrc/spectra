import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:chameleon_flutter/src/dfu/ble_dfu_channel.dart';
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
}
