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

  /// Shown when the slot read back after a load does not match the card.
  ///
  /// In en, this message translates to:
  /// **'The device stored something different from what Spectra sent.'**
  String get errorSlotVerify;

  /// Shown when a stored dump's length does not match the tag type it claims.
  ///
  /// In en, this message translates to:
  /// **'This dump is {actual} bytes, but a {type} needs {expected}.'**
  String errorCardDumpLength(String type, int expected, int actual);

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
  /// **'{read, plural, one {1 of {total} blocks could be read. Sectors with no known key are blank.} other {{read} of {total} blocks could be read. Sectors with no known key are blank.}}'**
  String cardsReadPartial(int read, int total);

  /// Shown for a tag with no readable dump format.
  ///
  /// In en, this message translates to:
  /// **'Spectra can show this card\'s identity but cannot read its memory yet.'**
  String get cardsReadIdentityOnly;

  /// How many sectors a working key was found for.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {Keys found for 1 sector.} other {Keys found for {count} sectors.}}'**
  String cardsReadKeysFound(int count);

  /// Names the key list a read will try.
  ///
  /// In en, this message translates to:
  /// **'Keys: {name}'**
  String cardsReadKeys(String name);

  /// Opens the key list picker from the read screen.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get cardsReadKeysChange;

  /// Saves the card that was just read.
  ///
  /// In en, this message translates to:
  /// **'Save to library'**
  String get cardsSaveToLibrary;

  /// Loads the card that was just read straight into a slot.
  ///
  /// In en, this message translates to:
  /// **'Emulate this card'**
  String get cardsEmulateThis;

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

  /// Accessible name of one colour swatch; the number is its position in the palette.
  ///
  /// In en, this message translates to:
  /// **'Colour {number}'**
  String cardsSaveColourSwatch(int number);

  /// Accessible name of the colour swatch that is currently chosen.
  ///
  /// In en, this message translates to:
  /// **'Colour {number}, selected'**
  String cardsSaveColourSwatchSelected(int number);

  /// Confirms the save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get cardsSaveConfirm;

  /// Warns, in the save sheet, that the dump about to be stored has gaps the reader could not fill.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 block could not be read. It is saved as zeros.} other {{count} blocks could not be read. They are saved as zeros.}}'**
  String cardsSavePartial(int count);

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

  /// Opens the import sheet from the library screen.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get cardsImport;

  /// Title of the import sheet.
  ///
  /// In en, this message translates to:
  /// **'Import cards'**
  String get cardsImportTitle;

  /// Explains what may be pasted.
  ///
  /// In en, this message translates to:
  /// **'Paste a card export from Spectra or from the Chameleon Ultra GUI.'**
  String get cardsImportHint;

  /// Label of the paste field.
  ///
  /// In en, this message translates to:
  /// **'Exported JSON'**
  String get cardsImportLabel;

  /// Confirms the import inside the sheet. Deliberately not the bare "Import" of cardsImport, which is the library screen's entry point: two different controls with the same word read as the same control.
  ///
  /// In en, this message translates to:
  /// **'Import cards'**
  String get cardsImportConfirm;

  /// Confirms how many cards were imported.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {Imported {count} card.} other {Imported {count} cards.}}'**
  String cardsImported(int count);

  /// The pasted text is not JSON.
  ///
  /// In en, this message translates to:
  /// **'That text is not a card export Spectra can read.'**
  String get cardsImportNotJson;

  /// The pasted export is empty.
  ///
  /// In en, this message translates to:
  /// **'That export has no cards in it.'**
  String get cardsImportNoCards;

  /// The export names a tag type with no dump format.
  ///
  /// In en, this message translates to:
  /// **'Spectra cannot read that tag type yet.'**
  String get cardsImportUnsupported;

  /// A card's data rows are not hex.
  ///
  /// In en, this message translates to:
  /// **'That export\'s card data could not be read.'**
  String get cardsImportBadBytes;

  /// Puts the card's export on the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy as JSON'**
  String get cardsExport;

  /// Confirms the export reached the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to the clipboard.'**
  String get cardsExported;

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

  /// Opens the sheet that edits a saved card's name, folder and colour.
  ///
  /// In en, this message translates to:
  /// **'Edit details'**
  String get cardsDetailEdit;

  /// Title of the sheet that edits a saved card's name, folder and colour.
  ///
  /// In en, this message translates to:
  /// **'Edit details'**
  String get cardsDetailEditTitle;

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
  /// **'{count, plural, one {{count} byte} other {{count} bytes}}'**
  String cardsDetailBytes(int count);

  /// Heading of the dump editor.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get cardsEditTitle;

  /// Label of the block-number field.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get cardsEditChunkLabelBlock;

  /// Label of the page-number field.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get cardsEditChunkLabelPage;

  /// Label of the LF id field.
  ///
  /// In en, this message translates to:
  /// **'Id'**
  String get cardsEditChunkLabelId;

  /// Label of the hex value field.
  ///
  /// In en, this message translates to:
  /// **'Bytes (hex)'**
  String get cardsEditValue;

  /// Applies the typed bytes to the working copy.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get cardsEditApply;

  /// The typed value is not a hex string.
  ///
  /// In en, this message translates to:
  /// **'That is not hex.'**
  String get cardsEditBadHex;

  /// The typed value is the wrong length. The unit is the lower-case chunk name (block, page, id) matching the field's own label.
  ///
  /// In en, this message translates to:
  /// **'This card takes {size} bytes per {unit}.'**
  String cardsEditBadLength(int size, String unit);

  /// The MIFARE Classic edit unit, mid-sentence and lower case.
  ///
  /// In en, this message translates to:
  /// **'block'**
  String get cardsEditChunkUnitBlock;

  /// The Ultralight edit unit, mid-sentence and lower case.
  ///
  /// In en, this message translates to:
  /// **'page'**
  String get cardsEditChunkUnitPage;

  /// The EM410x edit unit, mid-sentence and lower case.
  ///
  /// In en, this message translates to:
  /// **'id'**
  String get cardsEditChunkUnitId;

  /// The typed block or page number is out of range.
  ///
  /// In en, this message translates to:
  /// **'Choose a number between 0 and {last}.'**
  String cardsEditBadIndex(int last);

  /// Writes the edited dump back to the library.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get cardsEditSave;

  /// Throws the edits away and reloads the stored dump.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get cardsEditDiscard;

  /// Title of the unsaved-changes guard.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving?'**
  String get cardsEditUnsavedTitle;

  /// Body of the unsaved-changes guard.
  ///
  /// In en, this message translates to:
  /// **'The edits to this dump have not been saved.'**
  String get cardsEditUnsavedBody;

  /// Shown for a dump with no editable layout.
  ///
  /// In en, this message translates to:
  /// **'Spectra cannot edit this card\'s format yet.'**
  String get cardsEditNotEditable;

  /// Title of the card picker sheet other features open.
  ///
  /// In en, this message translates to:
  /// **'Choose a card'**
  String get cardsPickerTitle;

  /// Action on a saved card: put it into an emulation slot.
  ///
  /// In en, this message translates to:
  /// **'Load into a slot'**
  String get cardsLoadToSlot;

  /// Title of the load-to-slot sheet; the one-based slot number.
  ///
  /// In en, this message translates to:
  /// **'Load into slot {number}'**
  String cardsLoadTitle(int number);

  /// What loading will do, before it is confirmed.
  ///
  /// In en, this message translates to:
  /// **'{name} will replace whatever slot {number} holds on the {type} side.'**
  String cardsLoadPrompt(String name, int number, String type);

  /// Confirm-step note: loading makes the target slot active on the device; the previously active slot is not restored.
  ///
  /// In en, this message translates to:
  /// **'Slot {number} becomes the slot the device emulates.'**
  String cardsLoadActivates(int number);

  /// Confirm-step warning shown when the target slot's other sense already has a tag type enabled.
  ///
  /// In en, this message translates to:
  /// **'Slot {number}\'s {sense} side already emulates {type}; it stays enabled, so both sides will be live after this load.'**
  String cardsLoadOtherSenseStaysLive(int number, String sense, String type);

  /// Starts the load.
  ///
  /// In en, this message translates to:
  /// **'Load'**
  String get cardsLoadConfirm;

  /// Progress label while a slot is being loaded.
  ///
  /// In en, this message translates to:
  /// **'Writing the card into the slot…'**
  String get cardsLoadProgress;

  /// Progress label for the read-back at the end of a load.
  ///
  /// In en, this message translates to:
  /// **'Checking what the device stored…'**
  String get cardsLoadVerifying;

  /// Shown when a load finished and the read-back matched.
  ///
  /// In en, this message translates to:
  /// **'Loaded into slot {number}.'**
  String cardsLoadDone(int number);

  /// Shown for a tag type with no emulator write.
  ///
  /// In en, this message translates to:
  /// **'Spectra cannot emulate this tag type yet.'**
  String get cardsLoadUnsupported;

  /// Confirmation shown on the screen behind the sheet after a load.
  ///
  /// In en, this message translates to:
  /// **'Loaded into slot {number}.'**
  String cardsLoadedToSlot(int number);

  /// Heading of the unread-sector-trailer warning before a load.
  ///
  /// In en, this message translates to:
  /// **'Some sectors have no known key'**
  String get cardsLoadUnreadSectorsTitle;

  /// Names the sector trailers a saved dump has no recovered key for.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {Sector {sectors} was never read; it will load blank.} other {Sectors {sectors} were never read; they will load blank.}}'**
  String cardsLoadUnreadSectorsBody(int count, String sectors);

  /// Proceeds with a load despite the unread sectors.
  ///
  /// In en, this message translates to:
  /// **'Load anyway'**
  String get cardsLoadUnreadSectorsConfirm;

  /// Action on a saved card: put it onto a physical blank.
  ///
  /// In en, this message translates to:
  /// **'Write to a card'**
  String get cardsWriteToCard;

  /// Title of the write-to-card sheet.
  ///
  /// In en, this message translates to:
  /// **'Write to a card'**
  String get cardsWriteTitle;

  /// What writing will do, before it is confirmed.
  ///
  /// In en, this message translates to:
  /// **'Hold a writable blank against the back of the Chameleon, then write {name} onto it.'**
  String cardsWritePrompt(String name);

  /// Standing hardware-validation notice on the write sheet.
  ///
  /// In en, this message translates to:
  /// **'Writing to a physical card has not been checked on real hardware yet. Use a card you can afford to lose.'**
  String get cardsWriteNotice;

  /// Label of the opt-in toggle for writing sector trailers.
  ///
  /// In en, this message translates to:
  /// **'Also write sector keys and access bits'**
  String get cardsWriteTrailersLabel;

  /// Warning shown under the sector-trailers toggle.
  ///
  /// In en, this message translates to:
  /// **'This rewrites the sector trailers (keys and access bits) and can lock the card.'**
  String get cardsWriteTrailersWarning;

  /// Starts the write.
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get cardsWriteConfirm;

  /// Progress label while a card is being written.
  ///
  /// In en, this message translates to:
  /// **'Writing to the card…'**
  String get cardsWriteProgress;

  /// Summary after a write.
  ///
  /// In en, this message translates to:
  /// **'{written} of {attempted} blocks written.'**
  String cardsWriteDone(int written, int attempted);

  /// Extra line shown when some blocks were refused.
  ///
  /// In en, this message translates to:
  /// **'Blocks that did not take the write are unchanged on the card.'**
  String get cardsWritePartial;

  /// Shown for a tag type with no reader write.
  ///
  /// In en, this message translates to:
  /// **'Spectra cannot write this tag type onto a card yet.'**
  String get cardsWriteUnsupported;

  /// Shown when the user cancelled a write mid-flight.
  ///
  /// In en, this message translates to:
  /// **'Write stopped. How much reached the card is unknown.'**
  String get cardsWriteCancelled;

  /// Heading of the unread-sector-trailer warning before a write.
  ///
  /// In en, this message translates to:
  /// **'Some sectors have no known key'**
  String get cardsWriteUnreadSectorsTitle;

  /// Names the sector trailers a saved dump has no recovered key for.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {Sector {sectors} has no recovered key; writing it puts a zero key on the card.} other {Sectors {sectors} have no recovered key; writing them puts zero keys on the card.}}'**
  String cardsWriteUnreadSectorsBody(int count, String sectors);

  /// Proceeds with a write despite the unread sectors.
  ///
  /// In en, this message translates to:
  /// **'Write anyway'**
  String get cardsWriteUnreadSectorsConfirm;

  /// Placeholder body of the Settings tab.
  ///
  /// In en, this message translates to:
  /// **'Settings arrive in Phase 9.'**
  String get comingSoonSettings;

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

  /// Heading of the package-picking section.
  ///
  /// In en, this message translates to:
  /// **'Firmware package'**
  String get updatePackageSection;

  /// Label of the field taking a path to a DFU zip.
  ///
  /// In en, this message translates to:
  /// **'Package file'**
  String get updatePackagePathLabel;

  /// Placeholder in the package path field.
  ///
  /// In en, this message translates to:
  /// **'/path/to/ultra-dfu-app.zip'**
  String get updatePackagePathHint;

  /// Reads and validates the package at the typed path.
  ///
  /// In en, this message translates to:
  /// **'Load package'**
  String get updateLoadPackage;

  /// Where release zips come from; v1 has no in-app download.
  ///
  /// In en, this message translates to:
  /// **'Download a release package from {url}, then load it here.'**
  String updateReleasesHint(String url);

  /// Summary of the loaded package.
  ///
  /// In en, this message translates to:
  /// **'{name} · {images, plural, =1{1 image} other{{images} images}} · {bytes} bytes'**
  String updatePackageSummary(String name, int images, int bytes);

  /// Package hardware version 0.
  ///
  /// In en, this message translates to:
  /// **'Built for the Chameleon Ultra.'**
  String get updatePackageForUltra;

  /// Package hardware version 1.
  ///
  /// In en, this message translates to:
  /// **'Built for the Chameleon Lite.'**
  String get updatePackageForLite;

  /// Package hardware version is neither 0 nor 1.
  ///
  /// In en, this message translates to:
  /// **'This package does not name a known model; the bootloader will decide.'**
  String get updatePackageForUnknown;

  /// Starts the update.
  ///
  /// In en, this message translates to:
  /// **'Install firmware'**
  String get updateStart;

  /// Shown when there is nothing to update.
  ///
  /// In en, this message translates to:
  /// **'Connect a device, or choose a device in the bootloader on the connect screen.'**
  String get updateNoTarget;

  /// Names the connected device the update will flash.
  ///
  /// In en, this message translates to:
  /// **'Updating {name}.'**
  String updateTargetConnected(String name);

  /// DfuPhase.checking.
  ///
  /// In en, this message translates to:
  /// **'Checking the package'**
  String get updateStepChecking;

  /// DfuPhase.enteringBootloader.
  ///
  /// In en, this message translates to:
  /// **'Rebooting into the bootloader'**
  String get updateStepBootloader;

  /// DfuPhase.findingBootloader.
  ///
  /// In en, this message translates to:
  /// **'Finding the bootloader'**
  String get updateStepFindingBootloader;

  /// DfuPhase.transferring.
  ///
  /// In en, this message translates to:
  /// **'Writing the firmware'**
  String get updateStepTransferring;

  /// DfuPhase.findingDevice.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the device'**
  String get updateStepFindingDevice;

  /// DfuPhase.done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get updateStepDone;

  /// Label of the progress bar.
  ///
  /// In en, this message translates to:
  /// **'Updating firmware'**
  String get updateProgressLabel;

  /// Byte counter under the progress bar.
  ///
  /// In en, this message translates to:
  /// **'{sent} of {total} bytes'**
  String updateProgressDetail(int sent, int total);

  /// The update finished.
  ///
  /// In en, this message translates to:
  /// **'Firmware installed.'**
  String get updateSucceeded;

  /// Shown while a flash is running.
  ///
  /// In en, this message translates to:
  /// **'Keep the device connected and powered until this finishes.'**
  String get updateDoNotDisconnect;

  /// A BLE bootloader was chosen while dfuOverBleEnabled is off.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth updates are switched off in this build. Update over USB.'**
  String get updateBleDisabled;

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

  /// Dismisses a sheet that has finished.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// Tools entry that opens the key lists.
  ///
  /// In en, this message translates to:
  /// **'Key dictionaries'**
  String get toolsDictionaries;

  /// Subtitle of the Tools entry for key lists.
  ///
  /// In en, this message translates to:
  /// **'Key lists used when reading and writing cards.'**
  String get toolsDictionariesSubtitle;

  /// Title of the key lists screen.
  ///
  /// In en, this message translates to:
  /// **'Key dictionaries'**
  String get dictTitle;

  /// Name of the built-in, read-only key list.
  ///
  /// In en, this message translates to:
  /// **'Default keys'**
  String get dictBuiltInName;

  /// Name shown for a saved key list with no name.
  ///
  /// In en, this message translates to:
  /// **'Untitled list'**
  String get dictUnnamed;

  /// Shown when only the built-in list exists.
  ///
  /// In en, this message translates to:
  /// **'No key lists of your own yet.'**
  String get dictEmpty;

  /// How many keys a list holds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0 {No keys} one {{count} key} other {{count} keys}}'**
  String dictKeyCount(int count);

  /// Title of the key list picker sheet.
  ///
  /// In en, this message translates to:
  /// **'Choose a key list'**
  String get dictPickerTitle;

  /// Marks the list a read or write takes its keys from.
  ///
  /// In en, this message translates to:
  /// **'Used for reading and writing'**
  String get dictInUse;

  /// Selects a list as the one reads and writes use.
  ///
  /// In en, this message translates to:
  /// **'Use these keys'**
  String get dictUse;

  /// Creates an empty key list.
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get dictNew;

  /// Title of the sheet that names a key list.
  ///
  /// In en, this message translates to:
  /// **'Name this list'**
  String get dictNameTitle;

  /// Label of the key list name field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get dictNameLabel;

  /// Confirms a key list's name.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get dictNameConfirm;

  /// Shown when a key list route names a deleted list.
  ///
  /// In en, this message translates to:
  /// **'That key list no longer exists.'**
  String get dictNotFound;

  /// Section header above a list's keys.
  ///
  /// In en, this message translates to:
  /// **'Keys'**
  String get dictKeysTitle;

  /// Shown when a key list is empty.
  ///
  /// In en, this message translates to:
  /// **'This list has no keys yet.'**
  String get dictNoKeys;

  /// Adds a key to the list.
  ///
  /// In en, this message translates to:
  /// **'Add key'**
  String get dictAddKey;

  /// Label of the key entry field.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get dictKeyLabel;

  /// Hint under the key entry field.
  ///
  /// In en, this message translates to:
  /// **'12 hexadecimal characters'**
  String get dictKeyHint;

  /// The typed key is not a 6-byte key.
  ///
  /// In en, this message translates to:
  /// **'A key is 12 hexadecimal characters.'**
  String get dictKeyInvalid;

  /// The typed key is already stored.
  ///
  /// In en, this message translates to:
  /// **'That key is already in this list.'**
  String get dictKeyDuplicate;

  /// Removes one key from the list.
  ///
  /// In en, this message translates to:
  /// **'Remove key'**
  String get dictRemoveKey;

  /// Renames a key list.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get dictRename;

  /// Title of the rename sheet.
  ///
  /// In en, this message translates to:
  /// **'Rename this list'**
  String get dictRenameTitle;

  /// Copies a key list into an editable one.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get dictDuplicate;

  /// Title of the sheet that names a duplicated list.
  ///
  /// In en, this message translates to:
  /// **'Name the copy'**
  String get dictDuplicateTitle;

  /// Default name offered for a duplicated list.
  ///
  /// In en, this message translates to:
  /// **'{name} copy'**
  String dictDuplicateSuffix(String name);

  /// Explains why the built-in list cannot be edited.
  ///
  /// In en, this message translates to:
  /// **'Built in and read-only. Duplicate it to make a list you can edit.'**
  String get dictBuiltInNote;

  /// Deletes a key list.
  ///
  /// In en, this message translates to:
  /// **'Delete list'**
  String get dictDelete;

  /// Title of the delete confirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete this list?'**
  String get dictDeleteTitle;

  /// Body of the delete confirmation.
  ///
  /// In en, this message translates to:
  /// **'The keys in it are removed from Spectra. Cards and slots are untouched.'**
  String get dictDeleteBody;

  /// Opens the key list import sheet.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get dictImport;

  /// Title of the import sheet.
  ///
  /// In en, this message translates to:
  /// **'Import key lists'**
  String get dictImportTitle;

  /// Explains what may be pasted.
  ///
  /// In en, this message translates to:
  /// **'Paste a key list: one key per line, or a JSON export from Spectra or the reference app.'**
  String get dictImportHint;

  /// Label of the import text field.
  ///
  /// In en, this message translates to:
  /// **'Pasted text'**
  String get dictImportLabel;

  /// Runs the import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get dictImportConfirm;

  /// The pasted text is neither keys nor a known JSON shape.
  ///
  /// In en, this message translates to:
  /// **'That is not a key list Spectra can read.'**
  String get dictImportNotReadable;

  /// The paste parsed but held no keys.
  ///
  /// In en, this message translates to:
  /// **'There are no keys in that text.'**
  String get dictImportNoKeys;

  /// A key in the paste is malformed.
  ///
  /// In en, this message translates to:
  /// **'One of those keys is not 12 hexadecimal characters.'**
  String get dictImportBadKey;

  /// Confirms how many key lists were imported.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {Imported {count} list.} other {Imported {count} lists.}}'**
  String dictImported(int count);

  /// Copies a key list to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy list'**
  String get dictExport;

  /// Confirms the copy.
  ///
  /// In en, this message translates to:
  /// **'List copied to the clipboard.'**
  String get dictExported;
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
