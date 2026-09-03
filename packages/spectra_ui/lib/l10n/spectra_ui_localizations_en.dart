// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'spectra_ui_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SpectraUiLocalizationsEn extends SpectraUiLocalizations {
  SpectraUiLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get disclosureShow => 'Show details';

  @override
  String get disclosureHide => 'Hide details';

  @override
  String get hexViewerOffsetHeader => 'Offset';

  @override
  String get hexViewerAsciiHeader => 'ASCII';

  @override
  String get hexViewerEmpty => 'No data';

  @override
  String get slotTileEmpty => 'Empty';

  @override
  String get slotTileDisabled => 'Disabled';

  @override
  String get slotTileActive => 'Active';

  @override
  String slotLabel(int number) {
    return 'Slot $number';
  }

  @override
  String get statusConnected => 'Connected';

  @override
  String get statusConnecting => 'Connecting';

  @override
  String get statusDisconnected => 'Disconnected';

  @override
  String get statusLimited => 'Limited';

  @override
  String get statusUpdating => 'Updating';

  @override
  String batteryLevel(int percent) {
    return '$percent%';
  }

  @override
  String batteryCharging(int percent) {
    return '$percent% charging';
  }

  @override
  String stepProgress(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'OK';

  @override
  String get close => 'Close';

  @override
  String get requiredField => 'Required';
}
