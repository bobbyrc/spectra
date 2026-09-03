import 'dart:typed_data';

import 'package:chameleon_flutter/src/ble/ble_adapter.dart';
import 'package:chameleon_flutter/src/ble/ble_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_ble_adapter.dart';

/// The fake stands in for the radio in Tasks 5, 6, 12 and 14, so its
/// scripting is worth proving here rather than in every suite that uses it.
void main() {
  late FakeBleAdapter adapter;

  setUp(() => adapter = FakeBleAdapter());
  tearDown(() => adapter.dispose());

  test('connect fails the scripted number of times, then succeeds', () async {
    adapter
      ..failConnectTimes = 2
      ..failConnectWith = BleFailure.deviceNotFound;

    await expectLater(
      adapter.connect('d'),
      throwsA(
        isA<BleAdapterException>().having(
          (e) => e.failure,
          'failure',
          BleFailure.deviceNotFound,
        ),
      ),
    );
    await expectLater(
      adapter.connect('d'),
      throwsA(isA<BleAdapterException>()),
    );
    await adapter.connect('d');
    expect(adapter.connectAttempts, 3);
  });

  test('subscribe and write failures fire once, then clear', () async {
    adapter
      ..failSubscribeWith = BleFailure.insufficientAuthentication
      ..failWriteWith = BleFailure.writeFailed;

    await expectLater(
      adapter.subscribe('d', service: 's', characteristic: 'c'),
      throwsA(isA<BleAdapterException>()),
    );
    await adapter.subscribe('d', service: 's', characteristic: 'c');

    await expectLater(
      adapter.write(
        'd',
        service: 's',
        characteristic: 'c',
        value: Uint8List(1),
      ),
      throwsA(isA<BleAdapterException>()),
    );
    expect(adapter.writes, isEmpty);
  });

  test(
    'writes are captured in order with their characteristic and mode',
    () async {
      await adapter.write(
        'd',
        service: 's',
        characteristic: 'w',
        value: Uint8List.fromList([1, 2]),
      );
      await adapter.write(
        'd',
        service: 's',
        characteristic: 'p',
        value: Uint8List.fromList([3]),
        withResponse: false,
      );

      expect(adapter.writes.map((w) => w.toList()), [
        [1, 2],
        [3],
      ]);
      expect(adapter.writtenCharacteristics, ['w', 'p']);
      expect(adapter.writeWithResponse, [true, false]);
    },
  );

  test('notifications and disconnects are injectable', () async {
    final notified = <List<int>>[];
    final connection = <bool>[];
    adapter
        .notifications('d', service: 's', characteristic: 'n')
        .listen((v) => notified.add(v.toList()));
    adapter.connectionChanges('d').listen(connection.add);

    adapter
      ..emitNotification('n', [7, 8])
      ..emitDisconnect();
    await pumpEventQueue();

    expect(notified, [
      [7, 8],
    ]);
    expect(connection, [false]);
  });

  test('seeded advertisements replay on scan; stopScan is recorded', () async {
    final seeded = FakeBleAdapter(
      advertisements: const [
        BleScanEntry(deviceId: 'd', name: 'ChameleonUltra'),
      ],
    );
    addTearDown(seeded.dispose);

    final seen = <String?>[];
    seeded.scan().listen((e) => seen.add(e.name));
    await pumpEventQueue();
    seeded.emitAdvertisement(const BleScanEntry(deviceId: 'e', name: 'CU'));
    await pumpEventQueue();

    expect(seen, ['ChameleonUltra', 'CU']);
    await seeded.stopScan();
    expect(seeded.scanStopped, isTrue);
  });

  test('a negative mtu makes requestMtu throw', () async {
    adapter.mtu = -1;
    await expectLater(
      adapter.requestMtu('d', 247),
      throwsA(isA<BleAdapterException>()),
    );
    adapter.mtu = 185;
    expect(await adapter.requestMtu('d', 247), 185);
  });

  test(
    'a scripted scan failure reaches the listener as a stream error',
    () async {
      adapter.failScanWith = BleFailure.adapterOff;

      await expectLater(
        adapter.scan(),
        emitsError(
          isA<BleAdapterException>().having(
            (e) => e.failure,
            'failure',
            BleFailure.adapterOff,
          ),
        ),
      );
    },
  );

  test(
    'a scripted discoverServices failure throws once, then clears',
    () async {
      adapter.failDiscoverWith = BleFailure.disconnected;

      await expectLater(
        adapter.discoverServices('d'),
        throwsA(
          isA<BleAdapterException>().having(
            (e) => e.failure,
            'failure',
            BleFailure.disconnected,
          ),
        ),
      );
      expect(adapter.discovered, isFalse);

      await adapter.discoverServices('d');
      expect(adapter.discovered, isTrue);
    },
  );

  test('stream errors are injectable as BleAdapterExceptions', () async {
    // The interface promises every failure is a BleAdapterException,
    // including ones delivered on a stream rather than thrown from a
    // future. The fake has to be able to script that so the transport's
    // handling of it can be proved.
    final onNotify = <Object>[];
    final onConnection = <Object>[];
    adapter
        .notifications('d', service: 's', characteristic: 'n')
        .listen((_) {}, onError: onNotify.add);
    adapter.connectionChanges('d').listen((_) {}, onError: onConnection.add);

    adapter
      ..emitNotificationError('n', BleFailure.disconnected)
      ..emitConnectionError(BleFailure.adapterOff);
    await pumpEventQueue();

    expect(onNotify.single, isA<BleAdapterException>());
    expect(onConnection.single, isA<BleAdapterException>());
  });

  test('notifications support a second listener', () async {
    final a = <int>[];
    final b = <int>[];
    final stream = adapter.notifications(
      'd',
      service: 's',
      characteristic: 'n',
    );
    stream.listen((v) => a.addAll(v));
    stream.listen((v) => b.addAll(v));

    adapter.emitNotification('n', [1]);
    await pumpEventQueue();

    expect(a, [1]);
    expect(b, [1]);
  });

  test('seeded advertisements replay only on the first scan', () async {
    final seeded = FakeBleAdapter(
      advertisements: const [BleScanEntry(deviceId: 'd', name: 'A')],
    );
    addTearDown(seeded.dispose);

    final seen = <String?>[];
    seeded.scan().listen((e) => seen.add(e.name));
    await pumpEventQueue();
    seeded.scan();
    await pumpEventQueue();

    expect(seen, ['A']);
  });
}
