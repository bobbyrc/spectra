// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'repository_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(knownDevicesRepository)
final knownDevicesRepositoryProvider = KnownDevicesRepositoryProvider._();

final class KnownDevicesRepositoryProvider
    extends
        $FunctionalProvider<
          KnownDevicesRepository,
          KnownDevicesRepository,
          KnownDevicesRepository
        >
    with $Provider<KnownDevicesRepository> {
  KnownDevicesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'knownDevicesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$knownDevicesRepositoryHash();

  @$internal
  @override
  $ProviderElement<KnownDevicesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  KnownDevicesRepository create(Ref ref) {
    return knownDevicesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(KnownDevicesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<KnownDevicesRepository>(value),
    );
  }
}

String _$knownDevicesRepositoryHash() =>
    r'3a4514f7932aac0547b173f4c26d312615e5eba5';

@ProviderFor(preferencesRepository)
final preferencesRepositoryProvider = PreferencesRepositoryProvider._();

final class PreferencesRepositoryProvider
    extends
        $FunctionalProvider<
          PreferencesRepository,
          PreferencesRepository,
          PreferencesRepository
        >
    with $Provider<PreferencesRepository> {
  PreferencesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'preferencesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$preferencesRepositoryHash();

  @$internal
  @override
  $ProviderElement<PreferencesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PreferencesRepository create(Ref ref) {
    return preferencesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PreferencesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PreferencesRepository>(value),
    );
  }
}

String _$preferencesRepositoryHash() =>
    r'f2b66daa9f652bd5ac8a8a3447c5864ff56ec172';

@ProviderFor(savedCardsRepository)
final savedCardsRepositoryProvider = SavedCardsRepositoryProvider._();

final class SavedCardsRepositoryProvider
    extends
        $FunctionalProvider<
          SavedCardsRepository,
          SavedCardsRepository,
          SavedCardsRepository
        >
    with $Provider<SavedCardsRepository> {
  SavedCardsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedCardsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedCardsRepositoryHash();

  @$internal
  @override
  $ProviderElement<SavedCardsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SavedCardsRepository create(Ref ref) {
    return savedCardsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SavedCardsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SavedCardsRepository>(value),
    );
  }
}

String _$savedCardsRepositoryHash() =>
    r'1e8673a37efed57fb0fe95a404549c422665e71b';
