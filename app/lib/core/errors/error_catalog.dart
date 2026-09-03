import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';

import '../../l10n/app_localizations.dart';
import 'error_presentation.dart';

/// Spec 9: the one place an error becomes words. Keyed by the sealed error
/// types, so a new SDK error is a compile error here rather than a silent
/// "something went wrong" in the UI.
final class ErrorCatalog {
  const ErrorCatalog(this._l10n);
  final AppLocalizations _l10n;

  ErrorPresentation describe(Object error) {
    if (error is! ChameleonException) {
      return ErrorPresentation(
        message: _l10n.errorUnexpected,
        recovery: ErrorRecovery.retry,
        detail: error.toString(),
      );
    }
    final (String message, ErrorRecovery recovery) = switch (error) {
      MalformedResponse() => (
        _l10n.errorMalformedResponse,
        ErrorRecovery.retry,
      ),
      CommandTimeout() => (_l10n.errorTimeout, ErrorRecovery.retry),
      CommandCancelled() => (_l10n.errorCancelled, ErrorRecovery.none),
      SessionNotReady() => (_l10n.errorNotReady, ErrorRecovery.reconnect),
      BackgroundTaskFailed() => (
        _l10n.errorBackgroundTask,
        ErrorRecovery.retry,
      ),
      UnsupportedFirmware(:final reason) => (
        switch (reason) {
          UnsupportedReason.preTwoPointZero => _l10n.errorFirmwareTooOld,
          UnsupportedReason.newerMajor => _l10n.errorFirmwareTooNew,
          UnsupportedReason.legacyMustUpdate => _l10n.errorFirmwareLegacy,
        },
        ErrorRecovery.update,
      ),
      ReaderUnavailable() => (_l10n.errorNoReader, ErrorRecovery.none),
      Disconnected() => (_l10n.errorDisconnected, ErrorRecovery.reconnect),
      PermissionDenied() => (
        _l10n.errorPermissionDenied,
        ErrorRecovery.openSettings,
      ),
      PortBusy() => (_l10n.errorPortBusy, ErrorRecovery.platformInstructions),
      DeviceNotFound() => (_l10n.errorDeviceNotFound, ErrorRecovery.retry),
      PairingRequired() => (
        _l10n.errorPairingRequired,
        ErrorRecovery.platformInstructions,
      ),
      AdapterOff() => (_l10n.errorAdapterOff, ErrorRecovery.openSettings),
      DfuError() => (_l10n.errorDfu, ErrorRecovery.retry),
      HfTagNotFound() => (_l10n.errorNoHfTag, ErrorRecovery.retry),
      HfTagError() => (_l10n.errorHfTag, ErrorRecovery.retry),
      AuthenticationFailed() => (_l10n.errorAuthFailed, ErrorRecovery.retry),
      LfTagNotFound() => (_l10n.errorNoLfTag, ErrorRecovery.retry),
      LfLoginRequired() => (_l10n.errorLfLoginRequired, ErrorRecovery.none),
      ParameterError() => (_l10n.errorParameter, ErrorRecovery.none),
      DeviceModeError() => (_l10n.errorDeviceMode, ErrorRecovery.retry),
      InvalidCommand() => (_l10n.errorInvalidCommand, ErrorRecovery.update),
      NotImplemented() => (_l10n.errorNotImplemented, ErrorRecovery.update),
      FlashWriteFailed() => (_l10n.errorFlashWrite, ErrorRecovery.retry),
      FlashReadFailed() => (_l10n.errorFlashRead, ErrorRecovery.retry),
      InvalidSlotType() => (_l10n.errorInvalidSlotType, ErrorRecovery.none),
      MemoryError() => (_l10n.errorMemory, ErrorRecovery.retry),
      CreateResponseError() => (_l10n.errorCreateResponse, ErrorRecovery.retry),
      CommandFailed() => (_l10n.errorCommandFailed, ErrorRecovery.retry),
      UnknownDeviceError(:final code) => (
        _l10n.errorUnknownStatus('0x${code.toRadixString(16)}'),
        ErrorRecovery.none,
      ),
    };
    return ErrorPresentation(
      message: message,
      recovery: recovery,
      detail: error.toString(),
    );
  }

  /// The platform-specific step behind [ErrorRecovery.platformInstructions]
  /// and [ErrorRecovery.openSettings]. `chameleon_flutter` ships the enum;
  /// the words live here (spec 7.6).
  ///
  /// No `default:` clause on purpose: a new [TransportGuidance] value must
  /// fail this switch at compile time rather than silently falling through.
  String guidance(TransportGuidance guidance) => switch (guidance) {
    TransportGuidance.androidBluetoothPermission =>
      _l10n.guidanceAndroidBluetoothPermission,
    TransportGuidance.applePairingPrompt => _l10n.guidanceApplePairingPrompt,
    TransportGuidance.applePermissionSettings =>
      _l10n.guidanceApplePermissionSettings,
    TransportGuidance.windowsPairDevice => _l10n.guidanceWindowsPairDevice,
    TransportGuidance.linuxPairFromSettings =>
      _l10n.guidanceLinuxPairFromSettings,
    TransportGuidance.bluetoothAdapterOff => _l10n.guidanceBluetoothAdapterOff,
    TransportGuidance.linuxSerialGroup => _l10n.guidanceLinuxSerialGroup,
    TransportGuidance.linuxModemManager => _l10n.guidanceLinuxModemManager,
    TransportGuidance.windowsPortAccessDenied =>
      _l10n.guidanceWindowsPortAccessDenied,
    TransportGuidance.macosSerialEntitlement =>
      _l10n.guidanceMacosSerialEntitlement,
    TransportGuidance.androidUsbPermission =>
      _l10n.guidanceAndroidUsbPermission,
    TransportGuidance.portBusyOther => _l10n.guidancePortBusyOther,
    TransportGuidance.portNotFound => _l10n.guidancePortNotFound,
  };
}
