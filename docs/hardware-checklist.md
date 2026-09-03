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
- [ ] pending: control-line configuration (DTR only vs RTS/CTS+DTR/DSR) —
      commands added in Phase 3.
- [ ] pending: BLE connect and pairing — commands added in Phase 3.
- [ ] pending: connect handshake on real firmware — commands added in
      Phase 3.
- [ ] pending: slot round trip — commands added in Phase 3.

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
