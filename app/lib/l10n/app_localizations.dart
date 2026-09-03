import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// The application name, shown as the window title.
  ///
  /// In en, this message translates to:
  /// **'Spectra'**
  String get appTitle;

  /// A response payload did not match the expected shape.
  ///
  /// In en, this message translates to:
  /// **'The device sent a reply Spectra could not read.'**
  String get errorMalformedResponse;

  /// A command timed out.
  ///
  /// In en, this message translates to:
  /// **'The device did not answer in time.'**
  String get errorTimeout;

  /// The user cancelled a long operation.
  ///
  /// In en, this message translates to:
  /// **'Cancelled.'**
  String get errorCancelled;

  /// A command was attempted with no ready session.
  ///
  /// In en, this message translates to:
  /// **'That needs a connected device.'**
  String get errorNotReady;

  /// An unexpected failure in a background task.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong in the background.'**
  String get errorBackgroundTask;

  /// Firmware predates the supported protocol.
  ///
  /// In en, this message translates to:
  /// **'This firmware is older than 2.0. Update it to use Spectra.'**
  String get errorFirmwareTooOld;

  /// Firmware major version is above the supported one.
  ///
  /// In en, this message translates to:
  /// **'This firmware is newer than Spectra supports. Update Spectra.'**
  String get errorFirmwareTooNew;

  /// The legacy 0.1 firmware, which only supports an update.
  ///
  /// In en, this message translates to:
  /// **'This device runs the legacy 0.1 firmware and must be updated.'**
  String get errorFirmwareLegacy;

  /// A reader command on a Chameleon Lite.
  ///
  /// In en, this message translates to:
  /// **'This device has no card reader.'**
  String get errorNoReader;

  /// The transport closed unexpectedly.
  ///
  /// In en, this message translates to:
  /// **'The connection to the device was lost.'**
  String get errorDisconnected;

  /// Bluetooth or serial permission was refused.
  ///
  /// In en, this message translates to:
  /// **'Spectra needs permission to reach the device.'**
  String get errorPermissionDenied;

  /// A serial port is held by another process.
  ///
  /// In en, this message translates to:
  /// **'That port is in use by another program.'**
  String get errorPortBusy;

  /// The device disappeared before it could be opened.
  ///
  /// In en, this message translates to:
  /// **'Spectra could not find that device.'**
  String get errorDeviceNotFound;

  /// BLE pairing is required before use.
  ///
  /// In en, this message translates to:
  /// **'This device has to be paired first.'**
  String get errorPairingRequired;

  /// The Bluetooth adapter is powered off.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is switched off.'**
  String get errorAdapterOff;

  /// A failure inside the DFU stack.
  ///
  /// In en, this message translates to:
  /// **'The firmware update could not be completed.'**
  String get errorDfu;

  /// An HF scan found nothing.
  ///
  /// In en, this message translates to:
  /// **'No high-frequency card was found. Hold the card against the device.'**
  String get errorNoHfTag;

  /// An HF communication error such as CRC or collision.
  ///
  /// In en, this message translates to:
  /// **'The card did not answer cleanly. Try holding it steady.'**
  String get errorHfTag;

  /// MIFARE authentication failed.
  ///
  /// In en, this message translates to:
  /// **'That key was rejected by the card.'**
  String get errorAuthFailed;

  /// An LF scan found nothing.
  ///
  /// In en, this message translates to:
  /// **'No low-frequency card was found.'**
  String get errorNoLfTag;

  /// The LF tag requires a login.
  ///
  /// In en, this message translates to:
  /// **'This card needs a password before it can be read.'**
  String get errorLfLoginRequired;

  /// The firmware reported a parameter error.
  ///
  /// In en, this message translates to:
  /// **'The device rejected that value.'**
  String get errorParameter;

  /// Reader/emulator mode mismatch.
  ///
  /// In en, this message translates to:
  /// **'The device is in the wrong mode for that.'**
  String get errorDeviceMode;

  /// The firmware refused an unknown command.
  ///
  /// In en, this message translates to:
  /// **'This firmware does not support that action.'**
  String get errorInvalidCommand;

  /// The firmware reported not-implemented.
  ///
  /// In en, this message translates to:
  /// **'That is not implemented on this firmware yet.'**
  String get errorNotImplemented;

  /// A flash write failure.
  ///
  /// In en, this message translates to:
  /// **'Writing to the device\'s storage failed.'**
  String get errorFlashWrite;

  /// A flash read failure.
  ///
  /// In en, this message translates to:
  /// **'Reading the device\'s storage failed.'**
  String get errorFlashRead;

  /// The firmware rejected the slot tag type.
  ///
  /// In en, this message translates to:
  /// **'That tag type cannot go in this slot.'**
  String get errorInvalidSlotType;

  /// The firmware reported a memory error.
  ///
  /// In en, this message translates to:
  /// **'The device ran out of memory.'**
  String get errorMemory;

  /// The firmware failed to create a response.
  ///
  /// In en, this message translates to:
  /// **'The device could not build a reply.'**
  String get errorCreateResponse;

  /// A generic command failure.
  ///
  /// In en, this message translates to:
  /// **'The device could not carry that out.'**
  String get errorCommandFailed;

  /// A status code the SDK does not recognise.
  ///
  /// In en, this message translates to:
  /// **'The device reported an unknown status ({code}).'**
  String errorUnknownStatus(String code);

  /// Shown when "Reconnect to last device" finds nothing to reconnect to.
  ///
  /// In en, this message translates to:
  /// **'No known device is visible. Wake the device or plug it in, then try again.'**
  String get errorNoKnownDeviceVisible;

  /// Fallback for an error that is not from the SDK.
  ///
  /// In en, this message translates to:
  /// **'Something unexpected went wrong.'**
  String get errorUnexpected;

  /// Android 12+ Bluetooth permission instructions.
  ///
  /// In en, this message translates to:
  /// **'Open Android settings and allow Spectra to find and connect to nearby devices.'**
  String get guidanceAndroidBluetoothPermission;

  /// iOS and macOS pairing instructions.
  ///
  /// In en, this message translates to:
  /// **'Accept the pairing prompt when it appears.'**
  String get guidanceApplePairingPrompt;

  /// iOS/macOS Bluetooth permission was denied; enable it in Settings.
  ///
  /// In en, this message translates to:
  /// **'Allow Bluetooth for Spectra in System Settings, then try again.'**
  String get guidanceApplePermissionSettings;

  /// Windows pairing instructions.
  ///
  /// In en, this message translates to:
  /// **'Pair the Chameleon in Windows Bluetooth settings, then try again.'**
  String get guidanceWindowsPairDevice;

  /// Linux BlueZ pairing instructions.
  ///
  /// In en, this message translates to:
  /// **'Pair the Chameleon from your system Bluetooth settings using the device\'s passkey, then try again.'**
  String get guidanceLinuxPairFromSettings;

  /// Adapter is powered off.
  ///
  /// In en, this message translates to:
  /// **'Switch Bluetooth on, then scan again.'**
  String get guidanceBluetoothAdapterOff;

  /// Linux serial permission instructions.
  ///
  /// In en, this message translates to:
  /// **'Add your user to the dialout group, or install the Chameleon udev rule, then reconnect the cable.'**
  String get guidanceLinuxSerialGroup;

  /// Linux port-busy instructions.
  ///
  /// In en, this message translates to:
  /// **'ModemManager is holding the port. Stop it, or add the Chameleon to its ignore list, then reconnect.'**
  String get guidanceLinuxModemManager;

  /// Windows serial access-denied instructions.
  ///
  /// In en, this message translates to:
  /// **'Close any other program using the COM port, then try again.'**
  String get guidanceWindowsPortAccessDenied;

  /// macOS serial entitlement instructions.
  ///
  /// In en, this message translates to:
  /// **'Allow Spectra to use USB devices when macOS asks, then try again.'**
  String get guidanceMacosSerialEntitlement;

  /// Android USB permission instructions.
  ///
  /// In en, this message translates to:
  /// **'Allow Spectra to use the USB device when Android asks.'**
  String get guidanceAndroidUsbPermission;

  /// A port is busy on a platform with no more specific hint.
  ///
  /// In en, this message translates to:
  /// **'Another app is using this port. Close it and try again.'**
  String get guidancePortBusyOther;

  /// The named serial port no longer exists.
  ///
  /// In en, this message translates to:
  /// **'That port is gone. Reconnect the cable and scan again.'**
  String get guidancePortNotFound;

  /// Top-level destination: the device dashboard.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get navDevice;

  /// Top-level destination: emulation slots.
  ///
  /// In en, this message translates to:
  /// **'Slots'**
  String get navSlots;

  /// Top-level destination: the saved card library.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get navCards;

  /// Top-level destination: update, dictionaries, frame log.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get navTools;

  /// Top-level destination: app and device settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Heading of the full-screen connect route.
  ///
  /// In en, this message translates to:
  /// **'Connect a device'**
  String get connectTitle;

  /// Heading of the slots grid.
  ///
  /// In en, this message translates to:
  /// **'Slots'**
  String get slotsTitle;

  /// Shown on the slots screen with no session.
  ///
  /// In en, this message translates to:
  /// **'Connect a device to see its slots.'**
  String get slotsEmpty;

  /// Title of the slot editor; the device's one-based slot number.
  ///
  /// In en, this message translates to:
  /// **'Slot {number}'**
  String slotDetailTitle(int number);

  /// Shown when a slot route names an index the device does not have.
  ///
  /// In en, this message translates to:
  /// **'That slot does not exist.'**
  String get slotNotFound;

  /// Marks the slot the device is emulating.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get slotActive;

  /// Button that switches the device to this slot.
  ///
  /// In en, this message translates to:
  /// **'Make active'**
  String get slotMakeActive;

  /// Shown on a slot the device is not currently emulating.
  ///
  /// In en, this message translates to:
  /// **'Not the active slot'**
  String get slotInactive;

  /// Label of the per-sense enable switch.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get slotEnabled;

  /// Label of the slot nickname field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get slotNameLabel;

  /// Sends the edited slot nickname to the device.
  ///
  /// In en, this message translates to:
  /// **'Save name'**
  String get slotSaveName;

  /// Title of the read-a-card screen.
  ///
  /// In en, this message translates to:
  /// **'Card reader'**
  String get cardsReadTitle;

  /// Opens the read screen from the card library.
  ///
  /// In en, this message translates to:
  /// **'Read a card'**
  String get cardsReadAction;

  /// Instruction shown before a scan starts.
  ///
  /// In en, this message translates to:
  /// **'Hold the card flat against the back of the Chameleon, then choose a frequency.'**
  String get cardsReadHint;

  /// Starts a 13.56 MHz scan.
  ///
  /// In en, this message translates to:
  /// **'Scan high frequency'**
  String get cardsReadHf;

  /// Starts a 125 kHz scan.
  ///
  /// In en, this message translates to:
  /// **'Scan low frequency'**
  String get cardsReadLf;

  /// Progress label while the field is being scanned.
  ///
  /// In en, this message translates to:
  /// **'Looking for a card…'**
  String get cardsReadScanning;

  /// Progress label while a full dump is being read.
  ///
  /// In en, this message translates to:
  /// **'Reading the card…'**
  String get cardsReadDumping;

  /// Clears the result and returns to the idle screen.
  ///
  /// In en, this message translates to:
  /// **'Read again'**
  String get cardsReadAgain;

  /// Explains a partial dump.
  ///
  /// In en, this message translates to:
  /// **'{read} of {total} blocks could be read. Sectors with no known key are blank.'**
  String cardsReadPartial(int read, int total);

  /// Shown for a tag with no readable dump format.
  ///
  /// In en, this message translates to:
  /// **'Spectra can show this card\'s identity but cannot read its memory yet.'**
  String get cardsReadIdentityOnly;

  /// How many sectors a working key was found for.
  ///
  /// In en, this message translates to:
  /// **'Keys found for {count} sectors.'**
  String cardsReadKeysFound(int count);

  /// Saves the card that was just read.
  ///
  /// In en, this message translates to:
  /// **'Save to library'**
  String get cardsSaveToLibrary;

  /// Title of the save-to-library sheet.
  ///
  /// In en, this message translates to:
  /// **'Save this card'**
  String get cardsSaveTitle;

  /// Label of the card name field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get cardsSaveName;

  /// Label of the optional folder field.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get cardsSaveFolder;

  /// Example folder name.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get cardsSaveFolderHint;

  /// Label above the colour swatches.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get cardsSaveColour;

  /// Confirms the save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get cardsSaveConfirm;

  /// Validation message under an empty name field.
  ///
  /// In en, this message translates to:
  /// **'Give the card a name.'**
  String get cardsSaveNameRequired;

  /// Confirms a card reached the library.
  ///
  /// In en, this message translates to:
  /// **'Saved to the library.'**
  String get cardsSaved;

  /// Heading of the card library.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get cardsTitle;

  /// Shown when the library has no cards at all.
  ///
  /// In en, this message translates to:
  /// **'No cards yet. Read one, or import from another app.'**
  String get cardsEmpty;

  /// Shown when the filter hides every card.
  ///
  /// In en, this message translates to:
  /// **'No cards match that search.'**
  String get cardsNoMatches;

  /// Label of the library search field.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get cardsSearch;

  /// Folder filter entry that clears the filter.
  ///
  /// In en, this message translates to:
  /// **'All folders'**
  String get cardsAllFolders;

  /// Sorts the library by last change.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get cardsSortRecent;

  /// Sorts the library alphabetically.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get cardsSortName;

  /// Second line of a library row when the card has a folder: the tag type and folder.
  ///
  /// In en, this message translates to:
  /// **'{tagType} · {folder}'**
  String cardsSubtitle(String tagType, String folder);

  /// Second line of a library row when the card has no folder (ruling 20: no dangling separator).
  ///
  /// In en, this message translates to:
  /// **'{tagType}'**
  String cardsSubtitleNoFolder(String tagType);

  /// Shown when a card route names an id that is gone.
  ///
  /// In en, this message translates to:
  /// **'That card is not in the library.'**
  String get cardsDetailNotFound;

  /// Removes a card from the library.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get cardsDetailDelete;

  /// Title of the delete confirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete this card?'**
  String get cardsDetailDeleteTitle;

  /// Body of the delete confirmation.
  ///
  /// In en, this message translates to:
  /// **'The saved dump is removed from Spectra. The physical card is not touched.'**
  String get cardsDetailDeleteBody;

  /// Lists the validation problems of a stored dump.
  ///
  /// In en, this message translates to:
  /// **'This dump has problems: {problems}'**
  String cardsDetailProblems(String problems);

  /// Size of the stored dump.
  ///
  /// In en, this message translates to:
  /// **'{count} bytes'**
  String cardsDetailBytes(int count);

  /// Placeholder body of the Settings tab.
  ///
  /// In en, this message translates to:
  /// **'Settings arrive in Phase 9.'**
  String get comingSoonSettings;

  /// Placeholder body of the update screen.
  ///
  /// In en, this message translates to:
  /// **'Firmware update arrives in Phase 8.'**
  String get comingSoonUpdate;

  /// Heading of the Tools tab.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get toolsTitle;

  /// Tools entry opening the frame log.
  ///
  /// In en, this message translates to:
  /// **'Frame log'**
  String get toolsFrameLog;

  /// Explains what the frame log is.
  ///
  /// In en, this message translates to:
  /// **'Everything sent to and received from the device.'**
  String get toolsFrameLogSubtitle;

  /// Tools entry opening the firmware update screen.
  ///
  /// In en, this message translates to:
  /// **'Firmware update'**
  String get toolsUpdate;

  /// Heading of the frame log screen.
  ///
  /// In en, this message translates to:
  /// **'Frame log'**
  String get frameLogTitle;

  /// Heading of the firmware update screen.
  ///
  /// In en, this message translates to:
  /// **'Firmware update'**
  String get updateTitle;

  /// Shown when the frame log has no entries.
  ///
  /// In en, this message translates to:
  /// **'No frames yet. Connect a device and the log fills up.'**
  String get frameLogEmpty;

  /// Copies the whole frame log to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get frameLogCopy;

  /// Confirms the frame log reached the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Frame log copied.'**
  String get frameLogCopied;

  /// Names the bootloader a recovery was started for.
  ///
  /// In en, this message translates to:
  /// **'Recovering the device at {transportId}.'**
  String updateRecoverTarget(String transportId);

  /// Spec 5.6 recovery instructions.
  ///
  /// In en, this message translates to:
  /// **'If the device is not listed, hold button B while plugging in the USB cable to enter the bootloader from any state.'**
  String get updateRecoverInstructions;

  /// Shown while dfuOverBleEnabled is false.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth firmware update is pending hardware validation and is switched off in this build.'**
  String get updateBleNotice;

  /// Heading of the device dashboard.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get dashboardTitle;

  /// One-line explanation under the connect heading.
  ///
  /// In en, this message translates to:
  /// **'Choose a Chameleon to connect to.'**
  String get connectSubtitle;

  /// Shown while the first scan is running.
  ///
  /// In en, this message translates to:
  /// **'Looking for devices…'**
  String get connectScanning;

  /// Empty-scan hint covering the device's sleep behaviour (spec 5.1).
  ///
  /// In en, this message translates to:
  /// **'No devices found. Over Bluetooth, press a button on the device to wake it — it sleeps eight seconds after losing a connection.'**
  String get connectNothingFound;

  /// Button that reopens the most recently used device.
  ///
  /// In en, this message translates to:
  /// **'Reconnect to last device'**
  String get connectReconnectLast;

  /// Progress label while a session is opening.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connectConnecting;

  /// Action on a device sitting in its bootloader.
  ///
  /// In en, this message translates to:
  /// **'Recover'**
  String get connectRecover;

  /// Marks a device that is in DFU mode.
  ///
  /// In en, this message translates to:
  /// **'In bootloader'**
  String get connectBootloaderBadge;

  /// Transport badge for a USB connection.
  ///
  /// In en, this message translates to:
  /// **'USB'**
  String get connectKindUsb;

  /// Transport badge for a Bluetooth connection.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get connectKindBle;

  /// Transport badge for the emulated device.
  ///
  /// In en, this message translates to:
  /// **'Emulated'**
  String get connectKindFake;

  /// Heading of the manual port entry on desktop.
  ///
  /// In en, this message translates to:
  /// **'Add a serial port'**
  String get connectManualPortTitle;

  /// Label of the manual serial port field.
  ///
  /// In en, this message translates to:
  /// **'Port path'**
  String get connectManualPortLabel;

  /// Example serial port path.
  ///
  /// In en, this message translates to:
  /// **'/dev/cu.usbmodem1'**
  String get connectManualPortHint;

  /// Confirms a manually typed port.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get connectManualPortAdd;

  /// Retries the failed action.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonRetry;

  /// Sends the user to system settings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get commonOpenSettings;

  /// Reveals the raw error line.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get commonDetails;

  /// Opens the firmware update screen.
  ///
  /// In en, this message translates to:
  /// **'Update firmware'**
  String get commonUpdateFirmware;

  /// Closes the session with the connected device.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get dashboardDisconnect;

  /// Label for the device model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get dashboardModel;

  /// Label for the running firmware version.
  ///
  /// In en, this message translates to:
  /// **'Firmware'**
  String get dashboardFirmware;

  /// Label for the firmware git version string.
  ///
  /// In en, this message translates to:
  /// **'Build'**
  String get dashboardGitVersion;

  /// Label for the device's unique chip identifier.
  ///
  /// In en, this message translates to:
  /// **'Chip ID'**
  String get dashboardChipId;

  /// Label for the device's BLE address.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth address'**
  String get dashboardBleAddress;

  /// Label for the slot the device is emulating.
  ///
  /// In en, this message translates to:
  /// **'Active slot'**
  String get dashboardActiveSlot;

  /// Chip label when the device is in reader mode.
  ///
  /// In en, this message translates to:
  /// **'Reader mode'**
  String get dashboardModeReader;

  /// Chip label when the device is emulating.
  ///
  /// In en, this message translates to:
  /// **'Emulator mode'**
  String get dashboardModeEmulator;

  /// Display name of the Ultra.
  ///
  /// In en, this message translates to:
  /// **'Chameleon Ultra'**
  String get dashboardModelUltra;

  /// Display name of the Lite.
  ///
  /// In en, this message translates to:
  /// **'Chameleon Lite'**
  String get dashboardModelLite;

  /// Placeholder for a value the device has not reported.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get dashboardUnknown;

  /// Heading of the reduced dashboard.
  ///
  /// In en, this message translates to:
  /// **'This device needs a firmware update'**
  String get dashboardLimitedTitle;

  /// Shown where a slot sense has no tag type set.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get slotTypeEmpty;

  /// The 13.56 MHz side of a slot.
  ///
  /// In en, this message translates to:
  /// **'High frequency'**
  String get slotSenseHf;

  /// The 125 kHz side of a slot.
  ///
  /// In en, this message translates to:
  /// **'Low frequency'**
  String get slotSenseLf;

  /// Validation message under the slot name field.
  ///
  /// In en, this message translates to:
  /// **'Names are limited to 32 bytes.'**
  String get slotNicknameTooLong;

  /// Label of the row showing a sense's tag type.
  ///
  /// In en, this message translates to:
  /// **'Tag type'**
  String get slotTagType;

  /// Opens the tag type picker for one sense.
  ///
  /// In en, this message translates to:
  /// **'Change type'**
  String get slotChangeType;

  /// Title of the tag type sheet.
  ///
  /// In en, this message translates to:
  /// **'Choose a tag type'**
  String get slotChooseType;

  /// Title of the slot picker sheet other features open.
  ///
  /// In en, this message translates to:
  /// **'Choose a slot'**
  String get slotPickerTitle;

  /// Empties one sense of a slot.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get slotClear;

  /// Title of the clear-sense confirmation.
  ///
  /// In en, this message translates to:
  /// **'Clear this slot?'**
  String get slotClearTitle;

  /// Body of the clear-sense confirmation; the sense's name.
  ///
  /// In en, this message translates to:
  /// **'This removes the tag type and the emulated data on the {sense} side. It cannot be undone.'**
  String slotClearBody(String sense);

  /// Progress label while a slot change is in flight.
  ///
  /// In en, this message translates to:
  /// **'Saving to the device…'**
  String get slotSaving;

  /// Dismisses a dialog without acting.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
