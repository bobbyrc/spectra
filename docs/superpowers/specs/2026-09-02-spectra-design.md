# Spectra design spec

Date: 2026-09-02 (revised after adversarial review the same day)
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
  GPL-3.0) is used only to cross-check behavior and to learn its data
  formats, never copied.
- Custom design system (own tokens and core components) on Material 3.
- Foundation-first build order: design system, SDK, transports, then
  feature screens.
- Everything must work without hardware, through a fake device in tests and
  an emulator mode in the app.
- A failed firmware update must never leave the user without a recovery path
  from Spectra itself (section 5.6).

v1 features: connect and device dashboard, slot management, read, write and
emulate cards, card dump editor, firmware update (DFU over BLE and USB), key
dictionaries, import from the reference app, and settings.

Out of scope for v1: key recovery computations (the CPU-heavy routines the
reference app runs in C), web target, cloud sync, plugins, multi-device
sessions (but see 7.1), dynamic color, custom desktop window chrome.

## 2. Workspace layout and dependency rules

The repo is a pub workspace with four member packages. Melos is used only for
scripts (test all, format all), not for versioning.

```
spectra/
  pubspec.yaml            # workspace root
  mise.toml               # Flutter / Dart pins
  packages/
    chameleon/            # pure Dart device SDK
    chameleon_flutter/    # platform transports and DFU channels
    spectra_ui/           # design system
  app/                    # the Spectra app
  docs/
  tool/                   # CI and release scripts
```

Dependency direction is one way and enforced by a CI lint that fails on any
forbidden import.

| Package | May depend on | Must not depend on |
|---|---|---|
| chameleon | Dart SDK, meta, collection, freezed, archive (zip reading), crypto (DFU init-packet hash) | flutter, any plugin |
| chameleon_flutter | chameleon, flutter, universal_ble, libserialport_plus, usb_serial | spectra_ui, app |
| spectra_ui | flutter, material_ui, google_fonts, flutter_animate, flutter_localizations, intl | chameleon, chameleon_flutter |
| app | all three packages, riverpod, go_router, drift, flutter_localizations, wakelock_plus | nothing further restricted |

Consequences:

- All hardware-facing behavior is verified by `dart test` inside `chameleon`
  with no Flutter engine.
- The design system is developed and golden-tested against sample data, so a
  protocol change can never break a widget test.
- Codegen uses build_runner (freezed, json_serializable, riverpod_generator,
  drift). Generated files are committed. CI regenerates and fails if the
  result differs from what is committed.
- Package names are lowercase snake. The SDK is named `chameleon`, not
  `chameleon_ultra`, because it also serves the Lite.
- Versioning: `chameleon` and `chameleon_flutter` are versioned together as
  the SDK and can be published on their own. `spectra_ui` and `app` share the
  app version.

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
  value that means success for its range: 0x68 for 1xxx, 4xxx and 5xxx; 0x00
  for 2xxx; 0x40 for 3xxx; 0x00 for 6xxx pending hardware validation.
- Grouped in files by firmware range: `device` (1000-1040), `hf_reader`
  (2000-2201), `lf_reader` (3000-3032), `hf_emulator` (4000-4044),
  `lf_emulator` (5000-5013), `iso14443_4` (6000-6005). These catalog files
  are the one exception to the one-public-type-per-file rule in 8.5.
- Decoders are tolerant by default: unknown trailing bytes are ignored and a
  short payload produces a typed `MalformedResponse` error, never an
  uncaught exception. Version-dependent payloads (settings, 1034) decode by
  their leading version byte.
- Commands whose payload format the wiki leaves uncertain carry a doc comment
  and the test tag `hardware-validate` so they can be found and checked on a
  device.
- Commands are internal to the SDK. App code uses the facades in section 4.

### 3.3 Typed results and errors

- Firmware status maps to a sealed `DeviceError` hierarchy covering every
  documented code: HF tag not found, HF tag error (CRC, BCC, parity,
  collision, ATS, generic), authentication failed, LF tag not found, LF login
  required, parameter error, device mode error, invalid command, not
  implemented, flash write, flash read, invalid slot type, memory, create
  response, command error. Unknown codes map to `DeviceError.unknown(code)`.
- `TransportError` (disconnected, permission denied, port busy, not found,
  pairing required) and `CommandTimeout` are separate types so the UI can
  tell "card not present" from "device unplugged".
