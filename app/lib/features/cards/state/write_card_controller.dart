import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/app_failures.dart';
import '../../../core/session/active_device.dart';
import '../../../core/session/active_session.dart';
import '../../dictionaries/dictionaries.dart';
import 'default_keys.dart';
import 'write_target.dart';

part 'write_card_controller.g.dart';

/// The write's whole state; no `copyWith`, for the reason
/// `SlotLoadState` gives.
final class CardWriteState {
  const CardWriteState({
    this.busy = false,
    this.progress,
    this.error,
    this.cancelled = false,
    this.unsupported = false,
    this.written,
    this.attempted,
    this.unreadSectors,
  });

  final bool busy;

  /// A fraction of the **sectors** done, not the blocks:
  /// `ReaderFacade.mf1WriteDump`'s `onProgress(done, total)` counts sectors
  /// (16 for a 1K), while [written] and [attempted] count blocks (47 of the
  /// 64 on the same card). Both are correct, they just count different
  /// units — the sheet must label them separately rather than show a
  /// sector fraction next to a block count with nothing saying they differ
  /// (ruling 14; the same hazard Phase 6 ruling 23 names one screen
  /// earlier). Null for a write with no per-chunk notion (an LF id).
  final double? progress;

  /// The typed error the last write ended with, rendered through the spec 9
  /// catalog. Never a string, and never a cancellation — see [cancelled].
  final Object? error;

  /// The write ended because [CardWriter.cancel] was called, not because
  /// anything went wrong. A terminal state with its own words (ruling 3):
  /// `ErrorCatalog` has no branch for `CommandCancelled` beyond the
  /// generic "something unexpected went wrong" fallback, and a user's own
  /// Cancel tap must never read as a failure on the one screen that can
  /// leave a card half-written.
  final bool cancelled;

  /// This tag type has no reader write in the SDK
  /// (`CardWriteMethod.unsupported`). A state, not an error.
  final bool unsupported;

  /// Blocks written and blocks attempted, once the write has finished. One
  /// and one for an LF id: it is a single command, and reporting it as
  /// "1 of 1" keeps the summary one sentence instead of two.
  final int? written;
  final int? attempted;

  /// Classic-only (ruling 23): set when the caller asked to
  /// [CardWriter.write] with `writeTrailers: true` against a dump whose
  /// sector trailers `write_target.dart`'s `unreadSectors` flags — key A
  /// all zero, which is the mark a *read* dump carries for every sector
  /// (a real card never returns its keys), not only the ones a read never
  /// authenticated (ruling 27). Writing those blocks would put six zero
  /// bytes in place of the card's real key A, so the write stops here and
  /// waits for a second call with `confirmUnread: true` — the caller is
  /// expected to have shown this sector list first.
  final List<int>? unreadSectors;

  bool get isDone => written != null;

  /// Some of what was attempted did not go on. A normal outcome for a card
  /// with locked sectors, not an error.
  bool get isPartial =>
      written != null && attempted != null && written! < attempted!;
}

/// Spec 7.7 step 5: write a saved dump back onto a physical card.
///
/// Only the two families the SDK's `ReaderFacade` can write are offered —
/// MIFARE Classic block by block (`mf1WriteDump`), and an EM410x id onto a
/// T55xx blank (`em410xWriteToT55xx`). Everything else is
/// [CardWriteState.unsupported]: a typed state the sheet renders as a
/// sentence, never a silent no-op and never a guess at some other encoding.
/// Ultralight has no reader write in spec 8.1's `ReaderFacade` at all
/// (`write_target.dart`'s `CardWriteMethod` doc), so it lands here too.
///
/// [write]'s `writeTrailers` defaults to false, matching
/// `ReaderFacade.mf1WriteDump`: a saved dump's sector trailers only go onto
/// the card when the caller explicitly opts in, and a *read* dump carries
/// key A zeroed out in every trailer, so writing trailers from one straight
/// back overwrites the card's real key A with zeros (the same footgun the
/// facade's own doc comment carries). The sheet's copy is the one place
/// that warns about it before the opt-in is even offered (Task 9).
///
/// A dump with all-zero sector trailers *and* `writeTrailers: true` is
/// refused before any command is sent, as [CardWriteState.unreadSectors]
/// (ruling 23), until a second call passes `confirmUnread: true`.
///
/// A device that bails the whole dump early — `InvalidCommand` when
/// MF1_WRITE_ONE_BLOCK is missing from the device's advertised
/// capabilities (a Lite has no 2009) — is not special-cased: `InvalidCommand`
/// already has its own words in `ErrorCatalog` (`errorInvalidCommand`), so
/// landing it in [CardWriteState.error] is exactly the typed state ruling 25
/// asks for, not the generic "something unexpected went wrong" fallback.
///
/// **`hardware-validate` (checklist H3): nothing here is proven on a real
/// card.** `FakeDevice` accepts every write and hands the bytes straight
/// back, which proves the app's sequencing and nothing about a card whose
/// access bits refuse a key or a blank that will not take a password. The
/// sheet says so on screen for as long as that stays true.
///
/// No wakelock code: `mf1WriteDump` runs the whole write inside one reader
/// lease and one `DeviceSession.busy`, which is exactly what
/// `sessionNeedsWakelock` (`core/lifecycle/wakelock.dart`) polls.
///
/// Drop, do not queue (`_inFlight`); the sheet disables its button while
/// `state.busy`. Every post-`await` assignment is guarded with `ref.mounted`
/// (R25) — the device write still runs to completion, there is simply no
/// longer anywhere to report it.
@riverpod
class CardWriter extends _$CardWriter {
  @override
  CardWriteState build() {
    ref.onDispose(() {
      // Not `state` — the element is gone by now.
      _cancel?.cancel();
      _inFlight = false;
    });
    return const CardWriteState();
  }

