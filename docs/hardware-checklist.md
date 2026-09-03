# Hardware checklist

This tracks the checks that need a real Chameleon Ultra and can't be proven
by tests against `FakeDevice`. The user runs each check on their own device
and reports the result back; every item stays `- [ ] pending` in this file
until that report comes in — an agent must not tick a box from inference or
from a clean CI run alone.

## H1 (after Phase 3): USB serial, BLE, handshake, slot round trip

Run these with the Chameleon Ultra to hand — most from the Mac, a few need a
second desktop OS or an Android device, called out per item. Report back
what you see; the agent records the results here. Nothing below may be
ticked from inference or from a green CI run.

Set up the shell once, on whichever machine the item runs on:

```bash
cd /path/to/spectra
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
flutter pub get
```

The example's emulator row (`Emulated Chameleon Ultra`) is off by default;
none of the items below may be ticked from it. It only appears if the app
is launched with `--dart-define=SPECTRA_EMULATOR=true`, which is for a dry
run with no device attached, never for H1 itself.

**Serial**

- [ ] pending: **enumeration.** Plug the device in over USB, then
      `cd packages/chameleon_flutter/example && flutter run -d macos`.
      Expect a row with a title (the device name) and a subtitle reading
      `usb · <port path>`, e.g. `usb · /dev/cu.usbmodemXXXX`, and a matching
      `[serial_probe] scan: <name> (usb <port path>)` line in the
      `flutter run` console — that line is the only device identity the app
      logs (name, transport kind, transport id, and `bootloader` if
      applicable; it does not print VID/PID or manufacturer). Report the
      exact row and log line.
- [ ] pending: **control lines.** With the app running, set the dropdown in
      the app bar to `dtrOnly`, tap the device row, and report whether the
      page reaches `connection state: ready` (shown live under the app bar title, and logged as a `[serial_probe] connection state: ...` line). Then go back, set the
      dropdown to `hardwareFlowControl` and tap the row again. **Report
      which of the two modes works** (both may). This decides the default
      in `SerialControlLineMode`.
- [ ] pending: **handshake.** On whichever mode worked, report the
      `device:` and `chip id:` lines the page prints.
- [ ] pending: **slot round trip.** On the session page, tap
      "Rename slot 1" and report whether the last line reads
      `slot round trip OK` or `slot round trip MISMATCH`.
- [ ] pending: **an active slot survives a power cycle.** In Spectra itself
      (`cd app && flutter run -d macos`, device attached), open Slots, open a
      slot that is not the active one, tap "Make active" and confirm the
      grid moves the marker. Then unplug the device, plug it back in,
      reconnect and report which slot the app shows as active.
      `SlotsFacade.setActive` sends SET_ACTIVE_SLOT on its own, with no
      SLOT_DATA_CONFIG_SAVE after it — if the marker goes back to where it
      was, Phase 6/7 has to add that save.
- [ ] pending: **the contract suite on hardware.** With the device attached:
      `cd packages/chameleon_flutter && flutter test --tags hardware --run-skipped test/contract`
      (`dart_test.yaml` marks the `hardware` tag `skip:`, so `--run-skipped`
      is required or the suite silently reports zero tests run). Report the
      summary line. See `test/contract/hardware_contract_test.dart` for how
      it picks the device. To test the other control-line mode:
      `flutter test --tags hardware --run-skipped test/contract --dart-define=SPECTRA_SERIAL_CONTROL_LINES=hardwareFlowControl`.
- [ ] pending: **the serial entitlement.** Spike A found enumeration works
      without `com.apple.security.device.serial`, but opening a port is
      expected to need it. Remove that key from
      `packages/chameleon_flutter/example/macos/Runner/DebugProfile.entitlements`,
      re-run `flutter run -d macos`, tap the device and report whether the
      open fails (and with what message). **Put the key back afterwards.**
- [ ] pending: **`SerialTransport.fromPath` open on each desktop OS.** Run
      the enumeration and control-line checks above once each on Windows and
      Linux, not only macOS (`flutter run -d windows` /
      `flutter run -d linux` from `packages/chameleon_flutter/example`).
      Report the port path format and whether `open()` succeeds on each.
- [ ] pending: **unplug mid-scan.** With two serial devices attached (a
      second Chameleon, or any other USB-serial device), start the example,
      confirm both rows appear, then unplug one. Report whether its row
      disappears from the list and the other keeps working.
