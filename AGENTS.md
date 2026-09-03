# Spectra: agent context

Spectra is a polished, cross-platform companion app for the Chameleon Ultra
(open-source NFC/RFID research hardware by RfidResearchGroup). Targets:
Windows, macOS, Linux, iOS, Android. Goal: the one-stop shop for the device,
serving both first-time hobbyists and security researchers through
progressive disclosure (simple default path, expert detail one tap away).

## Current status (2026-09-02)

Brainstorming, architectural path. No application code exists yet.
Research is complete. Next steps, in order:

1. Present 2-3 architecture approaches with a recommendation.
2. Walk through the design section by section for approval.
3. Write the spec to `docs/superpowers/specs/YYYY-MM-DD-spectra-design.md`.
4. Write an implementation plan, then scaffold.

Do not scaffold or write app code before the spec is approved.

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

## Session note

The Fable 5.1 cyber safeguard has false-positive flagged this project on
RFID vocabulary (MIFARE, emulate, keys). When opening a session, lead with
app-architecture framing (for example: "Continue the Spectra Flutter app
brainstorm; read AGENTS.md first") rather than card-attack terminology.