- Callers never see raw status integers.

### 3.4 Models

Immutable freezed types: `DeviceInfo` (model, app version, git version, chip
id, address), `DeviceIdentity` (chip id; see 4.2), `Capabilities`, `Slot`
(index, hf and lf tag types, enabled per sense, nicknames per sense),
`TagType` enum with wire codes and a family classification (LF, MIFARE
Classic, Ultralight/NTAG, ISO14443-4, SEOS), `DeviceSettings`,
`ButtonFunction`, `AnimationMode`, `BatteryInfo`, `DeviceMode`.
Capabilities gate features in the UI, so the Lite never shows reader
features.

### 3.5 Dump formats

`DumpFormat` is a pure abstraction, one implementation per tag family: parse
a dump into a typed structure, describe it for display, validate it, and
serialise it back. The family is chosen by `TagType.family`. UI code may
switch on family; the enforced rule is that nothing outside the SDK
switches on raw wire codes.

### 3.6 Testing

Every command has encode and decode tests using byte vectors derived from the
firmware sources, including the documented ENTER_BOOTLOADER frame
`11 EF 03 F2 00 00 00 00 0B 00`. The decoder has fragmentation, resync,
corruption, short-payload and long-payload tests.

## 4. The `chameleon` SDK: transport, session, fake and DFU

### 4.1 Transport interface

```dart
abstract class Transport {
  Future<void> open();
  Future<void> close();
  Stream<Uint8List> get incoming;
  Future<void> write(Uint8List bytes);
  int get maxWriteLength;
  // opening, open, closed(cause), pairingRequired, permissionDenied, adapterOff
  Stream<TransportState> get state;
}
```

Transports move bytes only and know nothing about frames. `closed(cause)`
carries whether the close was requested, expected (bootloader reboot) or
unexpected (cable pulled, link lost). `permissionDenied` and `adapterOff`
join `pairingRequired` as states that are not closes but still mean the link
will carry nothing, so the app can show the permission or "turn Bluetooth on"
step (spec 5.1) rather than a connection error; the session maps all three to
`SessionDisconnected(unexpected)` carrying the matching typed error.
`maxWriteLength` is informational — the dispatcher never chunks, because
every request fits in one frame.

### 4.2 Discovery and identity

`DeviceScanner` yields `DiscoveredDevice` (display name, transport kind,
transport identifier, isBootloader). Multiple scanners run concurrently and
their results are merged.

`DeviceIdentity` is the chip id (command 1011), known only after a
handshake. The app persists a map from identity to last-seen transport
identifiers and display name. The connect screen merges discovered entries
by identity when known, otherwise by name plus transport kind, and shows one
row per device with transport badges. "Reconnect to last device" uses this
map.

The SDK ships `FakeScanner`, which lists one emulated device.

### 4.3 DeviceSession and its state machine

The single owner of a connection. It wraps a transport and the codec.

States:

- `connecting`: transport opening, handshake running.
- `ready`: handshake passed; all facades available.
- `limited(reason)`: transport open but the handshake found unsupported
  firmware (pre-2.0, higher major, or legacy 0.1). Only `device.info` as far
  as known and `firmware.enterBootloader()` are available. This is the path
  by which outdated devices get updated.
- `updating`: the session has sent ENTER_BOOTLOADER on purpose. The transport
  close that follows is expected and does not count as a disconnect.
- `disconnected(cause)`: closed, with the cause from the transport.

`connectionState` is derived from `Transport.state` plus the handshake
outcome; it is the only state the app routes on.

Handshake to reach `ready`: capabilities (1035), app version (1000), model
(1033). Everything else (git version, chip id, address, mode, active slot,
slot info, enabled slots, nicknames, settings, battery) is loaded after
`ready` by the facades that need it, in the background, and a failure there
yields partial state with a typed error, never a refused session. Nicknames
use 1038 when the capability list includes it, otherwise 1008 per slot.

Command dispatch: `Future<R> send(Command<R>)` is internal. It queues
commands, keeps one in flight, matches responses by command id plus a
per-dispatch generation token so a late response to an abandoned command is
discarded, and applies a per-command timeout (3 s default, per-command
override for slow reader operations). One retry on timeout for idempotent
read commands only.

