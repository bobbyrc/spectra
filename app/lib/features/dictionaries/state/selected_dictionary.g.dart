// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'selected_dictionary.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Which key list a read or a write uses (spec 8.1: the app supplies the
/// keys). Persisted, because it is a preference and not a per-session
/// choice — the same `PreferencesRepository`-backed keepAlive shape
/// `core/flags/feature_flags.dart` uses.

@ProviderFor(SelectedDictionaryId)
final selectedDictionaryIdProvider = SelectedDictionaryIdProvider._();

/// Which key list a read or a write uses (spec 8.1: the app supplies the
/// keys). Persisted, because it is a preference and not a per-session
/// choice — the same `PreferencesRepository`-backed keepAlive shape
/// `core/flags/feature_flags.dart` uses.
final class SelectedDictionaryIdProvider
    extends $AsyncNotifierProvider<SelectedDictionaryId, String> {
  /// Which key list a read or a write uses (spec 8.1: the app supplies the
  /// keys). Persisted, because it is a preference and not a per-session
  /// choice — the same `PreferencesRepository`-backed keepAlive shape
  /// `core/flags/feature_flags.dart` uses.
  SelectedDictionaryIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedDictionaryIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedDictionaryIdHash();

  @$internal
  @override
  SelectedDictionaryId create() => SelectedDictionaryId();
}

String _$selectedDictionaryIdHash() =>
    r'f4f7cde49b8914bf35b49b3250925aa1bcf8b59d';

/// Which key list a read or a write uses (spec 8.1: the app supplies the
/// keys). Persisted, because it is a preference and not a per-session
/// choice — the same `PreferencesRepository`-backed keepAlive shape
/// `core/flags/feature_flags.dart` uses.

abstract class _$SelectedDictionaryId extends $AsyncNotifier<String> {
  FutureOr<String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String>, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String>, String>,
              AsyncValue<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The selected list itself. A selection whose list has since been deleted
/// falls back to the built-in one rather than leaving a read with no keys;
/// the preference is deliberately *not* rewritten on that path, because the
/// fallback is a display decision, not a user choice.
///
/// A caller that only `ref.read`s this (`candidateMifareKeysProvider`
/// below, and `CardReader._readHf`, which reads through that) creates no
/// listener, so without help this autoDispose provider is torn down
/// mid-await the moment the synchronous scope of that read returns —
/// before its own two `await`s finish — throwing `UnmountedRefException`
/// on the second one. `ref.keepAlive()` pins it for the duration of one
/// build and releases the pin once it resolves, so normal autoDispose
/// (torn down once nothing watches it any more) still applies between
/// reads.

@ProviderFor(selectedDictionary)
final selectedDictionaryProvider = SelectedDictionaryProvider._();

/// The selected list itself. A selection whose list has since been deleted
/// falls back to the built-in one rather than leaving a read with no keys;
/// the preference is deliberately *not* rewritten on that path, because the
/// fallback is a display decision, not a user choice.
///
/// A caller that only `ref.read`s this (`candidateMifareKeysProvider`
/// below, and `CardReader._readHf`, which reads through that) creates no
/// listener, so without help this autoDispose provider is torn down
/// mid-await the moment the synchronous scope of that read returns —
/// before its own two `await`s finish — throwing `UnmountedRefException`
/// on the second one. `ref.keepAlive()` pins it for the duration of one
/// build and releases the pin once it resolves, so normal autoDispose
/// (torn down once nothing watches it any more) still applies between
/// reads.

final class SelectedDictionaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<KeyDictionary>,
          KeyDictionary,
          FutureOr<KeyDictionary>
        >
    with $FutureModifier<KeyDictionary>, $FutureProvider<KeyDictionary> {
  /// The selected list itself. A selection whose list has since been deleted
  /// falls back to the built-in one rather than leaving a read with no keys;
  /// the preference is deliberately *not* rewritten on that path, because the
  /// fallback is a display decision, not a user choice.
  ///
  /// A caller that only `ref.read`s this (`candidateMifareKeysProvider`
  /// below, and `CardReader._readHf`, which reads through that) creates no
  /// listener, so without help this autoDispose provider is torn down
  /// mid-await the moment the synchronous scope of that read returns —
  /// before its own two `await`s finish — throwing `UnmountedRefException`
  /// on the second one. `ref.keepAlive()` pins it for the duration of one
  /// build and releases the pin once it resolves, so normal autoDispose
  /// (torn down once nothing watches it any more) still applies between
  /// reads.
  SelectedDictionaryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedDictionaryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedDictionaryHash();

  @$internal
  @override
  $FutureProviderElement<KeyDictionary> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<KeyDictionary> create(Ref ref) {
    return selectedDictionary(ref);
  }
}

String _$selectedDictionaryHash() =>
    r'38e85d3df8cb8924819fb5c6cc8f0cde7d72925c';

/// The keys a MIFARE Classic read or write hands to the facade.
///
/// An empty list falls back to the built-in keys: a user who empties a list
/// and then reads a card should get the default attempt, not a silent
/// no-key read that reports every sector locked.
///
/// Also `ref.keepAlive()`-pinned for the reason [selectedDictionary]'s doc
/// comment gives: this is the provider `CardReader._readHf` reads with a
/// bare `ref.read`, so it is the one that most needs to survive its own
/// await with no external listener.

@ProviderFor(candidateMifareKeys)
final candidateMifareKeysProvider = CandidateMifareKeysProvider._();

/// The keys a MIFARE Classic read or write hands to the facade.
///
/// An empty list falls back to the built-in keys: a user who empties a list
/// and then reads a card should get the default attempt, not a silent
/// no-key read that reports every sector locked.
///
/// Also `ref.keepAlive()`-pinned for the reason [selectedDictionary]'s doc
/// comment gives: this is the provider `CardReader._readHf` reads with a
/// bare `ref.read`, so it is the one that most needs to survive its own
/// await with no external listener.

final class CandidateMifareKeysProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Uint8List>>,
          List<Uint8List>,
          FutureOr<List<Uint8List>>
        >
    with $FutureModifier<List<Uint8List>>, $FutureProvider<List<Uint8List>> {
  /// The keys a MIFARE Classic read or write hands to the facade.
  ///
  /// An empty list falls back to the built-in keys: a user who empties a list
  /// and then reads a card should get the default attempt, not a silent
  /// no-key read that reports every sector locked.
  ///
  /// Also `ref.keepAlive()`-pinned for the reason [selectedDictionary]'s doc
  /// comment gives: this is the provider `CardReader._readHf` reads with a
  /// bare `ref.read`, so it is the one that most needs to survive its own
  /// await with no external listener.
  CandidateMifareKeysProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'candidateMifareKeysProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$candidateMifareKeysHash();

  @$internal
  @override
  $FutureProviderElement<List<Uint8List>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Uint8List>> create(Ref ref) {
    return candidateMifareKeys(ref);
  }
}

String _$candidateMifareKeysHash() =>
    r'46ec0dd32778e2a80e2c5c3614434f1e17ad8714';
