# Spectra: agent context

Spectra is a polished, cross-platform companion app for the Chameleon Ultra
(open-source NFC/RFID research hardware by RfidResearchGroup). Targets:
Windows, macOS, Linux, iOS, Android. Goal: the one-stop shop for the device,
serving both first-time hobbyists and security researchers through
progressive disclosure (simple default path, expert detail one tap away).

## Current status (2026-09-03)

Phase 0 (foundation) is complete: pub workspace, lint and CI tooling, and both
package spikes are done and merged to `bobbyrc/chinook`.

- Spike A: keep `libserialport_plus` 1.0.4; build hooks verified on
  macOS/Windows/Linux; `open()` and the serial entitlement's necessity are
  deferred to hardware handoff H1.
- Spike B: build `spectra_ui` on `material_ui` 1.1.1; no `ThemeData` bridge
  file needed; spec section 6 amended to match.

Phase 2 (`packages/spectra_ui`) is complete (2026-09-03): tokens and
`SpectraTheme` on `material_ui` 1.1.1, every spec 6.2 component with CI
goldens that obscure text and verify layout/colour/shape, the string
literal lint live, ARB localization, and a component gallery that builds
on macOS.

Phase 1 (`packages/chameleon`) is complete (2026-09-03): the pure-Dart,
clean-room SDK — LRC framing and a resynchronising decoder, the full command
catalog (internal), freezed models, `Transport`/`DeviceScanner` seams, a
`FakeDevice`/`FakeFirmware` that speaks the real protocol across the whole
firmware version matrix, `DeviceSession` (handshake, connection state,
dispatch with timeouts/retry/cancellation, reader lease, write-through cache
and idle poll) with six typed facades, MIFARE Classic/Ultralight/EM410x dump
formats, and Nordic Secure DFU with an orchestrator and recovery path. 319
tests, no hardware needed; 91.5% line coverage of the hand-written sources.
See `packages/chameleon/README.md`.

