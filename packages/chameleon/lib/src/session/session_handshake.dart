part of 'device_session.dart';

/// The connect handshake and the tolerant background load (spec 4.3).
///
/// Only three commands gate readiness: capabilities (1035), app version
/// (1000) and model (1033). Everything else is loaded afterwards and is
/// allowed to fail: a failure yields partial state plus a typed error on
/// [DeviceSession.backgroundErrors], never a refused session.
extension SessionHandshake on DeviceSession {
  Future<void> _handshake() async {
    final caps = await _capabilitiesOrNull();
    if (caps == null) {
      // No GET_DEVICE_CAPABILITIES: firmware older than 2.0. The version
      // still tells legacy 0.1 apart from the rest, and is itself allowed to
      // fail — such a device is unusable either way.
      final version = await _versionOrNull();
      connectionState.set(
        SessionLimited(
          version != null && version.isLegacy
              ? UnsupportedReason.legacyMustUpdate
              : UnsupportedReason.preTwoPointZero,
          version: version,
        ),
      );
      return;
    }
    final version = await _sendRaw(const GetAppVersion());
    if (version.isLegacy) {
      connectionState.set(
        SessionLimited(UnsupportedReason.legacyMustUpdate, version: version),
      );
      return;
    }
    if (version.major > DeviceSession.supportedMajor) {
      connectionState.set(
        SessionLimited(UnsupportedReason.newerMajor, version: version),
      );
      return;
    }
    final model = await _sendRaw(const GetDeviceModel());
    final info = DeviceInfo(model: model, version: version, capabilities: caps);
    deviceInfo.set(info);
    _readyAt = DateTime.now();
    connectionState.set(SessionReady(info));
    unawaited(_loadBackground());
    _startPolling();
  }

  /// Any answer but a usable capability list means the firmware predates
  /// GET_DEVICE_CAPABILITIES: a refusal, a timeout and a payload that does not
  /// decode are all "no capabilities", not a failed connection. A transport
  /// error is different in kind — the link is gone — and is rethrown so the
  /// session lands disconnected rather than limited.
  Future<Capabilities?> _capabilitiesOrNull() async {
    try {
      return await _sendRaw(const GetDeviceCapabilities());
    } on TransportError {
      rethrow;
    } on ChameleonException {
      return null;
    }
  }

  Future<FirmwareVersion?> _versionOrNull() async {
    try {
      return await _sendRaw(const GetAppVersion());
    } on TransportError {
      rethrow;
    } on ChameleonException {
      return null;
    }
  }

  /// Everything the dashboard wants but readiness does not depend on. Each
  /// step is independent: one failing does not skip the rest.
  Future<void> _loadBackground() async {
    await _background(() async {
      final git = await send(const GetGitVersion());
      final chip = await send(const GetDeviceChipId());
      final address = await send(const GetDeviceAddress());
      deviceInfo.set(
        _requireInfo.copyWith(
          gitVersion: git,
          identity: DeviceIdentity(chip),
          bleAddress: address,
        ),
      );
    });
    await _background(() async => mode.set(await send(const GetDeviceMode())));
    await _background(refreshSlots);
    await _background(
      () async => settingsState.set(await send(const GetDeviceSettings())),
    );
    await _background(() async {
      // The battery reading settles a few seconds after power-up; wait out
      // whatever is left of that from the moment the session became ready.
      final wait = batteryDelay - DateTime.now().difference(_readyAt!);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      if (!isReady) return;
      battery.set(await send(const GetBatteryInfo()));
    });
  }

  Future<void> _background(Future<void> Function() body) async {
    if (!isReady) return;
    try {
      await body();
    } on ChameleonException catch (e) {
      _reportBackground(e);
    }
  }

  /// Reloads the slot cache from the device (1018, 1019, 1023, nicknames).
  ///
  /// Nicknames come from GET_ALL_SLOT_NICKS (1038) when the device admits to
  /// supporting it, and from sixteen GET_SLOT_TAG_NICK (1008) calls otherwise:
  /// 2.0 firmware has no 1038.
  ///
  /// Internal to the SDK: an app refreshes slots through
  /// `session.slots.refresh()`, which also tracks busy state.
  @internal
  Future<List<Slot>> refreshSlots() async {
    final caps = _requireInfo.capabilities;
    final active = await send(const GetActiveSlot());
    final types = await send(const GetSlotInfo());
    final enabled = await send(const GetEnabledSlots());
    final List<SlotNicks> nicks;
    if (caps.supports(1038)) {
      nicks = await send(const GetAllSlotNicks());
    } else {
      nicks = [];
      for (var i = 0; i < DeviceSession.slotCount; i++) {
        final hf = await _nickOrEmpty(i, Sense.hf);
        final lf = await _nickOrEmpty(i, Sense.lf);
        nicks.add(SlotNicks(hf, lf));
      }
    }
    final list = List.generate(
      DeviceSession.slotCount,
      (i) => Slot(
        index: i,
        hfType: types[i].hf,
        lfType: types[i].lf,
        hfEnabled: enabled[i].hf,
        lfEnabled: enabled[i].lf,
        hfNick: nicks[i].hf,
        lfNick: nicks[i].lf,
      ),
    );
    activeSlot.set(active);
    slotsState.set(list);
    return list;
  }

  /// A slot with no nickname answers with an error on some firmware; that is
  /// not worth failing the whole slot load over.
  Future<String> _nickOrEmpty(int slot, Sense sense) async {
    try {
      return await send(GetSlotTagNick(slot, sense));
    } on DeviceError {
      return '';
    }
  }
}
