# Spectra design spec

Date: 2026-09-02
Status: approved in brainstorm, awaiting written review
Scope: v1 of Spectra, a cross-platform companion app for the Chameleon Ultra
and Chameleon Lite.

## 1. Goals and constraints

Spectra is a polished companion app for the Chameleon Ultra family, running
from one Flutter codebase on Windows, macOS, Linux, iOS and Android. It serves
first-time hobbyists and security researchers through progressive
disclosure: the default view of every screen shows the outcome in plain
words, and one tap reveals raw bytes, status codes and timing.

Fixed decisions (see `docs/research/DECISIONS.md`):

- Flutter single codebase. Toolchain pinned with mise: Flutter 3.47.x stable,
  Dart 3.13.
- The protocol layer is a clean-room Dart implementation from the official
  firmware sources. The reference app (GameTec-live/ChameleonUltraGUI,
  GPL-3.0) is used only to cross-check behavior, never copied.
- Custom design system (own tokens and core components) on Material 3.
- Foundation-first build order: design system, SDK, transports, then
  feature screens.
- Everything must work without hardware, through a fake device in tests and
  an emulator mode in the app.

v1 features: connect and device dashboard, slot management, read, write and
emulate cards, firmware update (DFU), key dictionaries and settings.

Out of scope for v1: key recovery computations (the CPU-heavy routines the
reference app runs in C), web target, serial DFU, cloud sync, plugins.

## 2. Workspace layout and dependency rules

The repo is a pub workspace with four member packages. Melos is used only for
scripts (test all, format all), not for versioning.

```
spectra/
  pubspec.yaml            # workspace root
  mise.toml               # Flutter / Dart pins
  packages/
    chameleon/            # pure Dart device SDK
    chameleon_flutter/    # platform transports and DFU runners
    spectra_ui/           # design system
  app/                    # the Spectra app
  docs/
  tool/                   # CI and release scripts
```

Dependency direction is one way and enforced by a CI lint that fails on any
forbidden import.

| Package | May depend on | Must not depend on |
|---|---|---|
| chameleon | Dart SDK, meta, collection, freezed | flutter, any plugin |
| chameleon_flutter | chameleon, flutter, universal_ble, libserialport_plus, usb_serial, nordic_dfu | spectra_ui, app |
| spectra_ui | flutter, material_ui, google_fonts, dynamic_color, flutter_animate, window_manager, macos_window_utils | chameleon, chameleon_flutter |
| app | all three packages, riverpod, go_router, drift | nothing further restricted |

Consequences:

- All hardware-facing behavior is verified by `dart test` inside `chameleon`
  with no Flutter engine.
- The design system is developed and golden-tested against sample data, so a
  protocol change can never break a widget test.
- Codegen uses build_runner (freezed, json_serializable, riverpod_generator,
  drift). Generated files are committed so a fresh clone builds without
  running codegen first.
- Package names are lowercase snake. The SDK is named `chameleon`, not
  `chameleon_ultra`, because it also serves the Lite.
- One semantic version across all packages.

## 3. The `chameleon` SDK: protocol layer

Layered bottom up: frame codec, command catalog, models, then session (section
4). Wire facts come from `docs/research/chameleon-protocol.md`.

### 3.1 Frame codec

- `FrameEncoder` builds a frame from a command id and payload: SOF 0x11, LRC1,
  CMD u16 BE, STATUS u16 BE (0 in requests), LEN u16 BE, LRC2 over bytes 2..7,
  DATA, LRC3 over DATA. LRC = (0x100 - (sum & 0xFF)) & 0xFF.
- `FrameDecoder` is a byte-stream state machine. It accepts arbitrary chunks,
  resyncs on SOF, validates all three LRCs, caps LEN at 4096, and emits
  complete `Frame` values. Corrupt input is dropped and reported through a
  diagnostics stream, never thrown, because fragmentation and noise are normal
  on BLE.

### 3.2 Command catalog

- Each firmware command is a class `Command<R>` with a command id, `encode()`
  for the request payload, `decode(bytes)` for the response, and the status
  value that means success for its range (0x68 for 1xxx/4xxx/5xxx, 0x00 for
  2xxx, 0x40 for 3xxx).
- Grouped in files by firmware range: `device` (1000-1040), `hf_reader`
  (2000-2201), `lf_reader` (3000-3032), `hf_emulator` (4000-4044),
  `lf_emulator` (5000-5013), `iso14443_4` (6000-6005).