- [ ] pending: **`UsbSerialAdapter.refresh()` finds the device (Android).**
      On an Android device or emulator with USB host support,
      `flutter run` the example with the Chameleon attached over USB-OTG;
      report whether the row appears and, after unplugging and replugging,
      whether it reappears (`UsbSerialAdapter.refresh()` is what re-scans).
- [ ] pending: **Android USB permission prompt and device filter.** On the
      same Android run, report whether the OS shows the "Allow app to
      access USB device" prompt naming the Chameleon, and whether the
      `device_filter.xml` (VID `0x6868`/`0x1915`, PID `0x8686`/`0x521F`)
      correctly matches it and excludes unrelated USB devices.
- [ ] pending: **Android control lines.** `usb_serial` has no CTS/DSR
      hardware flow-control API, so `UsbSerialAdapter.open` only asserts DTR
      and (in `hardwareFlowControl`) RTS — the `hardware-validate` note in
      `usb_serial_adapter.dart`. On the same Android run, try the app-bar
      dropdown in both modes and report which one reaches
      `connection state: ready`, and whether it agrees with the desktop
      answer above.

**BLE**

- [ ] pending: **scan.** Unplug USB, press a button on the device to wake it
      (it sleeps eight seconds after losing a connection), then
      `flutter run -d macos` in the example. Report whether a row appears
      with kind `ble`.
- [ ] pending: **scan filtering.** Report whether other nearby BLE
      peripherals (phones, headphones, etc.) show up as rows too, or only
      Chameleon devices — `BleScanner`/`UniversalBleAdapter` are expected to
      filter by the Chameleon service UUID.
- [ ] pending: **connect and pairing.** Tap the BLE row. Report whether
      macOS shows a pairing prompt, whether accepting it leads to
      `connection state: ready` (shown live under the app bar title, and logged as a `[serial_probe] connection state: ...` line), and — if it fails — the `failed:`
      line including the `(guidance: ...)` value. This is the pairing flow
      `BleTransport._subscribeWithPairing` drives.
- [ ] pending: **handshake over BLE.** Report the `device:` and `chip id:`
      lines, and whether they match the USB run.
- [ ] pending: **MTU negotiation.** Note whether the connection is usable
      immediately or whether early reads/writes stall or fail before
      settling — `hardware-validate` in `ble_transport.dart` flags MTU
      negotiation as unobservable against the fake.
- [ ] pending: **`isPaired` on Apple.** After the pairing prompt is
      accepted once, disconnect and reconnect (leave the app, or restart
      it) without unpairing in System Settings. Report whether the second
      connect skips the OS pairing prompt (i.e. `isPaired` correctly
      reports the existing bond).
- [ ] pending: **per-platform BLE error codes and permission mapping.**
      With Bluetooth turned off in System Settings, tap a BLE row (or start
      the app) and report the `failed:` line and its `(guidance: ...)`
      value — expected `bluetoothAdapterOff`. If a second platform
      (Windows/Linux/Android) is available, repeat there and report the
      guidance value it maps to; compare against
      `universal_ble_adapter.dart`'s `bleFailureFromCode`.
- [ ] pending: **connection changes for a device that is not connected
      yet.** `BleTransport.open` and `BleDfuChannel.open` subscribe to
      `connectionChanges(deviceId)` *before* calling `connect`, so a drop
      during the handshake is never missed; both carry a
      `hardware-validate` note that universal_ble must deliver events for a
      device it has not connected yet. Tap a BLE row and then immediately
      move the device out of range (or press its power button) while the
      page still says connecting. Report whether the page reports a failure
      promptly with a `failed:` line, or hangs until a timeout — a hang
      means the events are not delivered before the first connect.
- [ ] pending: **a second `pair()` after a Windows pre-pair.** Windows only:
      `BleTransport._subscribeWithPairing` pre-pairs, and if the subscribe
      still reports insufficient authentication it calls
      `BleAdapter.pair` a second time, which is *assumed* to be harmless for
      an already-bonded device (`hardware-validate` in `ble_transport.dart`).
      On Windows, connect once so the device is bonded, then remove the app's
      pairing in Windows Settings while leaving the device paired, reconnect,
      and report whether the second `pair()` succeeds, prompts again, or
      errors.
- [ ] pending: **BLE scanner ageing.** `BleScanner.staleAfter` drops a
      device that has not advertised for ten seconds, sized to the roughly
      eight-second sleep the Chameleon takes after a disconnect (spec 5.1).
      With a BLE row showing, power the device off (or carry it out of
      range) and report how long the row takes to disappear; then wake it
      and report how quickly it comes back. If a device that is still in
      range blinks off the list, the default is too short.

