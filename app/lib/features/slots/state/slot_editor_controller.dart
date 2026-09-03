import 'package:chameleon/chameleon.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/session/active_device.dart';
import '../../../core/session/active_session.dart';

part 'slot_editor_controller.g.dart';

/// Every change to one slot, as an [AsyncValue] the screen renders.
///
/// Failures stay in the state rather than being thrown, so the editor shows
/// them through the error catalog (spec 9) instead of catching. One notifier
/// per slot index, so a failure on slot 3 does not grey out slot 4.
///
/// Nothing here refreshes afterwards: every [SlotsFacade] method already
/// ends with SLOT_DATA_CONFIG_SAVE and writes the change through to
/// `DeviceSession.slotsState`, which `slotViewsProvider` is watching.
/// `setActive` is the one exception to both of those — it is a single
/// SET_ACTIVE_SLOT command with no save step, and (unlike the other five
/// methods) it is not wrapped in `DeviceSession.busy`, so the wakelock
/// `sessionNeedsWakelock` polls is not held while it runs.
///
/// A call made while another is already in flight is dropped, not queued
/// (see `_inFlight`): the screen must disable its controls while
/// `state.isLoading` so a dropped call is never the only thing standing
/// between a tap and the change it was supposed to make.
@riverpod
class SlotEditor extends _$SlotEditor {
  @override
  Future<void> build(int index) async {}

  /// Emulate this slot from now on (SET_ACTIVE_SLOT).
  Future<void> makeActive() =>
      _run((SlotsFacade slots) => slots.setActive(index));

  Future<void> setEnabled(Sense sense, bool enabled) =>
      _run((SlotsFacade slots) => slots.setEnabled(index, sense, enabled));

  /// The caller validates with `validateSlotNickname` first: the SDK's own
  /// length check throws an `ArgumentError`, which is not a
  /// `ChameleonException` and would reach the catalog as "something
  /// unexpected went wrong".
  Future<void> rename(Sense sense, String nick) =>
      _run((SlotsFacade slots) => slots.rename(index, sense, nick));

  /// [type] carries its own sense, so this changes exactly one side.
  Future<void> setTagType(TagType type) =>
      _run((SlotsFacade slots) => slots.setTagType(index, type));

  /// Empties one sense: the type becomes undefined and the sense is
  /// disabled (DELETE_SLOT_SENSE_TYPE).
  Future<void> clearSense(Sense sense) =>
      _run((SlotsFacade slots) => slots.deleteSense(index, sense));

  /// Clears a failed change back to idle, so the screen can offer the
  /// action again (spec 9's retry).
  void reset() => state = const AsyncData<void>(null);

  /// Lets Task 9's tests drive an `AsyncError` state directly, without a
  /// real facade failure. [Notifier.state] is `@protected`; this is the
  /// narrow, test-only door around that.
  @visibleForTesting
  void debugFail(Object error) =>
      state = AsyncError<void>(error, StackTrace.current);

  /// Guards against a second call landing while one is still in flight —
  /// distinct from `state.isLoading`, which is also true for the moment
  /// between the notifier being read and [build] resolving.
  bool _inFlight = false;

  Future<void> _run(Future<void> Function(SlotsFacade slots) body) async {
    if (_inFlight) return;
    _inFlight = true;
    final ActiveSession? active = ref.read(activeSessionProvider);
    if (active == null) {
      state = AsyncError<void>(
        const SessionNotReady('no active session'),
        StackTrace.current,
      );
      _inFlight = false;
      return;
    }
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard<void>(() => body(active.session.slots));
    _inFlight = false;
  }
}
