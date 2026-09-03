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
  String get errorSlotVerify =>
      'The device stored something different from what Spectra sent.';

  @override
  String errorCardDumpLength(String type, int expected, int actual) {
    return 'This dump is $actual bytes, but a $type needs $expected.';
  }

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
  String slotDetailTitle(int number) {
    return 'Slot $number';
  }

  @override
  String get slotNotFound => 'That slot does not exist.';

  @override
  String get slotActive => 'Active';

  @override
  String get slotMakeActive => 'Make active';

  @override
  String get slotInactive => 'Not the active slot';

  @override
  String get slotEnabled => 'Enabled';

  @override
  String get slotNameLabel => 'Name';

  @override
  String get slotSaveName => 'Save name';

  @override
  String get cardsReadTitle => 'Card reader';

  @override
  String get cardsReadAction => 'Read a card';

  @override
  String get cardsReadHint =>
      'Hold the card flat against the back of the Chameleon, then choose a frequency.';

  @override
  String get cardsReadHf => 'Scan high frequency';

  @override
  String get cardsReadLf => 'Scan low frequency';

  @override
  String get cardsReadScanning => 'Looking for a card…';

  @override
  String get cardsReadDumping => 'Reading the card…';

  @override
  String get cardsReadAgain => 'Read again';

  @override
  String cardsReadPartial(int read, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      read,
      locale: localeName,
      other:
          '$read of $total blocks could be read. Sectors with no known key are blank.',
      one:
          '1 of $total blocks could be read. Sectors with no known key are blank.',
    );
    return '$_temp0';
  }

  @override
  String get cardsReadIdentityOnly =>
      'Spectra can show this card\'s identity but cannot read its memory yet.';

  @override
  String cardsReadKeysFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Keys found for $count sectors.',
      one: 'Keys found for 1 sector.',
    );
    return '$_temp0';
  }

  @override
  String get cardsSaveToLibrary => 'Save to library';

  @override
  String get cardsEmulateThis => 'Emulate this card';

  @override
  String get cardsSaveTitle => 'Save this card';

  @override
  String get cardsSaveName => 'Name';

  @override
  String get cardsSaveFolder => 'Folder';

  @override
  String get cardsSaveFolderHint => 'Work';

  @override
  String get cardsSaveColour => 'Colour';

  @override
  String cardsSaveColourSwatch(int number) {
    return 'Colour $number';
  }

  @override
  String cardsSaveColourSwatchSelected(int number) {
    return 'Colour $number, selected';
  }

  @override
  String get cardsSaveConfirm => 'Save';

  @override
  String cardsSavePartial(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocks could not be read. They are saved as zeros.',
      one: '1 block could not be read. It is saved as zeros.',
    );
    return '$_temp0';
  }

  @override
  String get cardsSaveNameRequired => 'Give the card a name.';

  @override
  String get cardsSaved => 'Saved to the library.';

  @override
  String get cardsTitle => 'Cards';

  @override
  String get cardsEmpty =>
      'No cards yet. Read one, or import from another app.';

  @override
  String get cardsNoMatches => 'No cards match that search.';

  @override
  String get cardsSearch => 'Search';

  @override
  String get cardsAllFolders => 'All folders';

  @override
  String get cardsSortRecent => 'Recent';

  @override
  String get cardsSortName => 'Name';

  @override
  String get cardsImport => 'Import';

  @override
  String get cardsImportTitle => 'Import cards';

  @override
  String get cardsImportHint =>
      'Paste a card export from Spectra or from the Chameleon Ultra GUI.';

  @override
  String get cardsImportLabel => 'Exported JSON';

  @override
  String get cardsImportConfirm => 'Import cards';

  @override
  String cardsImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count cards.',
      one: 'Imported $count card.',
    );
    return '$_temp0';
  }

  @override
  String get cardsImportNotJson =>
      'That text is not a card export Spectra can read.';

  @override
  String get cardsImportNoCards => 'That export has no cards in it.';

  @override
  String get cardsImportUnsupported => 'Spectra cannot read that tag type yet.';

  @override
  String get cardsImportBadBytes =>
      'That export\'s card data could not be read.';

  @override
  String get cardsExport => 'Copy as JSON';

  @override
  String get cardsExported => 'Copied to the clipboard.';

  @override
  String cardsSubtitle(String tagType, String folder) {
    return '$tagType · $folder';
  }

  @override
  String cardsSubtitleNoFolder(String tagType) {
    return '$tagType';
  }

  @override
  String get cardsDetailNotFound => 'That card is not in the library.';

  @override
  String get cardsDetailEdit => 'Edit details';

  @override
  String get cardsDetailEditTitle => 'Edit details';

  @override
  String get cardsDetailDelete => 'Delete';

  @override
  String get cardsDetailDeleteTitle => 'Delete this card?';

  @override
  String get cardsDetailDeleteBody =>
      'The saved dump is removed from Spectra. The physical card is not touched.';

  @override
  String cardsDetailProblems(String problems) {
    return 'This dump has problems: $problems';
  }

  @override
  String cardsDetailBytes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bytes',
      one: '$count byte',
    );
    return '$_temp0';
  }

  @override
  String get cardsEditTitle => 'Edit';

  @override
  String get cardsEditChunkLabelBlock => 'Block';

  @override
  String get cardsEditChunkLabelPage => 'Page';

  @override
  String get cardsEditChunkLabelId => 'Id';

  @override
  String get cardsEditValue => 'Bytes (hex)';

  @override
  String get cardsEditApply => 'Apply';

  @override
  String get cardsEditBadHex => 'That is not hex.';

  @override
  String cardsEditBadLength(int size, String unit) {
    return 'This card takes $size bytes per $unit.';
  }

  @override
  String get cardsEditChunkUnitBlock => 'block';

  @override
  String get cardsEditChunkUnitPage => 'page';

  @override
  String get cardsEditChunkUnitId => 'id';

  @override
  String cardsEditBadIndex(int last) {
    return 'Choose a number between 0 and $last.';
  }

  @override
  String get cardsEditSave => 'Save changes';

  @override
  String get cardsEditDiscard => 'Discard changes';

  @override
  String get cardsEditUnsavedTitle => 'Leave without saving?';

  @override
  String get cardsEditUnsavedBody =>
      'The edits to this dump have not been saved.';

  @override
  String get cardsEditNotEditable =>
      'Spectra cannot edit this card\'s format yet.';

  @override
  String get cardsPickerTitle => 'Choose a card';

  @override
  String get cardsLoadToSlot => 'Load into a slot';

  @override
  String cardsLoadTitle(int number) {
    return 'Load into slot $number';
  }

  @override
  String cardsLoadPrompt(String name, int number, String type) {
    return '$name will replace whatever slot $number holds on the $type side.';
  }

  @override
  String cardsLoadActivates(int number) {
    return 'Slot $number becomes the slot the device emulates.';
  }

  @override
  String cardsLoadOtherSenseStaysLive(int number, String sense, String type) {
    return 'Slot $number\'s $sense side already emulates $type; it stays enabled, so both sides will be live after this load.';
  }

  @override
  String get cardsLoadConfirm => 'Load';

  @override
  String get cardsLoadProgress => 'Writing the card into the slot…';

  @override
  String get cardsLoadVerifying => 'Checking what the device stored…';

  @override
  String cardsLoadDone(int number) {
    return 'Loaded into slot $number.';
  }

  @override
  String get cardsLoadUnsupported =>
      'Spectra cannot emulate this tag type yet.';

  @override
  String cardsLoadedToSlot(int number) {
    return 'Loaded into slot $number.';
  }

  @override
  String get cardsLoadUnreadSectorsTitle => 'Some sectors have no known key';

  @override
  String cardsLoadUnreadSectorsBody(int count, String sectors) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sectors $sectors were never read; they will load blank.',
      one: 'Sector $sectors was never read; it will load blank.',
    );
    return '$_temp0';
  }

  @override
  String get cardsLoadUnreadSectorsConfirm => 'Load anyway';

  @override
  String get cardsWriteToCard => 'Write to a card';

  @override
  String get cardsWriteTitle => 'Write to a card';

  @override
  String cardsWritePrompt(String name) {
    return 'Hold a writable blank against the back of the Chameleon, then write $name onto it.';
  }

  @override
  String get cardsWriteNotice =>
      'Writing to a physical card has not been checked on real hardware yet. Use a card you can afford to lose.';

  @override
  String get cardsWriteTrailersLabel =>
      'Also write sector keys and access bits';

  @override
  String get cardsWriteTrailersWarning =>
      'This rewrites the sector trailers (keys and access bits) and can lock the card.';

  @override
  String get cardsWriteConfirm => 'Write';

  @override
  String get cardsWriteProgress => 'Writing to the card…';

  @override
  String cardsWriteDone(int written, int attempted) {
    return '$written of $attempted blocks written.';
  }

  @override
  String get cardsWritePartial =>
      'Blocks that did not take the write are unchanged on the card.';

  @override
  String get cardsWriteUnsupported =>
      'Spectra cannot write this tag type onto a card yet.';

  @override
  String get cardsWriteCancelled =>
      'Write stopped. How much reached the card is unknown.';

  @override
  String get cardsWriteUnreadSectorsTitle => 'Some sectors have no known key';

  @override
  String cardsWriteUnreadSectorsBody(int count, String sectors) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Sectors $sectors have no recovered key; writing them puts zero keys on the card.',
      one:
          'Sector $sectors has no recovered key; writing it puts a zero key on the card.',
    );
    return '$_temp0';
  }

  @override
  String get cardsWriteUnreadSectorsConfirm => 'Write anyway';

  @override
  String get comingSoonSettings => 'Settings arrive in Phase 9.';

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
  String get updatePackageSection => 'Firmware package';

  @override
  String get updatePackagePathLabel => 'Package file';

  @override
  String get updatePackagePathHint => '/path/to/ultra-dfu-app.zip';

  @override
  String get updateLoadPackage => 'Load package';

  @override
  String updateReleasesHint(String url) {
    return 'Download a release package from $url, then load it here.';
  }

  @override
  String updatePackageSummary(String name, int images, int bytes) {
    String _temp0 = intl.Intl.pluralLogic(
      images,
      locale: localeName,
      other: '$images images',
      one: '1 image',
    );
    return '$name · $_temp0 · $bytes bytes';
  }

  @override
  String get updatePackageForUltra => 'Built for the Chameleon Ultra.';

  @override
  String get updatePackageForLite => 'Built for the Chameleon Lite.';

  @override
  String get updatePackageForUnknown =>
      'This package does not name a known model; the bootloader will decide.';

  @override
  String get updateStart => 'Install firmware';

  @override
  String get updateNoTarget =>
      'Connect a device, or choose a device in the bootloader on the connect screen.';

  @override
  String updateTargetConnected(String name) {
    return 'Updating $name.';
  }

  @override
  String get updateStepChecking => 'Checking the package';

  @override
  String get updateStepBootloader => 'Rebooting into the bootloader';

  @override
  String get updateStepFindingBootloader => 'Finding the bootloader';

  @override
  String get updateStepTransferring => 'Writing the firmware';

  @override
  String get updateStepFindingDevice => 'Waiting for the device';

  @override
  String get updateStepDone => 'Done';

  @override
  String get updateProgressLabel => 'Updating firmware';

  @override
  String updateProgressDetail(int sent, int total) {
    return '$sent of $total bytes';
  }

  @override
  String get updateSucceeded => 'Firmware installed.';

  @override
  String get updateDoNotDisconnect =>
      'Keep the device connected and powered until this finishes.';

  @override
  String get updateBleDisabled =>
      'Bluetooth updates are switched off in this build. Update over USB.';

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

  @override
  String get slotTagType => 'Tag type';

  @override
  String get slotChangeType => 'Change type';

  @override
  String get slotChooseType => 'Choose a tag type';

  @override
  String get slotPickerTitle => 'Choose a slot';

  @override
  String get slotClear => 'Clear';

  @override
  String get slotClearTitle => 'Clear this slot?';

  @override
  String slotClearBody(String sense) {
    return 'This removes the tag type and the emulated data on the $sense side. It cannot be undone.';
  }

  @override
  String get slotSaving => 'Saving to the device…';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get toolsDictionaries => 'Key dictionaries';

  @override
  String get toolsDictionariesSubtitle =>
      'Key lists used when reading and writing cards.';

  @override
  String get dictTitle => 'Key dictionaries';

  @override
  String get dictBuiltInName => 'Default keys';

  @override
  String get dictUnnamed => 'Untitled list';

  @override
  String get dictEmpty => 'No key lists of your own yet.';

  @override
  String dictKeyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count keys',
      one: '$count key',
      zero: 'No keys',
    );
    return '$_temp0';
  }

  @override
  String get dictInUse => 'Used for reading and writing';

  @override
  String get dictUse => 'Use these keys';

  @override
  String get dictNew => 'New list';

  @override
  String get dictNameTitle => 'Name this list';

  @override
  String get dictNameLabel => 'Name';

  @override
  String get dictNameConfirm => 'Save';
}
