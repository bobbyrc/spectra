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
  int get readerLeaseCount => _leases;

  /// A long operation is running, so the idle poll stands down.
  bool get isBusy => _busy > 0;

  /// Puts the device into reader mode and returns the lease that takes it out
  /// again. Throws [ReaderUnavailable] on a device with no reader (the Lite),
  /// and whatever the mode change failed with if the device refuses it — in
  /// both cases without taking a lease.
  Future<ReaderLease> acquireReaderMode() async {
    if (!_requireInfo.capabilities.hasReader) throw const ReaderUnavailable();
    if (_leases == 0) {
      await send(const ChangeDeviceMode(DeviceMode.reader));
      mode.set(DeviceMode.reader);
    }
    _leases++;
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
    _leases--;
    if (_leases > 0 || !isReady) return;
    try {
      await send(const ChangeDeviceMode(DeviceMode.emulator));
      mode.set(DeviceMode.emulator);
    } on ChameleonException catch (e) {
      _reportBackground(e);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
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
  Future<void> _pollOnce() async {
    if (_polling || !_pollAllowed || !_dispatcher.isIdle) return;
    _polling = true;
    try {
      await _background(() async {
        if (!_pollAllowed) return;
        activeSlot.setIfChanged(await send(const GetActiveSlot()));
        if (!_pollAllowed) return;
        mode.setIfChanged(await send(const GetDeviceMode()));
        // The battery reading is meaningless for the first few seconds after
        // power-up; the background load waits the same delay out.
        if (!_pollAllowed ||
            DateTime.now().difference(_readyAt!) < batteryDelay) {
          return;
        }
        battery.setIfChanged(await send(const GetBatteryInfo()));
      });
    } finally {
      _polling = false;
    }
  }
}
