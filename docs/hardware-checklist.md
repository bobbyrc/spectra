# Hardware checklist

This tracks the checks that need a real Chameleon Ultra and can't be proven
by tests against `FakeDevice`. The user runs each check on their own device
and reports the result back; every item stays `- [ ] pending` in this file
until that report comes in — an agent must not tick a box from inference or
from a clean CI run alone.

## H1 (after Phase 3): USB serial, BLE, handshake, slot round trip

- [ ] pending: serial enumeration with the device plugged in shows VID
      `0x6868` / PID `0x8686` and manufacturer "Proxgrind". Command:
      `cd packages/chameleon_flutter/example && mise x -- flutter run -d macos`,
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
