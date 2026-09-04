import '../repositories.dart';
import 'spectra_database.dart';

final class DriftPreferencesRepository implements PreferencesRepository {
  DriftPreferencesRepository(this._db);
  final SpectraDatabase _db;

  @override
  Future<String?> read(String key) async {
    final row = await (_db.select(
      _db.appPreferences,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> write(String key, String value) async {
    await _db
        .into(_db.appPreferences)
        .insertOnConflictUpdate(
          AppPreferencesCompanion.insert(key: key, value: value),
        );
  }

  @override
  Future<void> remove(String key) async {
    await (_db.delete(
      _db.appPreferences,
    )..where((t) => t.key.equals(key))).go();
  }
}
