import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/app_failures.dart';
import '../../../core/session/active_device.dart';
import '../../../core/session/active_session.dart';
import 'write_target.dart';

part 'load_to_slot_controller.g.dart';

/// The load's whole state. Deliberately without a `copyWith`: every
/// transition builds a complete new value, so there is no "unchanged versus
/// explicitly null" sentinel to get wrong.
final class SlotLoadState {
  const SlotLoadState({
    this.busy = false,
    this.progress,
    this.done = false,
    this.error,
    this.unsupported = false,
    this.unreadSectors,
  });

  /// True from the first command until the load ends, however it ends.
  final bool busy;

  /// 0..1 across the device steps and the read-back. Not a byte count: the
  /// steps are commands of very different sizes, so the fraction is a
  /// position in the sequence, which is what the sheet's bar shows.
  final double? progress;

  /// The slot now holds the card, and the read-back agreed.
  final bool done;

  /// The typed error the last load ended with, rendered through the spec 9
  /// catalog. Never a string.
  final Object? error;

  /// This tag type has no emulation Spectra can fill
  /// ([SlotLoadMethod.unsupported]). A state, not an error: nothing went
  /// wrong, there is simply nothing to do.
  final bool unsupported;

  /// Classic-only (Phase 7 ruling 23): the sector indexes whose trailer
  /// block is sixteen zero bytes — a read dump's mark for "this sector's
  /// keys were never recovered". Non-null and non-empty means [SlotLoader
  /// .load] stopped short of touching the device and is waiting for a
  /// second call with `confirmUnread: true`; the sheet renders this as a
  /// warning naming the sectors, never silently loading a partial card.
  final List<int>? unreadSectors;
}

/// Spec 7.7 step 5: load a dump into one of the eight slots.
///
/// The order matters and is the device's, not a preference: select the slot
/// (so every `EmulatorFacade` call lands on it — that facade always operates
/// on the *active* slot), reset it to the target type (which sets the type
/// and clears that sense's old data in one command, so no byte of the
/// previous card survives), write the data, set the anti-collision, name it,
/// enable it. Every `SlotsFacade` mutation ends in SLOT_DATA_CONFIG_SAVE on
/// its own, so nothing here has to save.
///
/// The load then reads the slot back and compares. A device that stores
/// something else is a [SlotLoadVerificationFailed], which the error catalog
/// has words for — silently reporting success for a slot that will not
/// emulate is the one outcome worth spending an extra round trip to avoid.
///
/// A dump whose byte length does not match [type]'s expected length is
/// refused before any command is sent, as a [CardDumpLengthMismatch]
/// (ruling 4): a stored row of the wrong size was never a valid dump, and
/// half-writing it would leave the slot worse than it started.
///
/// A MIFARE Classic dump with an all-zero sector trailer — the shape a read
/// leaves behind for a sector it never authenticated — is refused the same
/// way, but as [SlotLoadState.unreadSectors] rather than [SlotLoadState
/// .error]: nothing is wrong with the request, the caller just has not
/// confirmed it yet (ruling 23). Passing `confirmUnread: true` proceeds
/// anyway; the caller is expected to have shown the sector list first.
///
/// There is no wakelock code here and there must not be: `writeMf1Blocks`
/// and `readMf1Blocks` run inside `DeviceSession.busy`, as does every
/// `SlotsFacade` mutation but `setActive`, and `sessionNeedsWakelock`
/// (`core/lifecycle/wakelock.dart`) polls exactly that.
///
/// A call made while another is in flight is dropped, not queued
/// (`_inFlight`); the sheet disables its button while `state.busy`. This
/// notifier is autoDispose and lives under a sheet the user can dismiss, so
/// every assignment to [state] after an `await` is guarded with `ref.mounted`
/// (R25) — the device write still runs to completion, there is simply no
/// longer anywhere to report it.
@riverpod
class SlotLoader extends _$SlotLoader {
  @override
  SlotLoadState build() {
    ref.onDispose(() {
      // Not `state` — the element is gone by now.
      _inFlight = false;
    });
    return const SlotLoadState();
  }

  bool _inFlight = false;

