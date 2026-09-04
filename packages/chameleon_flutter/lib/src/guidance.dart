/// Why a transport could not be used, in terms the app can turn into a
/// concrete instruction. The transport exposes the reason as a value; the
/// wording lives in the app's ARB files (spec 7.6), never here.
///
/// Each value is scoped to the platform(s) that can actually produce it, so
/// no platform is ever handed another platform's instructions.
enum TransportGuidance {
  /// Android 12+ BLUETOOTH_SCAN / BLUETOOTH_CONNECT, or location below 12.
  androidBluetoothPermission,

  /// The OS shows its own pairing prompt; tell the user to accept it.
  applePairingPrompt,

  /// iOS/macOS: Bluetooth permission was denied. Enable it in
  /// Settings / System Settings.
  applePermissionSettings,

  /// Windows: pairing is driven from the app; retry or pair from Settings.
  windowsPairDevice,

  /// Linux: BlueZ has no pairing agent. Pair from system settings with the
  /// device's passkey, then reconnect.
  linuxPairFromSettings,

  /// Bluetooth is switched off.
  bluetoothAdapterOff,

  /// Linux: the user is not in the serial group (dialout/uucp) or no udev
  /// rule grants access to the port.
  linuxSerialGroup,

  /// Linux: another process holds the port. ModemManager is the usual cause.
  linuxModemManager,

  /// Windows: the COM port is open in another application.
  windowsPortAccessDenied,

  /// macOS: the sandboxed build lacks com.apple.security.device.serial.
  macosSerialEntitlement,

  /// Android: the USB device permission dialog was declined.
  androidUsbPermission,

  /// A port is held by another process, on a platform without a more
  /// specific hint than "something else has it open".
  portBusyOther,

  /// The port or device is gone: unplugged, or out of range.
  portNotFound,
}

/// A transport that can explain a failure as a [TransportGuidance].
abstract interface class GuidedTransport {
  /// The reason for the most recent failure, or null if there was none.
  TransportGuidance? get guidance;
}