Phase 3 (`packages/chameleon_flutter`) is complete (2026-09-03): BLE and
serial transports behind the `BleAdapter`/`SerialPortAdapter` seams,
`BleScanner`/`SerialScanner` (identical stream semantics) and `mergedScan`
over them, `BleDfuChannel`/`SlipSerialDfuChannel`,
`ChameleonTransports.defaultScanners`/`transportFor`, the transport contract
suite (tagged `hardware` for the real-device run), and the `serial_probe`
example app for hardware handoff H1. The H1 section of
`docs/hardware-checklist.md` is written and every item is still pending the
user's report; the serial control-line default is `SerialControlLineMode
.dtrOnly`, provisionally, until H1 comes back. BLE DFU stays behind the
`dfuOverBleEnabled` flag until H2. Run the hardware checks with
`flutter test --tags hardware --run-skipped test/contract` from
`packages/chameleon_flutter`.

Phase 4 (`app/`) is complete (2026-09-03): the app shell. `app/lib/core/`
has `session` (the session registry keyed by `DeviceIdentity`, registered
after the handshake), `discovery` (built on `chameleon_flutter`'s
`mergedScan`), `routing` (redirect on `connectionState`), `lifecycle`
(background grace period, one silent reconnect, wakelock), `errors` (the
error catalog and frame log) and `flags` (`dfuOverBleEnabled`, off by
default). `app/lib/data` is Drift at schema version 1 plus in-memory
repositories, both behind `data/data.dart` — features never import
`data/database/`. `app/lib/features/` has `connect`, `dashboard` and `tools`
built out; `slots`, `cards` and `settings` are placeholders for Phases 5, 6
and 9, and the update screen (`tools`) is a placeholder that already carries
the recovery target and the `dfuOverBleEnabled` notice. The test harness is
`app/test/support/app_harness.dart`: `testWidgetsApp` builds the app under
test with provider overrides, and `connectToEmulator` drives a widget
tester through discovery and connect to the emulated device. The gate is
`app/test/flows/connect_flow_test.dart` (every CI job) with a
`integration_test/` twin that runs the same flow on a real engine on
`macos-latest`, push-only. Emulator mode defaults to on: the connect screen
lists the emulated Chameleon Ultra alongside any real devices, so
`cd app && flutter run -d macos` (or any desktop target) reaches a working
dashboard with no hardware attached.

Phase 5 (`app/lib/features/slots/`) is complete (2026-09-03): the slots
grid, the slot editor (rename with byte-level validation, per-sense enable,
tag type, clear, set active), every mutation written through `SlotsFacade`
with no re-read, failures rendered through the error catalog, and
`showSlotPicker` exported from `features/slots/slots.dart` as the public API
Phase 6 and 7 consume — it returns a wire index (0..7) or `null`, never the
1..8 the device prints. The test harness gained `keepAlive` (holds a
listener on an autoDispose provider before it is read), `readProvider`
(reads through the pumped app's own container), and `openSlots`/`openSlot`
(drive from the dashboard to a slot or the picker). `core/routing/
sub_page_scaffold.dart` is the promoted, shared `SubPageScaffold({title,
body})` that `slots`, `frame_log` and `update` now all use. Gate green:
`app/test/flows/slot_edit_flow_test.dart` (192 app tests) and
`app/integration_test/slot_edit_flow_test.dart` (picked up by the existing
macOS CI `integration` job) edit and save a slot on the emulator.

Phase 6 (`app/lib/features/cards/`) is complete (2026-09-03): reading a card
through `ReaderFacade` under its own reader lease with progress and cancel,
the saved-cards repository (Drift and in-memory) behind
`savedCardsRepository`, the library list with search/folders/sort, the card
detail screen with a hex viewer and a chunk editor (working-copy edits, an
unsaved-changes guard on Back), import of the reference app's JSON export
plus Spectra's own versioned export, and the public `showCardPicker` API —
it returns the chosen `SavedCard` or `null` and is exported from
`features/cards/cards.dart`, published for a later consumer (Phase 7 does
not call it yet). The emulated device now presents demo cards to every read
through `emulatorAwareTransport`, so the whole feature works in emulator
mode with no hardware (spec 7.5). Error surfaces share `ProblemView` from
`core/errors/`; tag-type product names render through
`core/format/tag_labels.dart`, not the SDK's raw enum names. Gate green:
`app/test/flows/cards_flow_test.dart` (295 app tests) and
`app/integration_test/cards_flow_test.dart` (picked up by the existing
macOS CI `integration` job) scan, save, edit and import on the emulator.
Reading a real card is hardware-validate: see `docs/hardware-checklist.md`
H1 and H3.

Phase 7 (write and emulate) is complete (2026-09-03): the SDK gained
`ReaderFacade.mf1WriteDump` and `ReaderFacade.em410xWriteToT55xx`, with
`FakeDevice` answering EM410X_WRITE_TO_T55XX. `app/lib/features/cards/`
gained `state/write_target.dart` (`SlotLoadMethod`/`CardWriteMethod` per tag
type, and the shared `unreadSectors` predicate both writers gate on),
`SlotLoader` and `CardWriter`, the load-to-slot and write-to-card sheets
(both a `PopScope(canPop: !state.busy)` while a write is in flight), and
quick emulate from the read screen. The shared `ProblemView` now hides its
action entirely for `ErrorRecovery.none` rather than offering a dead "Try
again". Entry points are on the card detail page and the read screen;
"which slot?" goes through the Slots feature's published `showSlotPicker`,
so the feature dependency runs one way, `cards -> slots`. The enforced gate
is the widget flow `app/test/flows/write_emulate_flow_test.dart` (every CI
job); its `app/integration_test/load_to_slot_flow_test.dart` twin runs in
the existing macOS `integration` job once it lands. Writing a physical card is
`hardware-validate`; the write sheet carries a standing on-screen notice
(`cardsWriteNotice`) until H3 reports otherwise.

Phase 8 (firmware update) is complete (2026-09-03): firmware update over a
local nrfutil package, both entry points. The SDK closed the two gaps
Phase 3 parked — `DfuOrchestrator` no longer lets a pre-stream failure
escape `run()` as a raw stream error, and `SecureDfu`/`SlipSerialDfuChannel`
now query `GetSerialMTU` (opcode `0x07`) and size serial writes from the
answer instead of a fixed 64 bytes; the DFU stack no longer `await`s
`StreamSubscription.cancel()` (the same root-zone-future hazard Phase 4
found in `DeviceSession`/`CommandDispatcher`, this time in
`ResponseQueue`/`SecureDfu`/the reboot wait). `chameleon_flutter` gained the
negotiated serial write size end to end, and both DFU channels flash the
fake bootloader in tests. `app/lib/core/dfu/` is the runtime that decides
which channel and scanners a run uses (`dfuActivityProvider`,
`dfuChannelOpenerProvider`, `dfuScannersProvider`); `features/tools/state/
update_controller.dart`'s `UpdateController` drives `DfuOrchestrator` and
reports phase/progress/cancellation; routing locks to the update screen and
the wakelock holds for the whole flash (spec 5.6, via `redirectFor`'s
`updating` parameter, which outranks connection state so the bootloader-only
recovery path is never routed away from). The update screen
(`features/tools/ui/update_page.dart`) covers package pick, run and
recovery, entered from a connected device or from the connect screen's
`?recover=` link. USB DFU is enabled; BLE and iOS stay behind
`dfuOverBleEnabled` (still off) until hardware handoff H2 reports USB DFU
and recovery passing (spec 5.6). Gate green:
`app/test/flows/firmware_update_flow_test.dart` (every CI job) and its
`app/integration_test/firmware_update_flow_test.dart` twin (existing macOS
`integration` job). Next: Phase 9.

Next: Phases 9 (dictionaries and settings) and 10 (release) are executing
concurrently — plans and ledgers exist for both under
`docs/superpowers/plans/` and `.superpowers/sdd/`.

Draft PR #1 (`bobbyrc/chinook` -> `main`) carries CI on every push; see
"Decisions made overnight" below.

Design spec approved (including an adversarial-review revision):
`docs/superpowers/specs/2026-09-02-spectra-design.md`. Rationale in
`docs/research/DECISIONS.md`.

Plans, in `docs/superpowers/plans/`:

- `2026-09-02-spectra-v1-roadmap.md`: the ten phases, gates and the three
  hardware handoffs. Start here.
- `2026-09-02-phase-0-foundation.md`: toolchain, workspace, lint, CI, spikes
  (complete).
- `2026-09-02-phase-1-chameleon-sdk.md`: the pure-Dart SDK, task by task
  (complete).
- `2026-09-03-phase-2-design-system.md`: the design system on `spectra_ui`
  (complete).
- `2026-09-03-phase-3-transports.md`: USB serial and BLE transports,
  scanners and the platform seams (complete).
- `2026-09-03-phase-4-app-shell.md`: app shell and connect, from spec
  7.1-7.5, 8.3, 8.4 and 9 (complete).
- `2026-09-03-phase-5-slots.md`: slots grid and editor, from spec 7.7 step 2
  and 8.3 (complete).
- `2026-09-03-phase-6-cards.md`: read cards, library, dump editor, import
  (complete).
- `2026-09-03-phase-7-write-emulate.md`: load to slot, write to card, quick
  emulate, from spec 7.7 step 5 (complete).
- `2026-09-03-phase-8-firmware-update.md`: release feed, package pick,
  orchestrated DFU UI, recovery flow (written).
- `2026-09-03-phase-9-dictionaries-settings.md`: key lists, device settings,
  app settings, export (written).
- `2026-09-03-phase-10-release.md`: signing, notarization, installers,
  changelog, `v1.0.0-rc.1` (written).

Execute plans with superpowers:subagent-driven-development. Hardware steps
need the user's device and never block progress: build against the fake,
keep `docs/hardware-checklist.md` current, and gate BLE and iOS DFU behind
the `dfuOverBleEnabled` flag until the user reports the checks passed.

## Decisions made overnight (2026-09-03, Phase 8)

- Ruling 8-1: `archive` and `crypto` are added to `chameleon_flutter`'s
  test-only dependency allowlist in `tool/src/dep_rules.dart` (+
  `dep_rules_test.dart`) — a DFU test fixture needs them, and dep-lint
  otherwise treats any non-production import as a violation. Test-only,
  never production.
- Ruling 8-2: the update controller's "no target" and "BLE disabled" cases
  are typed `UpdateState`, not `DfuError` routed through the shared error
  catalog — collapsing a typed error into one catalog string would have
  hidden screen-specific copy the update screen needs (see the lessons.md
  entry on this).
- Ruling 8-3: the update screen's step index is recovery-aware. It maps the
  orchestrator's `DfuPhase` to a step rather than always starting at step
  one, so entering through `?recover=` (no preceding "connecting"/"checking
  model" phases) starts the stepper at the phase the orchestrator actually
  reports instead of replaying phases that never happened.
- Ruling 8-4: `app/test/support/dfu_test_support.dart` is a shared test
  harness (fake bootloader wiring, provider overrides) built once and
  reused by every DFU-touching test file rather than duplicated per test.
- Ruling 8-5: dictated-but-unused imports found in review are stripped as
  part of the same fix round, not left for a later pass.
- Ruling 8-6: the wakelock test is rewritten to assert the wakelock during
  *recovery*, not only the ordinary connected-device flash — the two entry
  points are different code paths and both had to be covered.
- Ruling 8-7: the update screen's third routing test drives
  `/tools/update` directly with no session, covering the entry point that
  has no prior connect step (recovery) rather than only the connected one.
- Ruling 8-8: the ARB file's edit order is serialized across concurrent
  phases — Phase 7 Task 9, then Phase 8 Task 9, then Phase 9 Task 6 onward —
  so simultaneous ARB edits from different phases don't race.
- Ruling 8-9 / 10-2: the release feed is deferred to Phase 10; Phase 8
  ships local package selection only, with the official releases URL shown
  as plain text. See `docs/research/DECISIONS.md`, Phase 8, for the three
  reasons; this also corrects the roadmap's Phase 8 deliverable text, which
  had listed a release feed.
- Ruling 8-10: Task 9 does not touch `core/errors/`; the dedicated
  `updateNoTarget`/`updateBleDisabled` catalog wiring was left for Task 10
  (and the fix wave) once both Task 7 and Task 9 had landed, rather than
  having Task 9 guess at catalog shape ahead of its consumers.
- Ruling 8-11: a failed flash on the *connected-device* entry point also
  disconnects the session (`Sessions.disconnect` on the failure path), so
  `SessionUpdating` doesn't pin the router to the update screen after a
  failure the way it correctly does mid-flash. The recovery entry point is
  unaffected — there is no session to disconnect — so its target still
  stays on the update screen (Tools -> Update -> Recover) after a failure.

## Decisions made overnight (2026-09-03, Phase 7)

- `unreadSectors` (`cards/state/write_target.dart`) flags a trailer whose
  **key A alone** is all zero, not "the whole trailer is sixteen zero
  bytes": `mf1ReadDump` always zeroes key A in a read dump (a real card
  never returns its keys), so checking only the full-zero shape would let
  `writeTrailers: true` sail an ordinary read dump through the gate and
  overwrite every sector's real key A with zeros on write (ruling 27).
- `defaultT55xxOldKeyHex` lists `defaultT55xxKeyHex` itself as a candidate
  old key, alongside the two published defaults: `em410xWriteToT55xx`
  leaves a blank with `newKey` as its password, so the next write to the
  same card has to offer that password back or lock Spectra out of a card
  it just wrote (ruling 28).
- `ProblemView` hides its action entirely for `ErrorRecovery.none`, once,
  in the shared widget, rather than per sheet — it previously labelled a
  none-recovery error "Try again" with nothing behind the tap (ruling 29).
- Both the load-to-slot and write-to-card sheets wrap their body in
  `PopScope(canPop: !state.busy)`: a user cannot dismiss a sheet mid-write
  by accident, only by finishing it or tapping Cancel (ruling 30).
- Cancelling a write is a terminal state with its own words
  (`cardsWriteCancelled`, "stopped; amount unknown"), not a `ProblemView`
  branch — `CardWriter.cancel()` discards the partial written/attempted
  counts on purpose, since a cancelled write mid-block leaves the true
  count unknowable (ruling 3).
- `writeTrailers` is opt-in (default `false`) and, even when on, a dump
  carrying any `unreadSectors` is refused until the caller confirms by
  name — the load and write sheets show the flagged sector list as a
  warning, never write it silently (rulings 23, 25).
- LF load-to-slot is narrower than the device on purpose:
  `EmulatorFacade._lfIdCommands` can set an id for six LF families, but
  `slotLoadMethodFor` only ever returns `em410xId` — the read screen has no
  reader path for hidProx/viking/pac/jablotron/idteck, so a saved card can
  never actually carry one (ruling 11; see `DECISIONS.md`).
- A block write that the device refuses outright — `NotImplemented`, or
  `InvalidCommand` when MF1_WRITE_ONE_BLOCK is missing from the device's
  capabilities — bails the whole `mf1WriteDump` immediately instead of
  retrying block by block: every remaining block would fail identically,
  and the error still reaches the user through the existing catalog rather
  than a bespoke one.
- `FakeDevice`'s EM410X_WRITE_TO_T55XX (3001) handler is a guess at
  firmware behaviour, not a verified one: it ignores `oldKeys` entirely and
  answers `LF_TAG_NO_FOUND` for a field holding a non-EM410x card. Flagged
  `hardware-validate` in the SDK and carried to H3 rather than trusted
  as-is (ruling 21).

## Decisions made overnight (2026-09-03, Phase 6)

- Card import in v1 is paste-JSON plus a clipboard export, not a native file
  dialog: a file picker is a new dependency on five platforms and a spec
  section 2 amendment. Phase 9 revisits it with a real file dialog.
- The reference app's JSON field shape is not documented in this repo, so
  the importer's field-name assumptions (`referenceTagNames`, `_readCard`'s
  keys in `features/cards/state/card_import.dart`) are taken from the
  documented names in `docs/research/reference-gui.md` and verified against
  a real export only at hardware handoff H3.
- Ultralight/NTAG physical reads are identity-only in v1: `ReaderFacade` has
  no Ultralight *read* operation, only identify. A card can be identified
  but not dumped until the SDK grows one. Noted as an SDK gap, not a bug.
- `CardLibrary.update` is named `updateCard` because Riverpod's
  `AsyncNotifier` base class already reserves `update`.
- Re-importing the same reference-app export duplicates every card: the
  reference format carries no stable id to de-duplicate against. Accepted
  for v1; Phase 9 backlog.
- A partial import failure (some cards written, then an error) reports the
  honest written count alongside the error, rather than claiming 0 or
  silently swallowing the ones that landed.
- `SubPageScaffold`'s Back button uses Flutter's default
  `Navigator.maybePop` (not go_router's `context.pop()`), so the card
  editor's `PopScope` unsaved-changes guard actually fires — go_router 18's
  `context.pop()` bypasses `PopScope` entirely.
- Phase 8's plan defers the release feed screen to Phase 10; the roadmap
  currently lists it as a Phase 8 deliverable. Reconcile at the Phase 8
  pre-flight.

## Decisions made overnight (2026-09-03, Phase 5)

- Tag-type product names (`MIFARE Classic 1K`, `NTAG215`, `EM410x`) are not
  localized. They live in an exhaustive `switch` in `state/slot_labels.dart`;
  only the empty placeholder and the two sense names go through ARB.
- "Clear slot" calls `SlotsFacade.deleteSense`, not `resetToDefault`. That is
  what "clear the slot" means in the spec; `resetToDefault` is unused and
  left for a future "reset to a factory tag" action.
- `showSlotPicker` returns a wire index (0..7), not the 1..8 display number
  the device prints — documented on the function itself, because an
  off-by-one there is the one thing Phase 6 and 7 could get silently wrong.
- `slotNicknameMaxBytes = 32` is redeclared in the app: the SDK's
  `maxNickBytes` is internal to `packages/chameleon/lib/src` and its check
  throws `ArgumentError` rather than `ChameleonException`, so the app
  validates before sending (source: SET_SLOT_TAG_NICK (1007) `slot(1)
  sense(1) utf8<=32` in `docs/research/chameleon-protocol.md`).
- The wakelock is held during every slot mutation that writes and saves
  (`setEnabled`, `rename`, `setTagType`, `deleteSense`, all wrapped in
  `DeviceSession.busy`) — `setActive` is not wrapped in `busy` and does not
  hold the wakelock, because a single `SET_ACTIVE_SLOT` is not a long
  operation under spec 7.4.
- `SlotProblemView` duplicates `ConnectProblemView` almost line for line.
  Left slots-local for this phase; promoting a shared `ProblemView` to
  `core/errors` is a Phase 6 fix-wave item.

## Decisions made overnight (2026-09-03, Phase 4)

- Repository providers live in `app/lib/data/repository_providers.dart`,
  exported from `data/data.dart`. Features never import `data/database/`
  directly (spec 8.3); the Drift-typed implementations stay under
  `data/database/` and the storage swap seam is real, not fiction.
- Discovery is built on `chameleon_flutter`'s `mergedScan` (immediate first
  event, union of scanners, an errored scanner's rows dropped). A scanner
  error stays sticky in `DiscoveryState` until the connect screen's "Try
  again" invalidates `discoveryProvider` — a scanner that errors is closed
  by `mergedScan` and cannot recover on its own, so self-clearing would hide
  a dead scanner.
- A failed silent reconnect (in `core/lifecycle`) arms the connect screen's
  preselection via `Sessions.markLastDisconnected`, so the device that just
  dropped is preselected on the connect screen exactly as it would be after
  a manual disconnect.
- The macOS `integration` job in `.github/workflows/ci.yml` runs on push
  only (`if: github.event_name == 'push'`) and is not `continue-on-error`.
  The widget-test twin (`app/test/flows/connect_flow_test.dart`) is the
  enforced gate on every job; the macOS runner bills at 10x and duplicates
  the `build` matrix compile.
- `SessionOptions`/`sessionOptionsProvider` exists so tests can zero
  `batteryDelay` instead of depending on `DeviceSession`'s real 5-second
  battery timer; `app/test/support/app_harness.dart`'s `connectToEmulator`
  uses it so widget tests do not need a multi-second pump.
- The SDK's `DeviceSession`/`CommandDispatcher` no longer `await`
  `StreamSubscription.cancel()` — that future never completes under a
  `fakeAsync`/virtual clock, and doing so hung teardown paths; this is a
  root-zone-future hazard, not specific to broadcast streams. Phase 8 fixed
  the same hazard in the SDK's DFU stack (`ResponseQueue`, `SecureDfu`, the
  reboot wait in `DfuOrchestrator`), so as of Phase 8 the whole `packages/
  chameleon` SDK is clear of it (verify with `grep -rn "await.*\.cancel()"
  packages/chameleon/lib` — the one hit left, in `secure_dfu.dart`, awaits
  `ResponseQueue.cancel()`, which itself wraps its subscription's cancel in
  `unawaited`, so it is safe). `chameleon_flutter` still has `await
  …cancel()` sites — `merged_scan.dart`, `ble/ble_scanner.dart`,
  `ble/universal_ble_adapter.dart`, `serial/libserialport_adapter.dart`,
  `serial/usb_serial_adapter.dart`, and (unfixed by Phase 8, which only
  fixed the SDK's DFU stack) `dfu/ble_dfu_channel.dart`'s `close()` and
  `dfu/slip_serial_dfu_channel.dart`'s `close()` — that will need the same
  fix before widget tests reach them under a virtual clock.
- `FakeDevice.open()` is single-use (a Phase 3 decision); Phase 4 always
  constructs a new `DeviceSession` per connect attempt rather than reusing
  one across attempts.

## Decisions made overnight (2026-09-03, Phase 3)

- Draft PR #1 opened from `bobbyrc/chinook` to `main` so `pull_request` CI
  runs on every push; close or convert when reviewing.
- Spec section 6 amended by Spike B: no `ThemeData` bridge file.
- Goldens are alchemist CI-mode only (text obscured); platform goldens are
  opt-in via SPECTRA_PLATFORM_GOLDENS and git-ignored.
- Fonts are vendored (Inter 4.1 static weights, JetBrains Mono 2.304) under
  packages/spectra_ui/assets/google_fonts with their OFL licenses.
- `crypto` was added to the spec section 2 dependency table for `chameleon`
  (SHA-256 verification of the DFU init packet).
- `TransportState` gains `permissionDenied` and `adapterOff` in Phase 3; the
  SDK's error hierarchy already carries the matching `TransportError`s.
- Two DFU assumptions are H2 hardware items: nrfutil's byte-reversed image
  hash in the init packet, and the no-op Execute the resume path sends at the
  object boundary it picks up from.
- The macOS integration job is a post-merge canary plus on-demand: it runs
  on `main` pushes and `workflow_dispatch`, never on PRs, so run it on a
  branch with `gh workflow run ci.yml --ref <branch>`.
- LICENSE files in every package are still the template TODO — the user has
  to choose a license before release.
- `usb_serial` 0.5.2 is overridden to a patched vendor copy at
  `third_party/usb_serial/` (root `pubspec.yaml` `dependency_overrides`):
  upstream's `android/build.gradle` calls the now-removed `jcenter()` and
  never applies the Kotlin Gradle Plugin itself, which broke `flutter build
  apk` under Flutter 3.47.2/Gradle 9.3.1/AGP 9.1's Kotlin-injection shim.
  See `docs/research/DECISIONS.md`, Phase 3, for the two things that were
  tried and ruled out first and why. Re-check for a fixed upstream release
  before shipping and drop the override then.
- The serial DFU write-object frame is opcode `0x08` plus raw data with no
  length prefix, taken from nrfutil's `dfu_transport_serial.py` — the Phase 3
  plan's length-prefixed sketch was wrong. `SecureDfu` does not yet query
  GetSerialMTU (`0x07`), so serial DFU uses a conservative `maxDataWrite`;
  that query is a Phase 8 follow-up.
- `FakeDevice.open()` now throws `Disconnected` after `close()` (single-use,
  matching the real transports); the contract suite found the gap.
- The Phase 3 example app keeps the `serial_probe` name.
- The example's emulator row is behind `--dart-define=SPECTRA_EMULATOR=true`.

## Decisions already made (do not re-ask)

- Stack: Flutter, single codebase for all five platforms.
- Protocol layer: clean-room Dart implementation from the official firmware
  spec. The reference app (GameTec-live/ChameleonUltraGUI) is GPL-3.0; use it
  only to cross-check behavior, never copy code.
- Design: clean, modern, minimal. Custom design system (own color, type,
  spacing, motion tokens and core components) on top of Material 3.
- Build order: foundation-first (design system, protocol package, all
  transports, then feature screens).
- v1 scope: connect + device dashboard, slot management, read/write/emulate
  cards, firmware update (DFU), dictionaries and settings.
- Toolchain versions are pinned with mise (not FVM). Target Flutter 3.47.x
  stable / Dart 3.13; upgrade via mise before scaffolding.
- UI imports: inside `spectra_ui`, its gallery and `app/lib/features`, import
  `package:material_ui/material_ui.dart`, never `package:flutter/material.dart`.
  The two libraries declare the same names and an unprefixed dual import is a
  compile error.

Full detail and research-derived package recommendations that still need
approval: `docs/research/DECISIONS.md`.

## Reference material in this repo

- `docs/research/chameleon-protocol.md`: frame format, command IDs, status
  codes, BLE/USB transport, DFU, slot model, connect handshake.
- `docs/research/reference-gui.md`: how the reference app is built, its
  platform quirks and known pain points.
- `docs/research/flutter-ecosystem.md`: current package landscape and
  recommendations (BLE, serial, DFU, state, routing, storage, UI, testing, CI).

Read these before proposing architecture or writing protocol code.

## Conventions

- Follow the superpowers workflow: brainstorm, spec, plan, then TDD
  implementation. Verify before claiming anything works.
- Keep hardware-facing logic (protocol, transports) in pure Dart packages
  with no Flutter dependency so they are unit-testable without a device.
- Design for the device being absent: every feature must work against a fake
  transport in tests and in a dev "emulator" mode.
- Commit messages: imperative subject, short body explaining why.
- This is a git worktree; run commands from the worktree root and never use
  bare `git stash`.
- On this Mac, `mise x --` does not put Flutter 3.47.2 first on PATH because
  fvm's Dart precedes it. Run
  `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"` in the
  same shell command before any `dart`, `flutter` or `melos` invocation
  (`mise x -- ...` is then harmless).

## Session note

The Fable 5.1 cyber safeguard has false-positive flagged this project on
RFID vocabulary (MIFARE, emulate, keys). When opening a session, lead with
app-architecture framing (for example: "Continue the Spectra Flutter app
brainstorm; read AGENTS.md first") rather than card-attack terminology.
