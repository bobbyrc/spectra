import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/data/database/drift_known_devices_repository.dart';
import 'package:spectra/data/database/drift_preferences_repository.dart';
import 'package:spectra/data/database/spectra_database.dart';
import 'package:spectra/data/memory/in_memory_repositories.dart';

const identity = DeviceIdentity('chip-1');

void main() {
  group('every KnownDevicesRepository', () {
    late SpectraDatabase db;

    setUp(() => db = SpectraDatabase.memory());
    tearDown(() => db.close());

    for (final entry
        in <String, KnownDevicesRepository Function(SpectraDatabase)>{
          'drift': DriftKnownDevicesRepository.new,
          'memory': (_) => InMemoryKnownDevicesRepository(),
        }.entries) {
      test('${entry.key}: remembers a device and reads it back', () async {
        final repo = entry.value(db);
        await repo.remember(
          identity: identity,
          displayName: 'Ultra',
          kind: TransportKind.usb,
          transportId: '/dev/cu.usbmodem1',
          at: DateTime.utc(2026, 9, 1),
        );
        final found = await repo.byIdentity(identity);
        expect(found!.displayName, 'Ultra');
        expect(found.transports.single.transportId, '/dev/cu.usbmodem1');
      });

      test(
        '${entry.key}: adds a second transport to the same identity',
        () async {
          final repo = entry.value(db);
          await repo.remember(
            identity: identity,
            displayName: 'Ultra',
            kind: TransportKind.usb,
            transportId: '/dev/cu.usbmodem1',
            at: DateTime.utc(2026, 9, 1),
          );
          await repo.remember(
            identity: identity,
            displayName: 'Ultra',
            kind: TransportKind.ble,
            transportId: 'AA:BB',
            at: DateTime.utc(2026, 9, 2),
          );
          final found = await repo.byIdentity(identity);
          expect(found!.transports, hasLength(2));
          expect(found.lastSeen, DateTime.utc(2026, 9, 2));
        },
      );

      test('${entry.key}: lastSeen returns the newest device', () async {
        final repo = entry.value(db);
        await repo.remember(
          identity: identity,
          displayName: 'Older',
          kind: TransportKind.usb,
          transportId: 'a',
          at: DateTime.utc(2026, 9, 1),
        );
        await repo.remember(
          identity: const DeviceIdentity('chip-2'),
          displayName: 'Newer',
          kind: TransportKind.usb,
          transportId: 'b',
          at: DateTime.utc(2026, 9, 5),
        );
        expect((await repo.lastSeen())!.displayName, 'Newer');
      });

      test(
        '${entry.key}: matches a discovered device by kind and id',
        () async {
          final repo = entry.value(db);
          await repo.remember(
            identity: identity,
            displayName: 'Ultra',
            kind: TransportKind.usb,
            transportId: '/dev/cu.usbmodem1',
          );
          final known = (await repo.all()).single;
          expect(
            known.matches(
              const DiscoveredDevice(
                name: 'ChameleonUltra',
                kind: TransportKind.usb,
                transportId: '/dev/cu.usbmodem1',
              ),
            ),
            isTrue,
          );
        },
      );

      test('${entry.key}: forget removes it', () async {
        final repo = entry.value(db);
        await repo.remember(
          identity: identity,
          displayName: 'Ultra',
          kind: TransportKind.usb,
          transportId: 'a',
        );
        await repo.forget(identity);
        expect(await repo.all(), isEmpty);
      });
    }

    test(
      'memory: watchAll emits the current rows and then every change',
      () async {
        // The single-subscription controller's `onListen` runs inside
        // `listen()`, so a `remember()` issued before the first snapshot is
        // delivered is still seen. An `async*` version would have dropped it.
        final repo = InMemoryKnownDevicesRepository();
        await repo.remember(
          identity: identity,
          displayName: 'Ultra',
          kind: TransportKind.usb,
          transportId: 'a',
        );
        final collected = repo.watchAll().take(2).toList();
        await repo.remember(
          identity: const DeviceIdentity('chip-2'),
          displayName: 'Second',
          kind: TransportKind.usb,
          transportId: 'b',
        );
        final emissions = await collected;
        expect(emissions.first, hasLength(1));
        expect(emissions.last, hasLength(2));
      },
    );

    test('drift: watchAll emits on every change', () async {
      final repo = DriftKnownDevicesRepository(db);
      expect(repo.watchAll(), emitsInOrder(<Object>[isEmpty, hasLength(1)]));
      await repo.remember(
        identity: identity,
        displayName: 'Ultra',
        kind: TransportKind.usb,
        transportId: 'a',
      );
    });
  });

  group('every PreferencesRepository', () {
    late SpectraDatabase db;

    setUp(() => db = SpectraDatabase.memory());
    tearDown(() => db.close());

    for (final entry
        in <String, PreferencesRepository Function(SpectraDatabase)>{
          'drift': DriftPreferencesRepository.new,
          'memory': (_) => InMemoryPreferencesRepository(),
        }.entries) {
      test(
        '${entry.key}: reads back what it wrote, and null otherwise',
        () async {
          final repo = entry.value(db);
          expect(await repo.read('flag'), isNull);
          await repo.write('flag', 'true');
          expect(await repo.read('flag'), 'true');
          await repo.write('flag', 'false');
          expect(await repo.read('flag'), 'false');
          await repo.remove('flag');
          expect(await repo.read('flag'), isNull);
        },
      );
    }
  });
}
