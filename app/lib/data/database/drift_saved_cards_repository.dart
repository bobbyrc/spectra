import 'package:drift/drift.dart';

import '../models/saved_card.dart';
import '../repositories.dart';
import 'spectra_database.dart';

/// Saved card dumps over the `SavedCards` table (spec 7.3). The table landed
/// at schema version 1 in Phase 4, so this needs no migration.
///
/// Rows come back newest-updated first: the ordering contract both
/// implementations share, and the order a picker wants when it opens.
final class DriftSavedCardsRepository implements SavedCardsRepository {
  DriftSavedCardsRepository(this._db);
  final SpectraDatabase _db;

  @override
  Future<List<SavedCard>> all() async =>
      (await _newestFirst().get()).map(_toModel).toList();

  @override
  Future<SavedCard?> byId(String id) async {
    final row = await (_db.select(
      _db.savedCards,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toModel(row);
  }

  @override
  Future<void> save(SavedCard card) => _db
      .into(_db.savedCards)
      .insertOnConflictUpdate(
        SavedCardRow(
          id: card.id,
          name: card.name,
          tagType: card.tagType,
          bytes: card.bytes,
          folder: card.folder,
          color: card.color,
          updatedAt: card.updatedAt,
        ),
      );

  @override
  Future<void> delete(String id) =>
      (_db.delete(_db.savedCards)..where((t) => t.id.equals(id))).go();

  @override
  Stream<List<SavedCard>> watchAll() => _newestFirst().watch().map(
    (rows) => rows.map(_toModel).toList(growable: false),
  );

  SimpleSelectStatement<$SavedCardsTable, SavedCardRow> _newestFirst() =>
      _db.select(_db.savedCards)
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);

  // Drift's unix-epoch DateTime storage round-trips the same instant but
  // reads it back in the local zone; normalise to UTC so callers get back
  // exactly what they wrote.
  SavedCard _toModel(SavedCardRow row) => SavedCard(
    id: row.id,
    name: row.name,
    tagType: row.tagType,
    bytes: row.bytes,
    updatedAt: row.updatedAt.toUtc(),
    folder: row.folder,
    color: row.color,
  );
}
