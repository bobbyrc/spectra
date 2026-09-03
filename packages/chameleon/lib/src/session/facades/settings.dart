import '../../commands/device.dart';
import '../../model/enums.dart';
import '../../model/models.dart';
import '../device_session.dart';

/// Device settings: animation, button functions, BLE pairing and sleep
/// timeout (spec 8.1).
///
/// Unlike slot edits these do not auto-save: a BLE pairing change needs an
/// explicit [save] and a reboot, and batching the rest behind one save keeps
/// the settings screen's "save" button honest.
final class SettingsFacade {
  SettingsFacade(this._s);
  final DeviceSession _s;

  DeviceSettings? get current => _s.settingsState.value;

  Future<DeviceSettings> refresh() async {
    final v = await _s.send(const GetDeviceSettings());
    _s.settingsState.set(v);
    return v;
  }

  Future<void> setAnimation(AnimationMode mode) async {
    await _s.send(SetAnimationMode(mode));
    _update((s) => s.copyWith(animation: mode));
  }

  Future<void> setButton(
    DeviceButton button,
    ButtonFunction fn, {
    bool long = false,
  }) async {
    await _s.send(
      long
          ? SetLongButtonPressConfig(button, fn)
          : SetButtonPressConfig(button, fn),
    );
    _update(
      (s) => switch ((button, long)) {
        (DeviceButton.a, false) => s.copyWith(buttonA: fn),
        (DeviceButton.b, false) => s.copyWith(buttonB: fn),
        (DeviceButton.a, true) => s.copyWith(longButtonA: fn),
        (DeviceButton.b, true) => s.copyWith(longButtonB: fn),
      },
    );
  }

  Future<void> setBlePairingKey(String key) async {
    await _s.send(SetBlePairingKey(key));
    _update((s) => s.copyWith(blePairingKey: key));
  }

  Future<void> setBlePairingEnabled(bool enabled) async {
    await _s.send(SetBlePairingEnable(enabled));
    _update((s) => s.copyWith(blePairingEnabled: enabled));
  }

  Future<void> setSleepTimeout(int seconds) async {
    await _s.send(SetSleepTimeout(seconds));
    _update((s) => s.copyWith(sleepTimeoutSeconds: seconds));
  }

  /// Writes the current settings to flash. Pairing changes take effect after
  /// this and a reboot.
  Future<void> save() => _s.send(const SaveSettings());

  /// Restores factory settings on the device, then re-reads them: the reset
  /// touches every field, so a re-read is cheaper than mirroring the
  /// firmware's defaults here.
  Future<void> reset() async {
    await _s.send(const ResetSettings());
    await refresh();
  }

  Future<void> deleteAllBleBonds() => _s.send(const DeleteAllBleBonds());

  void _update(DeviceSettings Function(DeviceSettings) f) {
    final c = current;
    if (c != null) _s.settingsState.set(f(c));
  }
}
