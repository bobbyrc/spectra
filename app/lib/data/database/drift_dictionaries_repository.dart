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
          keys: _encodeKeyLines(dictionary.keys),
          updatedAt: dictionary.updatedAt,
        ),
      );

  @override
  Future<void> delete(String id) =>
      (_db.delete(_db.keyDictionaries)..where((t) => t.id.equals(id))).go();

  // Growable, matching `all()` above and `InMemoryDictionariesRepository`'s
  // own `watchAll()`: `DictionariesRepository` documents no fixed-length
  // contract, and a `growable: false` list here would throw the moment a
  // caller tried to sort or otherwise mutate what it got back.
  @override
  Stream<List<KeyDictionary>> watchAll() =>
      _newestFirst().watch().map((rows) => rows.map(_toModel).toList());

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
    keys: _decodeKeyLines(row.keys),
    updatedAt: row.updatedAt.toUtc(),
  );
}

/// One key per line, upper-case hex.
///
/// Private: `InMemoryDictionariesRepository` stores `KeyDictionary.keys`
/// directly and never calls this — only this table's own blob column needs
/// a text encoding — and nothing outside this file reads it either.
String _encodeKeyLines(List<Uint8List> keys) =>
    keys.map<String>(toHex).join('\n');

/// The inverse of [_encodeKeyLines]. Every dictionary in this app is a
/// MIFARE Classic key list (spec 7.3 scope for v1), so a line is kept only
/// when it parses as a 6-byte key via [parseMifareKey] — a line that is not
/// a key at all (a hand-edited database, a future format) is silently
/// dropped rather than failing the whole read, per this file's own top
/// doc comment. That same 6-byte check means a *shorter* key some future
/// dictionary kind might hold (an LF password, say) would be dropped here
/// too, not just outright-invalid text; there is no such kind yet, but a
/// change that adds one must widen this, not just `parseMifareKey`.
List<Uint8List> _decodeKeyLines(String blob) => <Uint8List>[
  for (final String line in blob.split('\n'))
    if (parseMifareKey(line) case final Uint8List key) key,
];
