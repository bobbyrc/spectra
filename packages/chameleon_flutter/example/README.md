# serial_probe

The Spectra transport example. It lists what every scanner on this platform
can see (the emulator's `FakeScanner` plus BLE and USB serial), opens a
transport for the row you tap, runs a `DeviceSession` handshake and offers a
slot rename round trip.

This is the app hardware handoff H1 is run from; see
`docs/hardware-checklist.md` at the repo root for the exact checks and
commands.

```
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH" && mise x -- flutter run -d macos
```
