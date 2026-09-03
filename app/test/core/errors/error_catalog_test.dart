import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/errors/app_failures.dart';
import 'package:spectra/core/errors/error_catalog.dart';
import 'package:spectra/core/errors/error_presentation.dart';
import 'package:spectra/l10n/app_localizations_en.dart';

/// Every error the SDK can raise, one instance each. `ChameleonException` is
/// sealed, so a missing entry here is caught by review, and a missing entry
/// in the catalog's switch is caught by the compiler.
final List<ChameleonException> everyError = <ChameleonException>[
  const MalformedResponse('bad payload'),
  CommandTimeout(1000, const Duration(seconds: 1)),
  const CommandCancelled(),
  const SessionNotReady('not ready'),
  BackgroundTaskFailed('boom', StackTrace.empty),
  const UnsupportedFirmware(UnsupportedReason.preTwoPointZero, 'old'),
  const ReaderUnavailable(),
  const Disconnected(),
  const PermissionDenied(),
  const PortBusy(),
  const DeviceNotFound(),
  const PairingRequired(),
  const AdapterOff(),
  DfuError('bad package'),
  const HfTagNotFound(),
  const HfTagError(HfTagErrorKind.crc, 0),
  const AuthenticationFailed(),
  const LfTagNotFound(),
  const LfLoginRequired(),
  const ParameterError(),
  const DeviceModeError(),
  const InvalidCommand(),
  const NotImplemented(),
  const FlashWriteFailed(),
  const FlashReadFailed(),
  const InvalidSlotType(),
  const MemoryError(),
  const CreateResponseError(),
  const CommandFailed(),
  UnknownDeviceError(0x99),
];

void main() {
  final catalog = ErrorCatalog(AppLocalizationsEn());

  test('every SDK error gets a message and a raw detail line', () {
    for (final error in everyError) {
      final p = catalog.describe(error);
      expect(p.message, isNotEmpty, reason: '${error.runtimeType}');
      expect(
        p.detail,
        contains(error.runtimeType.toString()),
        reason: '${error.runtimeType}',
      );
    }
  });

  test('recoverable transport problems name the right action', () {
    expect(
      catalog.describe(const PermissionDenied()).recovery,
      ErrorRecovery.openSettings,
    );
    expect(
      catalog.describe(const AdapterOff()).recovery,
      ErrorRecovery.openSettings,
    );
    expect(
      catalog.describe(const PairingRequired()).recovery,
      ErrorRecovery.platformInstructions,
    );
    expect(
      catalog.describe(const Disconnected()).recovery,
      ErrorRecovery.reconnect,
    );
    expect(
      catalog
          .describe(CommandTimeout(1000, const Duration(seconds: 1)))
          .recovery,
      ErrorRecovery.retry,
    );
    expect(
      catalog
          .describe(
            const UnsupportedFirmware(
              UnsupportedReason.legacyMustUpdate,
              'legacy',
            ),
          )
          .recovery,
      ErrorRecovery.update,
    );
    expect(
      catalog.describe(const CommandCancelled()).recovery,
      ErrorRecovery.none,
    );
  });

  test('an unsupported-firmware message says which kind of unsupported', () {
    final pre = catalog.describe(
      const UnsupportedFirmware(UnsupportedReason.preTwoPointZero, 'x'),
    );
    final newer = catalog.describe(
      const UnsupportedFirmware(UnsupportedReason.newerMajor, 'x'),
    );
    expect(pre.message, isNot(newer.message));
  });

  test('a non-SDK error still gets a message', () {
    final p = catalog.describe(StateError('nope'));
    expect(p.message, isNotEmpty);
    expect(p.detail, contains('nope'));
  });

  test('every TransportGuidance value has instruction text', () {
    for (final g in TransportGuidance.values) {
      expect(catalog.guidance(g), isNotEmpty, reason: g.name);
    }
  });

  test('an update with nothing to flash is retryable, and says so', () {
    final l10n = AppLocalizationsEn();
    final p = catalog.describe(const UpdateNoTarget());
    // TODO(phase-8 Task 9): its own copy, not errorDfu.
    expect(p.message, l10n.errorDfu);
    expect(p.recovery, ErrorRecovery.retry);
    expect(p.detail, contains('bootloader'));
  });

  test('a BLE update refused by the flag offers no retry', () {
    final l10n = AppLocalizationsEn();
    final p = catalog.describe(const UpdateBleDisabled());
    // TODO(phase-8 Task 9): its own copy, not errorDfu.
    expect(p.message, l10n.errorDfu);
    expect(p.recovery, ErrorRecovery.none);
    expect(p.detail, contains('dfuOverBleEnabled'));
  });

  test('a failed slot verification gets its own words', () {
    final l10n = AppLocalizationsEn();
    final p = catalog.describe(
      const SlotLoadVerificationFailed('the emulated blocks'),
    );
    expect(p.message, l10n.errorSlotVerify);
    expect(p.recovery, ErrorRecovery.retry);
    expect(p.detail, contains('the emulated blocks'));
  });

  test('a wrong-length dump gets its own words naming both lengths', () {
    final l10n = AppLocalizationsEn();
    const error = CardDumpLengthMismatch(
      type: TagType.mifare1k,
      expected: 1024,
      actual: 512,
    );
    final p = catalog.describe(error);
    expect(p.message, l10n.errorCardDumpLength('MIFARE Classic 1K', 1024, 512));
    expect(p.recovery, ErrorRecovery.none);
    expect(p.detail, contains('CardDumpLengthMismatch'));
  });
}
