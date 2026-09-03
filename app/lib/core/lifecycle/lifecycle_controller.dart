import 'dart:async';

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
    // The public parameter names below are the documented interface (spec
    // 7.4); the private fields keep the leading underscore for
    // encapsulation, so an initializing formal (which requires the same
    // name) is not available here — hence the ignores.
  }) : _closeSessions = closeSessions, // ignore: prefer_initializing_formals
       _reconnectLast = reconnectLast, // ignore: prefer_initializing_formals
       _hasSession = hasSession; // ignore: prefer_initializing_formals

  static const Duration defaultGrace = Duration(seconds: 30);

  final Future<void> Function() _closeSessions;
  final Future<void> Function() _reconnectLast;
  final bool Function() _hasSession;
  final Duration grace;

  Timer? _timer;
  bool _closedWhilePaused = false;
  bool _reconnecting = false;

  void onPaused() {
    _timer?.cancel();
    _timer = Timer(grace, () async {
      _closedWhilePaused = true;
      await _closeSessions();
    });
  }

  Future<void> onResumed() async {
    _timer?.cancel();
    _timer = null;
    if (!_closedWhilePaused || _reconnecting || _hasSession()) return;
    _closedWhilePaused = false;
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
