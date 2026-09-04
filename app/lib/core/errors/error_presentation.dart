/// The recovery action the UI should offer alongside an [ErrorPresentation].
enum ErrorRecovery {
  /// Try the same operation again.
  retry,

  /// Send the user to the OS's permission/settings surface.
  openSettings,

  /// Show platform-specific step-by-step instructions
  /// ([ErrorCatalog.guidance]).
  platformInstructions,

  /// Reconnect the device.
  reconnect,

  /// Update the firmware, or update Spectra.
  update,

  /// No action to offer; the message stands alone.
  none,
}

/// A typed error turned into words for the UI (spec 9): one plain sentence,
/// the recovery action to offer, and the raw line the spec puts one tap
/// away for anyone who wants the underlying detail.
final class ErrorPresentation {
  const ErrorPresentation({
    required this.message,
    required this.recovery,
    required this.detail,
    this.instructions,
  });

  /// One plain sentence describing what went wrong.
  final String message;

  /// Which action the UI offers for this error.
  final ErrorRecovery recovery;

  /// The raw line (spec 9): the underlying error's `toString()`, shown one
  /// tap away from [message] for anyone who wants the detail.
  final String detail;

  /// Platform-specific guidance, when there is any. Filled in by the caller
  /// that knows which transport failed (Task 14); the catalog itself has no
  /// transport.
  final String? instructions;
}
