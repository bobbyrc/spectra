import 'package:drift/drift.dart';

/// Saved card dumps (spec 7.3). Written from Phase 6; the table exists now so
/// schema version 1 is the whole v1 shape and Phase 6 needs no migration.
@DataClassName('SavedCardRow')
class SavedCards extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get tagType => text()();
  BlobColumn get bytes => blob()();
  TextColumn get folder => text().nullable()();
  IntColumn get color => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Key dictionaries (spec 7.3). Written from Phase 9. Keys are stored as one
/// newline-separated hex blob: a dictionary is read and written whole.
@DataClassName('KeyDictionaryRow')
class KeyDictionaries extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get keys => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Identity to last-seen transports (spec 4.2). [transports] is a
/// newline-separated list of `kind:transportId`, because it is only ever read
/// and written whole and a join table would buy nothing.
@DataClassName('KnownDeviceRow')
class KnownDevices extends Table {
  TextColumn get identity => text()();
  TextColumn get displayName => text()();
  TextColumn get transports => text()();
  DateTimeColumn get lastSeen => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {identity};
}

/// App preferences (spec 7.3): a key/value store, one row per setting.
class AppPreferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
