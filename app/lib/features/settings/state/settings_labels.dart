import 'package:chameleon/chameleon.dart';

import '../../../l10n/app_localizations.dart';

/// How the SDK's settings enums become words. Both switches are exhaustive,
/// so a value added to the SDK is a compile error here rather than a blank
/// row in the settings screen.
String animationLabel(AnimationMode mode, AppLocalizations l10n) =>
    switch (mode) {
      AnimationMode.full => l10n.settingsAnimationFull,
      AnimationMode.minimal => l10n.settingsAnimationMinimal,
      AnimationMode.none => l10n.settingsAnimationNone,
      AnimationMode.symmetric => l10n.settingsAnimationSymmetric,
    };

String buttonFunctionLabel(ButtonFunction fn, AppLocalizations l10n) =>
    switch (fn) {
      ButtonFunction.none => l10n.settingsButtonNone,
      ButtonFunction.nextSlot => l10n.settingsButtonNextSlot,
      ButtonFunction.prevSlot => l10n.settingsButtonPrevSlot,
      ButtonFunction.cloneUid => l10n.settingsButtonCloneUid,
      ButtonFunction.battery => l10n.settingsButtonBattery,
      ButtonFunction.nfcFieldGenerator => l10n.settingsButtonField,
    };

final RegExp _sixDigits = RegExp(r'^[0-9]{6}$');

/// The firmware's BLE pairing passkey is exactly six ASCII digits
/// (`docs/research/chameleon-protocol.md`, command 1030).
bool isValidPairingKey(String key) => _sixDigits.hasMatch(key);

/// The firmware's sleep-timeout bounds, inclusive
/// (`docs/research/chameleon-protocol.md`, commands 1039/1040). The SDK's
/// `SetSleepTimeout.encode` enforces the same range with a raw
/// `ArgumentError`, not a `ChameleonException` the catalog knows, so the app
/// validates before sending — same shape as `slotNicknameMaxBytes` in
/// `features/slots/state/slot_nickname.dart`.
const int sleepTimeoutMin = 5;
const int sleepTimeoutMax = 60;

bool isValidSleepTimeout(int seconds) =>
    seconds >= sleepTimeoutMin && seconds <= sleepTimeoutMax;