Cancellation: cancelling a pending command drops its future immediately and
puts the session into a `draining` sub-state until that command's response
arrives or its timeout elapses. Nothing is dispatched while draining. The
firmware has no wire-level cancel, so this is the honest contract.

Reader mode is a lease: `acquireReaderMode()` returns a disposable, the
session switches to reader mode when the count goes from zero to one and
back to emulator mode when it returns to zero, including on error.

Cached state as streams: `deviceInfo`, `slots`, `activeSlot`, `settings`,
`battery`, `mode`, `connectionState`. Cache contract: every facade call that
changes device state updates the cache from its own response (write-through).
In addition an idle poll refreshes `activeSlot`, `mode` and `battery` every
few seconds while no lease and no long operation is active, so a slot change
made with the device buttons appears in the app. The first battery read is
delayed until roughly five seconds after connect because the firmware reports
garbage before that.

Typed facades expose domain operations (see 8.1): `device`, `slots`,
`reader`, `emulator`, `settings`, `firmware`.

### 4.4 FakeDevice

An in-memory `Transport` that behaves like firmware: parses frames, holds
eight slots, settings, mode and battery, and answers every device, emulator
and settings command. Reader commands are scripted: tests and the emulator
mode load `FakeCard` data so scans succeed or fail on demand. It is
configurable as Ultra or Lite, with a chosen firmware version and capability
list (so version skew is tested: 2.0 without 1038, 2.1, 2.2 with SEOS, and
pre-2.0), with injected latency, corruption and disconnects, and with a
bootloader mode that speaks Secure DFU over a `FakeDfuChannel`.

There is exactly one fake, at the transport level. Every test above it runs
the real `DeviceSession`.

### 4.5 DFU

- `DfuPackage` reads an nrfutil zip (manifest.json, .bin, .dat), validates
  the manifest, and reports hardware version (0 Ultra, 1 Lite). The app
  checks it against the connected model before sending ENTER_BOOTLOADER.
- `SecureDfu` is one pure-Dart Nordic Secure DFU protocol v1 state machine
  driving object transfer over an abstract `DfuChannel`, with progress,
  cancellation and a 30 s bootloader inactivity budget. It is the only DFU
  implementation; there is no native DFU library.
- `DfuChannel` is a small interface: write control, write data, receive
  notifications. The Flutter package supplies a BLE channel and a serial SLIP
  channel.
- `DfuOrchestrator` in the SDK runs the whole update: model check, move the
  session to `updating`, send ENTER_BOOTLOADER, scan for the bootloader,
  open a channel, run `SecureDfu`, then scan for the normal device and
  reconnect. It also accepts a device that is already in the bootloader as
  its starting point.

## 5. The `chameleon_flutter` package: platform transports

Contains every native dependency and nothing else.

### 5.1 BLE transport

universal_ble on all five platforms. Scan filters on the Nordic UART service
`6E400001-B5A3-F393-E0A9-E50E24DCCA9E` and the name prefixes
`ChameleonUltra` and `ChameleonLite`. On connect: subscribe to notify
`6E400003`, use the platform-reported maximum write length (the firmware
requests MTU 247; the app never assumes it), write to `6E400002` with
response, in chunks of that length. Connect retries up to five times with
backoff.

Runtime behavior per platform:

- Permissions: Android 12+ BLUETOOTH_SCAN and BLUETOOTH_CONNECT, older
  Android location; iOS and macOS usage strings. The transport reports
  `permissionDenied` and `adapterOff` states so the app can show the right
  step.
- Pairing: on Android, iOS and macOS the OS prompts. On Windows the
  transport drives pairing through universal_ble's pair call. On Linux the
  transport attempts pairing through universal_ble and, if BlueZ has no
  agent, reports `pairingRequired` with instructions to pair from system
  settings using the default passkey. `pairingRequired` is detected from an
  insufficient-authentication error on subscribe or write.
- Device sleep: the device sleeps eight seconds after losing a connection.
  The connect screen tells the user to press a button on the device if a
  scan finds nothing.
- Settings copy warns that enabling pairing on the device makes it invisible
  to other hosts until bonds are cleared.

### 5.2 Serial transport

