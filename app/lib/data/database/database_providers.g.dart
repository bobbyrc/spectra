// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The one database. Overridden at the app root in tests and in the
/// integration test with [SpectraDatabase.memory] (spec 7.1).
///
/// Drift-typed, so this file stays under `lib/data/database/`; the public
/// face features may read is re-exported from `repository_providers.dart`
/// (spec 8.4).

@ProviderFor(database)
final databaseProvider = DatabaseProvider._();

/// The one database. Overridden at the app root in tests and in the
/// integration test with [SpectraDatabase.memory] (spec 7.1).
///
/// Drift-typed, so this file stays under `lib/data/database/`; the public
/// face features may read is re-exported from `repository_providers.dart`
/// (spec 8.4).

final class DatabaseProvider
    extends
        $FunctionalProvider<SpectraDatabase, SpectraDatabase, SpectraDatabase>
    with $Provider<SpectraDatabase> {
  /// The one database. Overridden at the app root in tests and in the
  /// integration test with [SpectraDatabase.memory] (spec 7.1).
  ///
  /// Drift-typed, so this file stays under `lib/data/database/`; the public
  /// face features may read is re-exported from `repository_providers.dart`
  /// (spec 8.4).
  DatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'databaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$databaseHash();

  @$internal
  @override
  $ProviderElement<SpectraDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SpectraDatabase create(Ref ref) {
    return database(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SpectraDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SpectraDatabase>(value),
    );
  }
}

String _$databaseHash() => r'190fb3f06899608946c8e101d059776f1b30e13c';
