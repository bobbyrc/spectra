import 'dart:typed_data';

import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/data.dart';
import 'built_in_keys.dart';
import 'dictionaries_provider.dart';

part 'selected_dictionary.g.dart';

/// Which key list a read or a write uses (spec 8.1: the app supplies the
/// keys). Persisted, because it is a preference and not a per-session
/// choice — the same `PreferencesRepository`-backed keepAlive shape
/// `core/flags/feature_flags.dart` uses.
@Riverpod(keepAlive: true)
class SelectedDictionaryId extends _$SelectedDictionaryId {
  static const String preferenceKey = 'dictionary.selectedId';

  @override
  Future<String> build() async =>
      await ref.watch(preferencesRepositoryProvider).read(preferenceKey) ??
      builtInDictionaryId;

  Future<void> select(String id) async {
    await ref.read(preferencesRepositoryProvider).write(preferenceKey, id);
    if (!ref.mounted) return;
    state = AsyncData<String>(id);
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
@riverpod
Future<KeyDictionary> selectedDictionary(Ref ref) async {
  final KeepAliveLink link = ref.keepAlive();
  try {
    final String id = await ref.watch(selectedDictionaryIdProvider.future);
    final List<KeyDictionary> all = await ref.watch(
      dictionariesProvider.future,
    );
    return all.firstWhere(
      (KeyDictionary d) => d.id == id,
      orElse: builtInDictionary,
    );
  } finally {
    link.close();
  }
}

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
@riverpod
Future<List<Uint8List>> candidateMifareKeys(Ref ref) async {
  final KeepAliveLink link = ref.keepAlive();
  try {
    final KeyDictionary selected = await ref.watch(
      selectedDictionaryProvider.future,
    );
    return selected.keys.isEmpty
        ? defaultMifareKeys()
        : <Uint8List>[
            for (final Uint8List key in selected.keys) Uint8List.fromList(key),
          ];
  } finally {
    link.close();
  }
}
