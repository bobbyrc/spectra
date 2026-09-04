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
///
/// [error] is set when the last mutator failed, and [failedOp] says which
/// one. This is deliberately not an `AsyncError` state (Phase 6 ruling 29
/// item 1): the working copy — [bytes], [dirty] — is kept exactly as it
/// was, so the detail page can show `ProblemView` above the editor with the
/// edits still on screen. Its "Try again" action re-runs [failedOp]: a
/// failed save is retried by saving, a failed discard by discarding, a
/// failed delete by deleting. Retrying with the wrong operation is not a
/// nicety — "Try again" on a failed discard that ran [CardEditor.save]
/// would write the very bytes the user was throwing away.
final class CardEditState {
  const CardEditState({
    required this.card,
    required this.bytes,
    required this.dirty,
    this.busy = false,
    this.error,
    this.failedOp,
  });

  final SavedCard card;
  final Uint8List bytes;
  final bool dirty;
  final bool busy;
  final Object? error;

  /// Which mutator [error] came from. Null exactly when [error] is null.
  final CardEditOp? failedOp;

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

  /// [card] with [bytes] substituted for its stored bytes: what a
  /// [CardEditor.save] would write, and what [validateSavedCard] checks
  /// (Phase 6 ruling 29 item 2) both here and in the detail page's problems
  /// banner — the working copy, not the stored row.
  SavedCard get workingCard => SavedCard(
    id: card.id,
    name: card.name,
    tagType: card.tagType,
    bytes: bytes,
    updatedAt: card.updatedAt,
    folder: card.folder,
    color: card.color,
  );
}

