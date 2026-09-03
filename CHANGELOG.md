# Changelog

All notable changes to Spectra are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Release candidates (`v1.0.0-rc.N`) do not get their own entry: they are
candidates for the entry below them.

## [Unreleased]

## [1.0.0] - 2026-09-03

The first release of Spectra, a cross-platform companion app for the
Chameleon Ultra and Chameleon Lite.

### Added

- Connect: USB serial and Bluetooth Low Energy transports on Windows, macOS,
  Linux, Android and iOS, with device discovery, pairing guidance and an
  emulator mode that needs no hardware.
- Device dashboard: firmware and chip identity, battery, active slot, and
  the animation and button settings the device exposes.
- Slots: all eight slots, nicknames, enable and disable, high- and
  low-frequency tag types, and making a slot active.
- Cards: read MIFARE Classic, MIFARE Ultralight and EM410x cards, save them
  to a local library, edit dumps in a hex viewer, and import the reference
  app's JSON exports.
- Write and emulate: load a saved card into a slot, write a dump to a card,
  and quick-emulate from the library.
- Firmware update: a release feed, package selection, and an orchestrated
  Nordic Secure DFU over USB with a recovery path for an interrupted flash,
  so firmware update stays behind the `dfuOverBleEnabled` flag over
  Bluetooth, off by default until hardware validation completes.
- Dictionaries: key lists with import and export.
- Settings: device settings, app settings, and a frame log that can be
  exported with any bug report.
- A design system with light and dark themes, adaptive navigation, and
  localized copy throughout.

### Known limitations

- Bluetooth DFU and iOS DFU are behind the `dfuOverBleEnabled` flag.
- Mobile app stores are a later step; Android artifacts are published as an
  APK and an AAB on the release page.
