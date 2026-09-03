// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dictionaries_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every key list the app knows: the built-in one, then the stored ones
/// newest-updated first (the repository's ordering contract,
/// `data/database/drift_dictionaries_repository.dart`). Every screen
/// watches this; nothing calls the repository directly.

@ProviderFor(dictionaries)
final dictionariesProvider = DictionariesProvider._();

/// Every key list the app knows: the built-in one, then the stored ones
/// newest-updated first (the repository's ordering contract,
/// `data/database/drift_dictionaries_repository.dart`). Every screen
/// watches this; nothing calls the repository directly.

final class DictionariesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<KeyDictionary>>,
          List<KeyDictionary>,
          Stream<List<KeyDictionary>>
        >
    with
        $FutureModifier<List<KeyDictionary>>,
        $StreamProvider<List<KeyDictionary>> {
  /// Every key list the app knows: the built-in one, then the stored ones
  /// newest-updated first (the repository's ordering contract,
  /// `data/database/drift_dictionaries_repository.dart`). Every screen
  /// watches this; nothing calls the repository directly.
  DictionariesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dictionariesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dictionariesHash();

  @$internal
  @override
  $StreamProviderElement<List<KeyDictionary>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<KeyDictionary>> create(Ref ref) {
    return dictionaries(ref);
  }
}

String _$dictionariesHash() => r'b3c990a0d6ce579b8c1d80fc1e17a8fe239c478b';

/// Every write to the dictionaries, as an [AsyncValue] the screen renders.
///
/// Failures stay in the state rather than being thrown, so a screen shows
/// them through the spec 9 catalog (`ProblemView`) instead of catching. A
/// call made while another is in flight is dropped, not queued, and the
/// screen disables its controls while `state.isLoading`.
///
/// This notifier is autoDispose: a sheet can be dismissed (or the screen
/// under it torn down) while a write is still in flight, so every
/// assignment to [state] after an `await` is guarded with `ref.mounted`
/// (R25) — the write itself still completes, there is simply no longer
/// anywhere to report it.

@ProviderFor(DictionaryLibrary)
final dictionaryLibraryProvider = DictionaryLibraryProvider._();

/// Every write to the dictionaries, as an [AsyncValue] the screen renders.
///
/// Failures stay in the state rather than being thrown, so a screen shows
/// them through the spec 9 catalog (`ProblemView`) instead of catching. A
/// call made while another is in flight is dropped, not queued, and the
/// screen disables its controls while `state.isLoading`.
///
/// This notifier is autoDispose: a sheet can be dismissed (or the screen
/// under it torn down) while a write is still in flight, so every
/// assignment to [state] after an `await` is guarded with `ref.mounted`
/// (R25) — the write itself still completes, there is simply no longer
/// anywhere to report it.
final class DictionaryLibraryProvider
    extends $AsyncNotifierProvider<DictionaryLibrary, void> {
  /// Every write to the dictionaries, as an [AsyncValue] the screen renders.
  ///
  /// Failures stay in the state rather than being thrown, so a screen shows
  /// them through the spec 9 catalog (`ProblemView`) instead of catching. A
  /// call made while another is in flight is dropped, not queued, and the
  /// screen disables its controls while `state.isLoading`.
  ///
  /// This notifier is autoDispose: a sheet can be dismissed (or the screen
  /// under it torn down) while a write is still in flight, so every
  /// assignment to [state] after an `await` is guarded with `ref.mounted`
  /// (R25) — the write itself still completes, there is simply no longer
  /// anywhere to report it.
  DictionaryLibraryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dictionaryLibraryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dictionaryLibraryHash();

  @$internal
  @override
  DictionaryLibrary create() => DictionaryLibrary();
}

String _$dictionaryLibraryHash() => r'0d384cc9c48910867aea88c38c8bdaf92662cced';

/// Every write to the dictionaries, as an [AsyncValue] the screen renders.
///
/// Failures stay in the state rather than being thrown, so a screen shows
/// them through the spec 9 catalog (`ProblemView`) instead of catching. A
/// call made while another is in flight is dropped, not queued, and the
/// screen disables its controls while `state.isLoading`.
///
/// This notifier is autoDispose: a sheet can be dismissed (or the screen
/// under it torn down) while a write is still in flight, so every
/// assignment to [state] after an `await` is guarded with `ref.mounted`
/// (R25) — the write itself still completes, there is simply no longer
/// anywhere to report it.

abstract class _$DictionaryLibrary extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
