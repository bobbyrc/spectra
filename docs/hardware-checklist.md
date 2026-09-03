# Hardware checklist

This tracks the checks that need a real Chameleon Ultra and can't be proven
by tests against `FakeDevice`. The user runs each check on their own device
and reports the result back; every item stays `- [ ] pending` in this file
until that report comes in — an agent must not tick a box from inference or
from a clean CI run alone.

## H1 (after Phase 3): USB serial, BLE, handshake, slot round trip

- [ ] pending: serial enumeration with the device plugged in shows VID
      `0x6868` / PID `0x8686` and manufacturer "Proxgrind". Command:
      `cd packages/chameleon_flutter/example && export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH" && mise x -- flutter run -d macos`,
      then observe the port list.
- [ ] pending: whether opening the port requires the
      `com.apple.security.device.serial` entitlement. Both entitlements
      files (`DebugProfile.entitlements`, `Release.entitlements`) already
      carry it; Spike A found enumeration works without it, so also test
      with the entitlement removed to confirm it's actually required for
      `open()` and not just enumeration.
      `hardware-validate`: the serial entitlement's necessity for `open()`
      (Task 15 fills in the rest of this list's Phase 3 commands).
- [ ] pending: control-line configuration (DTR only vs RTS/CTS+DTR/DSR) —
      commands added in Phase 3.
- [ ] pending: BLE connect and pairing — commands added in Phase 3.
- [ ] pending: connect handshake on real firmware — commands added in
      Phase 3.
- [ ] pending: slot round trip — commands added in Phase 3.

## H1 — wire format (verify with a device attached)

The nine assumptions the SDK makes about payload layouts that the firmware
documentation does not pin down. Each was derived from
`docs/research/chameleon-protocol.md` plus the reference app's behaviour and
is tagged `hardware-validate` in the source (`dart test -t hardware-validate`
runs the tests that encode them). Run these from the transport example once
Phase 3 lands: `cd packages/chameleon_flutter/example && export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH" && mise x -- flutter run -d macos`,
connect, then use the console the example exposes (added in Phase 3) to run
the call named in each item and compare the bytes against the frame log.

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
- [ ] pending: executing an already-executed object is a no-op on the real
      bootloader. The resume path in `SecureDfu` sends an unconditional
      Execute at the boundary it picks up from; `FakeBootloader` models it as
      harmless, which is the assumption to verify on an interrupted transfer.

## H3 (before release): full checklist (spec section 10)

Written in Phase 10.

- [ ] pending: connect
- [ ] pending: pairing
- [ ] pending: slot round trip
- [ ] pending: HF scan
- [ ] pending: LF scan
- [ ] pending: USB DFU
- [ ] pending: BLE DFU
- [ ] pending: recovery from interrupted DFU
