import '../../commands/device.dart';
import '../connection_state.dart';
import '../device_session.dart';

/// The firmware update entry point (spec 8.1). The transfer itself is the
/// app's DFU layer; the SDK only puts the device into the bootloader.
final class FirmwareFacade {
  FirmwareFacade(this._s);
  final DeviceSession _s;

  /// Reboots the device into the DFU bootloader.
  ///
  /// The session moves to [SessionUpdating] *before* the command goes out:
  /// the firmware never answers ENTER_BOOTLOADER, it just drops the link, and
  /// only an updating session reads that close as the reboot it asked for
  /// rather than as a disconnect. The session stays updating afterwards so
  /// the DFU flow can reconnect to the bootloader.
  ///
  /// Allowed from ready and from [SessionLimited]: firmware too old for
  /// anything else must still be updatable.
  Future<void> enterBootloader() async {
    final state = _s.connectionState.value;
    if (state is! SessionReady && state is! SessionLimited) {
      throw StateError('cannot enter bootloader from ${state.runtimeType}');
    }
    _s.connectionState.set(const SessionUpdating());
    await _s.send(const EnterBootloader(), allowLimited: true);
  }
}
