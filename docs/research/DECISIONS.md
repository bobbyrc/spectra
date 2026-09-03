# Spectra: architecture decisions so far (2026-09-02)

Status: design approved in brainstorm; spec at docs/superpowers/specs/2026-09-02-spectra-design.md. Next: user spec review, then implementation plan.

## Agreed with user
- Product: polished, cross-platform (Windows, macOS, Linux, iOS, Android) Chameleon Ultra companion. "One stop shop": both hobbyists and researchers, progressive disclosure (simple default path, expert detail one tap away).
- Stack: Flutter single codebase.
- Protocol layer: clean-room Dart implementation from official firmware spec (reference GUI is GPL-3.0; use only to cross-check behavior).
- Design: clean modern minimal; custom design system (own tokens + core components) on Material 3.
- Build order: foundation-first (design system, full protocol package, all transports, then feature screens).
- v1 scope: connect + device dashboard, slot management, read/write/emulate cards, firmware/DFU + advanced (dictionaries, settings).
- Toolchain versions are managed with mise (not FVM). Local Flutter was 3.32.5; stable is 3.47.1 / Dart 3.13.1: upgrade before scaffolding.

## Architecture (approved 2026-09-02, detail in the spec)
- Approach A: four-package pub workspace. packages/chameleon (pure Dart SDK: codec, commands, models, DeviceSession with facades, FakeDevice, SecureDfu), packages/chameleon_flutter (BLE, serial, DFU runners), packages/spectra_ui (design system on material_ui 1.0), app/ (Riverpod, go_router, Drift, feature modules with a FeatureModule registry).
- Extension points: DumpFormat per tag family (pure, in SDK), a plain scanner list, and plain route/destination lists in the shell. Dependency lint in CI enforces package and feature boundaries.
- Revised 2026-09-02 after an adversarial review (18 findings, most accepted):
  - DFU: one pure-Dart SecureDfu implementation on all platforms over BLE and serial SLIP channels; nordic_dfu dropped. USB DFU on desktop is validated on hardware first, then BLE, then iOS, so the user's only device can always be recovered over USB (spec 5.6).
  - Design system base: material_ui 1.0 with one bridge file for in-SDK ThemeData consumers; early spike to confirm coexistence with go_router and alchemist.
  - Session has an explicit state machine (connecting, ready, limited, updating, disconnected); handshake requires only capabilities, version and model; routing keys off connectionState.
  - Reader mode is a ref-counted lease; commands carry generation tokens; cancellation drains.
  - Cache is write-through plus idle poll. Localization (ARB, English) from the first screen. Lifecycle section added. Import of the reference app's JSON export is v1.
  - One fake only, at transport level; the real DeviceSession runs in all tests. Hardware checklist is a release gate.
  - Cut from v1: dynamic_color, custom desktop window chrome, emulated Lite UI toggle, single version across all packages (SDK versions independently).

## Research-derived recommendations (approved as part of the spec)
- Pub workspace + melos: packages/protocol (pure Dart), transport_ble, transport_serial, data (Drift), app.
- BLE universal_ble; serial libserialport_plus (desktop) + usb_serial (Android); DFU nordic_dfu (mobile/macOS) + pure-Dart Secure DFU over universal_ble (Win/Linux).
- Riverpod 3 + riverpod_generator; go_router; Drift; freezed 4 + json_serializable; material_ui + dynamic_color + google_fonts + flutter_animate; window_manager + macos_window_utils; alchemist + mocktail + integration_test.

## Phase 0 decisions (2026-09-03)

