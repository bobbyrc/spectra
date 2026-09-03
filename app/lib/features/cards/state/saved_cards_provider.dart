import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/data.dart';
import 'card_codec.dart';

part 'saved_cards_provider.g.dart';

/// The library, newest-updated first (the repository's ordering contract,
/// `data/database/drift_saved_cards_repository.dart`). Every screen watches
/// this; nothing calls the repository directly.
@riverpod
Stream<List<SavedCard>> savedCards(Ref ref) =>
    ref.watch(savedCardsRepositoryProvider).watchAll();

/// The colours a card may be tinted with (spec 7.3's `color` column). A
/// fixed palette rather than a full picker: seven distinguishable hues is
/// what a library needs, and it keeps the value a plain ARGB int.
const List<int> cardColors = <int>[
  0xFF4C8DFF,
  0xFF35C08A,
  0xFFF5A524,
  0xFFE5484D,
  0xFF9B6BFF,
  0xFF19B3C4,
  0xFF8C8C99,
];

int _seq = 0;

/// A unique id for a new card, without adding a uuid dependency: the
/// microsecond clock plus a per-session counter, so two cards saved in the
/// same microsecond still differ.
String newCardId() => 'card-${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

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
@riverpod
class CardLibrary extends _$CardLibrary {
  @override
  Future<void> build() async {
    ref.onDispose(() {
      // Not `state` — the element is gone by now (Global Constraints).
      _inFlight = false;
    });
  }

  bool _inFlight = false;

  /// Writes a new card and returns its id, or null when the write failed
  /// (or was dropped because one was already in flight, or the notifier was
  /// disposed before the write finished).
  Future<String?> add({
    required String name,
    required TagType type,
    required Uint8List bytes,
    String? folder,
    int? color,
  }) async {
    final String id = newCardId();
    final bool ok = await _run(
      (SavedCardsRepository repo) => repo.save(
        SavedCard(
          id: id,
          name: name,
          tagType: tagTypeName(type),
          bytes: bytes,
          updatedAt: DateTime.now(),
          folder: folder,
          color: color,
        ),
      ),
    );
    return ok ? id : null;
  }

  /// Replaces an existing card, stamping it as changed now.
  ///
  /// Named `updateCard`, not `update`: `AsyncNotifier` (riverpod 3.4.2)
  /// already declares a `@protected` `update` method with an incompatible
  /// signature — overriding it with `update(SavedCard card)` is a compile
  /// error (`invalid_override`), not a style choice.
  Future<void> updateCard(SavedCard card) async {
    await _run(
      (SavedCardsRepository repo) => repo.save(
        SavedCard(
          id: card.id,
          name: card.name,
          tagType: card.tagType,
          bytes: card.bytes,
          updatedAt: DateTime.now(),
          folder: card.folder,
          color: card.color,
        ),
      ),
    );
  }

  Future<void> remove(String id) async {
    await _run((SavedCardsRepository repo) => repo.delete(id));
  }

  /// Lets a test drive an `AsyncError` without a repository that throws.
  /// `Notifier.state` is `@protected`; this is the narrow door around that.
  @visibleForTesting
  void debugFail(Object error) =>
      state = AsyncError<void>(error, StackTrace.current);

  /// Drop-not-queue: a call made while another is in flight is refused.
  /// Every assignment to [state] after the `await` is guarded with
  /// `ref.mounted`, and `_inFlight` is reset on the disposed branch too, so
  /// a notifier torn down mid-write does not wedge a future caller that
  /// somehow still held a reference to it.
  Future<bool> _run(
    Future<void> Function(SavedCardsRepository repo) body,
  ) async {
    if (_inFlight) return false;
    _inFlight = true;
    state = const AsyncLoading<void>();
    final AsyncValue<void> next = await AsyncValue.guard<void>(
      () => body(ref.read(savedCardsRepositoryProvider)),
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
