import 'package:chameleon/chameleon.dart';

// TODO(phase-9 Task 11): move these to ARB (app/lib/l10n/app_en.arb) once
// Task 11 lands the settingsAnimation*/settingsButton* keys; app/lib/l10n
// is single-writer and owned by another implementer while this task runs,
// so `animationLabel`/`buttonFunctionLabel` return literal English strings
// instead of taking an `AppLocalizations` and calling its getters.

/// How the SDK's settings enums become words. Both switches are exhaustive,
/// so a value added to the SDK is a compile error here rather than a blank
/// row in the settings screen.
String animationLabel(AnimationMode mode) => switch (mode) {
  AnimationMode.full => 'Full',
  AnimationMode.minimal => 'Minimal',
  AnimationMode.none => 'None',
  AnimationMode.symmetric => 'Symmetric',
};

String buttonFunctionLabel(ButtonFunction fn) => switch (fn) {
  ButtonFunction.none => 'None',
  ButtonFunction.nextSlot => 'Next slot',
  ButtonFunction.prevSlot => 'Previous slot',
  ButtonFunction.cloneUid => 'Clone UID',
  ButtonFunction.battery => 'Show battery',
  ButtonFunction.nfcFieldGenerator => 'NFC field detector',
};

final RegExp _sixDigits = RegExp(r'^[0-9]{6}$');

/// The firmware's BLE pairing passkey is exactly six ASCII digits
/// (`docs/research/chameleon-protocol.md`, command 1030).
bool isValidPairingKey(String key) => _sixDigits.hasMatch(key);
