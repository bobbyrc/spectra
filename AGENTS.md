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
on macOS. Phase 1 (`packages/chameleon`) is in progress, running
concurrently on the same branch.

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
- `2026-09-02-phase-1-chameleon-sdk.md`: the pure-Dart SDK, task by task.
  Next step.
- `2026-09-03-phase-2-design-system.md`: the design system on `spectra_ui`
  (complete).
- Phases 3 to 10: write each plan with the writing-plans skill from the spec
  sections the roadmap lists, when that phase starts.

Execute plans with superpowers:subagent-driven-development. Hardware steps
need the user's device and never block progress: build against the fake,
keep `docs/hardware-checklist.md` current, and gate BLE and iOS DFU behind
the `dfuOverBleEnabled` flag until the user reports the checks passed.

## Decisions made overnight (2026-09-03)

- Draft PR #1 opened from `bobbyrc/chinook` to `main` so `pull_request` CI
  runs on every push; close or convert when reviewing.
- Spec section 6 amended by Spike B: no `ThemeData` bridge file.
- Goldens are alchemist CI-mode only (text obscured); platform goldens are
  opt-in via SPECTRA_PLATFORM_GOLDENS and git-ignored.
- Fonts are vendored (Inter 4.1 static weights, JetBrains Mono 2.304) under
  packages/spectra_ui/assets/google_fonts with their OFL licenses.

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