- Commands whose payload format the wiki leaves uncertain carry a doc comment
  and the test tag `hardware-validate` so they can be found and checked on a
  device.
- Commands are internal to the SDK. App code uses the facades in section 4.

### 3.3 Typed results and errors

- Firmware status maps to a sealed `DeviceError` hierarchy: tag not found,
  tag error (CRC, BCC, parity, collision, ATS), authentication failed,
  invalid command, not implemented, device mode error, flash read/write,
  invalid slot type, memory, parameter, command error.
- `TransportError` (disconnected, permission denied, port busy, not found) and
  `CommandTimeout` are separate types so the UI can tell "card not present"
  from "device unplugged".
- Callers never see raw status integers.

### 3.4 Models

Immutable freezed types: `DeviceInfo` (model, app version, git version, chip
id, address), `Capabilities`, `Slot` (index, hf and lf tag types, enabled per
sense, nicknames per sense), `TagType` enum with wire codes and a family
classification (LF, MIFARE Classic, Ultralight/NTAG, ISO14443-4, SEOS),
`DeviceSettings`, `ButtonFunction`, `AnimationMode`, `BatteryInfo`,
`DeviceMode`. Capabilities gate features in the UI, so the Lite never shows
reader features.

### 3.5 Testing

Every command has encode and decode tests using byte vectors derived from the
firmware sources, including the documented ENTER_BOOTLOADER frame
`11 EF 03 F2 00 00 00 00 0B 00`. The decoder has fragmentation, resync and
corruption tests.

## 4. The `chameleon` SDK: transport, session, fake and DFU

### 4.1 Transport interface

```dart
abstract class Transport {
  Future<void> open();
  Future<void> close();
  Stream<Uint8List> get incoming;
  Future<void> write(Uint8List bytes);
  Stream<TransportState> get state; // connected, disconnected, error, pairingRequired
}
```

Transports move bytes only and know nothing about frames.

### 4.2 Discovery

`DeviceScanner` yields `DiscoveredDevice` (display name, transport kind,
identifier, isBootloader). The SDK ships `FakeScanner`, which lists one
emulated Ultra and, when enabled, one emulated Lite.

### 4.3 DeviceSession

The single owner of a connection. It wraps a transport and the codec.

- `Future<R> send(Command<R>)` is internal to the SDK. It queues commands,
  keeps one in flight, matches responses by command id, applies a per-command
  timeout (3 s default, longer for slow reader operations), and maps status
  to typed results.
- On open it runs the connect handshake: capabilities (missing means
  pre-2.0 firmware, refuse), app version (higher major refuses, legacy 0.1
  demands update), model, git version, chip id and address, mode, active slot,
  slot info, enabled slots, all nicknames, settings, battery.
- Cached state as streams: `deviceInfo`, `slots`, `activeSlot`, `settings`,
  `battery`, `mode`, `connectionState`.
- `withReaderMode(() async {...})` switches to reader mode around a reader
  operation and restores emulator mode afterwards, including on failure.
- Typed facades expose domain operations (see section 8.1): `device`,
  `slots`, `reader`, `emulator`, `settings`, `firmware`.

### 4.4 FakeDevice

An in-memory `Transport` that behaves like firmware: parses frames, holds
eight slots, settings, mode and battery, and answers every device, emulator
and settings command. Reader commands are scripted: tests and the emulator
mode load `FakeCard` data so scans succeed or fail on demand. It can be
configured as Ultra or Lite, with a chosen firmware version, and with
injected latency and disconnects. It backs unit tests, the app's emulator
mode and the transport contract suite.

### 4.5 DFU

- `DfuPackage` reads an nrfutil zip (manifest.json, .bin, .dat), validates
  the manifest and checks hardware version (0 Ultra, 1 Lite) against the
  connected model.
- `SecureDfu` is a pure-Dart Nordic Secure DFU protocol v1 state machine
  driving object transfer over an abstract `DfuChannel`, with progress and
  cancellation.
- `DfuRunner` is the interface the app uses: `run(package, target,
  onProgress)`. Two implementations live in `chameleon_flutter`: one built on
  `SecureDfu` over a BLE channel, one wrapping the native nordic_dfu library.

## 5. The `chameleon_flutter` package: platform transports

Contains every native dependency and nothing else.

### 5.1 BLE transport