libserialport_plus on desktop, usb_serial on Android. Discovery filters on
VID 0x6868 / PID 0x8686 and manufacturer "Proxgrind". Opens at 115200 8N1.
Control line handling (DTR only versus RTS/CTS and DTR/DSR, which the two
research notes disagree on) is tagged `hardware-validate` and tried both
ways. Windows access-denied and Linux permission failures map to
`permissionDenied`; a port held by another process (ModemManager on Linux is
the usual cause) maps to `portBusy`. Each has platform-specific guidance
text, including the udev rule and dialout group on Linux. Desktop offers a
manual port entry fallback. An early spike validates libserialport_plus build
hooks on all three desktop targets, including macOS sandbox and Windows
signing, before the package is committed to.

### 5.3 DFU channels

- `BleDfuChannel`: the Nordic DFU service FE59 with control point 8EC90001
  and packet 8EC90002. Write size 20 bytes on iOS and macOS, up to the
  platform maximum elsewhere.
- `SlipSerialDfuChannel`: SLIP framing over the serial transport for desktop
  and Android USB.

### 5.4 Platform matrix

| Platform | BLE | Serial | DFU |
|---|---|---|---|
| Windows | universal_ble | libserialport_plus | SecureDfu over BLE or USB |
| macOS | universal_ble | libserialport_plus | SecureDfu over BLE or USB |
| Linux | universal_ble | libserialport_plus | SecureDfu over BLE or USB |
| Android | universal_ble | usb_serial | SecureDfu over BLE or USB |
| iOS | universal_ble | none | SecureDfu over BLE |

### 5.5 Bootloader discovery

The bootloader advertises as `CU` or `CL` over BLE and enumerates as VID
0x1915 / PID 0x521F over USB. Bootloader devices appear on the connect
screen with a "recover" action that starts the DFU orchestrator directly.

### 5.6 Device recovery guarantee

The Nordic bootloader is never overwritten by an application update, so a
failed or interrupted update leaves the device in the bootloader, and holding
button B while plugging in USB enters the bootloader from any state. Spectra
must therefore always be able to complete an update over USB from a desktop.
Rules:

- USB DFU on desktop is implemented and validated on real hardware first.
- BLE DFU on desktop is enabled only after USB DFU has recovered a device
  from a deliberately interrupted BLE update.
- iOS DFU is enabled only after the two steps above, and the iOS update
  screen links to the recovery instructions.
- The app keeps a wakelock and blocks navigation during a flash.

### 5.7 Platform setup owned here

Android USB device filter and Bluetooth permissions; iOS Bluetooth usage
strings; macOS sandbox entitlements for Bluetooth and serial.

### 5.8 Testing

A transport contract suite that any `Transport` must pass. CI runs it against
`FakeDevice`; it is also run against real hardware with the `hardware` tag.
The spec is explicit about what fakes cannot catch: pairing, MTU negotiation,
timing, device sleep, OS permissions, Windows COM and Linux ModemManager
behavior. Those are covered by a hardware checklist that is a release gate
(section 10).

## 6. The `spectra_ui` design system

Built on the `material_ui` 1.0 package. The in-SDK Material library is slated
for deprecation, so starting on it would mean a migration within the year.
`spectra_ui` wraps `material_ui` components and exposes its own `SpectraTheme`
inherited widget. No bridge to an in-SDK `ThemeData` is written: Spike B
(`docs/research/spikes.md`) found go_router already depends on `material_ui`
and alchemist needs no `ThemeData` from us, and `material_ui` ships
`MaterialUiCompatibilityBridge` should some later dependency need one. The
enforced rule is a lint against `package:flutter/material.dart` imports under
`app/lib/features`. Spike B confirmed material_ui 1.1.1 coexists with go_router
and alchemist before the kit is built out.

### 6.1 Tokens

Four const token groups:

- Color: one brand accent, neutral scales, semantic roles (success, warning,
  danger, connected). Light and dark schemes derive from the same tokens.
- Type: one variable sans via google_fonts, six-step scale.
- Spacing: 4 point scale.
- Motion: three durations, two curves, applied through flutter_animate.

### 6.2 Core components (v1)

Each has light and dark goldens.

- App shell with adaptive navigation: bottom bar under 600 logical pixels,
  navigation rail above. Native window chrome on desktop.
