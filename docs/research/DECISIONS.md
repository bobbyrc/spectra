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
- Extension points: CardCodec registry per tag family, transport registry, feature registry. Dependency lint in CI enforces package and feature boundaries.

## Research-derived recommendations (approved as part of the spec)
- Pub workspace + melos: packages/protocol (pure Dart), transport_ble, transport_serial, data (Drift), app.
- BLE universal_ble; serial libserialport_plus (desktop) + usb_serial (Android); DFU nordic_dfu (mobile/macOS) + pure-Dart Secure DFU over universal_ble (Win/Linux).
- Riverpod 3 + riverpod_generator; go_router; Drift; freezed 4 + json_serializable; material_ui + dynamic_color + google_fonts + flutter_animate; window_manager + macos_window_utils; alchemist + mocktail + integration_test.

## Session note
Fable 5.1 cyber safeguard has false-positive flagged this project twice (RFID vocabulary). Feedback sent (receipt f08bcc8c-cbd4-4a35-a145-5614eb553f92).
