import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'spectra_database.g.dart';

/// The app's one database (spec 7.3). Drift appears nowhere outside
/// `lib/data/`; features see only the repository interfaces.
@DriftDatabase(
  tables: [SavedCards, KeyDictionaries, KnownDevices, AppPreferences],
)
class SpectraDatabase extends _$SpectraDatabase {
  SpectraDatabase(super.e);

  /// The on-disk database, in the platform's application documents directory.
  factory SpectraDatabase.app() =>
      SpectraDatabase(driftDatabase(name: 'spectra'));

  /// A throwaway database. Every test and the integration test use this, so
  /// the real schema and the real queries are exercised with no file system.
  factory SpectraDatabase.memory() => SpectraDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;
}
