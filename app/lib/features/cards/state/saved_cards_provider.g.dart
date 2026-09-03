// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_cards_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The library, newest-updated first (the repository's ordering contract,
/// `data/database/drift_saved_cards_repository.dart`). Every screen watches
/// this; nothing calls the repository directly.

@ProviderFor(savedCards)
final savedCardsProvider = SavedCardsProvider._();

/// The library, newest-updated first (the repository's ordering contract,
/// `data/database/drift_saved_cards_repository.dart`). Every screen watches
/// this; nothing calls the repository directly.

final class SavedCardsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SavedCard>>,
          List<SavedCard>,
          Stream<List<SavedCard>>
        >
    with $FutureModifier<List<SavedCard>>, $StreamProvider<List<SavedCard>> {
  /// The library, newest-updated first (the repository's ordering contract,
  /// `data/database/drift_saved_cards_repository.dart`). Every screen watches
  /// this; nothing calls the repository directly.
  SavedCardsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedCardsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedCardsHash();

  @$internal
  @override
  $StreamProviderElement<List<SavedCard>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<SavedCard>> create(Ref ref) {
    return savedCards(ref);
  }
}

String _$savedCardsHash() => r'9fec74b63d0aec575953767a6ab3434346043cd4';

/// Every write to the library, as an [AsyncValue] the screen renders.
///
/// Failures stay in the state rather than being thrown, so a screen shows
/// them through the spec 9 catalog (`ProblemView`) instead of catching. A
/// call made while another is in flight is dropped, not queued; the sheet
/// disables its confirm button while `state.isLoading`.
///
/// This notifier is autoDispose: the save sheet can be dismissed (or the
/// screen underneath it torn down) while a write is still on the wire, so
/// every assignment to [state] after an `await` is guarded with
/// `ref.mounted` (Phase 6 ruling 2) — the write itself still runs to
/// completion, there is simply no longer anywhere to report it.

@ProviderFor(CardLibrary)
final cardLibraryProvider = CardLibraryProvider._();

/// Every write to the library, as an [AsyncValue] the screen renders.
///
/// Failures stay in the state rather than being thrown, so a screen shows
/// them through the spec 9 catalog (`ProblemView`) instead of catching. A
/// call made while another is in flight is dropped, not queued; the sheet
/// disables its confirm button while `state.isLoading`.
///
/// This notifier is autoDispose: the save sheet can be dismissed (or the
/// screen underneath it torn down) while a write is still on the wire, so
/// every assignment to [state] after an `await` is guarded with
/// `ref.mounted` (Phase 6 ruling 2) — the write itself still runs to
/// completion, there is simply no longer anywhere to report it.
final class CardLibraryProvider
    extends $AsyncNotifierProvider<CardLibrary, void> {
  /// Every write to the library, as an [AsyncValue] the screen renders.
  ///
  /// Failures stay in the state rather than being thrown, so a screen shows
  /// them through the spec 9 catalog (`ProblemView`) instead of catching. A
  /// call made while another is in flight is dropped, not queued; the sheet
  /// disables its confirm button while `state.isLoading`.
  ///
  /// This notifier is autoDispose: the save sheet can be dismissed (or the
  /// screen underneath it torn down) while a write is still on the wire, so
  /// every assignment to [state] after an `await` is guarded with
  /// `ref.mounted` (Phase 6 ruling 2) — the write itself still runs to
  /// completion, there is simply no longer anywhere to report it.
  CardLibraryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cardLibraryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cardLibraryHash();

  @$internal
  @override
  CardLibrary create() => CardLibrary();
}

String _$cardLibraryHash() => r'd9ddf3de5e96c4df2ba8922a4546c0e48ef32a17';

/// Every write to the library, as an [AsyncValue] the screen renders.
///
/// Failures stay in the state rather than being thrown, so a screen shows
/// them through the spec 9 catalog (`ProblemView`) instead of catching. A
/// call made while another is in flight is dropped, not queued; the sheet
/// disables its confirm button while `state.isLoading`.
///
/// This notifier is autoDispose: the save sheet can be dismissed (or the
/// screen underneath it torn down) while a write is still on the wire, so
/// every assignment to [state] after an `await` is guarded with
/// `ref.mounted` (Phase 6 ruling 2) — the write itself still runs to
/// completion, there is simply no longer anywhere to report it.

abstract class _$CardLibrary extends $AsyncNotifier<void> {
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
