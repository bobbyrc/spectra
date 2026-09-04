part of 'device_session.dart';

/// The reader-mode lease, busy tracking and the idle poll (spec 4.3).
///
/// Reader mode is a lease rather than a mode switch per operation: the device
/// is put into reader mode when the lease count goes 0 -> 1 and back into
/// emulator mode when it returns to 0, so nested reader work switches once.
///
/// The cache is write-through plus this poll: while nothing holds a lease and
/// no long operation is running, the active slot, the mode and the battery are
/// re-read every [DeviceSession.idlePollInterval] so a slot changed with the
/// device's own buttons shows up in the app. A poll only publishes values that
/// actually changed, so idle listeners see nothing.
extension SessionPolling on DeviceSession {
  /// Leases currently held; the device is in reader mode while this is > 0.
  /// Reset to zero when the link is lost: a lease over a dead link means
  /// nothing, and the mode it was holding no longer exists.
  int get readerLeaseCount => _leases;

  /// A long operation is running. The idle poll stands down whenever
  /// `readerLeaseCount > 0 || isBusy`, so the device is never interrupted
  /// mid-operation by a housekeeping read.
  bool get isBusy => _busy > 0;

  /// Puts the device into reader mode and returns the lease that takes it out
  /// again.
  ///
  /// Throws [ReaderUnavailable] on a device with no reader (the Lite),
  /// [SessionNotReady] when the session is not ready, and whatever the mode
  /// change failed with if the device refuses it. In every case no lease is
  /// left behind: the count is rolled back before the error propagates.
  ///
  /// The count is raised before the switch is sent and concurrent acquires
  /// share one in-flight switch, so two callers that start together produce
  /// one CHANGE_DEVICE_MODE on the wire and one restore between them.
  Future<ReaderLease> acquireReaderMode() async {
    if (!isReady) {
      throw SessionNotReady('session is ${connectionState.value.runtimeType}');
    }
    if (!_requireInfo.capabilities.hasReader) throw const ReaderUnavailable();
    _leases++;
    if (_leases == 1 || _modeSwitch != null) {
      try {
        await _switchMode(DeviceMode.reader);
      } on Object {
        _releaseLease();
        rethrow;
      }
    }
    return ReaderLease(_releaseReader);
  }

  /// Runs [body] with a reader lease held, releasing it however [body] ends.
  Future<T> withReaderMode<T>(Future<T> Function() body) async {
    final lease = await acquireReaderMode();
    try {
      return await body();
    } finally {
      await lease.release();
    }
  }

  /// Pauses the idle poll for the duration of a long operation. The body's
  /// result and its errors both pass straight through.
  Future<T> busy<T>(Future<T> Function() body) async {
    _busy++;
    try {
      return await body();
    } finally {
      _busy--;
    }
  }

  /// The last release restores emulator mode. A failure here is a background
  /// error: the operation the caller ran has already finished, and a session
  /// is never dropped because the device would not switch back.
  Future<void> _releaseReader() async {
    _releaseLease();
    if (_leases > 0 || !isReady) return;
    try {
      await _switchMode(DeviceMode.emulator);
    } on ChameleonException catch (e) {
      _reportBackground(e);
    }
  }

  /// Gives a lease back. Clamped: a release that arrives after the link died
  /// (which zeroed the count) must not push it negative.
  void _releaseLease() {
    if (_leases > 0) _leases--;
  }

  /// Sends CHANGE_DEVICE_MODE and updates the cache, joining the switch
  /// already on the wire when it is going to the same mode. A switch the other
  /// way queues behind it instead of racing it.
  Future<void> _switchMode(DeviceMode target) {
    final pending = _modeSwitch;
    if (pending != null && _modeSwitchTarget == target) return pending;
    final future = _runModeSwitch(pending, target);
    _modeSwitch = future;
    _modeSwitchTarget = target;
    future.whenComplete(() {
      if (identical(_modeSwitch, future)) _clearModeSwitch();
    }).ignore();
    return future;
  }

  Future<void> _runModeSwitch(Future<void>? previous, DeviceMode target) async {
    // A switch the other way is still in flight; its failure belongs to the
    // caller that started it, not to this one.
    if (previous != null) await previous.catchError((Object _) {});
    await send(ChangeDeviceMode(target));
    mode.set(target);
  }

  /// Drops every lease and any memoised switch: called when the link dies and
  /// on [DeviceSession.close].
  void _forgetLeases() {
    _leases = 0;
    _clearModeSwitch();
  }

  void _clearModeSwitch() {
    _modeSwitch = null;
    _modeSwitchTarget = null;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    // A tick that lands while the previous poll is still running is dropped,
    // not queued: the point is fresh state, and a device that is slow to
    // answer should not accumulate a backlog of stale polls.
    _pollTimer = Timer.periodic(
      idlePollInterval,
      (_) => unawaited(_pollOnce()),
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Nothing else is using the device, so a poll may run — or carry on.
  bool get _pollAllowed => isReady && !isBusy && _leases == 0;

  /// One poll. Skipped whenever the device is doing something else, and
  /// re-checked between reads so a lease taken mid-poll stops it at once
  /// rather than after two more commands.
  ///
  /// Nothing escapes: this runs unawaited from a timer, so even a bug in a
  /// read has to come out as a background error rather than an unhandled
  /// async error that takes the app down.
  Future<void> _pollOnce() async {
    if (_polling || !_pollAllowed || !_dispatcher.isIdle) return;
    _polling = true;
    try {
      await _background(_pollReads);
    } on Object catch (e, st) {
      _reportBackground(BackgroundTaskFailed(e, st));
    } finally {
      _polling = false;
    }
  }

  Future<void> _pollReads() async {
    if (!_pollAllowed) return;
    activeSlot.setIfChanged(await send(const GetActiveSlot()));
    if (!_pollAllowed) return;
    mode.setIfChanged(await send(const GetDeviceMode()));
    // The battery reading is meaningless for the first few seconds after
    // power-up; the background load waits the same delay out.
    final readyAt = _readyAt;
    if (!_pollAllowed ||
        readyAt == null ||
        DateTime.now().difference(readyAt) < batteryDelay) {
      return;
    }
    battery.setIfChanged(await send(const GetBatteryInfo()));
  }
}
