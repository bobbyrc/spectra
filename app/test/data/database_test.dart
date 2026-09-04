import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/data/database/spectra_database.dart';

void main() {
  late SpectraDatabase db;

  setUp(() => db = SpectraDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('is at schema version 1', () {
    expect(db.schemaVersion, 1);
  });

  test('creates all four tables', () async {
    final names = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final tables = names.map((r) => r.read<String>('name')).toSet();
    expect(
      tables,
      containsAll(<String>[
        'saved_cards',
        'key_dictionaries',
        'known_devices',
        'app_preferences',
      ]),
    );
  });

  test('app_preferences round trips a value', () async {
    await db
        .into(db.appPreferences)
        .insert(AppPreferencesCompanion.insert(key: 'theme', value: 'dark'));
    final row = await (db.select(
      db.appPreferences,
    )..where((t) => t.key.equals('theme'))).getSingle();
    expect(row.value, 'dark');
  });

  test('known_devices is keyed by identity', () async {
    await db
        .into(db.knownDevices)
        .insert(
          KnownDevicesCompanion.insert(
            identity: 'chip-1',
            displayName: 'Ultra',
            transports: 'usb:/dev/cu.usbmodem1',
            lastSeen: DateTime.utc(2026, 9, 3),
          ),
        );
    final rows = await db.select(db.knownDevices).get();
    expect(rows.single.identity, 'chip-1');
  });
}
