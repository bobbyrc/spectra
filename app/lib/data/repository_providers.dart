import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'database/database_providers.dart';
import 'database/drift_known_devices_repository.dart';
import 'database/drift_preferences_repository.dart';
import 'repositories.dart';

/// The public face of the database provider: features that need to override
/// it (tests, and the integration test) reach it here, never by importing
/// `data/database/…` directly (spec 8.4).
export 'database/database_providers.dart' show databaseProvider;

part 'repository_providers.g.dart';

@Riverpod(keepAlive: true)
KnownDevicesRepository knownDevicesRepository(Ref ref) =>
    DriftKnownDevicesRepository(ref.watch(databaseProvider));

@Riverpod(keepAlive: true)
PreferencesRepository preferencesRepository(Ref ref) =>
    DriftPreferencesRepository(ref.watch(databaseProvider));