- Cards, list tiles, section headers, status chip (connection, battery).
- Hex viewer: monospaced, byte grouping, highlight ranges.
- Slot tile: number, nickname, tag types, enabled state.
- Progress and step indicators for long operations.
- Disclosure: summary row that expands to expert detail.
- Buttons, inputs, dialogs, sheets.

### 6.3 Rules

No dependency on the device world. A gallery app in `spectra_ui/example`
shows every component with sample data. Goldens use alchemist and run on
one CI platform to avoid font rendering drift. All user-facing strings in
the kit go through localization (section 7.6).

## 7. The `app` package: state, routing, storage, features

### 7.1 State

Riverpod 3 with riverpod_generator. `deviceSessionProvider` is a family
keyed by `DeviceIdentity`; `activeDeviceProvider` names the one the UI shows.
Features read the active session only. Multi-device is not built, but this
shape means adding it later does not touch feature code. Feature providers
derive from session streams. Long operations are async notifiers exposing
progress and cancellation. Nothing outside providers touches the session.
Riverpod overrides are used at the app root only, to inject the fake in
emulator mode and tests.

### 7.2 Routing

go_router with the adaptive shell. Top-level destinations: Device, Slots,
Cards, Tools (firmware update, dictionaries, frame log), Settings. Routing
is driven by `connectionState`: no session or `disconnected` shows the
full-screen connect route; `limited` shows a reduced dashboard whose only
action is update; `updating` locks navigation on the update screen. Deep
routes (slot editor, dump editor) push on top of their tab.

### 7.3 Storage

Drift, one database. Tables: saved cards (dump bytes, tag type, name, color,
folder), key dictionaries, known devices (identity to transport map), app
preferences. Drift schema migrations with generated schema-verification
tests from the first table. Features access storage through repository
interfaces in `data/`; Drift appears only inside `data/`.

Import and export: Spectra's own format is versioned JSON with a
`schemaVersion`. Import from the reference app's JSON export is a v1
requirement for cards and dictionaries, with fixtures built from the
documented format. No cloud.

### 7.4 Lifecycle

- App paused (mobile background): the session is kept for 30 seconds then
  closed. On resume, one silent reconnect to the last device identity is
  attempted.
- USB detach or BLE link loss: the session closes immediately with an
  unexpected cause; the app returns to the connect screen with that device
  preselected.
- During a flash or a reader lease the app holds a wakelock.
- Host sleep mid-flash is treated as a failed update; recovery follows 5.6.

### 7.5 Emulator mode

The connect screen lists real devices plus "Emulated Chameleon Ultra".
Selecting it opens a session on `FakeDevice`. Every feature works there; it
is also how screenshots and manual QA happen without hardware. Lite behavior
is covered by configuring the fake in tests, not by a second UI entry.

### 7.6 Localization and accessibility

flutter_localizations with ARB files from the first screen, English only in
v1. The error-to-message mapping is a localized catalog keyed by the sealed
error types. A lint fails on string literals in `ui/` folders. Every
component sets semantics labels and meets minimum touch target and contrast
guidelines.

### 7.7 v1 features, in build order

1. Connect and dashboard: discovery, identity merge, connect, device info,
   battery, mode, firmware version, disconnect, recovery entry for bootloader
   devices.
2. Slots: grid of eight, enable per sense, rename, change tag type, set
   active, save to device. Exposes a slot picker sheet as its public API.
3. Read cards: scan HF and LF, show identity and detail, read full dump where
   supported, save to library.
4. Cards library and dump editor: folders, colors, view and edit dumps
   through the hex viewer, import from the reference app. Exposes a card
   picker as its public API.
5. Write and emulate: load a saved card into a slot, write to a physical card
   for supported types, quick emulate from the library.
6. Firmware update: release feed check, download or local zip, model check,
   orchestrated DFU with progress, reconnect and verify. Delivered in the
   order set by 5.6.
7. Dictionaries and settings: key lists; device settings (LEDs, buttons,
   sleep, pairing); app theme, export.

## 8. Internal module structure and extension points

### 8.1 SDK facades

`DeviceSession` exposes typed facades so app code never sends raw commands:

- `session.device`: info, mode, battery, identity.
- `session.slots`: list, select, enable, rename, set type, reset, save.
- `session.reader`: scan, read block or page, authenticate, write; each
  per-family operation takes keys as parameters, supplied by the app from
  its dictionary repository.
