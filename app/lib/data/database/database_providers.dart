import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'spectra_database.dart';

part 'database_providers.g.dart';

/// The one database. Overridden at the app root in tests and in the
/// integration test with [SpectraDatabase.memory] (spec 7.1).
///
/// Drift-typed, so this file stays under `lib/data/database/`; the public
/// face features may read is re-exported from `repository_providers.dart`
/// (spec 8.4).
@Riverpod(keepAlive: true)
SpectraDatabase database(Ref ref) {
  final db = SpectraDatabase.app();
  ref.onDispose(db.close);
  return db;
}