/// The mutators [CardEditor] can fail in, so the detail page's "Try again"
/// re-runs the one that actually failed ([CardEditState.failedOp]).
enum CardEditOp { save, discard, delete, refresh }

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
  /// the typed hex against [CardEditState.chunkSize]. Clears a stale
  /// [CardEditState.error] from a previous failed [save]: the working copy
  /// just changed, so that failure was about bytes that no longer exist.
  ///
  /// [R35]: takes the [_inFlight] guard like every other mutator. An Apply
  /// landing mid-[save] would otherwise edit the working copy the save is
  /// about to mark clean — the edit would be silently swallowed by the
  /// `dirty: false` state the save sets on completion, and the user would
  /// be looking at bytes nobody ever wrote. Dropped, not queued: the
  /// editor's controls are disabled while [CardEditState.busy], so this
  /// only catches a call that raced the disable.
  void replaceChunk(int index, Uint8List chunk) {
    final CardEditState? current = state.value;
    if (current == null || _inFlight) return;
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
  ///
  /// [Ruling 29 item 2]: refuses when [validateSavedCard] finds problems in
  /// [CardEditState.workingCard] — those already render inline via the
  /// detail page's problems banner (which validates the same working copy),
  /// so there is nothing more useful to say by attempting the write.
  ///
  /// [Ruling 29 item 1]: a failed write keeps the working copy exactly as
  /// it was — [CardEditState.error] carries the failure, `busy` clears —
  /// rather than moving to `AsyncError` and losing the edits.
  Future<void> save() async {
    final CardEditState? current = state.value;
    if (current == null || _inFlight) return;
    if (validateSavedCard(current.workingCard).isNotEmpty) return;
    _inFlight = true;
    state = AsyncData<CardEditState?>(
      CardEditState(
        card: current.card,
        bytes: current.bytes,
        dirty: current.dirty,
        busy: true,
      ),
    );
    // Built once and kept: this row *is* the library's row once the write
    // lands, so it — not the pre-save `current.card` — is what the new
    // state carries. Keeping the old one made `CardEditState.card` a
    // stale copy whose `bytes` were the ones this save just replaced, and
    // anything that wrote that row back (the details sheet, R34) reverted
    // the edit that had just been saved.
    final SavedCard written = SavedCard(
      id: current.card.id,
      name: current.card.name,
      tagType: current.card.tagType,
      bytes: current.bytes,
      updatedAt: DateTime.now().toUtc(),
      folder: current.card.folder,
      color: current.card.color,
    );
    final AsyncValue<void> result = await AsyncValue.guard<void>(
      () => ref.read(savedCardsRepositoryProvider).save(written),
    );
    if (!ref.mounted) {
      _inFlight = false;
      return;
    }
    final Object? error = result.error;
    state = AsyncData<CardEditState?>(
      error != null
          ? CardEditState(
              card: current.card,
              bytes: current.bytes,
              dirty: current.dirty,
              error: error,
              failedOp: CardEditOp.save,
            )
          : CardEditState(card: written, bytes: current.bytes, dirty: false),
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
  ///
  /// [R31]: the reload is wrapped in an `AsyncValue.guard`. A repository
  /// that throws would otherwise escape as an unhandled asynchronous error
  /// (nothing awaits this method's future from the button that calls it)
  /// and leave [_inFlight] true forever, wedging every later mutator. A
  /// failure keeps the working copy exactly as it was and reports itself
  /// through [CardEditState.error], the same way [save] does — so the
  /// detail page's `ProblemView` comes up over edits that are still there.
  /// Its "Try again" re-invokes [save], which is the useful escape from a
  /// storage failure with unsaved edits on screen.
  ///
  /// A no-op when there is no working copy to discard (`state.value` is
  /// null — the not-found screen, which offers no Discard button anyway):
  /// with [save] keeping the working copy on a failed write (ruling 29 item
  /// 1), that is the only remaining way to reach this method with nothing
  /// to preserve while reloading.
  Future<void> discard() async {
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
    final AsyncValue<SavedCard?> reloaded = await AsyncValue.guard<SavedCard?>(
      () => ref.read(savedCardsRepositoryProvider).byId(id),
    );
    if (!ref.mounted) {
      _inFlight = false;
      return;
    }
    final Object? error = reloaded.error;
    if (error != null) {
      state = AsyncData<CardEditState?>(
        CardEditState(
          card: current.card,
          bytes: current.bytes,
          dirty: current.dirty,
          error: error,
          failedOp: CardEditOp.discard,
        ),
      );
      _inFlight = false;
      return;
    }
    final SavedCard? card = reloaded.value;
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

  /// Re-reads the stored row's name, folder and colour, keeping the working
  /// copy: [CardEditState.bytes] and [CardEditState.dirty] are untouched.
  ///
  /// The edit-details sheet (R34) writes those three fields through
  /// `CardLibrary.updateCard`; this is how the screen behind it catches up
  /// without a full reload, which would throw away unsaved hex edits. The
  /// detail page also runs it *before* opening that sheet, so the row the
  /// sheet merges the new name, folder and colour onto is one it has just
  /// read — never a stale copy whose bytes would overwrite a saved edit.
  ///
  /// A re-read that fails reports itself like the other mutators
  /// ([CardEditState.failedOp] `refresh`) and leaves the details as they
  /// were; an empty one (the row is gone) also leaves them, rather than
  /// blanking a card the user is looking at.
  Future<void> refreshDetails() async {
    final CardEditState? current = state.value;
    if (current == null || _inFlight) return;
    _inFlight = true;
    // Busy like every other mutator that claims `_inFlight`: this drops a
    // save issued while it runs, and dropping a write is only honest if
    // the screen's controls were visibly disabled at the time.
    state = AsyncData<CardEditState?>(
      CardEditState(
        card: current.card,
        bytes: current.bytes,
        dirty: current.dirty,
        busy: true,
      ),
    );
    final AsyncValue<SavedCard?> reloaded = await AsyncValue.guard<SavedCard?>(
      () => ref.read(savedCardsRepositoryProvider).byId(id),
    );
    if (!ref.mounted) {
      _inFlight = false;
      return;
    }
    final Object? error = reloaded.error;
    final SavedCard? card = reloaded.value;
    state = AsyncData<CardEditState?>(
      CardEditState(
        card: card ?? current.card,
        bytes: current.bytes,
        dirty: current.dirty,
        error: error ?? current.error,
        failedOp: error != null ? CardEditOp.refresh : current.failedOp,
      ),
    );
    _inFlight = false;
  }

  /// [Ruling 12]: deletes through the repository directly, not through
  /// `cardLibraryProvider.notifier` — that provider is autoDispose and
  /// nothing is watching it from here, so reading its notifier just to
  /// mutate it would create it, use it, and let it be disposed mid-write.
  ///
  /// [R31]: the delete is wrapped in an `AsyncValue.guard` for the same
  /// reason as [discard] — an unguarded throw escapes unhandled and wedges
  /// [_inFlight]. A failure reports itself through [CardEditState.error]
  /// (or, on the not-found screen where there is no working copy to carry
  /// it, as an `AsyncError`), and the card is still in the library.
  ///
  /// [Ruling 29 item 3]: sets/clears [CardEditState.busy] like every other
  /// mutator, so a screen that is still mounted while this is in flight
  /// (the detail page navigates away first, but a test can call this
  /// directly) sees the same disabled-controls behaviour.
  Future<void> deleteCard() async {
    final CardEditState? current = state.value;
    if (_inFlight) return;
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
    }
    final AsyncValue<void> deleted = await AsyncValue.guard<void>(
      () => ref.read(savedCardsRepositoryProvider).delete(id),
    );
    if (!ref.mounted) {
      _inFlight = false;
      return;
    }
    final Object? error = deleted.error;
    if (error != null) {
      state = current == null
          ? AsyncError<CardEditState?>(error, deleted.stackTrace!)
          : AsyncData<CardEditState?>(
              CardEditState(
                card: current.card,
                bytes: current.bytes,
                dirty: current.dirty,
                error: error,
                failedOp: CardEditOp.delete,
              ),
            );
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
