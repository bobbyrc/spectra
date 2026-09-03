import 'dart:async';

// The public constructor parameter names below are the documented interface
// (spec 7.4); the private fields keep the leading underscore for
// encapsulation, so an initializing formal (which requires the field and
// parameter to share a name) is not available for any of the three.
// ignore_for_file: prefer_initializing_formals

/// Spec 7.4. Backgrounding does not drop the link straight away — switching
/// apps for five seconds is not a disconnect — but a session cannot be held
/// open for ever either, so it is closed after [defaultGrace]. On the way
/// back, exactly one silent reconnect is attempted, and only if the grace
/// period actually expired.
///
/// Every effect is injected, so this is unit-tested with no binding and no
/// real clock.
final class LifecycleController {
  LifecycleController({
    required Future<void> Function() closeSessions,
    required Future<void> Function() reconnectLast,
    required bool Function() hasSession,
    this.grace = defaultGrace,
  }) : _closeSessions = closeSessions,
       _reconnectLast = reconnectLast,
       _hasSession = hasSession;

  static const Duration defaultGrace = Duration(seconds: 30);

  final Future<void> Function() _closeSessions;
  final Future<void> Function() _reconnectLast;
  final bool Function() _hasSession;
  final Duration grace;

  Timer? _timer;
  bool _closedWhilePaused = false;
  bool _reconnecting = false;

  /// A no-op when there is nothing to hold open: no session means nothing
  /// backgrounding could drop, so no timer is armed and
  /// [_closedWhilePaused] is left untouched. Called again while a timer is
  /// already running (the app is paused, resumed to inactive, then paused
  /// again without a full resume, for instance) restarts the grace period
  /// from zero rather than stacking a second timer.
  void onPaused() {
    _timer?.cancel();
    _timer = null;
    if (!_hasSession()) return;
    _timer = Timer(grace, () async {
      try {
        await _closeSessions();
      } catch (_) {
        // A failing `closeSessions` must not become an unhandled async
        // error off a bare `Timer` callback — see the class doc: the app
        // still treats this as "gone" so a resume gets its one silent
        // reconnect attempt regardless of how the close itself went.
      } finally {
        // Only set once the timer has actually run and attempted to close
        // a session that existed at pause time — never for a pause that
        // was a no-op above.
        _closedWhilePaused = true;
      }
    });
  }

  Future<void> onResumed() async {
    _timer?.cancel();
    _timer = null;
    // Read and clear on every call, whether or not this resume ends up
    // reconnecting: a resume that declines (nothing was closed, one is
    // already in flight, or a session already exists again) must not leave
    // a stale flag for a later, unrelated background/resume dip to act on.
    final wasClosedWhilePaused = _closedWhilePaused;
    _closedWhilePaused = false;
    if (!wasClosedWhilePaused || _reconnecting || _hasSession()) return;
    _reconnecting = true;
    try {
      await _reconnectLast();
    } on Object {
      // One silent attempt (spec 7.4). A failure is not worth a dialog: the
      // connect screen is already what the user is looking at.
    } finally {
      _reconnecting = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