  /// [fallbackLabel] is the tag-type label (`core/format/tag_labels.dart`'s
  /// `tagTypeLabel(type, l10n)`) the caller resolves: this file stays pure
  /// state with no `AppLocalizations` dependency (ruling 26), so the label
  /// travels in as a plain string rather than being looked up here.
  Future<void> load({
    required int slotIndex,
    required TagType type,
    required Uint8List bytes,
    required String name,
    required String fallbackLabel,
    bool confirmUnread = false,
  }) async {
    if (_inFlight) return;

    final SlotLoadMethod method = slotLoadMethodFor(type);
    if (method == SlotLoadMethod.unsupported) {
      state = const SlotLoadState(unsupported: true);
      return;
    }

    final int expected = expectedDumpLength(type);
    if (bytes.length != expected) {
      // Before anything is sent: a stored row of the wrong size was never a
      // valid dump, and half-writing it would leave the slot worse than it
      // started.
      state = SlotLoadState(
        error: CardDumpLengthMismatch(
          type: type,
          expected: expected,
          actual: bytes.length,
        ),
      );
      return;
    }

    if (method == SlotLoadMethod.mifareClassicBlocks && !confirmUnread) {
      final List<int> unread = _unreadSectors(type, bytes);
      if (unread.isNotEmpty) {
        state = SlotLoadState(unreadSectors: unread);
        return;
      }
    }

    final ActiveSession? active = ref.read(activeSessionProvider);
    if (active == null) {
      state = const SlotLoadState(error: SessionNotReady('no active session'));
      return;
    }

    _inFlight = true;
    state = const SlotLoadState(busy: true, progress: 0);
    try {
      final String nick = slotNicknameFor(name, fallbackLabel: fallbackLabel);
      await _load(active.session, slotIndex, type, bytes, nick, method);
      if (ref.mounted) {
        state = const SlotLoadState(done: true, progress: 1);
      }
    } on Object catch (error) {
      if (ref.mounted) state = SlotLoadState(error: error);
    } finally {
      _inFlight = false;
    }
  }

  /// Back to the empty state, so the sheet's "Try again" offers the load
  /// again rather than leaving a `ProblemView` (or an unread-sector
  /// warning) up forever.
  void reset() => state = const SlotLoadState();

  /// Lets a test drive an error state without a facade that throws.
  /// `Notifier.state` is `@protected`; this is the narrow door around that.
  @visibleForTesting
  void debugFail(Object error) => state = SlotLoadState(error: error);

  Future<void> _load(
    DeviceSession session,
    int slotIndex,
    TagType type,
    Uint8List bytes,
    String nick,
    SlotLoadMethod method,
  ) async {
    final SlotsFacade slots = session.slots;
    final EmulatorFacade emulator = session.emulator;

    await slots.setActive(slotIndex);
    _publish(0.15);
    await slots.resetToDefault(slotIndex, type);
    _publish(0.3);

    switch (method) {
      case SlotLoadMethod.mifareClassicBlocks:
        await emulator.writeMf1Blocks(0, bytes);
        _publish(0.55);
        await emulator.setAntiColl(antiCollForClassic(bytes));
      case SlotLoadMethod.ultralightPages:
        // No anti-collision call: the firmware derives the emulated
        // anti-collision answer from pages 0-2, which are part of the dump.
        await emulator.writeNtagPages(0, bytes);
      case SlotLoadMethod.em410xId:
        await emulator.setLfId(TagType.em410x, bytes);
      case SlotLoadMethod.unsupported:
        return; // Unreachable: refused by the caller.
    }
    _publish(0.65);

    await slots.rename(slotIndex, type.sense, nick);
    _publish(0.8);
    await slots.setEnabled(slotIndex, type.sense, true);
    _publish(0.9);

    final Uint8List stored = await _readBack(emulator, method, bytes.length);
    if (!_sameBytes(stored, bytes)) {
      throw SlotLoadVerificationFailed(switch (method) {
        SlotLoadMethod.mifareClassicBlocks => 'the emulated blocks',
        SlotLoadMethod.ultralightPages => 'the emulated pages',
        SlotLoadMethod.em410xId ||
        SlotLoadMethod.unsupported => 'the stored id',
      });
    }
  }

  Future<Uint8List> _readBack(
    EmulatorFacade emulator,
    SlotLoadMethod method,
    int length,
  ) => switch (method) {
    SlotLoadMethod.mifareClassicBlocks => emulator.readMf1Blocks(
      0,
      length ~/ 16,
    ),
    SlotLoadMethod.ultralightPages => emulator.readNtagPages(0, length ~/ 4),
    SlotLoadMethod.em410xId ||
    SlotLoadMethod.unsupported => emulator.getLfId(TagType.em410x),
  };

  static bool _sameBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// The sector indexes of [type] whose trailer block in [blocks] is
  /// sixteen zero bytes. Pure and device-free, so the check runs before
  /// `activeSessionProvider` is even consulted.
  static List<int> _unreadSectors(TagType type, Uint8List blocks) {
    final int sectors = MifareGeometry.sectorCount(type);
    final List<int> unread = <int>[];
    for (int s = 0; s < sectors; s++) {
      final int start = MifareGeometry.trailerOf(s) * 16;
      bool allZero = true;
      for (int i = 0; i < 16; i++) {
        if (blocks[start + i] != 0) {
          allZero = false;
          break;
        }
      }
      if (allZero) unread.add(s);
    }
    return unread;
  }

  /// A progress step. Guarded like every other post-`await` assignment: the
  /// sheet can be dismissed between two commands.
  void _publish(double progress) {
    if (!ref.mounted) return;
    state = SlotLoadState(busy: true, progress: progress);
  }
}
