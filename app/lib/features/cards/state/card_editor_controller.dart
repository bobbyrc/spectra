import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/data.dart';
import 'card_codec.dart';

part 'card_editor_controller.g.dart';

/// One card being looked at, and possibly edited.
///
/// [bytes] is a working copy: edits change it without touching the stored
/// row, and [dirty] says whether the two have drifted apart. [busy] is true
/// while [CardEditor.save]/[CardEditor.discard]/[CardEditor.deleteCard] has
/// a write in flight — [CardEditor] keeps `state` an `AsyncData` throughout
/// those calls (never a bare `AsyncLoading`, which would drop this value),
/// so the detail page keeps rendering the card and only disables its
/// controls on [busy], rather than blanking to a spinner and losing the
/// app-bar title mid-save.
final class CardEditState {
  const CardEditState({
    required this.card,
    required this.bytes,
    required this.dirty,
    this.busy = false,
  });

  final SavedCard card;
  final Uint8List bytes;
  final bool dirty;
  final bool busy;

  TagType get tagType => tagTypeFromName(card.tagType);

  /// The edit unit: a MIFARE Classic block, an Ultralight page, or the whole
  /// EM410x id. Zero for a type with no editable layout.
  int get chunkSize => chunkSizeFor(tagType);

  int get chunkCount => chunkCountFor(tagType, bytes.length);

  /// A copy, so a caller mutating it cannot edit the card behind the
  /// notifier's back.
  Uint8List chunk(int index) => Uint8List.fromList(
    bytes.sublist(index * chunkSize, index * chunkSize + chunkSize),
  );
}

/// The detail screen's state, one notifier per card id, so a failure on one
/// card does not grey out another (the `SlotEditor` shape).
///
/// A call made while another write is in flight is dropped, not queued; the
/// screen disables its controls while [CardEditState.busy]. Every
/// assignment to [state] after an `await` is guarded with `ref.mounted`
/// (Phase 6 ruling 2): the detail screen is a pushed sub-route and can be
/// popped (or the app can navigate elsewhere) while a write is still on the
/// wire.
///
/// Task 7 landed the read-only half: fields, the hex viewer, delete. Task 8
/// wires [replaceChunk] to the editable hex viewer and calls [save]/
/// [discard] from it.
@riverpod
class CardEditor extends _$CardEditor {
  @override
  Future<CardEditState?> build(String id) async {
    final SavedCard? card = await ref
        .read(savedCardsRepositoryProvider)
        .byId(id);
    if (card == null) return null;
    return CardEditState(
      card: card,
      bytes: Uint8List.fromList(card.bytes),
      dirty: false,
    );
  }

  bool _inFlight = false;

  /// Replaces one block, page or id in the working copy. In memory only:
  /// nothing reaches the database until [save].
  ///
  /// Called from `CardHexEditor`'s "Apply", after it has already validated
  /// the typed hex against [CardEditState.chunkSize].
  void replaceChunk(int index, Uint8List chunk) {
    final CardEditState? current = state.value;
    if (current == null) return;
    if (chunk.length != current.chunkSize) return;
    if (index < 0 || index >= current.chunkCount) return;
    final Uint8List next = Uint8List.fromList(current.bytes);
    next.setRange(
      index * current.chunkSize,
      (index + 1) * current.chunkSize,
      chunk,
    );
    state = AsyncData<CardEditState?>(
      CardEditState(card: current.card, bytes: next, dirty: true),
    );
  }

  /// Writes the working copy back to the library.
  Future<void> save() async {
    final CardEditState? current = state.value;
    if (current == null || _inFlight) return;
    _inFlight = true;
    state = AsyncData<CardEditState?>(
      CardEditState(
        card: current.card,
        bytes: current.bytes,
        dirty: current.dirty,
        busy: true,
      ),
    );
    final AsyncValue<void> written = await AsyncValue.guard<void>(
      () => ref
          .read(savedCardsRepositoryProvider)
          .save(
            SavedCard(
              id: current.card.id,
              name: current.card.name,
              tagType: current.card.tagType,
              bytes: current.bytes,
              updatedAt: DateTime.now().toUtc(),
              folder: current.card.folder,
              color: current.card.color,
            ),
          ),
    );
    if (!ref.mounted) {
      _inFlight = false;
      return;
    }
    final Object? error = written.error;
    state = error != null
        ? AsyncError<CardEditState?>(
            error,
            written.stackTrace ?? StackTrace.current,
          )
        : AsyncData<CardEditState?>(
            CardEditState(
              card: current.card,
              bytes: current.bytes,
              dirty: false,
            ),
          );
    _inFlight = false;
  }

  /// Throws the working copy away and reloads from the library.
  ///
  /// [Ruling 11]: takes the [_inFlight] guard like every other mutator, and
  /// reloads through a plain repository read rather than calling [build]
  /// directly — `build` is not how a family notifier reloads outside
  /// Riverpod's own lifecycle, and calling it by hand would let a Discard
  /// landing mid-[save] clobber the state the save is about to set.
  Future<void> discard() async {
    if (_inFlight) return;
    final CardEditState? current = state.value;
    _inFlight = true;
    if (current != null) {
      state = AsyncData<CardEditState?>(
        CardEditState(
          card: current.card,
          bytes: current.bytes,
          dirty: current.dirty,
          busy: true,
        ),
      );
    } else {
      state = const AsyncLoading<CardEditState?>();
    }
    final SavedCard? card = await ref
        .read(savedCardsRepositoryProvider)
        .byId(id);
    if (!ref.mounted) {
      _inFlight = false;
      return;
    }
    state = AsyncData<CardEditState?>(
      card == null
          ? null
          : CardEditState(
              card: card,
              bytes: Uint8List.fromList(card.bytes),
              dirty: false,
            ),
    );
    _inFlight = false;
  }

  /// [Ruling 12]: deletes through the repository directly, not through
  /// `cardLibraryProvider.notifier` — that provider is autoDispose and
  /// nothing is watching it from here, so reading its notifier just to
  /// mutate it would create it, use it, and let it be disposed mid-write.
  Future<void> deleteCard() async {
    if (_inFlight) return;
    _inFlight = true;
    await ref.read(savedCardsRepositoryProvider).delete(id);
    if (!ref.mounted) {
      _inFlight = false;
      return;
    }
    state = const AsyncData<CardEditState?>(null);
    _inFlight = false;
  }

  /// Lets a test drive an `AsyncError` without a repository that throws.
  @visibleForTesting
  void debugFail(Object error) =>
      state = AsyncError<CardEditState?>(error, StackTrace.current);
}