- **dep_lint allowlist is a deliberate superset of the spec 2 table.** The
  `chameleon` package additionally allows `freezed_annotation` and `crypto`
  (Phase 1's DFU implementation needs both, for models and the hash check);
  `spectra_ui` additionally allows `intl` (ships alongside
  `flutter_localizations`, which `material_ui` pulls in transitively); the
  `spectra_ui_gallery` example additionally allows `go_router` (it is the
  spike host validating go_router coexistence with `material_ui`, spec
  section 6). Cost if any of these turns out to be wrong: one extra entry in
  `tool/dep_lint.dart`'s allowlist to remove.
- **Spike A verdict: keep `libserialport_plus` 1.0.4.** Its code-assets build
  hook produces the native serial library on macOS, Windows and Linux with no
  toolchain changes, and `SerialPortInfo` exposes USB VID/PID directly, which
  is what device identification needs. `open()` behavior and whether the
  `com.apple.security.device.serial` entitlement is actually required (versus
  just recommended by the package) are deferred to hardware handoff H1, since
  they need real hardware. Full writeup: `docs/research/spikes.md`.
- **Spike B verdict: build `spectra_ui` on `material_ui` 1.1.1.** It is
  flutter.dev's own extraction of in-SDK Material with matching class names,
  is a drop-in replacement import, and both `go_router` (which now depends on
  `material_ui` directly) and `alchemist` goldens work against it without a
  bridge. The spec 5.6-era plan for a `ThemeData` bridge file is dropped —
  see the import convention below. Full writeup: `docs/research/spikes.md`.
- **Import convention for the design system.** `spectra_ui`, its gallery, and
  app features import `package:material_ui/material_ui.dart` and never
  `package:flutter/material.dart` — the two declare distinct, same-named
  types (`ThemeData`, `Theme`, `MaterialApp`, ...) and importing both
  unprefixed into one file is an `ambiguous_import` analyzer error. This is
  enforced by lint in `app/lib/features` per the original spec; `spectra_ui`
  and the gallery follow it by convention pending the same enforcement in a
  later phase.
- **Draft PR strategy for CI.** A draft PR (#1, `bobbyrc/chinook` -> `main`)
  stays open through the phases so `pull_request`-triggered CI runs on every
  push to the branch, without merging early or blocking on review. Close or
  convert to ready when the branch is actually ready to merge.

## Phase 2 decisions (2026-09-03)

- **material_ui import convention.** `spectra_ui`, its gallery and
  `app/lib/features` import `package:material_ui/material_ui.dart` and never
  `package:flutter/material.dart`; the two declare the same names and an
  unprefixed dual import is an `ambiguous_import` error. No in-SDK `ThemeData`
  bridge is written (Spike B: go_router 18.0.1 already depends on material_ui,
  alchemist 0.14.0 needs no wrapper). `spectraThemeData()` maps Spectra tokens
  onto material_ui's own `ThemeData` instead.
- **Goldens policy.** Alchemist CI goldens only (`test/goldens/ci/`), generated
  with `melos run goldens:update` (or `flutter test --update-goldens` in the
  package). Platform goldens are disabled unless `SPECTRA_PLATFORM_GOLDENS=true`
  and their directories are git-ignored, so macOS-rendered images can never be
  committed. Goldens run in the existing Ubuntu `check` job via
  `melos run test:flutter`; no extra CI job.
- **Goldens comparator tolerance (revised 2026-09-03, Task 17).** CI-mode
  text obscuring does not make renders byte-identical across host platforms:
  the first real Ubuntu `check` run of the full component set failed nine
  golden tests with pixel diffs from 0.01% to 0.68%, from anti-aliasing on
  borders, rounded corners and icons rather than any layout/colour/shape
  regression. `flutter_test_config.dart` now sets
  `CiGoldensConfig(diffThreshold: 0.01)` (1% of pixels) so that
  macOS-authored goldens verify cleanly on the Ubuntu runner without masking
  a real difference; the images committed under `test/*/goldens/ci/` did not
  need regenerating.
- **Font fallback.** One variable sans (Inter) and one mono (JetBrains Mono),
  both bundled under `packages/spectra_ui/assets/google_fonts/` with
  `GoogleFonts.config.allowRuntimeFetching = false`. Production is offline
  capable; tests do not await the async font load, so golden text renders in
  flutter_test's Ahem rather than Inter. That removes glyph rendering as a
  source of cross-platform golden noise, but not all of it: see the goldens
  decision below.
- **Localization.** The kit owns an ARB catalog for its own strings
  (`SpectraUiLocalizations`), generated with `flutter gen-l10n` into
  `lib/l10n/` and committed; `tool/check_codegen.sh` fails when it goes stale.
  A textual lint (`tool/src/string_rules.dart`, rule `no-literal-text`) fails
  on string literals passed to `Text(` under
  `packages/spectra_ui/lib/src/components/` and `app/lib/features/**/ui/`,
  with `// l10n-exempt` for genuinely non-user-facing text. The named
  arguments it scans are `label`, `labelText`, `title`, `subtitle`,
  `hintText`, `helperText`, `errorText`, `semanticsLabel` and `tooltip`.

### Final-review decisions (2026-09-03)

- **`borderStrong` colour role.** `border` (neutral200 light / neutral700
  dark) is a decorative separator at 1.3:1 and 1.5:1 on surface, well under
  WCAG 1.4.11's 3:1 for a control boundary. A second role, `borderStrong`
  (neutral500 light / neutral400 dark, 4.6:1 to 6.3:1 on surface,
  surfaceRaised and background), now outlines anything interactive: the
  secondary button and the text field. The secondary button's fill moved from
  `surface` to `surfaceRaised` at the same time, so it reads as a control on
  a card. `tokens_test.dart` computes and asserts both contrasts.
- **`SpectraTappable`.** Every tappable component (button, card, list tile,
  slot tile, section-header action, bottom-sheet close, disclosure header)
  routes through one internal primitive built on `FocusableActionDetector`:
  Tab focus, Enter/Space activation, an accent 2px focus ring animated over
  `SpectraMotion.fast`, a hover tint, and `onTap` on the semantics node so
  the node actually carries `SemanticsAction.tap`. The child's semantics are
  excluded *inside* the detector rather than at the top, and the whole thing
  is wrapped in `MergeSemantics`, so the single announced node keeps both the
  tap action and the focusable flag.
- **Theme completeness.** `spectraThemeData` now fills every `ColorScheme`
  role from a token (outline, outlineVariant, secondaryContainer, the
  surfaceContainer ladder, surfaceTint, scrim, onSurfaceVariant) and adds
  `inputDecorationTheme`, `dialogTheme`, `bottomSheetTheme`, `appBarTheme`
  and `dividerTheme`; `SpectraTypography.textTheme` fills all fifteen
  `TextTheme` roles, not six, because `material_ui` reads `bodyLarge`,
  `labelMedium` and `titleLarge` internally and an unset role falls back to
  Roboto.
- **Goldens on Linux (supersedes the 1% tolerance above).** The committed CI
  goldens are generated on ubuntu-latest by
  `.github/workflows/goldens.yml` (`workflow_dispatch`, uploads
  `test/components/goldens/ci` as the `goldens-ci` artifact) and downloaded
  into the repo, so the images and the comparing `check` job share a
  platform (spec 6.3). `diffThreshold` drops accordingly. The cost is that a
  plain `flutter test` on macOS may report sub-1% golden diffs; the CI run is
  authoritative and `packages/spectra_ui/README.md` says so.
- **`no-material-in-features` message.** The rule stays — it prevents the
  dual-import compile error — but its message no longer claims features may
  not use Material widgets. It now says to import
  `package:material_ui/material_ui.dart` (or `package:flutter/widgets.dart`)
  instead of the SDK's Material library. A symbol allowlist for `material_ui`
  is deferred.

## Session note
Fable 5.1 cyber safeguard has false-positive flagged this project twice (RFID vocabulary). Feedback sent (receipt f08bcc8c-cbd4-4a35-a145-5614eb553f92).