- `session.emulator`: load and read emulated data, anti-collision, config.
- `session.settings`: get, set, save, reset.
- `session.firmware`: enter bootloader, version checks.

Multi-command workflows are one method (for example `slots.rename` sends the
nickname command then the save command).

### 8.2 Extension points

- Dump formats (3.5): a new tag family is one new `DumpFormat` plus its
  reader operations on the facade.
- Transports: `chameleon_flutter` exposes a plain list of scanners; a new
  transport is one entry.
- Features: the shell is assembled from two plain lists, routes and
  navigation destinations. No provider scoping is attempted, because
  riverpod_generator providers are global.

### 8.3 App feature layout

```
app/lib/
  core/           session providers, storage wiring, logging, error catalog, shell, lifecycle
  data/           repository interfaces and Drift implementations
  features/
    connect/      state/, ui/, connect.dart (barrel)
    dashboard/
    slots/
    cards/
    tools/
    settings/
```

Features import `core`, `data` interfaces and `spectra_ui`. They never import
another feature's internals. Cross-feature needs are declared up front as
each feature's public API in its barrel: `slots` exports the slot picker and
its providers; `cards` exports the card picker and its providers. Anything
else that two features need moves to `core` as a deliberate decision.

### 8.4 Enforcement

A dependency lint in CI fails when: a feature imports another feature's
internals; the app imports Drift outside `data/`; anything outside
`chameleon` imports command classes; `package:flutter/material.dart` is
imported under `app/lib/features`; any package violates the table in
section 2.

### 8.5 Code shape

Files stay under about 300 lines and hold one public type, except the
command catalog files (3.2). Screens are layout only; logic lives in
notifiers unit-tested without widgets.

### 8.6 Interfaces at every seam

Repositories, transports, scanners, DFU channels and the transport-level
fake are abstract. The session is concrete and is always the real one in
tests.

## 9. Error handling and logging

- Errors stay typed to the UI. The localized catalog maps each `DeviceError`,
  `TransportError`, `CommandTimeout` and `DfuError` to a user message plus a
  recovery action (retry, open settings, show platform instructions). A raw
  detail line is one tap away.
- Unexpected disconnects follow 7.4.
- Long operations are cancellable with the semantics in 4.3 and always
  release their reader lease.
- A frame log ring buffer (sent and received, a few kilobytes) is always on.
  Viewing it in the Tools tab and exporting it as text are available in every
  build, because it is the first thing asked for in a bug report.

## 10. Testing, CI and release

Testing pyramid:

- `chameleon`: unit tests for codec, every command, session state machine,
  cache and lease behavior, cancellation, and the DFU state machine, all
  against `FakeDevice` across its firmware version matrix. Target near full
  coverage. Stated limit: for `hardware-validate` commands the encoder and
  the fake share the same assumptions, so those are only proven on hardware.
- `chameleon_flutter`: transport contract suite against the fake in CI,
  against hardware with the `hardware` tag.
- `spectra_ui`: goldens for every component in light and dark.
- `app`: widget tests per screen against the real session on `FakeDevice`;
  integration_test flows for connect, slot edit, read and save, import, and
  DFU with the fake bootloader, all in emulator mode.

Hardware checklist, run before every release on an Ultra over USB and BLE
from macOS at minimum: connect, pairing, slot round trip, HF and LF scan,
USB DFU, BLE DFU, recovery from interrupted DFU. This gate is not optional.

CI on GitHub Actions: on every pull request, one job runs format, analyze,
dependency lint, codegen freshness and all tests on Ubuntu, and a matrix
builds a debug binary for Windows, macOS, Linux, Android and iOS so platform
breakage surfaces early. Tagged builds produce release artifacts. Signing
and notarization are added at the first release.

Release: semantic versions, a changelog. Desktop ships as a signed installer
per platform, Linux as an AppImage. Mobile stores are a later step.

## 11. Open items to validate on hardware

The wiki lags firmware for several payload formats (commands 2013-2017,
2020, 3004 and later, 4031 and later, 5004 and later, 6xxx, SEOS, and the
settings payload length), and the serial control-line configuration is
disputed between sources. These are tagged `hardware-validate` in the SDK and
are checked on a device before the corresponding UI ships. Two spikes run
before foundation work is committed: libserialport_plus build hooks on all
desktop targets, and material_ui coexistence with go_router and alchemist.
