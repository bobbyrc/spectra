import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_ble_adapter.dart';

BleTransport build(
  FakeBleAdapter adapter, {
  HostPlatform platform = HostPlatform.macos,
  int attempts = 5,
}) => BleTransport(
  deviceId: 'AA:BB:CC:DD:EE:FF',
  adapter: adapter,
  platform: platform,
  connectAttempts: attempts,
  initialBackoff: const Duration(milliseconds: 1),
  maxBackoff: const Duration(milliseconds: 4),
);

void main() {
  test('open goes opening -> open and subscribes to notify', () async {
    final adapter = FakeBleAdapter();
    final t = build(adapter);
    final seen = <TransportState>[];
    t.state.listen(seen.add);
    await t.open();
    await Future<void>.delayed(Duration.zero);
    expect(seen.map((s) => s.runtimeType).toList(), [
      TransportOpening,
      TransportOpen,
    ]);
    expect(t.currentState, isA<TransportOpen>());
    expect(t.kind, TransportKind.ble);
    expect(adapter.discovered, isTrue);
    await t.close();
    await adapter.dispose();
  });

  test('maxWriteLength is the largest frame the transport accepts', () async {
    final adapter = FakeBleAdapter(mtu: 23);
    final t = build(adapter);
    await t.open();
    expect(t.maxWriteLength, 4105);
    await t.close();
    await adapter.dispose();
  });

  test('the chunk size comes from the negotiated MTU, never assumed', () async {
    final adapter = FakeBleAdapter(mtu: 104);
    final t = build(adapter);
    await t.open();
    expect(t.chunkSize, 101); // mtu - 3
    await t.close();
    await adapter.dispose();
  });

  test('an MTU the platform will not report falls back to 20', () async {
    final adapter = FakeBleAdapter(mtu: -1);
    final t = build(adapter);
    await t.open();
    expect(t.chunkSize, 20);
    await t.close();
    await adapter.dispose();
  });

  test(
    'writes are chunked at the chunk size, with response, to 6E400002',
    () async {
      final adapter = FakeBleAdapter(mtu: 23); // -> 20 byte chunks
      final t = build(adapter);
      await t.open();
      await t.write(Uint8List.fromList(List<int>.generate(50, (i) => i)));
      expect(adapter.writes.map((c) => c.length).toList(), [20, 20, 10]);
      expect(
        adapter.writes.expand((c) => c).toList(),
        List<int>.generate(50, (i) => i),
      );
      expect(adapter.writtenCharacteristics.toSet(), {NusUuids.write});
      expect(adapter.writeWithResponse, everyElement(isTrue));
      await t.close();
      await adapter.dispose();
    },
  );

  test('notifications on 6E400003 arrive on incoming', () async {
    final adapter = FakeBleAdapter();
    final t = build(adapter);
    final got = <List<int>>[];
    t.incoming.listen((b) => got.add(b.toList()));
    await t.open();
    adapter.emitNotification(NusUuids.notify, const [1, 2, 3]);
    await Future<void>.delayed(Duration.zero);
    expect(got, [
      [1, 2, 3],
    ]);
    await t.close();
    await adapter.dispose();
  });

  test('connect retries up to five times with growing backoff', () async {
    final adapter = FakeBleAdapter()
      ..failConnectTimes = 4
      ..failConnectWith = BleFailure.timeout;
    final t = build(adapter);
    await t.open();
    expect(adapter.connectAttempts, 5);
    expect(t.currentState, isA<TransportOpen>());
    await t.close();
    await adapter.dispose();
  });

  test('a sixth failure gives up with DeviceNotFound and closes', () async {
    final adapter = FakeBleAdapter()
      ..failConnectTimes = 99
      ..failConnectWith = BleFailure.deviceNotFound;
    final t = build(adapter);
    await expectLater(t.open(), throwsA(isA<DeviceNotFound>()));
    expect(adapter.connectAttempts, 5);
    final state = t.currentState;
    expect(state, isA<TransportClosed>());
    expect((state as TransportClosed).cause, CloseCause.linkLost);
    expect(state.error, isA<DeviceNotFound>());
    expect(t.guidance, TransportGuidance.portNotFound);
    await t.close();
    await adapter.dispose();
  });

  test('a permission failure on connect is not retried', () async {
    final adapter = FakeBleAdapter()
      ..failConnectTimes = 99
      ..failConnectWith = BleFailure.permissionDenied;
    final t = build(adapter, platform: HostPlatform.android);
    await expectLater(t.open(), throwsA(isA<PermissionDenied>()));
    expect(adapter.connectAttempts, 1);
    expect(t.currentState, isA<TransportPermissionDenied>());
    expect(t.guidance, TransportGuidance.androidBluetoothPermission);
    await t.close();
    await adapter.dispose();
  });

  test('a powered-off adapter reports adapterOff without connecting', () async {
    final adapter = FakeBleAdapter(availability_: BleAvailability.poweredOff);
    final t = build(adapter);
    final seen = <TransportState>[];
    t.state.listen(seen.add);
    await expectLater(t.open(), throwsA(isA<AdapterOff>()));
    await Future<void>.delayed(Duration.zero);
    expect(seen.map((s) => s.runtimeType).toList(), [
      TransportOpening,
      TransportAdapterOff,
    ]);
    expect(adapter.connectAttempts, 0);
    expect(t.guidance, TransportGuidance.bluetoothAdapterOff);
    await t.close();
    await adapter.dispose();
  });

  test(
    'an unauthorized adapter reports permissionDenied with platform guidance',
    () async {
      final adapter = FakeBleAdapter(
        availability_: BleAvailability.unauthorized,
      );
      final t = build(adapter, platform: HostPlatform.android);
      final seen = <TransportState>[];
      t.state.listen(seen.add);
      await expectLater(t.open(), throwsA(isA<PermissionDenied>()));
      await Future<void>.delayed(Duration.zero);
      expect(seen.map((s) => s.runtimeType).toList(), [
        TransportOpening,
        TransportPermissionDenied,
      ]);
      expect(t.guidance, TransportGuidance.androidBluetoothPermission);
      await t.close();
      await adapter.dispose();
    },
  );

  test('an Apple host is sent to the permission settings pane', () async {
    final adapter = FakeBleAdapter(availability_: BleAvailability.unauthorized);
    final t = build(adapter, platform: HostPlatform.ios);
    await expectLater(t.open(), throwsA(isA<PermissionDenied>()));
    expect(t.guidance, TransportGuidance.applePermissionSettings);
    await t.close();
    await adapter.dispose();
  });

  test('a host with no useful advice gets no guidance', () async {
    final adapter = FakeBleAdapter(availability_: BleAvailability.unauthorized);
    final t = build(adapter, platform: HostPlatform.unknown);
    await expectLater(t.open(), throwsA(isA<PermissionDenied>()));
    expect(t.guidance, isNull);
    await t.close();
    await adapter.dispose();
  });

  test(
    'insufficient authentication on subscribe pairs, then succeeds',
    () async {
      final adapter = FakeBleAdapter()
        ..failSubscribeWith = BleFailure.insufficientAuthentication
        ..pairSucceeds = true;
      final t = build(adapter, platform: HostPlatform.windows);
      await t.open();
      expect(adapter.pairCalls, 1);
      expect(t.currentState, isA<TransportOpen>());
      await t.close();
      await adapter.dispose();
    },
  );

  test('Windows pairs an unpaired device before subscribing', () async {
    final adapter = FakeBleAdapter()..isPaired_ = false;
    final t = build(adapter, platform: HostPlatform.windows);
    await t.open();
    expect(adapter.pairCalls, 1);
    expect(t.currentState, isA<TransportOpen>());
    await t.close();
    await adapter.dispose();
  });

  test('a bonded Windows device is not paired again', () async {
    final adapter = FakeBleAdapter()..isPaired_ = true;
    final t = build(adapter, platform: HostPlatform.windows);
    await t.open();
    expect(adapter.pairCalls, 0);
    await t.close();
    await adapter.dispose();
  });

  test('a failed Windows pre-pair reports pairingRequired, in order', () async {
    final adapter = FakeBleAdapter()
      ..isPaired_ = false
      ..pairSucceeds = false;
    final t = build(adapter, platform: HostPlatform.windows);
    final seen = <TransportState>[];
    t.state.listen(seen.add);
    await expectLater(t.open(), throwsA(isA<PairingRequired>()));
    await Future<void>.delayed(Duration.zero);
    expect(adapter.pairCalls, 1);
    expect(seen.map((s) => s.runtimeType).toList(), [
      TransportOpening,
      TransportPairingRequired,
    ]);
    expect(t.guidance, TransportGuidance.windowsPairDevice);
    await t.close();
    await adapter.dispose();
  });

  test(
    'a failed pair reports pairingRequired with the platform reason',
    () async {
      final adapter = FakeBleAdapter()
        ..failSubscribeWith = BleFailure.insufficientAuthentication
        ..pairSucceeds = false;
      final t = build(adapter, platform: HostPlatform.linux);
      final seen = <TransportState>[];
      t.state.listen(seen.add);
      await expectLater(t.open(), throwsA(isA<PairingRequired>()));
      await Future<void>.delayed(Duration.zero);
      // The quiet disconnect must not land a linkLost on top of this.
      expect(seen.map((s) => s.runtimeType).toList(), [
        TransportOpening,
        TransportPairingRequired,
      ]);
      expect(t.guidance, TransportGuidance.linuxPairFromSettings);
      await t.close();
      await adapter.dispose();
    },
  );

  test('Android leaves pairing to the OS prompt, so has no guidance', () async {
    final adapter = FakeBleAdapter()
      ..failSubscribeWith = BleFailure.insufficientAuthentication
      ..pairSucceeds = false;
    final t = build(adapter, platform: HostPlatform.android);
    await expectLater(t.open(), throwsA(isA<PairingRequired>()));
    expect(t.guidance, isNull);
    await t.close();
    await adapter.dispose();
  });

  test('a failed open disconnects the half-open link', () async {
    final adapter = FakeBleAdapter()
      ..failDiscoverWith = BleFailure.disconnected;
    final t = build(adapter);
    await expectLater(t.open(), throwsA(isA<Disconnected>()));
    expect(adapter.disconnected, isTrue);
    final state = t.currentState;
    expect(state, isA<TransportClosed>());
    expect((state as TransportClosed).cause, CloseCause.linkLost);
    await t.close();
    await adapter.dispose();
  });

  test('a link that drops mid-handshake does not report open', () async {
    final adapter = _DropsOnSubscribe();
    final t = build(adapter);
    final got = <List<int>>[];
    t.incoming.listen((b) => got.add(b.toList()));
    await expectLater(t.open(), throwsA(isA<Disconnected>()));
    final state = t.currentState;
    expect(state, isA<TransportClosed>());
    expect((state as TransportClosed).cause, CloseCause.linkLost);
    // Nothing may still be feeding incoming after the transport gave up.
    adapter.emitNotification(NusUuids.notify, const [9, 9]);
    await Future<void>.delayed(Duration.zero);
    expect(got, isEmpty);
    await t.close();
    await adapter.dispose();
  });

  test('a dropped link closes with linkLost', () async {
    final adapter = FakeBleAdapter();
    final t = build(adapter);
    await t.open();
    adapter.emitDisconnect();
    await Future<void>.delayed(Duration.zero);
    final state = t.currentState;
    expect(state, isA<TransportClosed>());
    expect((state as TransportClosed).cause, CloseCause.linkLost);
    expect(state.error, isA<Disconnected>());
    await t.close();
    await adapter.dispose();
  });

  test('concurrent writes are serialised, never interleaved', () async {
    final adapter = FakeBleAdapter(mtu: 23); // -> 20 byte chunks
    final t = build(adapter);
    await t.open();
    final first = t.write(Uint8List.fromList(List<int>.filled(50, 1)));
    final second = t.write(Uint8List.fromList(List<int>.filled(50, 2)));
    await Future.wait(<Future<void>>[first, second]);
    expect(adapter.writes.map((c) => c.length).toList(), [
      20,
      20,
      10,
      20,
      20,
      10,
    ]);
    expect(adapter.writes.map((c) => c.first).toList(), [1, 1, 1, 2, 2, 2]);
    await t.close();
    await adapter.dispose();
  });

  test('a write queued behind a failed one still runs in order', () async {
    final adapter = FakeBleAdapter(mtu: 23)
      ..failWriteWith = BleFailure.writeFailed;
    final t = build(adapter);
    await t.open();
    final first = t.write(Uint8List.fromList(List<int>.filled(50, 1)));
    final second = t.write(Uint8List.fromList(List<int>.filled(10, 2)));
    await expectLater(first, throwsA(isA<Disconnected>()));
    // The first write closed the link, so the queued one is refused rather
    // than interleaved onto a dead characteristic.
    await expectLater(second, throwsA(isA<Disconnected>()));
    expect(adapter.writes, isEmpty);
    await t.close();
    await adapter.dispose();
  });

  test('a failed write closes the link with Disconnected', () async {
    final adapter = FakeBleAdapter()..failWriteWith = BleFailure.writeFailed;
    final t = build(adapter);
    await t.open();
    await expectLater(
      t.write(Uint8List.fromList(const [1])),
      throwsA(isA<Disconnected>()),
    );
    final state = t.currentState;
    expect(state, isA<TransportClosed>());
    expect((state as TransportClosed).cause, CloseCause.linkLost);
    await t.close();
    await adapter.dispose();
  });

  test(
    'insufficient authentication on write asks for pairing, then closes',
    () async {
      final adapter = FakeBleAdapter()
        ..failWriteWith = BleFailure.insufficientAuthentication;
      final t = build(adapter, platform: HostPlatform.macos);
      final seen = <TransportState>[];
      t.state.listen(seen.add);
      await t.open();
      await expectLater(
        t.write(Uint8List.fromList(const [1])),
        throwsA(isA<PairingRequired>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(seen.map((s) => s.runtimeType).toList(), [
        TransportOpening,
        TransportOpen,
        TransportPairingRequired,
        TransportClosed,
      ]);
      final state = t.currentState;
      expect(state, isA<TransportClosed>());
      expect((state as TransportClosed).error, isA<PairingRequired>());
      expect(t.guidance, TransportGuidance.applePairingPrompt);
      await t.close();
      await adapter.dispose();
    },
  );

  test('close is requested, idempotent, and refuses later writes', () async {
    final adapter = FakeBleAdapter();
    final t = build(adapter);
    await t.open();
    await t.close();
    await t.close();
    expect((t.currentState as TransportClosed).cause, CloseCause.requested);
    expect(adapter.disconnected, isTrue);
    await expectLater(
      t.write(Uint8List.fromList(const [1])),
      throwsA(isA<Disconnected>()),
    );
    await adapter.dispose();
  });

  test('a closed transport does not open again', () async {
    final adapter = FakeBleAdapter();
    final t = build(adapter);
    await t.open();
    await t.close();
    await expectLater(t.open(), throwsA(isA<Disconnected>()));
    await adapter.dispose();
  });

  test('writing before open throws Disconnected', () async {
    final adapter = FakeBleAdapter();
    final t = build(adapter);
    await expectLater(
      t.write(Uint8List.fromList(const [1])),
      throwsA(isA<Disconnected>()),
    );
    await t.close();
    await adapter.dispose();
  });
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