  CancelToken? _cancel;
  bool _inFlight = false;

  Future<void> write({
    required TagType type,
    required Uint8List bytes,
    bool writeTrailers = false,
    bool confirmUnread = false,
  }) async {
    if (_inFlight) return;

    final CardWriteMethod method = writeMethodFor(type);
    if (method == CardWriteMethod.unsupported) {
      state = const CardWriteState(unsupported: true);
      return;
    }

    final int expected = expectedDumpLength(type);
    if (bytes.length != expected) {
      // Before anything is sent: a stored row of the wrong size was never a
      // valid dump.
      state = CardWriteState(
        error: CardDumpLengthMismatch(
          type: type,
          expected: expected,
          actual: bytes.length,
        ),
      );
      return;
    }

    if (method == CardWriteMethod.mifareClassicBlocks &&
        writeTrailers &&
        !confirmUnread) {
      final List<int> unread = unreadSectors(type, bytes);
      if (unread.isNotEmpty) {
        state = CardWriteState(unreadSectors: unread);
        return;
      }
    }

    final ActiveSession? active = ref.read(activeSessionProvider);
    if (active == null) {
      state = const CardWriteState(error: SessionNotReady('no active session'));
      return;
    }

    _inFlight = true;
    final CancelToken cancel = CancelToken();
    _cancel = cancel;
    state = const CardWriteState(busy: true);
    try {
      // Spec 8.1: the app supplies the keys. `candidateMifareKeysProvider`
      // resolves the user's selected dictionary (Phase 9), falling back to
      // the built-in list, and never an empty one — resolved once here,
      // before any device I/O, the same way `read_controller.dart` does.
      // `_inFlight`/`state.busy` are set above, before this first `await`,
      // so a provider torn down mid-write (ruling: "outlives its
      // provider") is caught by the `ref.mounted` check below rather than
      // throwing out of a still-synchronous `ref.read`.
      final List<Uint8List> keys = method == CardWriteMethod.mifareClassicBlocks
          ? await ref.read(candidateMifareKeysProvider.future)
          : const <Uint8List>[];
      if (!ref.mounted) return;

      final (int written, int attempted) = switch (method) {
        CardWriteMethod.mifareClassicBlocks => await _writeClassic(
          active.session.reader,
          type,
          bytes,
          writeTrailers,
          keys,
          cancel,
        ),
        CardWriteMethod.em410xT55xx => await _writeEm410x(
          active.session.reader,
          bytes,
        ),
        CardWriteMethod.unsupported => (0, 0), // Unreachable.
      };
      if (ref.mounted) {
        state = CardWriteState(written: written, attempted: attempted);
      }
    } on CommandCancelled {
      if (ref.mounted) state = const CardWriteState(cancelled: true);
    } on Object catch (error) {
      if (ref.mounted) state = CardWriteState(error: error);
    } finally {
      _inFlight = false;
      _cancel = null;
    }
  }

  /// Asks the running write to stop. The SDK has no wire-level cancel, so
  /// the command already in flight still runs to completion before the
  /// future resolves with `CommandCancelled`, which lands as
  /// [CardWriteState.cancelled] (spec 4.3's honest contract). An EM410x
  /// write is one round trip with nothing to check cancellation between, so
  /// calling this during one does nothing.
  void cancel() => _cancel?.cancel();

  /// Back to the empty state, so the sheet's "Try again" offers the write
  /// again rather than leaving a `ProblemView` (or an unread-sector
  /// warning, or the cancelled state) up forever.
  void reset() => state = const CardWriteState();

  /// Lets a test drive an error state without a facade that throws.
  /// `Notifier.state` is `@protected`; this is the narrow door around that.
  @visibleForTesting
  void debugFail(Object error) => state = CardWriteState(error: error);

  Future<(int, int)> _writeClassic(
    ReaderFacade reader,
    TagType type,
    Uint8List bytes,
    bool writeTrailers,
    List<Uint8List> candidateKeys,
    CancelToken cancel,
  ) async {
    final Mf1DumpWriteResult result = await reader.mf1WriteDump(
      type: type,
      blocks: bytes,
      candidateKeys: candidateKeys,
      writeTrailers: writeTrailers,
      onProgress: (int done, int total) {
        if (!ref.mounted) return;
        state = CardWriteState(
          busy: true,
          progress: total == 0 ? null : done / total,
        );
      },
      cancel: cancel,
    );
    return (result.writtenBlockCount, result.attemptedBlockCount);
  }

  Future<(int, int)> _writeEm410x(ReaderFacade reader, Uint8List id) async {
    await reader.em410xWriteToT55xx(
      id: id,
      newKey: defaultT55xxKey(),
      oldKeys: defaultT55xxOldKeys(),
    );
    return (1, 1);
  }
}
