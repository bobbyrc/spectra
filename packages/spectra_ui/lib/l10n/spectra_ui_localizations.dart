import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'spectra_ui_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of SpectraUiLocalizations
/// returned by `SpectraUiLocalizations.of(context)`.
///
/// Applications need to include `SpectraUiLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/spectra_ui_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: SpectraUiLocalizations.localizationsDelegates,
///   supportedLocales: SpectraUiLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the SpectraUiLocalizations.supportedLocales
/// property.
abstract class SpectraUiLocalizations {
  SpectraUiLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static SpectraUiLocalizations of(BuildContext context) {
    return Localizations.of<SpectraUiLocalizations>(
      context,
      SpectraUiLocalizations,
    )!;
  }

  static const LocalizationsDelegate<SpectraUiLocalizations> delegate =
      _SpectraUiLocalizationsDelegate();

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

  /// Expands a disclosure to its expert detail.
  ///
  /// In en, this message translates to:
  /// **'Show details'**
  String get disclosureShow;

  /// Collapses a disclosure back to its summary.
  ///
  /// In en, this message translates to:
  /// **'Hide details'**
  String get disclosureHide;

  /// Column header above the byte offsets.
  ///
  /// In en, this message translates to:
  /// **'Offset'**
  String get hexViewerOffsetHeader;

  /// Column header above the ASCII gutter.
  ///
  /// In en, this message translates to:
  /// **'ASCII'**
  String get hexViewerAsciiHeader;

  /// Shown when a hex viewer is given zero bytes.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get hexViewerEmpty;

  /// Semantics summary announced for the whole hex viewer.
  ///
  /// In en, this message translates to:
  /// **'{count} bytes'**
  String hexViewerSummary(int count);

  /// A slot with no tag configured.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get slotTileEmpty;

  /// A slot that exists but is switched off.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get slotTileDisabled;

  /// The slot the device is currently emulating.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get slotTileActive;

  /// Names a slot by its one-based number.
  ///
  /// In en, this message translates to:
  /// **'Slot {number}'**
  String slotLabel(int number);

  /// Connection status chip label.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get statusConnected;

  /// Connection status chip label.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get statusConnecting;

  /// Connection status chip label.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get statusDisconnected;

  /// Connected but only firmware update is possible.
  ///
  /// In en, this message translates to:
  /// **'Limited'**
  String get statusLimited;

  /// A firmware update is in progress.
  ///
  /// In en, this message translates to:
  /// **'Updating'**
  String get statusUpdating;

  /// Battery charge as a percentage.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String batteryLevel(int percent);

  /// Battery charge while on external power.
  ///
  /// In en, this message translates to:
  /// **'{percent}% charging'**
  String batteryCharging(int percent);

  /// Position within a multi-step operation.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String stepProgress(int current, int total);

  /// Cancels a dialog, sheet or long operation.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Confirms a dialog.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get confirm;

  /// Closes a bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Default error text on an empty required input.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredField;
}

class _SpectraUiLocalizationsDelegate
    extends LocalizationsDelegate<SpectraUiLocalizations> {
  const _SpectraUiLocalizationsDelegate();

  @override
  Future<SpectraUiLocalizations> load(Locale locale) {
    return SynchronousFuture<SpectraUiLocalizations>(
      lookupSpectraUiLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_SpectraUiLocalizationsDelegate old) => false;
}

SpectraUiLocalizations lookupSpectraUiLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SpectraUiLocalizationsEn();
  }

  throw FlutterError(
    'SpectraUiLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
