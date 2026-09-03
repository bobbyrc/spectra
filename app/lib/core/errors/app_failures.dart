import 'package:chameleon/chameleon.dart';

/// The app's own typed failures (spec 9).
///
/// Not `ChameleonException`s: no transport reported them, the app concluded
/// them. `ErrorCatalog` handles each one ahead of its
/// `error is! ChameleonException` fallback, so they reach the user through
/// the same `ProblemView` as everything else instead of as "something
/// unexpected went wrong". `NoKnownDeviceVisible`
/// (`core/session/reconnect.dart`) is the same idea, kept next to the
/// provider that raises it.

/// A slot was written and read back, and what came back is not what went in.
///
/// [what] names the data that did not match ('the emulated blocks', 'the
/// stored id'), and is the whole of the raw detail line spec 9 puts one tap
/// away — the bytes themselves are not put in an error message.
final class SlotLoadVerificationFailed implements Exception {
  const SlotLoadVerificationFailed(this.what);

  final String what;

  @override
  String toString() =>
      'SlotLoadVerificationFailed: the device stored different $what';
}

/// `UpdateController.start` was asked to flash with no connected device and
/// no bootloader picked (the recovery entry) — nothing to flash.
///
/// Not a [DfuError]: `ErrorCatalog` collapses every `DfuError` to one
/// generic string, so a hand-written message here would never reach the
/// user. This gets its own catalog arm instead.
// TODO(phase-8 Task 9): dedicated copy instead of reusing errorDfu.
final class UpdateNoTarget implements Exception {
  const UpdateNoTarget();

  @override
  String toString() =>
      'UpdateNoTarget: connect a device, or choose one in the bootloader';
}

/// `UpdateController.start` was asked to flash a bootloader reached over
/// BLE while `dfuOverBleEnabled` is off (roadmap hardware handoff H2).
///
/// Same reasoning as [UpdateNoTarget]: a distinct type so the catalog (and
/// Task 9/10's copy) can tell this apart from every other `DfuError`.
// TODO(phase-8 Task 9): dedicated copy instead of reusing errorDfu.
final class UpdateBleDisabled implements Exception {
  const UpdateBleDisabled();

  @override
  String toString() =>
      'UpdateBleDisabled: Bluetooth firmware update is disabled until '
      'hardware handoff H2 passes (dfuOverBleEnabled)';
}

/// `DeviceSettingsController.setSleepTimeout` was asked for a value outside
/// the firmware's 5..60 second range.
///
/// The SDK's `SetSleepTimeout.encode` enforces the same bound with a raw
/// `ArgumentError`, which is not a `ChameleonException` — reusing it here
/// would fall through to the unexpected-error fallback. The controller
/// validates first with `isValidSleepTimeout`
/// (`features/settings/state/settings_labels.dart`) and raises this typed
/// failure instead, so the catalog has an arm for it.
final class SleepTimeoutOutOfRange implements Exception {
  const SleepTimeoutOutOfRange(this.seconds);

  final int seconds;

  @override
  String toString() =>
      'SleepTimeoutOutOfRange: $seconds is outside 5..60 seconds';
}

/// A stored dump's length does not match what [type] needs.
///
/// Raised before any device step, by the load-to-slot and write-to-card
/// controllers, when a saved dump was never valid for the type it claims —
/// not a device malfunction, so it gets its own words rather than the
/// unexpected-error fallback (ruling 4).
final class CardDumpLengthMismatch implements Exception {
  const CardDumpLengthMismatch({
    required this.type,
    required this.expected,
    required this.actual,
  });

  /// The tag type the dump was declared as.
  final TagType type;

  /// The byte length [type] needs.
  final int expected;

  /// The byte length the dump actually has.
  final int actual;

  @override
  String toString() =>
      'CardDumpLengthMismatch: $type expects $expected bytes, got $actual';
}
