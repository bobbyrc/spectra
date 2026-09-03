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