universal_ble on all five platforms. Scan filters on the Nordic UART service
`6E400001-B5A3-F393-E0A9-E50E24DCCA9E` and the name prefixes
`ChameleonUltra` and `ChameleonLite`. On connect: subscribe to notify
`6E400003`, request MTU 247, write to `6E400002` in chunks of MTU minus 3.
Pairing uses the OS prompt; the transport reports `pairingRequired` so the
app can explain the default passkey.

### 5.2 Serial transport

libserialport_plus on desktop, usb_serial on Android. Discovery filters on
VID 0x6868 / PID 0x8686 and manufacturer "Proxgrind". Opens at 115200 8N1,
asserts DTR, no flow control. Windows access-denied and Linux permission
failures map to `TransportError.permissionDenied` with platform-specific
guidance text. Desktop offers a manual port entry fallback.

### 5.3 Platform matrix

| Platform | BLE | Serial | DFU |
|---|---|---|---|
| Windows | universal_ble | libserialport_plus | SecureDfu over BLE |
| macOS | universal_ble | libserialport_plus | nordic_dfu |
| Linux | universal_ble | libserialport_plus | SecureDfu over BLE |
| Android | universal_ble | usb_serial | nordic_dfu |
| iOS | universal_ble | none | nordic_dfu |

### 5.4 Bootloader discovery

The bootloader advertises as `CU` or `CL` over BLE and as VID 0x1915 / PID
0x521F over USB. The update flow sends ENTER_BOOTLOADER, scans for the
bootloader, runs DFU, then scans for the normal device and reconnects.

### 5.5 Platform setup owned here

Android USB device filter and Bluetooth permissions; iOS Bluetooth usage
strings; macOS sandbox entitlements for Bluetooth and serial.

### 5.6 Testing

A transport contract suite that any `Transport` must pass. CI runs it against
`FakeDevice`; developers run it against hardware with the `hardware` tag.

## 6. The `spectra_ui` design system

Built on the `material_ui` 1.0 package, not the in-SDK Material library
(slated for deprecation). Feature screens never construct raw Material
widgets; everything comes from this package.

### 6.1 Tokens

Four const token groups:

- Color: one brand accent, neutral scales, semantic roles (success, warning,
  danger, connected). Light and dark schemes derive from the same tokens.
  Dynamic color is supported on Android but off by default.
- Type: one variable sans via google_fonts, six-step scale.
- Spacing: 4 point scale.
- Motion: three durations, two curves, applied through flutter_animate.

### 6.2 Theme builder

One function turns tokens into `ThemeData` so Material components used inside
the kit match.

### 6.3 Core components (v1)

Each has light and dark goldens.

- App shell with adaptive navigation: bottom bar under 600 logical pixels,
  navigation rail above; desktop title bar via window_manager and
  macos_window_utils.
- Cards, list tiles, section headers, status chip (connection, battery).
- Hex viewer: monospaced, byte grouping, highlight ranges.
- Slot tile: number, nickname, tag types, enabled state.
- Progress and step indicators for long operations.
- Disclosure: summary row that expands to expert detail.
- Buttons, inputs, dialogs, sheets.

### 6.4 Rules

No dependency on the device world. A gallery app in `spectra_ui/example`
shows every component with sample data. Goldens use alchemist and run on
one CI platform to avoid font rendering drift.

## 7. The `app` package: state, routing, storage, features

### 7.1 State

Riverpod 3 with riverpod_generator. `deviceSessionProvider` holds the current
`DeviceSession` or null. Feature providers derive from session streams.
Long operations are async notifiers exposing progress and cancellation.
Nothing outside providers touches the session.

### 7.2 Routing

go_router with the adaptive shell. Top-level destinations: Device, Slots,
Cards, Tools (firmware update, dictionaries, frame log), Settings. Connect is a full-screen route shown when no session
exists. Deep routes (slot editor, dump editor) push on top of their tab.

### 7.3 Storage

Drift, one database. Tables: saved cards (dump bytes, tag type, name, color,
folder), key dictionaries, app preferences. JSON import and export. No cloud.
Features access storage through repository interfaces in `data/`; Drift
appears only inside `data/`.

### 7.4 Emulator mode

The connect screen lists real devices plus "Emulated Chameleon Ultra", and an
emulated Lite behind a developer toggle. Selecting one opens a session on
`FakeDevice`. Every feature works there; it is also how screenshots and manual
QA happen without hardware.

