import 'package:chameleon/chameleon.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/app_failures.dart';
import '../../../core/session/active_device.dart';
import '../../../core/session/active_session.dart';
import 'settings_labels.dart';

part 'device_settings_controller.g.dart';

/// What the settings screen needs beyond the values themselves.
///
/// The values are not here: `SettingsFacade` writes every change through to
/// `DeviceSession.settingsState` (spec 4.3's cache contract), which
/// `settingsProvider` (`core/session/session_streams.dart`) already streams.
/// Mirroring them into this state would give the screen two sources for one
/// fact.
final class DeviceSettingsEditState {
  const DeviceSettingsEditState({
    this.busy = false,
    this.dirty = false,
    this.error,
  });

  final bool busy;

  /// True when a change has reached the device's RAM but not its flash.
  /// The firmware needs an explicit SAVE_SETTINGS (1013); until then a
  /// reboot loses the change, so the screen says so.
  final bool dirty;

  final Object? error;
}

/// Every device-settings change, as state the screen renders (spec 7.7 step
/// 7, spec 8.1).
///
/// Failures stay in [DeviceSettingsEditState.error] rather than being
/// thrown, so the screen shows them through the spec 9 catalog. A call made
/// while another is in flight is dropped, not queued, and the screen
/// disables its controls while `busy`. Every post-`await` assignment is
/// guarded with `ref.mounted` (R25): the Settings tab can be left while a
/// write is on the wire.
///
/// `SlotsFacade`'s own methods call `DeviceSession.busy` internally;
/// `SettingsFacade`'s do not. Its writes are not "load a full tag dump"
/// long, but they are still a round trip over the wire, so this controller
/// wraps every facade call itself in `active.session.busy`, holding the
/// wakelock (`core/lifecycle/wakelock.dart`) for its duration the same way
/// a slot mutation does.
@riverpod
class DeviceSettingsController extends _$DeviceSettingsController {
  @override
  DeviceSettingsEditState build() {
    ref.onDispose(() {
      // Not `state` — the element is gone by now (Global Constraints).
      _inFlight = false;
    });
    return const DeviceSettingsEditState();
  }

  bool _inFlight = false;

  Future<void> setAnimation(AnimationMode mode) =>
      _run((SettingsFacade s) => s.setAnimation(mode));

  Future<void> setButton(
    DeviceButton button,
    ButtonFunction fn, {
    bool long = false,
  }) => _run((SettingsFacade s) => s.setButton(button, fn, long: long));

  /// The firmware accepts 5..60 seconds (`docs/research/chameleon-protocol.md`,
  /// 1039/1040); `SetSleepTimeout.encode` throws a raw `ArgumentError`
  /// outside that range, which the catalog can only render as "something
  /// unexpected went wrong". `isValidSleepTimeout` catches it here first, the
  /// same shape as `isValidPairingKey` and Phase 5's
  /// `validateSlotNickname` — a value the SDK would reject becomes a typed
  /// [SleepTimeoutOutOfRange] the catalog has words for, and nothing is
  /// sent to the device.
  Future<void> setSleepTimeout(int seconds) async {
    if (!isValidSleepTimeout(seconds)) {
      state = DeviceSettingsEditState(
        dirty: state.dirty,
        error: SleepTimeoutOutOfRange(seconds),
      );
      return;
    }
    await _run((SettingsFacade s) => s.setSleepTimeout(seconds));
  }

  Future<void> setBlePairingEnabled(bool enabled) =>
      _run((SettingsFacade s) => s.setBlePairingEnabled(enabled));

  /// The caller validates with `isValidPairingKey` first: the firmware wants
  /// exactly six ASCII digits, and a shorter string would be a wire-format
  /// error rather than a message the catalog has words for.
  Future<void> setBlePairingKey(String key) =>
      _run((SettingsFacade s) => s.setBlePairingKey(key));

  /// SAVE_SETTINGS, then a re-read: the settings struct is the one payload
  /// the wiki's length is uncertain about (spec 11), so reading back what
  /// the device actually kept is cheaper than trusting the write.
  Future<void> saveToDevice() => _run((SettingsFacade s) async {
    await s.save();
    await s.refresh();
  }, clearsDirty: true);

  /// RESET_SETTINGS. `SettingsFacade.reset` already re-reads.
  Future<void> resetToFactory() =>
      _run((SettingsFacade s) => s.reset(), clearsDirty: true);

  /// Clears the bonds a paired host holds (1032). Spec 5.1: with pairing
  /// enabled the device is invisible to hosts that are not bonded, so this
  /// is the way back.
  Future<void> deleteBonds() =>
      _run((SettingsFacade s) => s.deleteAllBleBonds(), marksDirty: false);

  void clearError() => state = DeviceSettingsEditState(dirty: state.dirty);

  @visibleForTesting
  void debugFail(Object error) =>
      state = DeviceSettingsEditState(dirty: state.dirty, error: error);

  Future<void> _run(
    Future<void> Function(SettingsFacade settings) body, {
    bool marksDirty = true,
    bool clearsDirty = false,
  }) async {
    if (_inFlight) return;
    final ActiveSession? active = ref.read(activeSessionProvider);
    if (active == null) {
      state = DeviceSettingsEditState(
        dirty: state.dirty,
        error: const SessionNotReady('no active session'),
      );
      return;
    }
    _inFlight = true;
    state = DeviceSettingsEditState(busy: true, dirty: state.dirty);
    Object? error;
    try {
      await active.session.busy(() => body(active.session.settings));
    } on Object catch (e) {
      error = e;
    }
    if (!ref.mounted) {
      _inFlight = false;
      return;
    }
    final bool dirty = switch ((error != null, clearsDirty, marksDirty)) {
      (true, _, _) => state.dirty, // a failed write changed nothing
      (false, true, _) => false,
      (false, false, true) => true,
      _ => state.dirty,
    };
    state = DeviceSettingsEditState(dirty: dirty, error: error);
    _inFlight = false;
  }
}
