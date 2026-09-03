# Spikes

Short, disposable experiments run in Phase 0 to de-risk package choices before
the real code depends on them. Each section records what was run, what happened
on each platform, and a verdict.

## Spike A: libserialport_plus build hooks

**Date:** 2026-09-03
**Question:** does `libserialport_plus` compile libserialport through its
Dart code-assets build hook on macOS, Windows and Linux, and does port
enumeration run?

**Package version:** `libserialport_plus` 1.0.4 (pub.dev, published 2026-08-26),
resolved against Flutter 3.47.2 / Dart 3.13.2. Transitive build-hook deps as
resolved: `code_assets` 2.0.0, `hooks` 2.2.0, `native_toolchain_c` 0.19.4,
`record_use` 1.1.1.

**Probe:** `packages/chameleon_flutter/example` (project name `serial_probe`),
a workspace member targeting macOS, Windows and Linux. It enumerates ports on
start, logs each one with `debugPrint` and shows them in a list.

**Enumeration call used:**

```dart
final names = SerialPort.getAvailablePorts();      // List<String> of OS port names
for (final name in names) {
  final info = SerialPort(name).getInfo();          // SerialPortInfo
  // info.name, info.description, info.transport,
  // info.usbVid, info.usbPid, info.usbManufacturer, info.usbProduct
}
```

`SerialPortInfo` exposes USB VID/PID and the manufacturer/product strings as
nullable `int?`/`String?` fields, so the earlier open question about whether
VID/PID are reachable is settled: they are, no extra FFI work needed.

**macOS:** `flutter build macos --debug` succeeded on macOS 15 (arm64,
Xcode toolchain). The hook produced
`build/macos/Build/Products/Debug/serial_probe.app/Contents/Frameworks/libserialport_plus.framework`.
Running the built app enumerated three ports:

```
[serial_probe] /dev/cu.debug-console | debug-console | native | vid=? pid=? | mfr=? product=?
[serial_probe] /dev/cu.Bluetooth-Incoming-Port | Bluetooth-Incoming-Port | native | vid=? pid=? | mfr=? product=?
[serial_probe] /dev/cu.soundcoreAeroFit2 | soundcoreAeroFit2 | native | vid=? pid=? | mfr=? product=?
```

No Chameleon Ultra was attached, so VID 0x6868 / PID 0x8686 was not observed;
confirming that specific port is part of hardware handoff H1. What this run
proves is that the native library builds, loads and enumerates.

**Windows:** built on `windows-latest` in CI (MSVC toolchain, no extra setup).
Artifacts: `build/native_assets/windows/libserialport_plus.dll` and
`build/windows/x64/runner/Debug/libserialport_plus.dll`.

**Linux:** built on `ubuntu-latest` in CI with the existing apt packages
(`clang cmake ninja-build pkg-config libgtk-3-dev`) — nothing serial-specific
had to be added. Artifacts: `build/native_assets/linux/liblibserialport_plus.so`
and `build/linux/x64/debug/bundle/lib/liblibserialport_plus.so`.

CI run: https://github.com/bobbyrc/spectra/actions/runs/33714216539 — all eight
jobs succeeded, including the two temporary probe entries. A green build alone
would not have proved much (the hook skips unsupported platforms silently and
still lets the app link), so the probe jobs also asserted a `*serialport*`
artifact exists in the bundle; both found one. Those two matrix entries and the
assertion step were removed afterwards.

**Sandbox and signing observations:**

- macOS enumeration worked *without* `com.apple.security.device.serial`. The
  entitlement was added to both `DebugProfile.entitlements` and
  `Release.entitlements` anyway — the package README requires it and the
  sibling package's issue tracker reports `Operation not permitted, errno = 1`
  on `open()` without it. So: not required to *list* ports, expected to be
  required to *open* one. Confirm at hardware handoff H1.
- Native assets need no experiment flag on Flutter 3.47.2; code assets are
  stable since 3.38.
- Windows needed no C toolchain setup beyond what `windows-latest` ships, and
  the DLL is unsigned — a future signed release build will have to cover the
  hook-produced DLL, not just the app binary.
- Nothing extra was needed on Linux; libserialport is built from the vendored
  sources, not from a system `libserialport-dev`.

**Verdict: keep `libserialport_plus` 1.0.4.** It builds through its code-assets
hook on all three desktop targets with no toolchain or CI changes, enumeration
runs on macOS, and it surfaces USB VID/PID directly, which is what the
Chameleon Ultra transport needs to identify the device. The fallback
(`flutter_libserialport` 0.6.0, classic plugin build) was not needed and was
not exercised. Spec section 5.2 stands as written.

The `serial_probe` example stays in the tree: Phase 3 turns it into the serial
transport example.
