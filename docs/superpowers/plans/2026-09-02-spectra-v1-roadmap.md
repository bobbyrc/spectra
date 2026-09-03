# Spectra v1 Roadmap

> **For agentic workers:** This roadmap orders the sub-plans that together build v1. Phases 0 and 1 have detailed plans already written (linked below). For every later phase, write its detailed plan with `superpowers:writing-plans` from the spec sections listed, get it reviewed, then execute it with `superpowers:subagent-driven-development`. Do not skip the plan for a phase.

**Goal:** Ship Spectra v1 as specified in `docs/superpowers/specs/2026-09-02-spectra-design.md`, phase by phase, each phase leaving working, tested software on `main`.

**Spec:** `docs/superpowers/specs/2026-09-02-spectra-design.md` (source of truth). Rationale: `docs/research/DECISIONS.md`. Wire facts: `docs/research/chameleon-protocol.md`.

## Global Constraints (apply to every phase)

- Toolchain pinned in `mise.toml`: Flutter 3.47.2 (bundles Dart 3.13). Run every Flutter or Dart command as `mise x -- flutter ...` / `mise x -- dart ...` from the worktree root or the package directory.
- Package boundaries and the dependency table in spec section 2 are enforced by `tool/dep_lint.dart`; CI and every phase gate require it green.
- TDD for every task: failing test, minimal code, passing test, commit. Commit messages: imperative subject, short body explaining why, trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Generated code (freezed, riverpod_generator, drift) is committed; `tool/check_codegen.sh` must pass.
- `chameleon` never imports Flutter. `spectra_ui` never imports the device packages. `app/lib/features/*` never import another feature's internals or `package:flutter/material.dart`.
- All user-facing strings go through ARB localization from the first screen (spec 7.6).
- This is a git worktree. Never use bare `git stash`.
- Never claim hardware behavior works without the user running the hardware checklist. Commands tagged `hardware-validate` are verified only on a device.
- At the end of each phase: update the "Current status" section of `AGENTS.md`, add lessons to `tasks/lessons.md`, mark the phase in this file.

## Hardware handoffs (non-blocking)

The user owns one Chameleon Ultra and a Mac. The executor cannot run hardware steps, and progress never waits for them. Instead:

- Everything is built and tested against `FakeDevice`. Work that would normally wait on hardware continues.
- The executor maintains `docs/hardware-checklist.md`: one section per handoff below, each with the exact commands, what to observe, and a checkbox per item. The user runs it whenever they are available and reports back; the executor then records results and fixes what failed.
- Anything the spec tags `hardware-validate` stays marked "pending hardware" in code comments and in the checklist until the user reports it passing. Never mark it verified without that report.
- Spec section 5.6 is honoured by feature flags, not by waiting: USB DFU on desktop ships enabled by default; BLE DFU and iOS DFU are built in full but sit behind a `dfuOverBleEnabled` flag that defaults to off. The flag flips to on only after the user reports H2 passed. The update screen shows a "pending hardware validation" notice while the flag is off.

- H1 (after Phase 3): serial open on macOS over USB, control-line configuration, BLE connect and pairing, connect handshake on real firmware, slot round trip.
- H2 (during Phase 8): USB DFU on macOS with a release package. Then a deliberately interrupted BLE DFU recovered over USB.
- H3 (before release): the full hardware checklist in spec section 10.

## Phases

| Phase | Plan | Spec sections | Deliverable | Gate |
|---|---|---|---|---|
| 0 Foundation | `2026-09-02-phase-0-foundation.md` (written) | 2, 11 | Toolchain pinned, workspace with four package skeletons, melos scripts, dependency lint, codegen check, CI with debug build matrix, two spikes recorded | CI green on a pull request; `docs/research/spikes.md` has both spike verdicts; spec 5.2 and 6 amended if a spike chose a fallback |
| 1 SDK | `2026-09-02-phase-1-chameleon-sdk.md` (written) | 3, 4, 8.1, 8.2, 9 (error types), 10 | `packages/chameleon`: codec, commands, errors, models, transport interface, FakeDevice across the firmware matrix, dispatcher, session state machine, cache, lease, facades, dump formats, DfuPackage, SecureDfu, DfuOrchestrator | `dart test` green with coverage report; every spec 4.3 behavior has a named test |
| 2 Design system | `2026-09-03-phase-2-design-system.md` (done) | 6, 7.6 | `packages/spectra_ui`: tokens, SpectraTheme, material_ui bridge, every 6.2 component with light and dark goldens, gallery example, ARB wiring | goldens pass on CI; gallery runs on macOS in emulator-free mode |
| 3 Transports | `2026-09-03-phase-3-transports.md` (written) | 5 | `packages/chameleon_flutter`: BLE transport, serial transport, scanners, BleDfuChannel, SlipSerialDfuChannel, permission and pairing states, platform setup files, contract suite | contract suite green against FakeDevice; H1 section written to docs/hardware-checklist.md |
| 4 App shell and connect | write from spec 7.1-7.5, 8.3, 8.4, 9 | 7, 8, 9 | `app`: core (session family, active device, routing on connectionState, lifecycle, error catalog, frame log), data layer (Drift, known devices), emulator mode, connect screen with identity merge, dashboard, bootloader recovery entry | integration test: connect to emulator, see dashboard, disconnect, reconnect |
| 5 Slots | write from spec 7.7 step 2, 8.3 | 7.7, 8 | Slots feature and its public slot picker API | integration test: edit and save a slot on the emulator |
| 6 Read, library, editor, import | write from spec 7.7 steps 3-4, 7.3, 3.5 | 3.5, 7.3, 7.7 | Read cards, cards library, dump editor with hex viewer, reference-app JSON import, card picker API | integration test: scan a fake card, save, edit, import fixture |
| 7 Write and emulate | write from spec 7.7 step 5 | 7.7 | Load to slot, write to card, quick emulate | integration test on emulator |
| 8 Firmware update | write from spec 4.5, 5.3, 5.5, 5.6, 7.7 step 6 | 4.5, 5.6 | Release feed, package pick, orchestrated DFU UI, recovery flow, BLE and iOS DFU behind the `dfuOverBleEnabled` flag (default off) | integration test on the fake bootloader over both channel types; H2 section written to the checklist |
| 9 Dictionaries and settings | write from spec 7.7 step 7 | 7.7 | Key lists, device settings, app settings, export | integration test on emulator |
| 10 Release | write from spec 10 | 10 | Signing, notarization, installers, AppImage, changelog; release candidate tagged as `v1.0.0-rc.1` | CI green; artifacts built; H3 section written; final `v1.0.0` tag waits for the user's H3 report |

Order is fixed as listed. Phase 2 and Phase 1 do not depend on each other and may be executed in parallel by separate subagents once Phase 0 is done.

## Phase status

- [x] Phase 0
- [x] Phase 1
- [x] Phase 2
- [x] Phase 3
- [ ] Phase 4
- [ ] Phase 5
- [ ] Phase 6
- [ ] Phase 7
- [ ] Phase 8
- [ ] Phase 9
- [ ] Phase 10
