import '../../commands/device.dart';
import '../../model/enums.dart';
import '../../model/models.dart';
import '../device_session.dart';

/// Device-wide reads and the emulator/reader mode switch (spec 4.3).
///
/// Every call that changes device state writes the new value straight into
/// the session cache from its own response, so the UI never waits for the
/// idle poll to catch up.
final class DeviceFacade {
  DeviceFacade(this._s);
  final DeviceSession _s;

  /// The identity, model and firmware of the connected device, as far as the
  /// handshake and the background load got.
  DeviceInfo? get info => _s.deviceInfo.value;

  Future<BatteryInfo> readBattery() async {
    final b = await _s.send(const GetBatteryInfo());
    _s.battery.setIfChanged(b);
    return b;
  }

  Future<DeviceMode> readMode() async {
    final m = await _s.send(const GetDeviceMode());
    _s.mode.setIfChanged(m);
    return m;
  }

  /// Switches the device between emulator and reader mode. This is the manual
  /// switch behind the mode toggle in the UI.
  ///
  /// Refused while a reader lease is held: the lease owns the mode and would
  /// restore the wrong one on release. Reader work takes a lease with
  /// [DeviceSession.withReaderMode] instead.
  Future<void> setMode(DeviceMode m) async {
    if (_s.readerLeaseCount > 0) {
      throw StateError('mode is held by a reader lease; use withReaderMode');
    }
    await _s.send(ChangeDeviceMode(m));
    _s.mode.setIfChanged(m);
  }

  Future<DeviceIdentity> readIdentity() async {
    final id = DeviceIdentity(await _s.send(const GetDeviceChipId()));
    final current = info;
    if (current != null) {
      _s.deviceInfo.setIfChanged(current.copyWith(identity: id));
    }
    return id;
  }
}
