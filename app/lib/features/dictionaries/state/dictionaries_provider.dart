import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/data.dart';
import 'built_in_keys.dart';
import 'dictionary_codec.dart';

part 'dictionaries_provider.g.dart';

/// Every key list the app knows: the built-in one, then the stored ones
/// newest-updated first (the repository's ordering contract,
/// `data/database/drift_dictionaries_repository.dart`). Every screen
/// watches this; nothing calls the repository directly.
@riverpod
Stream<List<KeyDictionary>> dictionaries(Ref ref) => ref
    .watch(dictionariesRepositoryProvider)
    .watchAll()
    .map(
      (List<KeyDictionary> stored) => <KeyDictionary>[
        builtInDictionary(),
        ...stored,
      ],
    );

/// What [DictionaryLibrary.importText] actually did: how many lists were
/// written, and — when it did not fully succeed — the failure that stopped
/// it going further.
///
/// The same shape `features/cards/state/saved_cards_provider.dart` uses,
/// and for the same reason: an import that wrote one list and then failed
/// must be able to say both things. It is declared again rather than
/// imported because that one is another feature's internal (spec 8.4).
final class ImportOutcome {
  const ImportOutcome({required this.written, this.error});

  final int written;

  /// Null when every list in the paste was written. A
  /// [DictionaryImportException] (the text could not be parsed at all)
  /// always carries [written] `== 0`, since [parseDictionaries] reads the
  /// whole paste before anything is written; any other error can carry a
  /// positive [written].
  final Object? error;

  bool get ok => error == null;
}

int _seq = 0;

/// A unique id for a new list, without a uuid dependency: the microsecond
/// clock plus a per-session counter (the `newCardId` pattern).
String newDictionaryId() =>
    'dict-${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

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
@riverpod
class DictionaryLibrary extends _$DictionaryLibrary {
  @override
  Future<void> build() async {
    ref.onDispose(() {
      // Not `state` — the element is gone by now (Global Constraints).
      _inFlight = false;
    });
  }

  bool _inFlight = false;

  /// Writes a new list and returns its id, or null when the write failed or
  /// was dropped.
  Future<String?> create(
    String name, {
    List<Uint8List> keys = const <Uint8List>[],
  }) async {
    final String id = newDictionaryId();
    final bool ok = await _run(
      (DictionariesRepository repo) => repo.save(_row(id, name, keys)),
    );
    return ok ? id : null;
  }

  /// A copy of [dictionary] under a fresh id — how the built-in list
  /// becomes editable.
  Future<String?> duplicate(KeyDictionary dictionary, String name) =>
      create(name, keys: dictionary.keys);

  Future<void> rename(KeyDictionary dictionary, String name) async {
    await _run(
      (DictionariesRepository repo) =>
          repo.save(_row(dictionary.id, name, dictionary.keys)),
    );
  }

  Future<void> setKeys(KeyDictionary dictionary, List<Uint8List> keys) async {
    await _run(
      (DictionariesRepository repo) =>
          repo.save(_row(dictionary.id, dictionary.name, keys)),
    );
  }

  Future<void> remove(String id) async {
    await _run((DictionariesRepository repo) => repo.delete(id));
  }

  /// Parses [text] in any format [parseDictionaries] understands and writes
  /// every list it holds under a fresh id. A `.dic` paste carries no name,
  /// so [fallbackName] names it; a JSON entry's own name wins.
  ///
  /// Writes one list at a time rather than inside a single
  /// `AsyncValue.guard`, for the reason `CardLibrary.importJson` records:
  /// a guard would report zero written the moment any list failed, even
  /// after earlier ones had already landed.
  Future<ImportOutcome> importText(String text, {String? fallbackName}) async {
    if (_inFlight) return const ImportOutcome(written: 0);
    _inFlight = true;
    state = const AsyncLoading<void>();
    int written = 0;
    Object? error;
    StackTrace? stackTrace;
    try {
      final List<ImportedDictionary> parsed = parseDictionaries(text);
      final DictionariesRepository repo = ref.read(
        dictionariesRepositoryProvider,
      );
      for (final ImportedDictionary d in parsed) {
        await repo.save(
          _row(newDictionaryId(), d.name ?? fallbackName ?? '', d.keys),
        );
        written++;
      }
    } on Object catch (e, st) {
      error = e;
      stackTrace = st;
    }
    if (!ref.mounted) {
      _inFlight = false;
      return ImportOutcome(written: written, error: error);
    }
    state = error == null
        ? const AsyncData<void>(null)
        : AsyncError<void>(error, stackTrace!);
    _inFlight = false;
    return ImportOutcome(written: written, error: error);
  }

  /// Clears a failed write back to idle, so a screen's "Try again" reopens
  /// the form instead of leaving the `ProblemView` up forever.
  void reset() => state = const AsyncData<void>(null);

  /// Lets a test drive an `AsyncError` without a repository that throws.
  /// `Notifier.state` is `@protected`; this is the narrow door around that.
  @visibleForTesting
  void debugFail(Object error) =>
      state = AsyncError<void>(error, StackTrace.current);

  KeyDictionary _row(String id, String name, List<Uint8List> keys) =>
      KeyDictionary(
        id: id,
        name: name,
        keys: keys,
        updatedAt: DateTime.now().toUtc(),
      );

  /// Drop-not-queue, with `ref.mounted` on every post-await assignment and
  /// `_inFlight` reset on the disposed branch too (the `CardLibrary._run`
  /// pattern).
  Future<bool> _run(
    Future<void> Function(DictionariesRepository repo) body,
  ) async {
    if (_inFlight) return false;
    _inFlight = true;
    state = const AsyncLoading<void>();
    final AsyncValue<void> next = await AsyncValue.guard<void>(
      () => body(ref.read(dictionariesRepositoryProvider)),
    );
    if (!ref.mounted) {
      _inFlight = false;
      return false;
    }
    state = next;
    _inFlight = false;
    return !next.hasError;
  }
}
