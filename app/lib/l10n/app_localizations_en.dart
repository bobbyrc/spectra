// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Spectra';

  @override
  String get errorMalformedResponse =>
      'The device sent a reply Spectra could not read.';

  @override
  String get errorTimeout => 'The device did not answer in time.';

  @override
  String get errorCancelled => 'Cancelled.';

  @override
  String get errorNotReady => 'That needs a connected device.';

  @override
  String get errorBackgroundTask => 'Something went wrong in the background.';

  @override
  String get errorFirmwareTooOld =>
      'This firmware is older than 2.0. Update it to use Spectra.';

  @override
  String get errorFirmwareTooNew =>
      'This firmware is newer than Spectra supports. Update Spectra.';

  @override
  String get errorFirmwareLegacy =>
      'This device runs the legacy 0.1 firmware and must be updated.';

  @override
  String get errorNoReader => 'This device has no card reader.';

  @override
  String get errorDisconnected => 'The connection to the device was lost.';

  @override
  String get errorPermissionDenied =>
      'Spectra needs permission to reach the device.';

  @override
  String get errorPortBusy => 'That port is in use by another program.';

  @override
  String get errorDeviceNotFound => 'Spectra could not find that device.';

  @override
  String get errorPairingRequired => 'This device has to be paired first.';

  @override
  String get errorAdapterOff => 'Bluetooth is switched off.';

  @override
  String get errorDfu => 'The firmware update could not be completed.';

  @override
  String get errorNoHfTag =>
      'No high-frequency card was found. Hold the card against the device.';

  @override
  String get errorHfTag =>
      'The card did not answer cleanly. Try holding it steady.';

  @override
  String get errorAuthFailed => 'That key was rejected by the card.';

  @override
  String get errorNoLfTag => 'No low-frequency card was found.';

  @override
  String get errorLfLoginRequired =>
      'This card needs a password before it can be read.';

  @override
  String get errorParameter => 'The device rejected that value.';

  @override
  String get errorDeviceMode => 'The device is in the wrong mode for that.';

  @override
  String get errorInvalidCommand =>
      'This firmware does not support that action.';

  @override
  String get errorNotImplemented =>
      'That is not implemented on this firmware yet.';

  @override
  String get errorFlashWrite => 'Writing to the device\'s storage failed.';

  @override
  String get errorFlashRead => 'Reading the device\'s storage failed.';

  @override
  String get errorInvalidSlotType => 'That tag type cannot go in this slot.';

  @override
  String get errorMemory => 'The device ran out of memory.';

  @override
  String get errorCreateResponse => 'The device could not build a reply.';

  @override
  String get errorCommandFailed => 'The device could not carry that out.';

  @override
  String errorUnknownStatus(String code) {
    return 'The device reported an unknown status ($code).';
  }

  @override
  String get errorNoKnownDeviceVisible =>
      'No known device is visible. Wake the device or plug it in, then try again.';

  @override
  String get errorUnexpected => 'Something unexpected went wrong.';

  @override
  String get guidanceAndroidBluetoothPermission =>
      'Open Android settings and allow Spectra to find and connect to nearby devices.';

  @override
  String get guidanceApplePairingPrompt =>
      'Accept the pairing prompt when it appears.';

  @override
  String get guidanceApplePermissionSettings =>
      'Allow Bluetooth for Spectra in System Settings, then try again.';

  @override
  String get guidanceWindowsPairDevice =>
      'Pair the Chameleon in Windows Bluetooth settings, then try again.';

  @override
  String get guidanceLinuxPairFromSettings =>
      'Pair the Chameleon from your system Bluetooth settings using the device\'s passkey, then try again.';

  @override
  String get guidanceBluetoothAdapterOff =>
      'Switch Bluetooth on, then scan again.';

  @override
  String get guidanceLinuxSerialGroup =>
      'Add your user to the dialout group, or install the Chameleon udev rule, then reconnect the cable.';

  @override
  String get guidanceLinuxModemManager =>
      'ModemManager is holding the port. Stop it, or add the Chameleon to its ignore list, then reconnect.';

  @override
  String get guidanceWindowsPortAccessDenied =>
      'Close any other program using the COM port, then try again.';

  @override
  String get guidanceMacosSerialEntitlement =>
      'Allow Spectra to use USB devices when macOS asks, then try again.';

  @override
  String get guidanceAndroidUsbPermission =>
      'Allow Spectra to use the USB device when Android asks.';

  @override
  String get guidancePortBusyOther =>
      'Another app is using this port. Close it and try again.';

  @override
  String get guidancePortNotFound =>
      'That port is gone. Reconnect the cable and scan again.';

  @override
  String get navDevice => 'Device';

  @override
  String get navSlots => 'Slots';

  @override
  String get navCards => 'Cards';

  @override
  String get navTools => 'Tools';

  @override
  String get navSettings => 'Settings';

  @override
  String get connectTitle => 'Connect a device';

  @override
  String get slotsTitle => 'Slots';

  @override
  String get slotsEmpty => 'Connect a device to see its slots.';

  @override
  String get comingSoonCards => 'The card library arrives in Phase 6.';

  @override
  String get comingSoonSettings => 'Settings arrive in Phase 9.';

  @override
  String get comingSoonUpdate => 'Firmware update arrives in Phase 8.';

  @override
  String get toolsTitle => 'Tools';

  @override
  String get toolsFrameLog => 'Frame log';

  @override
  String get toolsFrameLogSubtitle =>
      'Everything sent to and received from the device.';

  @override
  String get toolsUpdate => 'Firmware update';

  @override
  String get frameLogTitle => 'Frame log';

  @override
  String get updateTitle => 'Firmware update';

  @override
  String get frameLogEmpty =>
      'No frames yet. Connect a device and the log fills up.';

  @override
  String get frameLogCopy => 'Copy';

  @override
  String get frameLogCopied => 'Frame log copied.';

  @override
  String updateRecoverTarget(String transportId) {
    return 'Recovering the device at $transportId.';
  }

  @override
  String get updateRecoverInstructions =>
      'If the device is not listed, hold button B while plugging in the USB cable to enter the bootloader from any state.';

  @override
  String get updateBleNotice =>
      'Bluetooth firmware update is pending hardware validation and is switched off in this build.';

  @override
  String get dashboardTitle => 'Device';

  @override
  String get connectSubtitle => 'Choose a Chameleon to connect to.';

  @override
  String get connectScanning => 'Looking for devices…';

  @override
  String get connectNothingFound =>
      'No devices found. Over Bluetooth, press a button on the device to wake it — it sleeps eight seconds after losing a connection.';

  @override
  String get connectReconnectLast => 'Reconnect to last device';

  @override
  String get connectConnecting => 'Connecting…';

  @override
  String get connectRecover => 'Recover';

  @override
  String get connectBootloaderBadge => 'In bootloader';

  @override
  String get connectKindUsb => 'USB';

  @override
  String get connectKindBle => 'Bluetooth';

  @override
  String get connectKindFake => 'Emulated';

  @override
  String get connectManualPortTitle => 'Add a serial port';

  @override
  String get connectManualPortLabel => 'Port path';

  @override
  String get connectManualPortHint => '/dev/cu.usbmodem1';

  @override
  String get connectManualPortAdd => 'Add';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonOpenSettings => 'Open settings';

  @override
  String get commonDetails => 'Details';

  @override
  String get commonUpdateFirmware => 'Update firmware';

  @override
  String get dashboardDisconnect => 'Disconnect';

  @override
  String get dashboardModel => 'Model';

  @override
  String get dashboardFirmware => 'Firmware';

  @override
  String get dashboardGitVersion => 'Build';

  @override
  String get dashboardChipId => 'Chip ID';

  @override
  String get dashboardBleAddress => 'Bluetooth address';

  @override
  String get dashboardActiveSlot => 'Active slot';

  @override
  String get dashboardModeReader => 'Reader mode';

  @override
  String get dashboardModeEmulator => 'Emulator mode';

  @override
  String get dashboardModelUltra => 'Chameleon Ultra';

  @override
  String get dashboardModelLite => 'Chameleon Lite';

  @override
  String get dashboardUnknown => 'Unknown';

  @override
  String get dashboardLimitedTitle => 'This device needs a firmware update';

  @override
  String get slotTypeEmpty => 'Empty';

  @override
  String get slotSenseHf => 'High frequency';

  @override
  String get slotSenseLf => 'Low frequency';

  @override
  String get slotNicknameTooLong => 'Names are limited to 32 bytes.';
}