### 7.5 v1 features, in build order

1. Connect and dashboard: discovery, connect, device info, battery, mode,
   firmware version, disconnect.
2. Slots: grid of eight, enable per sense, rename, change tag type, set
   active, save to device.
3. Read cards: scan HF and LF, show identity and detail, read full dump where
   supported, save to library.
4. Write and emulate: load a saved card into a slot, write to a physical card
   for supported types, quick emulate from the library.
5. Firmware update: check release feed, download or pick a local zip, enter
   bootloader, run DFU with progress, reconnect and verify.
6. Dictionaries and settings: key lists; device settings (LEDs, buttons,
   sleep, pairing); app theme and export.

## 8. Internal module structure and extension points

### 8.1 SDK facades

`DeviceSession` exposes typed facades so app code never sends raw commands:

- `session.device`: info, mode, battery, reboot to bootloader.
- `session.slots`: list, select, enable, rename, set type, reset, save.
- `session.reader`: scan, read block or page, authenticate, write.
- `session.emulator`: load and read emulated data, anti-collision, config.
- `session.settings`: get, set, save, reset.
- `session.firmware`: enter bootloader, version checks.

Multi-command workflows are one method (for example `slots.rename` sends the
nickname command then the save command).

### 8.2 Registries instead of switches

- `CardCodec` registry, one codec per tag family: parse a dump, describe it,
  load it into a slot, write it to a card. Reader and library screens ask the
  registry; nothing switches on tag type outside it.
- Transport registry in `chameleon_flutter`: scanners are a list. Serial DFU
  later is one new entry.
- `FeatureModule` registry in the app: each feature exports routes, an
  optional navigation destination, and provider overrides. The shell assembles
  from a list.

### 8.3 App feature layout

```
app/lib/
  core/           session provider, storage wiring, logging, error mapping, shell
  data/           repository interfaces and Drift implementations
  features/
    connect/      module.dart, state/, ui/, connect.dart (barrel)
    dashboard/
    slots/
    cards/
    tools/
    settings/
```

Features import `core`, `data` interfaces and `spectra_ui`. They never import
another feature's internals. Shared needs move to `core` or become a public
method on the other feature's barrel, as a deliberate decision.

### 8.4 Enforcement

A dependency lint in CI fails when: a feature imports another feature's
internals; the app imports Drift outside `data/`; anything outside
`chameleon` imports command classes; any package violates the table in
section 2. Files stay under about 300 lines and hold one public type.
Screens are layout only; logic lives in notifiers unit-tested without
widgets.

### 8.5 Interfaces at every seam

Repositories, transports, scanners, DFU runners and the session are
abstract, each with a fake, so any layer can be replaced or tested alone.

## 9. Error handling and logging

- Errors stay typed to the UI. The app maps each `DeviceError`,
  `TransportError` and `DfuError` to a user message plus a recovery action
  (retry, open settings, show platform instructions). A raw detail line is one
  tap away.
- Unexpected disconnects drop the session and return to the connect screen
  with the last device preselected for one-tap reconnect.
- Long operations are cancellable and always restore device mode.
- A frame log ring buffer (sent and received) is viewable in the app and
  exportable as text. Off by default in release, toggled in settings.

## 10. Testing, CI and release

Testing pyramid:

- `chameleon`: unit tests for codec, every command, session behavior and
  DFU state machine, all against `FakeDevice`. Target near full coverage.
- `chameleon_flutter`: transport contract suite against the fake in CI,
  against hardware locally with the `hardware` tag.
- `spectra_ui`: goldens for every component in light and dark.
- `app`: widget tests per screen against a fake session; integration_test
  flows for connect, slot edit, read and save, and DFU, all in emulator mode.

CI on GitHub Actions: one job runs format, analyze, dependency lint and all
tests on Ubuntu. A build matrix produces Windows, macOS, Linux, Android and
iOS artifacts on tags. Signing and notarization are added at the first
release.

Release: semantic versions, one version across packages, a changelog.
Desktop ships as a signed installer per platform, Linux as an AppImage.
Mobile stores are a later step.

## 11. Open items to validate on hardware

The wiki lags firmware for several payload formats (commands 2013-2017,
2020, 3004 and later, 4031 and later, 5004 and later, 6xxx, SEOS, and the
settings payload length). These commands are tagged `hardware-validate` in
the SDK and are checked on a device before the corresponding UI ships.