## H1 — wire format (verify with a device attached)

The nine assumptions the SDK makes about payload layouts that the firmware
documentation does not pin down. Each was derived from
`docs/research/chameleon-protocol.md` plus the reference app's behaviour and
is tagged `hardware-validate` in the source (`dart test -t hardware-validate`
runs the tests that encode them). The example has no raw command console;
run the call named in each item either from the contract suite
(`cd packages/chameleon_flutter && flutter test --tags hardware --run-skipped test/contract`,
see `test/contract/hardware_contract_test.dart`) or from a short Dart
script/REPL against a `DeviceSession` built the same way the example does
(`ChameleonTransports.transportFor` + `DeviceSession.open()`), and compare
the bytes against the frame log.

- [ ] pending: 1034 GET_DEVICE_SETTINGS payload length by version byte — v5
      carries no sleep-timeout byte, v6 does. `session.settings.refresh()` on
      a 2.0 device and on a 2.2 device; check
      `settings.version` and whether `sleepTimeoutSeconds` is null, and that
      the frame log shows the payload length the version byte implies.
      Decoding falls back to the length branch only for an unrecognised
      version byte.
- [ ] pending: 2010 HF14A_RAW option bits. No facade method yet (command
      added in Phase 3's raw console): send HF14A_RAW with each option bit
      set in turn against a known tag and record which bit means
      activate-RF, wait-response, append-CRC and auto-select.
- [ ] pending: 2012 MF1_CHECK_KEYS_OF_SECTORS mask bit order — the SDK
      writes sector `i` at bit `i * 2`, key A on the even bit and key B on
      the odd one, MSB first within each byte. `session.reader.mf1CheckKeys(
      sectors: {1}, keyTypes: {KeyType.b}, keys: [<a key that only opens
      sector 1 B>])` must find exactly that key. A reversed order would still
      return keys — the wrong ones — so check the sector and key type of what
      comes back, not just that something did.
- [ ] pending: 4006 GET_DETECTION_LOG entry layout, 18 bytes per entry. No
      facade method yet (command added in Phase 3's raw console): enable
      detection with `session.emulator.setDetectionEnabled(true)`, present
      the slot to a reader, then read the log and confirm each record is 18
      bytes and splits into block, key type, UID and the nonce triple as
      assumed.
- [ ] pending: 4023-4026 Ultralight VERSION_DATA (8 bytes) and SIGNATURE (32
      bytes) lengths. Not advertised by the fake and reachable only as raw
      commands (added in Phase 3): read both from a slot holding an NTAG and
      confirm the payload sizes.
- [ ] pending: LF emulator id lengths for Viking (5004/5005, assumed 4
      bytes), PAC (5006/5007, 8), Jablotron (5010/5011, 5) and Idteck
      (5012/5013, 8). `session.emulator.setLfId(...)` then `getLfId(...)`
      for each; a wrong length is rejected before it reaches the wire, so
      confirm against a real tag id. IoProx (5008/5009) has no documented
      length and is deliberately unimplemented.
- [ ] pending: the 6000-6005 ISO14443-4 payloads in full. No facade methods
      (commands added in Phase 3's raw console): send each against an
      ISO14443-4 tag and record the request and response layouts.
- [ ] pending: the 6xxx success status is 0x00. Every other range has its
      own success value (0x68 for device and emulator, 0x00 for the
      readers); if 6xxx actually answers 0x68 then every ISO14443-4 call
      turns into a spurious `DeviceError`. Confirm from the frame log of any
      successful 6xxx call.
- [ ] pending: `MifareClassicDump.uid` assumes block 0 holds a 4-byte UID.
      Read a dump from a 7-byte-UID MIFARE Classic
      (`session.reader.mf1ReadDump(...)`, then `MifareClassicFormat().describe`)
      and confirm what block 0 holds; the getter is tagged
      `hardware-validate` for exactly this.

## H2 (during Phase 8): USB DFU, interrupted BLE DFU recovery

Written in Phase 8.

- [ ] pending: USB DFU completes successfully on real hardware.
- [ ] pending: BLE DFU completes successfully on real hardware.
- [ ] pending: recovery from a DFU interrupted mid-transfer (USB and BLE).
- [ ] pending: the bootloader appears to the scanners as a *new*
      `DiscoveredDevice` after the reboot, not as the application device's own
      entry changing. `DfuOrchestrator` scans for it rather than reusing the
      old transport id, and `DfuCompleted.device` is the entry found after the
      second reboot; confirm both ids on USB and on BLE.
- [ ] pending: the bootloader's advertised name really is `CU` on the Ultra and
      `CL` on the Lite (the orchestrator also accepts anything already flagged
      `isBootloader`, so record which of the two signals actually fires).
- [ ] pending: the transport reports the ENTER_BOOTLOADER close. The
      orchestrator waits for it (bounded by `scanTimeout`) before scanning and
      carries on if it never comes; confirm whether serial and BLE report it,
      so the wait is a real gate rather than dead time.
- [ ] pending: nrfutil stores the SHA-256 of each image byte-reversed in the
      init packet. `DfuImage.hashMatches` accepts that order only, and every
      run now refuses a package that fails it — check against a real Chameleon
      release zip before shipping DFU.
- [ ] pending: the serial DFU write-object frame layout is what the real
      bootloader accepts. `SlipSerialDfuChannel` sends one SLIP frame of
      `[0x08, ...raw data]` with no length prefix, taken from nrfutil's
      `__stream_data`; confirm a write object is accepted and CRC-matches
      rather than being rejected as a malformed request.
- [ ] pending: the default serial `maxDataWrite` of 64 transfers a full image
      without a `NRF_DFU_RES_CODE_INVALID_PARAMETER` or length error. Then
      check whether asking the bootloader with the GetSerialMTU opcode `0x07`
      would let it grow: the Chameleon's USB CDC bootloader reports
      `SLIP_MTU = 2051`, which by nrfutil's `(mtu - 1) // 2 - 1` is 1024 —
      sixteen times the current chunk. `SecureDfu` has no GetSerialMTU
      request yet.
- [ ] pending: the BLE DFU write size. `BleDfuChannel` uses 20 bytes on iOS
      and macOS — CoreBluetooth does not reliably report a
      write-without-response limit — and the negotiated MTU minus three
      elsewhere, floored at 20 (`hardware-validate` in
      `ble_dfu_channel.dart`). Report what `BleAdapter.requestMtu` returns
      for the *bootloader* (it is a different GATT server from the
      application) on macOS and on one non-Apple platform, and whether a
      larger write than 20 bytes actually succeeds there.
- [ ] pending: executing an already-executed object is a no-op on the real
      bootloader. The resume path in `SecureDfu` sends an unconditional
      Execute at the boundary it picks up from; `FakeBootloader` models it as
      harmless, which is the assumption to verify on an interrupted transfer.

## H3 (before release): the release-candidate pass (spec section 10)

Run against the **`v1.0.0-rc.1` artifacts**, not a `flutter run` debug
build — the point of H3 is that the thing being shipped works. Download them
from the release page:

```bash
gh release download v1.0.0-rc.1 -D ~/Downloads/spectra-rc1
```

Nothing below may be ticked from inference or from a green CI run. Report
each result and the agent records it here.

### Install the RC on each platform you have

- [ ] pending: **macOS.** Open `spectra-1.0.0-rc.1-macos.dmg`, drag Spectra
      to Applications, launch it. The dmg is ad-hoc signed unless the
      Developer ID secrets were set, so Gatekeeper will refuse the first
      launch: right-click the app and choose Open, or
      `xattr -dr com.apple.quarantine /Applications/spectra.app`. Report
      whether it launches and what Gatekeeper said.
- [ ] pending: **Windows.** Run
      `spectra-1.0.0-rc.1-windows-setup.exe`, accept the SmartScreen prompt
      (expected while unsigned), and confirm the Start-menu entry launches.
      Also unzip `spectra-1.0.0-rc.1-windows.zip` and run `spectra.exe` from
      it. Report both.
- [ ] pending: **Linux.**
      `chmod +x spectra-1.0.0-rc.1-linux-x86_64.AppImage &&
      ./spectra-1.0.0-rc.1-linux-x86_64.AppImage`. Report whether it starts
      and whether the window title and icon are right.
- [ ] pending: **Android.**
      `adb install spectra-1.0.0-rc.1-android-unsigned.apk` (or sideload it)
      and launch. Report whether Android complains about the debug
      signature.
- [ ] pending: **iOS.** The `.ipa` is unsigned and cannot be installed
      as-is. Confirm only that it unzips and that `Payload/Runner.app`
      exists; leave the install for the TestFlight route in
      `docs/RELEASING.md`.

### The hardware pass, on the RC build (macOS at minimum)

Chameleon Ultra attached over USB unless the item says otherwise. Turn
emulator mode **off** in Settings first, so no item can be satisfied by the
`Emulated Chameleon Ultra` row.

- [ ] pending: **connect over USB.** The connect screen lists the device;
      connecting reaches the dashboard. Report the firmware version, chip
      id and battery the dashboard shows.
- [ ] pending: **connect over BLE and pairing.** Unplug USB, wake the device
      with a button press, connect from the RC build. Report whether the OS
      pairing prompt appears, whether accepting it reaches the dashboard,
      and whether a second connect skips the prompt.
- [ ] pending: **slot round trip.** Rename a slot, change its tag type,
      make it active, disconnect, power-cycle the device, reconnect, and
      report whether all three survived.
- [ ] pending: **HF scan.** Present a MIFARE Classic card on the Read
      screen. Report the UID, ATQA/SAK, and whether the key check finds
      keys and the dump saves to the library.
- [ ] pending: **LF scan.** Present an EM410x tag. Report the id shown and
      whether it saves.
- [ ] pending: **write and emulate.** Load a saved card into a slot, make
      the slot active, and read it back with a second reader (or the
      Chameleon itself in reader mode). Report whether the emulated card is
      seen with the right UID.
- [ ] pending: **USB DFU with the RC build.** Update the device from the
      Tools tab over USB with a real Chameleon release package. Report the
      progress behaviour, the total time, and the firmware version after the
      reboot.
- [ ] pending: **recovery from an interrupted DFU.** Start a USB DFU and
      unplug the cable mid-transfer. Report whether the app detects the
      bootloader on reconnect and completes the recovery flow.
- [ ] pending: **BLE DFU — only if `dfuOverBleEnabled` is on.** The flag
      defaults off and flips only after H2 passed. If it is on, run a DFU
      over BLE from macOS and report the result; if it is off, report that
      and tick nothing.
- [ ] pending: **background and foreground on mobile.** On Android (and iOS
      if a signed build is available), connect, send the app to the
      background for under 30 seconds and return: the session should still
      be live. Then background it for over a minute and return: it should
      have closed and silently reconnected. Report both.
- [ ] pending: **USB detach.** With the app connected, unplug the device.
      Report whether the app returns to the connect screen with that device
      preselected, and the message it shows.
- [ ] pending: **the frame log.** Open Tools -> frame log after the runs
      above and export it. Attach the export to the report; it is the
      evidence for every item here.

### Cards and reads (carried over from Phase 6)

- [ ] pending: **a real reference-app export imports.** Export a library
      from the Chameleon Ultra GUI (Settings → export) and paste it into
      Spectra's import. Confirm every card lands with the right name, tag
      type, folder and colour, and that hex-string colour fields (however
      the reference app spells them) come through — Phase 6's importer
      never saw a real export, only its documented field names. If a field
      name differs from `referenceTagNames`/`_readCard`'s keys in
      `features/cards/state/card_import.dart`, fix the reader and add the
      real file (personal data stripped) as a second fixture.
- [ ] pending: **a real MIFARE Classic 1K read, twice.** Once with a card
      whose keys are all in `defaultMifareKeyHex` (expect a complete dump,
      `Save to library` enabled) and once with a card carrying at least one
      non-default key (expect a *partial* dump reported as partial, not a
      silent failure). Confirms `ReaderFacade.mf1ReadDump`'s partial-read
      contract against real firmware.
- [ ] pending: **a real EM410x read.** A fob's five id bytes match what
      another reader reports.
- [ ] pending: **a real NTAG identify-only read.** An NTAG215 held to the
      reader shows its UID and the "cannot read its memory yet" line — the
      documented v1 limit (no Ultralight read facade), not a crash.

### Sign-off list for `v1.0.0`

This is the sign-off list: `v1.0.0` is tagged only when all of these are
true. An agent may not tick any of them.

- [ ] pending: every H1 item above reported and recorded.
- [ ] pending: every H2 item above reported and recorded.
- [ ] pending: every H3 item in this section reported and recorded.
- [ ] pending: the LICENSE decision made (see `docs/RELEASING.md`).
- [ ] pending: the `dfuOverBleEnabled` default decided from the H2/H3 BLE
      results.
- [ ] pending: the vendored `usb_serial` override re-checked against
      upstream.
- [ ] pending: the release workflow green on the `v1.0.0-rc.1` tag with
      every artifact attached.
