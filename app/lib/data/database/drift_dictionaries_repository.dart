import 'package:drift/drift.dart';

import '../../core/format/hex.dart';
import '../models/key_dictionary.dart';
import '../repositories.dart';
import 'spectra_database.dart';

/// Key dictionaries over the `KeyDictionaries` table (spec 7.3). The table
/// landed at schema version 1 in Phase 4, so this needs no migration.
///
/// Keys are one newline-separated hex blob, as `tables.dart` says: a
/// dictionary is read and written whole, and a join table would buy nothing
/// but a migration. A row whose blob holds a line that is not a key (a
/// hand-edited database, a future format) drops that line rather than
/// failing the whole read — a dictionary is a hint list, and losing one bad
/// line is better than losing the list.
final class DriftDictionariesRepository implements DictionariesRepository {
  DriftDictionariesRepository(this._db);
  final SpectraDatabase _db;

  @override
  Future<List<KeyDictionary>> all() async =>
      (await _newestFirst().get()).map(_toModel).toList();

  @override
  Future<void> save(KeyDictionary dictionary) => _db
      .into(_db.keyDictionaries)
      .insertOnConflictUpdate(
        KeyDictionaryRow(
          id: dictionary.id,
          name: dictionary.name,
          keys: encodeKeyLines(dictionary.keys),
          updatedAt: dictionary.updatedAt,
        ),
      );

  @override
  Future<void> delete(String id) =>
      (_db.delete(_db.keyDictionaries)..where((t) => t.id.equals(id))).go();

  @override
  Stream<List<KeyDictionary>> watchAll() => _newestFirst().watch().map(
    (rows) => rows.map(_toModel).toList(growable: false),
  );

  SimpleSelectStatement<$KeyDictionariesTable, KeyDictionaryRow>
  _newestFirst() =>
      _db.select(_db.keyDictionaries)
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);

  // Drift's unix-epoch DateTime storage round-trips the same instant but
  // reads it back in the local zone; normalise to UTC so callers get back
  // exactly what they wrote (the `DriftSavedCardsRepository` note).
  KeyDictionary _toModel(KeyDictionaryRow row) => KeyDictionary(
    id: row.id,
    name: row.name,
    keys: decodeKeyLines(row.keys),
    updatedAt: row.updatedAt.toUtc(),
  );
}

/// One key per line, upper-case hex. Public so the in-memory repository and
/// the tests share exactly one encoding.
String encodeKeyLines(List<Uint8List> keys) =>
    keys.map<String>(toHex).join('\n');

List<Uint8List> decodeKeyLines(String blob) => <Uint8List>[
  for (final String line in blob.split('\n'))
    if (parseMifareKey(line) case final Uint8List key) key,
];
