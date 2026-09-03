# Phase 3: chameleon_flutter platform transports Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `packages/chameleon_flutter`: a BLE transport and scanner over `universal_ble`, a serial transport and scanner over `libserialport_plus` (desktop) and `usb_serial` (Android), the two Nordic DFU channels, the platform permission/pairing states, the platform setup files in `app/` and the example, and a transport contract suite that runs green against `FakeDevice` in CI and against real hardware under the `hardware` tag.

**Architecture:** Every native package is reached through a small abstract adapter interface declared in this package — `BleAdapter`, `SerialPortAdapter`/`SerialPortHandle` — with one real implementation (`UniversalBleAdapter`, `LibSerialPortAdapter`, `UsbSerialAdapter`) and one scripted fake in `test/support/`. The transports hold all the logic worth testing (connect retry and backoff, chunking at the platform-reported write length, state mapping, error mapping, pairing detection) and are unit-tested against the fakes with no device and no plugin channel. Native error types are mapped to two tiny package-private enums (`BleFailure`, `SerialFailure`) at the adapter boundary, so transport logic never sees a `UniversalBleException` or a `SerialPortException`.

**Tech Stack:** Flutter 3.47.2 / Dart 3.13, `universal_ble` 2.2.0, `libserialport_plus` 1.0.4, `usb_serial` 0.5.2, `chameleon` (this repo), `mocktail` and `flutter_test` for tests.

**Spec:** `docs/superpowers/specs/2026-09-02-spectra-design.md` sections 5 (5.1 BLE transport, 5.2 serial transport, 5.3 DFU channels, 5.4 platform matrix, 5.5 bootloader discovery, 5.6 recovery guarantee, 5.7 platform setup, 5.8 testing), 4.1 (transport interface), 4.2 (discovery and identity), 8.2 (extension points) and the section 2 dependency table row for `chameleon_flutter`. Wire facts: `docs/research/chameleon-protocol.md`. Package facts: `docs/research/spikes.md` Spike A.

## Global Constraints

- `chameleon_flutter` may depend on `chameleon`, `flutter`, `universal_ble`, `libserialport_plus` and `usb_serial` only, and **must not** depend on `spectra_ui` or `app` (spec section 2). `tool/dep_lint.dart` enforces it; its `chameleon_flutter` allowlist already lists exactly these five.
- `chameleon_flutter` must never import `package:chameleon/src/...`. Only the public barrel `package:chameleon/chameleon.dart`. `tool/dep_lint.dart` has an `sdk-internals` rule that fails on it.
- **Wire constants, verbatim from the spec and `docs/research/chameleon-protocol.md`. Never retype these from memory:**
  - Nordic UART service `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`, write characteristic `6E400002-B5A3-F393-E0A9-E50E24DCCA9E`, notify characteristic `6E400003-B5A3-F393-E0A9-E50E24DCCA9E`.
  - BLE application advertised name prefixes `ChameleonUltra` and `ChameleonLite`. BLE bootloader advertised names `CU` and `CL`.
  - Nordic DFU service `FE59`, control point `8EC90001-F315-4F60-9FB8-838830DAEA50`, packet `8EC90002-F315-4F60-9FB8-838830DAEA50`.
  - USB application VID `0x6868` / PID `0x8686`, manufacturer string `Proxgrind`. USB bootloader VID `0x1915` / PID `0x521F`.
  - Serial line settings: 115200 baud, 8 data bits, no parity, 1 stop bit.
  - BLE connect retries **up to five times** with backoff.
  - BLE writes go to `6E400002` **with response**, in chunks of the platform-reported maximum write length. The firmware requests MTU 247; **never assume 247** — ask, and fall back to 20 bytes if the platform will not say.
  - DFU packet writes are **20 bytes on iOS and macOS**, the platform maximum elsewhere.
  - SLIP framing bytes: END `0xC0`, ESC `0xDB`, ESC_END `0xDC`, ESC_ESC `0xDD`.
- **Commands:** once per shell, `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"`, then plain `flutter` / `dart` run **from the package directory** (`packages/chameleon_flutter` unless a task says otherwise). mise puts its tool paths after an older fvm Dart on this machine, so the export is not optional.
- Commit after every task. Imperative subject, short body explaining why, trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- This is a git worktree. Never use bare `git stash`.
- `dart run tool/dep_lint.dart`, `dart format --set-exit-if-changed .`, `dart analyze --fatal-infos .` and all tests stay green at every commit (from the worktree root: `dart run melos run check:all`).
- Anything only a device can prove carries a `hardware-validate` doc comment naming the checklist item, and any test that needs a device is tagged `hardware` and is skipped by default. **Never claim hardware behavior works** — every H1 item stays `- [ ] pending` in `docs/hardware-checklist.md` until the user reports it.
- Files stay under about 300 lines and hold one public type each (spec 8.5).
- Phase 1 Task 19 defines `DfuChannel`. This plan targets that interface exactly: `int get maxDataWrite; Future<void> writeControl(Uint8List); Future<void> writeData(Uint8List); Stream<Uint8List> get responses; Future<void> close();`. **Task 11 and Task 12's implementer must open `packages/chameleon/lib/src/dfu/dfu_channel.dart` first and follow the landed signature if it differs** (in particular if `responses` landed as `notifications`), then adjust the channel classes and their tests to match.

---

## File structure

```
packages/chameleon/lib/src/transport/transport.dart      + TransportPermissionDenied, TransportAdapterOff
packages/chameleon/lib/chameleon.dart                    barrel exports for transport, scanner, errors, codec, fakes
packages/chameleon/test/transport/transport_state_test.dart

packages/chameleon_flutter/
  pubspec.yaml                                 universal_ble, usb_serial, libserialport_plus, dev: mocktail
  dart_test.yaml                               declares the `hardware` tag, excluded by default
  lib/chameleon_flutter.dart                   public barrel
  lib/src/host_platform.dart                   HostPlatform enum + currentHostPlatform()
  lib/src/guidance.dart                        TransportGuidance enum + GuidedTransport interface
  lib/src/ble/ble_uuids.dart                   NUS + Nordic DFU UUIDs, advertised names, normalizeUuid()
  lib/src/ble/ble_failure.dart                 BleFailure enum + BleAdapterException
  lib/src/ble/ble_adapter.dart                 BleAdapter interface + BleScanEntry + BleAvailability
  lib/src/ble/universal_ble_adapter.dart       UniversalBleAdapter: the only file importing universal_ble
  lib/src/ble/ble_transport.dart               BleTransport
  lib/src/ble/ble_scanner.dart                 BleScanner + isChameleonAdvertisement()
  lib/src/serial/serial_ids.dart               VID/PID/manufacturer/line-setting constants
  lib/src/serial/serial_failure.dart           SerialFailure enum + SerialAdapterException
  lib/src/serial/serial_adapter.dart           SerialPortAdapter + SerialPortHandle + SerialPortDescriptor
  lib/src/serial/libserialport_adapter.dart    LibSerialPortAdapter: the only file importing libserialport_plus
  lib/src/serial/usb_serial_adapter.dart       UsbSerialAdapter: the only file importing usb_serial
  lib/src/serial/serial_adapter_factory.dart   defaultSerialPortAdapter()
  lib/src/serial/serial_transport.dart         SerialTransport (+ .fromPath)
  lib/src/serial/serial_scanner.dart           SerialScanner
  lib/src/dfu/slip.dart                        Slip constants, Slip.encode, SlipDecoder
  lib/src/dfu/slip_serial_dfu_channel.dart     SlipSerialDfuChannel
  lib/src/dfu/ble_dfu_channel.dart             BleDfuChannel
  lib/src/transports.dart                      ChameleonTransports.defaultScanners/transportFor
  test/support/fake_ble_adapter.dart           scripted BleAdapter for unit tests
  test/support/fake_serial_adapter.dart        scripted SerialPortAdapter/Handle for unit tests
  test/ble/*_test.dart                         uuid, failure mapping, transport, scanner
  test/serial/*_test.dart                      ids, failure mapping, transport, scanner
  test/dfu/slip_test.dart                      SLIP codec
  test/dfu/slip_serial_dfu_channel_test.dart
  test/dfu/ble_dfu_channel_test.dart
  test/transports_test.dart                    default scanner list per platform
  test/contract/transport_contract.dart        transportContractTests(): the shared body (spec 5.8)
  test/contract/fake_device_contract_test.dart runs the contract against FakeDevice (CI)
  test/contract/hardware_contract_test.dart    runs it against real serial/BLE, tagged `hardware`
  example/pubspec.yaml                         renamed to transport_example, adds chameleon + chameleon_flutter
  example/lib/main.dart                        entry: runApp(TransportExampleApp())
  example/lib/scan_page.dart                   merged scanner results, connect action
  example/lib/session_page.dart                DeviceSession handshake, version/model, slot rename round trip
  example/macos/Runner/DebugProfile.entitlements   + bluetooth (serial already present)
  example/macos/Runner/Release.entitlements        + bluetooth
  example/macos/Runner/Info.plist                  + NSBluetoothAlwaysUsageDescription
  example/android/…                             created by `flutter create --platforms=android .`

app/android/app/src/main/AndroidManifest.xml   Bluetooth + location permissions, USB device filter intent
app/android/app/src/main/res/xml/device_filter.xml  VID/PID filter for app + bootloader
app/ios/Runner/Info.plist                      NSBluetoothAlwaysUsageDescription
app/macos/Runner/DebugProfile.entitlements     bluetooth + serial
app/macos/Runner/Release.entitlements          bluetooth + serial
test/platform_setup_test.dart                  workspace-root test asserting every platform file above
tool/src/dep_rules.dart                        rename the `serial_probe` allowlist to `transport_example`
.github/workflows/ci.yml                       build the example on windows + linux
docs/hardware-checklist.md                     H1 filled in with exact commands
docs/research/DECISIONS.md                     Phase 3 decisions
tasks/lessons.md                               Phase 3 lessons
docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md   tick Phase 3
AGENTS.md                                      current status
```

---

### Task 1: Extend TransportState with permissionDenied and adapterOff

Spec 5.1 says the BLE transport "reports `permissionDenied` and `adapterOff` states so the app can show the right step". `TransportState` is the SDK's sealed family and the app routes on it, so the two states belong there next to `TransportPairingRequired`, not in a side channel. `TransportState` is only ever consumed with `is` checks (`device_session.dart:218`, `dispatcher.dart:83,125,247,251`), never an exhaustive `switch`, so adding variants is additive.

**Files:**
- Modify: `packages/chameleon/lib/src/transport/transport.dart`, `packages/chameleon/lib/chameleon.dart`
- Test: `packages/chameleon/test/transport/transport_state_test.dart`

**Interfaces:**
- Produces: `final class TransportPermissionDenied extends TransportState { const TransportPermissionDenied(); }`
- Produces: `final class TransportAdapterOff extends TransportState { const TransportAdapterOff(); }`
- Produces: the `package:chameleon/chameleon.dart` barrel exports every symbol Phase 3 needs: `Transport`, `TransportKind`, `TransportState` and all its variants, `CloseCause`, `DeviceScanner`, `DiscoveredDevice`, `FrameLog`, `Frame`, `FrameDecoder`, `DeviceSession`, `FakeDevice`, `FakeFirmware`, `FakeScanner`, and every type in `protocol/errors.dart`.

- [ ] **Step 1: Write the failing test**

```dart
// packages/chameleon/test/transport/transport_state_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:test/test.dart';

void main() {
  test('permissionDenied and adapterOff are TransportStates', () {
    const TransportState denied = TransportPermissionDenied();
    const TransportState off = TransportAdapterOff();
    expect(denied, isA<TransportState>());
    expect(off, isA<TransportState>());
    expect(denied, isNot(isA<TransportClosed>()));
    expect(off, isNot(isA<TransportClosed>()));
  });

  test('a session ignores non-closed states and stays connectable', () async {
    final device = FakeDevice();
    final session = DeviceSession(device);
    await session.open();
    expect(session.connectionState.value, isA<SessionReady>());
    await session.close();
  });

  test('the barrel exports the transport surface the platform package needs', () {
    expect(const TransportOpening(), isA<TransportState>());
    expect(const TransportOpen(), isA<TransportState>());
    expect(const TransportPairingRequired(), isA<TransportState>());
    expect(
      const TransportClosed(CloseCause.linkLost, error: PermissionDenied()),
      isA<TransportState>(),
    );
    expect(TransportKind.values, contains(TransportKind.ble));
    expect(
      const DiscoveredDevice(
        name: 'x',
        kind: TransportKind.usb,
        transportId: '/dev/x',
      ).isBootloader,
      isFalse,
    );
    expect(Frame(command: 1000).encode().first, 0x11);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd packages/chameleon && dart test test/transport/transport_state_test.dart
```

Expected: FAIL — `Undefined name 'TransportPermissionDenied'` and undefined names for anything the barrel does not yet export.

- [ ] **Step 3: Add the two states**

Append to `packages/chameleon/lib/src/transport/transport.dart`, after `TransportPairingRequired`:

```dart
/// The OS refused the permission the transport needs: Android's
/// BLUETOOTH_SCAN / BLUETOOTH_CONNECT, an iOS or macOS usage prompt the user
/// declined, or a serial port the process may not open. Not a close: the
/// transport never opened. The app shows the permission step (spec 5.1).
final class TransportPermissionDenied extends TransportState {
  const TransportPermissionDenied();
}

/// The Bluetooth adapter is off or unavailable. The app shows the
/// "turn Bluetooth on" step rather than a connection error (spec 5.1).
final class TransportAdapterOff extends TransportState {
  const TransportAdapterOff();
}
```

- [ ] **Step 4: Export the SDK surface from the barrel**

Replace the body of `packages/chameleon/lib/chameleon.dart` below the `library;` line with the version const plus:

```dart
export 'src/codec/frame.dart' show Frame, frameSof, frameMaxDataLength;
export 'src/codec/frame_decoder.dart' show FrameDecoder;
export 'src/fake/fake_device.dart' show FakeDevice;
export 'src/fake/fake_firmware.dart';
export 'src/fake/fake_scanner.dart' show FakeScanner;
export 'src/model/enums.dart';
export 'src/model/models.dart';
export 'src/protocol/errors.dart';
export 'src/protocol/status.dart';
export 'src/session/cancel_token.dart';
export 'src/session/connection_state.dart';
export 'src/session/device_session.dart' show DeviceSession;
export 'src/transport/frame_log.dart';
export 'src/transport/scanner.dart';
export 'src/transport/transport.dart';
```

Phase 1 may already have written some of these exports and may have landed a `src/dfu/` directory; keep what is there, add what is missing, and add `export 'src/dfu/dfu_channel.dart';` plus the rest of the DFU surface if `src/dfu/` exists. Do not export anything under `src/commands/` — the dispatcher owns those and `dep_lint`'s `sdk-internals` rule keeps callers out.

- [ ] **Step 5: Run the whole SDK suite**

```bash
cd packages/chameleon && dart test
```

Expected: PASS, including the three new tests. If a test elsewhere fails on an ambiguous export, narrow that export with a `show` clause rather than deleting it.

- [ ] **Step 6: Commit**

```bash
git add packages/chameleon
git commit -m "feat(chameleon): add permissionDenied and adapterOff transport states

The platform transports need to tell the app the difference between a
failed connection and a permission or adapter problem, and the app routes
on TransportState. Also widen the package barrel so chameleon_flutter can
reach the transport surface without importing src/."
```

---

### Task 2: Package setup, host platform, guidance and wire constants

**Files:**
- Modify: `packages/chameleon_flutter/pubspec.yaml`, `packages/chameleon_flutter/lib/chameleon_flutter.dart`
- Create: `packages/chameleon_flutter/dart_test.yaml`, `lib/src/host_platform.dart`, `lib/src/guidance.dart`, `lib/src/ble/ble_uuids.dart`, `lib/src/serial/serial_ids.dart`
- Test: `packages/chameleon_flutter/test/host_platform_test.dart`, `test/ble/ble_uuids_test.dart`, `test/serial/serial_ids_test.dart`

**Interfaces:**
- Produces: `enum HostPlatform { android, ios, macos, windows, linux, unknown }` and `HostPlatform currentHostPlatform()`.
- Produces: `enum TransportGuidance { androidBluetoothPermission, applePairingPrompt, windowsPairDevice, linuxPairFromSettings, bluetoothAdapterOff, linuxSerialGroup, linuxModemManager, windowsPortAccessDenied, macosSerialEntitlement, androidUsbPermission, portNotFound }` and `abstract interface class GuidedTransport { TransportGuidance? get guidance; }`.
- Produces: `abstract final class NusUuids { static const String service, write, notify; }`, `abstract final class NordicDfuUuids { static const String service, controlPoint, packet; }`, `abstract final class ChameleonBleNames { static const List<String> applicationPrefixes, bootloaderNames; }`, `String normalizeUuid(String uuid)`.
- Produces: `abstract final class ChameleonUsbIds { static const int applicationVid, applicationPid, bootloaderVid, bootloaderPid, baudRate, dataBits, stopBits; static const String manufacturer; }`.

- [ ] **Step 1: Add the dependencies and the test tag**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd packages/chameleon_flutter
flutter pub add universal_ble usb_serial
flutter pub add dev:mocktail
```

Expected resolved versions: `universal_ble` 2.2.0, `usb_serial` 0.5.2, `libserialport_plus` 1.0.4 (already pinned by Spike A — do not change it). Record the resolved versions in the commit body.

Create `packages/chameleon_flutter/dart_test.yaml`:

```yaml
tags:
  hardware:
    description: Needs a real Chameleon Ultra; see docs/hardware-checklist.md.
    skip: "run with --tags hardware and a device attached"
  hardware-validate:
    description: Behaviour unproven on hardware; see docs/hardware-checklist.md.
```

- [ ] **Step 2: Write the failing tests**

```dart
// test/host_platform_test.dart
import 'dart:io';

import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports the platform the test process runs on', () {
    final expected = switch (true) {
      _ when Platform.isMacOS => HostPlatform.macos,
      _ when Platform.isLinux => HostPlatform.linux,
      _ when Platform.isWindows => HostPlatform.windows,
      _ => HostPlatform.unknown,
    };
    expect(currentHostPlatform(), expected);
  });

  test('guidance values cover both link kinds', () {
    expect(TransportGuidance.values, contains(TransportGuidance.linuxModemManager));
    expect(TransportGuidance.values, contains(TransportGuidance.windowsPairDevice));
  });
}
```

```dart
// test/ble/ble_uuids_test.dart
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the Nordic UART UUIDs match the firmware', () {
    expect(NusUuids.service, '6E400001-B5A3-F393-E0A9-E50E24DCCA9E');
    expect(NusUuids.write, '6E400002-B5A3-F393-E0A9-E50E24DCCA9E');
    expect(NusUuids.notify, '6E400003-B5A3-F393-E0A9-E50E24DCCA9E');
  });

  test('the Nordic DFU UUIDs match the bootloader', () {
    expect(NordicDfuUuids.service, 'FE59');
    expect(NordicDfuUuids.controlPoint, '8EC90001-F315-4F60-9FB8-838830DAEA50');
    expect(NordicDfuUuids.packet, '8EC90002-F315-4F60-9FB8-838830DAEA50');
  });

  test('advertised names', () {
    expect(ChameleonBleNames.applicationPrefixes, ['ChameleonUltra', 'ChameleonLite']);
    expect(ChameleonBleNames.bootloaderNames, ['CU', 'CL']);
  });

  test('normalizeUuid lowercases and strips braces so comparisons are stable', () {
    expect(normalizeUuid('{6E400001-B5A3-F393-E0A9-E50E24DCCA9E}'),
        '6e400001-b5a3-f393-e0a9-e50e24dcca9e');
    expect(normalizeUuid('fe59'), 'fe59');
  });
}
```

```dart
// test/serial/serial_ids_test.dart
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('USB identifiers match the firmware and the bootloader', () {
    expect(ChameleonUsbIds.applicationVid, 0x6868);
    expect(ChameleonUsbIds.applicationPid, 0x8686);
    expect(ChameleonUsbIds.bootloaderVid, 0x1915);
    expect(ChameleonUsbIds.bootloaderPid, 0x521F);
    expect(ChameleonUsbIds.manufacturer, 'Proxgrind');
  });

  test('line settings are 115200 8N1', () {
    expect(ChameleonUsbIds.baudRate, 115200);
    expect(ChameleonUsbIds.dataBits, 8);
    expect(ChameleonUsbIds.stopBits, 1);
  });
}
```

- [ ] **Step 3: Run to verify they fail**

```bash
cd packages/chameleon_flutter && flutter test
```

Expected: FAIL — undefined names `HostPlatform`, `NusUuids`, `ChameleonUsbIds`.

- [ ] **Step 4: Implement**

```dart
// lib/src/host_platform.dart
import 'dart:io';

/// The five targets in spec 5.4, plus a fallback for anything else (a test
/// runner on an unusual host). Passed into transports rather than read
/// inline so platform-specific behaviour is unit-testable.
enum HostPlatform { android, ios, macos, windows, linux, unknown }

/// The platform this process runs on.
HostPlatform currentHostPlatform() {
  if (Platform.isAndroid) return HostPlatform.android;
  if (Platform.isIOS) return HostPlatform.ios;
  if (Platform.isMacOS) return HostPlatform.macos;
  if (Platform.isWindows) return HostPlatform.windows;
  if (Platform.isLinux) return HostPlatform.linux;
  return HostPlatform.unknown;
}
```

```dart
// lib/src/guidance.dart
/// Why a transport could not be used, in terms the app can turn into a
/// concrete instruction. The transport exposes the reason as a value; the
/// wording lives in the app's ARB files (spec 7.6), never here.
enum TransportGuidance {
  /// Android 12+ BLUETOOTH_SCAN / BLUETOOTH_CONNECT, or location below 12.
  androidBluetoothPermission,

  /// The OS shows its own pairing prompt; tell the user to accept it.
  applePairingPrompt,

  /// Windows: pairing is driven from the app; retry or pair from Settings.
  windowsPairDevice,

  /// Linux: BlueZ has no pairing agent. Pair from system settings with the
  /// device's passkey, then reconnect.
  linuxPairFromSettings,

  /// Bluetooth is switched off.
  bluetoothAdapterOff,

  /// Linux: the user is not in the serial group (dialout/uucp) or no udev
  /// rule grants access to the port.
  linuxSerialGroup,

  /// Linux: another process holds the port. ModemManager is the usual cause.
  linuxModemManager,

  /// Windows: the COM port is open in another application.
  windowsPortAccessDenied,

  /// macOS: the sandboxed build lacks com.apple.security.device.serial.
  macosSerialEntitlement,

  /// Android: the USB device permission dialog was declined.
  androidUsbPermission,

  /// The port or device is gone: unplugged, or out of range.
  portNotFound,
}

/// A transport that can explain a failure as a [TransportGuidance].
abstract interface class GuidedTransport {
  /// The reason for the most recent failure, or null if there was none.
  TransportGuidance? get guidance;
}
```

```dart
// lib/src/ble/ble_uuids.dart
/// Nordic UART Service, the Chameleon's application-mode BLE link.
///
/// Values are copied from `docs/research/chameleon-protocol.md` and the
/// firmware sources. Never retype them.
abstract final class NusUuids {
  static const String service = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String write = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String notify = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E';
}

/// Nordic Secure DFU service, the bootloader's BLE link (spec 5.3).
abstract final class NordicDfuUuids {
  static const String service = 'FE59';
  static const String controlPoint = '8EC90001-F315-4F60-9FB8-838830DAEA50';
  static const String packet = '8EC90002-F315-4F60-9FB8-838830DAEA50';
}

/// Advertised names (spec 5.1 and 5.5).
abstract final class ChameleonBleNames {
  static const List<String> applicationPrefixes = <String>[
    'ChameleonUltra',
    'ChameleonLite',
  ];
  static const List<String> bootloaderNames = <String>['CU', 'CL'];
}

/// Case- and brace-insensitive form for comparing UUIDs. Platforms report
/// them inconsistently: CoreBluetooth uppercases, BlueZ lowercases, Windows
/// wraps them in braces.
String normalizeUuid(String uuid) =>
    uuid.replaceAll('{', '').replaceAll('}', '').trim().toLowerCase();
```

```dart
// lib/src/serial/serial_ids.dart
/// USB identifiers and line settings for the Chameleon over CDC-ACM
/// (spec 5.2, 5.5; `docs/research/chameleon-protocol.md`).
abstract final class ChameleonUsbIds {
  static const int applicationVid = 0x6868;
  static const int applicationPid = 0x8686;
  static const int bootloaderVid = 0x1915;
  static const int bootloaderPid = 0x521F;
  static const String manufacturer = 'Proxgrind';

  static const int baudRate = 115200;
  static const int dataBits = 8;
  static const int stopBits = 1;
}
```

Replace `lib/chameleon_flutter.dart` with the barrel:

```dart
/// Platform transports and DFU channels for the chameleon SDK.
///
/// Every native dependency of Spectra lives in this package and nowhere
/// else (spec section 5).
library;

export 'src/ble/ble_uuids.dart';
export 'src/guidance.dart';
export 'src/host_platform.dart';
export 'src/serial/serial_ids.dart';

/// Version of the platform package, mirrored from pubspec.yaml.
const String chameleonFlutterVersion = '0.1.0';
```

- [ ] **Step 5: Run the tests**

```bash
cd packages/chameleon_flutter && flutter test
```

Expected: PASS, 8 tests (including the existing version smoke test).

- [ ] **Step 6: Commit**

```bash
git add packages/chameleon_flutter pubspec.lock
git commit -m "feat(chameleon_flutter): add wire constants, host platform and guidance

The UUIDs, USB ids and line settings are transcribed once, from the
protocol research, so no transport retypes them. TransportGuidance gives
the app a typed reason for a permission or pairing failure without putting
user-facing text in the package."
```

---

### Task 3: Platform setup files for Bluetooth, USB and the macOS sandbox

Spec 5.7: this package owns the Android USB device filter and Bluetooth permissions, the iOS Bluetooth usage strings and the macOS sandbox entitlements. A Flutter *package* cannot carry the app's manifest, plist or entitlements, so the edits land in `app/` and in the example, and a workspace-root test asserts they stay there. Without them the plugins fail at runtime in ways no unit test catches.

**Files:**
- Modify: `app/android/app/src/main/AndroidManifest.xml`, `app/ios/Runner/Info.plist`, `app/macos/Runner/DebugProfile.entitlements`, `app/macos/Runner/Release.entitlements`
- Create: `app/android/app/src/main/res/xml/device_filter.xml`
- Test: `test/platform_setup_test.dart` (workspace root, run by `melos run test:root`)

**Interfaces:**
- Produces: nothing importable. The contract is the file content the root test asserts.

- [ ] **Step 1: Write the failing test**

```dart
// test/platform_setup_test.dart
import 'dart:io';

import 'package:test/test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  group('Android (spec 5.7)', () {
    late String manifest;
    setUpAll(() =>
        manifest = read('app/android/app/src/main/AndroidManifest.xml'));

    test('declares the Android 12+ Bluetooth permissions', () {
      expect(manifest, contains('android.permission.BLUETOOTH_SCAN'));
      expect(manifest, contains('android.permission.BLUETOOTH_CONNECT'));
      expect(manifest, contains('neverForLocation'));
    });

    test('declares the pre-12 legacy permissions and location', () {
      expect(manifest, contains('android:name="android.permission.BLUETOOTH"'));
      expect(manifest, contains('android:name="android.permission.BLUETOOTH_ADMIN"'));
      expect(manifest, contains('android.permission.ACCESS_FINE_LOCATION'));
      expect(manifest, contains('android:maxSdkVersion="30"'));
    });

    test('registers the USB attached intent and its device filter', () {
      expect(manifest, contains('android.hardware.usb.action.USB_DEVICE_ATTACHED'));
      expect(manifest, contains('@xml/device_filter'));
    });

    test('the device filter lists the app and the bootloader ids', () {
      final filter = read('app/android/app/src/main/res/xml/device_filter.xml');
      // 0x6868 = 26728, 0x8686 = 34438, 0x1915 = 6421, 0x521F = 21023.
      expect(filter, contains('vendor-id="26728"'));
      expect(filter, contains('product-id="34438"'));
      expect(filter, contains('vendor-id="6421"'));
      expect(filter, contains('product-id="21023"'));
    });
  });

  test('iOS declares the Bluetooth usage string', () {
    final plist = read('app/ios/Runner/Info.plist');
    expect(plist, contains('NSBluetoothAlwaysUsageDescription'));
  });

  test('macOS entitles Bluetooth and serial in both configurations', () {
    for (final name in const ['DebugProfile', 'Release']) {
      final ents = read('app/macos/Runner/$name.entitlements');
      expect(ents, contains('com.apple.security.device.bluetooth'),
          reason: '$name is missing the Bluetooth entitlement');
      expect(ents, contains('com.apple.security.device.serial'),
          reason: '$name is missing the serial entitlement');
    }
  });

  test('the transport example matches the app', () {
    final base = 'packages/chameleon_flutter/example/macos/Runner';
    for (final name in const ['DebugProfile', 'Release']) {
      final ents = read('$base/$name.entitlements');
      expect(ents, contains('com.apple.security.device.bluetooth'));
      expect(ents, contains('com.apple.security.device.serial'));
    }
    expect(read('$base/Info.plist'),
        contains('NSBluetoothAlwaysUsageDescription'));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart test test/platform_setup_test.dart
```

Expected: FAIL on every group — none of the entries exist yet.

- [ ] **Step 3: Edit the Android manifest**

Insert directly after the opening `<manifest ...>` tag in `app/android/app/src/main/AndroidManifest.xml`:

```xml
    <!-- Spec 5.7: BLE on Android 12+ uses the two runtime Bluetooth
         permissions; neverForLocation lets us skip the location grant.
         Android 11 and below need the legacy pair plus fine location, which
         is why both are capped with maxSdkVersion. -->
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN"
        android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.BLUETOOTH"
        android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN"
        android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"
        android:maxSdkVersion="30" />

    <uses-feature android:name="android.hardware.bluetooth_le"
        android:required="false" />
    <uses-feature android:name="android.hardware.usb.host"
        android:required="false" />
```

Inside the existing `<activity android:name=".MainActivity" ...>` element, after the LAUNCHER `<intent-filter>`, add:

```xml
            <!-- Spec 5.5: launch on attach for both the application and the
                 Nordic bootloader, so a device that reboots into DFU is
                 still reachable. -->
            <intent-filter>
                <action android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED" />
            </intent-filter>
            <meta-data
                android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED"
                android:resource="@xml/device_filter" />
```

- [ ] **Step 4: Create the USB device filter**

Android's `usb-device` attributes are decimal, not hex.

```xml
<?xml version="1.0" encoding="utf-8"?>
<!-- Spec 5.2 and 5.5. Decimal, because android:vendor-id is an integer:
     0x6868 = 26728, 0x8686 = 34438 (application);
     0x1915 = 6421,  0x521F = 21023 (Nordic bootloader). -->
<resources>
    <usb-device vendor-id="26728" product-id="34438" />
    <usb-device vendor-id="6421" product-id="21023" />
</resources>
```

- [ ] **Step 5: Edit the iOS plist and the macOS entitlements**

In `app/ios/Runner/Info.plist`, inside the top-level `<dict>`:

```xml
	<key>NSBluetoothAlwaysUsageDescription</key>
	<string>Spectra uses Bluetooth to connect to your Chameleon device.</string>
```

In **both** `app/macos/Runner/DebugProfile.entitlements` and `app/macos/Runner/Release.entitlements`, inside the `<dict>`:

```xml
	<key>com.apple.security.device.bluetooth</key>
	<true/>
	<key>com.apple.security.device.serial</key>
	<true/>
```

Apply the same two entitlement keys to `packages/chameleon_flutter/example/macos/Runner/DebugProfile.entitlements` and `Release.entitlements` — the serial key is already there from Spike A, so only the Bluetooth key is new — and add the same `NSBluetoothAlwaysUsageDescription` pair to `packages/chameleon_flutter/example/macos/Runner/Info.plist`.

Add a doc note in `docs/hardware-checklist.md` under H1 (Task 15 fills in the rest): the serial entitlement's necessity for `open()` is `hardware-validate`; Spike A proved enumeration works without it.

- [ ] **Step 6: Run the test and the analyzer**

```bash
dart test test/platform_setup_test.dart
```

Expected: PASS, 7 tests.

- [ ] **Step 7: Commit**

```bash
git add app/android app/ios app/macos packages/chameleon_flutter/example/macos test/platform_setup_test.dart
git commit -m "feat(app): add Bluetooth, USB and sandbox platform setup

Spec 5.7 assigns these files to the transports package, but a Flutter
package cannot own the app's manifest, plist or entitlements, so they live
in app/ and in the example with a workspace-root test pinning them."
```

---

### Task 4: The BleAdapter seam, error mapping and a scripted fake

`universal_ble` cannot be exercised in a unit test: every call goes through a plugin channel. So the transport talks to `BleAdapter`, an interface this package owns, and `UniversalBleAdapter` is the only file in the repo that imports `package:universal_ble/universal_ble.dart`. The adapter also collapses `universal_ble`'s 61-value `UniversalBleErrorCode` into the eight distinctions the transport actually makes, so the transport's error mapping is a pure function over `BleFailure`.

**Files:**
- Create: `lib/src/ble/ble_failure.dart`, `lib/src/ble/ble_adapter.dart`, `lib/src/ble/universal_ble_adapter.dart`, `test/support/fake_ble_adapter.dart`
- Modify: `lib/chameleon_flutter.dart`
- Test: `test/ble/ble_failure_test.dart`

**Interfaces:**
- Produces:

```dart
enum BleAvailability { unknown, resetting, unsupported, unauthorized, poweredOff, poweredOn }

enum BleFailure {
  insufficientAuthentication, permissionDenied, adapterOff,
  deviceNotFound, disconnected, timeout, writeFailed, unknown,
}

final class BleAdapterException implements Exception {
  const BleAdapterException(this.failure, this.message);
  final BleFailure failure;
  final String message;
}

final class BleScanEntry {
  const BleScanEntry({required String deviceId, required String? name, List<String> services = const []});
  final String deviceId;
  final String? name;
  final List<String> services; // normalized (lowercase, unbraced)
}

abstract interface class BleAdapter {
  Future<BleAvailability> availability();
  Stream<BleScanEntry> scan({List<String> withServices, List<String> withNamePrefix});
  Future<void> stopScan();
  Future<void> connect(String deviceId, {Duration? timeout});
  Future<void> disconnect(String deviceId);
  Stream<bool> connectionChanges(String deviceId);
  Future<void> discoverServices(String deviceId);
  Future<int> requestMtu(String deviceId, int expectedMtu);
  Future<void> subscribe(String deviceId, {required String service, required String characteristic});
  Stream<Uint8List> notifications(String deviceId, {required String service, required String characteristic});
  Future<void> write(String deviceId, {required String service, required String characteristic, required Uint8List value, bool withResponse = true});
  Future<void> pair(String deviceId);
  Future<bool?> isPaired(String deviceId);
}

BleFailure bleFailureFromCode(String code);
```

- Produces (test double, used by Tasks 5, 6, 12 and 14): `FakeBleAdapter` in `test/support/fake_ble_adapter.dart`, with:

```dart
final class FakeBleAdapter implements BleAdapter {
  FakeBleAdapter({BleAvailability availability = BleAvailability.poweredOn, int mtu = 247, List<BleScanEntry> advertisements = const []});
  BleAvailability availability_;                 // mutable
  int mtu;                                       // requestMtu result; set to -1 to throw
  int connectAttempts;                           // how many times connect() was called
  int failConnectTimes;                          // fail this many connects with failConnectWith
  BleFailure failConnectWith;
  BleFailure? failSubscribeWith;                 // thrown once, then cleared
  BleFailure? failWriteWith;                     // thrown once, then cleared
  bool pairSucceeds;
  int pairCalls;
  final List<Uint8List> writes;                  // every chunk, in order
  final List<String> writtenCharacteristics;     // parallel to writes
  final List<bool> writeWithResponse;            // parallel to writes
  void emitNotification(String characteristic, List<int> bytes);
  void emitDisconnect();
  void emitAdvertisement(BleScanEntry entry);
}
```

- [ ] **Step 1: Write the failing test**

```dart
// test/ble/ble_failure_test.dart
import 'package:chameleon_flutter/src/ble/ble_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('security codes become insufficientAuthentication', () {
    for (final code in const [
      'insufficientAuthentication',
      'insufficientEncryption',
      'insufficientAuthorization',
      'protectionLevelNotMet',
      'authenticationFailure',
      'notPaired',
      'pairingFailed',
    ]) {
      expect(bleFailureFromCode(code), BleFailure.insufficientAuthentication,
          reason: code);
    }
  });

  test('authorization codes become permissionDenied', () {
    for (final code in const [
      'bluetoothUnauthorized',
      'bluetoothNotAllowed',
      'accessDenied',
    ]) {
      expect(bleFailureFromCode(code), BleFailure.permissionDenied, reason: code);
    }
  });

  test('adapter codes become adapterOff', () {
    expect(bleFailureFromCode('bluetoothNotEnabled'), BleFailure.adapterOff);
    expect(bleFailureFromCode('bluetoothNotAvailable'), BleFailure.adapterOff);
  });

  test('lookup and link codes are distinguished', () {
    expect(bleFailureFromCode('deviceNotFound'), BleFailure.deviceNotFound);
    expect(bleFailureFromCode('characteristicNotFound'), BleFailure.deviceNotFound);
    expect(bleFailureFromCode('deviceDisconnected'), BleFailure.disconnected);
    expect(bleFailureFromCode('connectionTerminated'), BleFailure.disconnected);
    expect(bleFailureFromCode('connectionTimeout'), BleFailure.timeout);
    expect(bleFailureFromCode('operationTimeout'), BleFailure.timeout);
    expect(bleFailureFromCode('writeFailed'), BleFailure.writeFailed);
    expect(bleFailureFromCode('writeRequestBusy'), BleFailure.writeFailed);
  });

  test('anything unrecognised is unknown, not a crash', () {
    expect(bleFailureFromCode('somethingNewInAFutureRelease'), BleFailure.unknown);
    expect(bleFailureFromCode(''), BleFailure.unknown);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd packages/chameleon_flutter && flutter test test/ble/ble_failure_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: '.../ble_failure.dart'`.

- [ ] **Step 3: Implement the failure mapping**

```dart
// lib/src/ble/ble_failure.dart
/// The distinctions the BLE transport actually makes, mapped from
/// universal_ble's 61-value `UniversalBleErrorCode`. Keeping the mapping in
/// one pure function means the transport can be tested without the plugin.
enum BleFailure {
  /// The link needs a bond the device does not have: spec 5.1 detects
  /// `pairingRequired` from exactly this on subscribe or write.
  insufficientAuthentication,

  /// The OS refused the Bluetooth permission.
  permissionDenied,

  /// The adapter is off or unavailable.
  adapterOff,

  /// The device, service or characteristic could not be found.
  deviceNotFound,

  /// The link dropped.
  disconnected,

  /// The operation timed out.
  timeout,

  /// A write was rejected.
  writeFailed,

  /// Anything else, including codes added by a future universal_ble.
  unknown,
}

final class BleAdapterException implements Exception {
  const BleAdapterException(this.failure, this.message);
  final BleFailure failure;
  final String message;

  @override
  String toString() => 'BleAdapterException(${failure.name}): $message';
}

/// Maps a `UniversalBleErrorCode.name` to a [BleFailure].
///
/// Takes the code's *name* rather than the enum so this file has no
/// universal_ble import and stays unit-testable.
BleFailure bleFailureFromCode(String code) => switch (code) {
  'insufficientAuthentication' ||
  'insufficientEncryption' ||
  'insufficientAuthorization' ||
  'insufficientKeySize' ||
  'protectionLevelNotMet' ||
  'authenticationFailure' ||
  'notPaired' ||
  'notPairable' ||
  'pairingFailed' ||
  'pairingCancelled' ||
  'pairingTimeout' ||
  'pairingNotAllowed' => BleFailure.insufficientAuthentication,
  'bluetoothUnauthorized' ||
  'bluetoothNotAllowed' ||
  'accessDenied' => BleFailure.permissionDenied,
  'bluetoothNotEnabled' ||
  'bluetoothNotAvailable' ||
  'webBluetoothGloballyDisabled' => BleFailure.adapterOff,
  'deviceNotFound' ||
  'serviceNotFound' ||
  'characteristicNotFound' => BleFailure.deviceNotFound,
  'deviceDisconnected' ||
  'connectionTerminated' ||
  'connectionRejected' => BleFailure.disconnected,
  'connectionTimeout' || 'operationTimeout' => BleFailure.timeout,
  'writeFailed' ||
  'writeNotPermitted' ||
  'writeRequestBusy' ||
  'characteristicDoesNotSupportWrite' => BleFailure.writeFailed,
  _ => BleFailure.unknown,
};
```

- [ ] **Step 4: Declare the adapter interface**

```dart
// lib/src/ble/ble_adapter.dart
import 'dart:typed_data';

import 'ble_failure.dart';

/// Mirrors universal_ble's `AvailabilityState`.
enum BleAvailability { unknown, resetting, unsupported, unauthorized, poweredOff, poweredOn }

/// One advertisement seen during a scan.
final class BleScanEntry {
  const BleScanEntry({
    required this.deviceId,
    required this.name,
    this.services = const <String>[],
  });

  final String deviceId;
  final String? name;

  /// Advertised service UUIDs, already run through `normalizeUuid`.
  final List<String> services;
}

/// The seam over the native BLE stack.
///
/// Every method throws [BleAdapterException] on failure and nothing else, so
/// transport logic never sees a plugin type. `universal_ble` is imported by
/// exactly one implementation of this interface.
abstract interface class BleAdapter {
  Future<BleAvailability> availability();

  /// Advertisements matching the filters. Cancelling the subscription is
  /// not enough to stop the radio: call [stopScan].
  Stream<BleScanEntry> scan({
    List<String> withServices = const <String>[],
    List<String> withNamePrefix = const <String>[],
  });

  Future<void> stopScan();

  Future<void> connect(String deviceId, {Duration? timeout});

  Future<void> disconnect(String deviceId);

  /// true on connect, false on disconnect, for the life of the adapter.
  Stream<bool> connectionChanges(String deviceId);

  Future<void> discoverServices(String deviceId);

  /// The negotiated ATT MTU. Throws if the platform will not report one.
  Future<int> requestMtu(String deviceId, int expectedMtu);

  Future<void> subscribe(
    String deviceId, {
    required String service,
    required String characteristic,
  });

  Stream<Uint8List> notifications(
    String deviceId, {
    required String service,
    required String characteristic,
  });

  Future<void> write(
    String deviceId, {
    required String service,
    required String characteristic,
    required Uint8List value,
    bool withResponse = true,
  });

  Future<void> pair(String deviceId);

  Future<bool?> isPaired(String deviceId);
}
```

- [ ] **Step 5: Implement it over universal_ble**

```dart
// lib/src/ble/universal_ble_adapter.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

import 'ble_adapter.dart';
import 'ble_failure.dart';
import 'ble_uuids.dart';

/// The only file in Spectra that imports universal_ble (2.2.0).
///
/// Every call is wrapped so a `UniversalBleException` becomes a
/// [BleAdapterException]; the transport above never sees a plugin type.
final class UniversalBleAdapter implements BleAdapter {
  UniversalBleAdapter();

  final Map<String, BleDevice> _devices = <String, BleDevice>{};

  BleDevice _device(String deviceId) =>
      _devices.putIfAbsent(deviceId, () => BleDevice(deviceId: deviceId));

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on UniversalBleException catch (e) {
      throw BleAdapterException(bleFailureFromCode(e.code.name), e.toString());
    } on Exception catch (e) {
      throw BleAdapterException(BleFailure.unknown, e.toString());
    }
  }

  @override
  Future<BleAvailability> availability() => _guard(() async {
    final state = await UniversalBle.getBluetoothAvailabilityState();
    return switch (state) {
      AvailabilityState.poweredOn => BleAvailability.poweredOn,
      AvailabilityState.poweredOff => BleAvailability.poweredOff,
      AvailabilityState.unauthorized => BleAvailability.unauthorized,
      AvailabilityState.unsupported => BleAvailability.unsupported,
      AvailabilityState.resetting => BleAvailability.resetting,
      AvailabilityState.unknown => BleAvailability.unknown,
    };
  });

  @override
  Stream<BleScanEntry> scan({
    List<String> withServices = const <String>[],
    List<String> withNamePrefix = const <String>[],
  }) {
    final controller = StreamController<BleScanEntry>();
    StreamSubscription<BleDevice>? sub;
    controller.onListen = () {
      sub = UniversalBle.scanStream.listen((device) {
        _devices[device.deviceId] = device;
        controller.add(
          BleScanEntry(
            deviceId: device.deviceId,
            name: device.name,
            services: device.services.map(normalizeUuid).toList(growable: false),
          ),
        );
      }, onError: controller.addError);
      unawaited(
        _guard(
          () => UniversalBle.startScan(
            scanFilter: ScanFilter(
              withServices: withServices,
              withNamePrefix: withNamePrefix,
            ),
          ),
        ).catchError((Object e, StackTrace s) => controller.addError(e, s)),
      );
    };
    controller.onCancel = () async {
      await sub?.cancel();
      await stopScan();
      await controller.close();
    };
    return controller.stream;
  }

  @override
  Future<void> stopScan() => _guard(UniversalBle.stopScan);

  @override
  Future<void> connect(String deviceId, {Duration? timeout}) =>
      _guard(() => _device(deviceId).connect(timeout: timeout));

  @override
  Future<void> disconnect(String deviceId) =>
      _guard(() => _device(deviceId).disconnect());

  @override
  Stream<bool> connectionChanges(String deviceId) =>
      _device(deviceId).connectionStream;

  @override
  Future<void> discoverServices(String deviceId) =>
      _guard(() => _device(deviceId).discoverServices());

  @override
  Future<int> requestMtu(String deviceId, int expectedMtu) =>
      _guard(() => _device(deviceId).requestMtu(expectedMtu));

  @override
  Future<void> subscribe(
    String deviceId, {
    required String service,
    required String characteristic,
  }) => _guard(() async {
    final c = await _device(deviceId)
        .getCharacteristic(characteristic, service: service);
    await c.notifications.subscribe();
  });

  @override
  Stream<Uint8List> notifications(
    String deviceId, {
    required String service,
    required String characteristic,
  }) {
    final controller = StreamController<Uint8List>.broadcast();
    unawaited(() async {
      try {
        final c = await _device(deviceId)
            .getCharacteristic(characteristic, service: service);
        await controller.addStream(c.onValueReceived);
      } on Exception catch (e, s) {
        controller.addError(
          BleAdapterException(BleFailure.unknown, e.toString()),
          s,
        );
      }
    }());
    return controller.stream;
  }

  @override
  Future<void> write(
    String deviceId, {
    required String service,
    required String characteristic,
    required Uint8List value,
    bool withResponse = true,
  }) => _guard(() async {
    final c = await _device(deviceId)
        .getCharacteristic(characteristic, service: service);
    await c.write(value, withResponse: withResponse);
  });

  @override
  Future<void> pair(String deviceId) => _guard(() => _device(deviceId).pair());

  @override
  Future<bool?> isPaired(String deviceId) =>
      _guard(() => _device(deviceId).isPaired());
}
```

- [ ] **Step 6: Write the scripted fake**

```dart
// test/support/fake_ble_adapter.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:chameleon_flutter/src/ble/ble_adapter.dart';
import 'package:chameleon_flutter/src/ble/ble_failure.dart';

/// A [BleAdapter] whose every outcome is set by the test.
///
/// Nothing here talks to a radio: it exists so the transport's retry,
/// chunking, state and error logic can be proved without a device.
final class FakeBleAdapter implements BleAdapter {
  FakeBleAdapter({
    this.availability_ = BleAvailability.poweredOn,
    this.mtu = 247,
    List<BleScanEntry> advertisements = const <BleScanEntry>[],
  }) : _seed = advertisements;

  final List<BleScanEntry> _seed;

  BleAvailability availability_;

  /// Result of [requestMtu]; a negative value makes it throw instead.
  int mtu;

  int connectAttempts = 0;
  int failConnectTimes = 0;
  BleFailure failConnectWith = BleFailure.timeout;

  BleFailure? failSubscribeWith;
  BleFailure? failWriteWith;

  bool pairSucceeds = true;
  int pairCalls = 0;

  bool discovered = false;
  bool disconnected = false;
  bool scanStopped = false;

  final List<Uint8List> writes = <Uint8List>[];
  final List<String> writtenCharacteristics = <String>[];
  final List<bool> writeWithResponse = <bool>[];

  final StreamController<BleScanEntry> _scan =
      StreamController<BleScanEntry>.broadcast();
  final StreamController<bool> _connection = StreamController<bool>.broadcast();
  final Map<String, StreamController<Uint8List>> _notify =
      <String, StreamController<Uint8List>>{};

  StreamController<Uint8List> _controllerFor(String characteristic) =>
      _notify.putIfAbsent(
        characteristic,
        () => StreamController<Uint8List>.broadcast(),
      );

  void emitNotification(String characteristic, List<int> bytes) =>
      _controllerFor(characteristic).add(Uint8List.fromList(bytes));

  void emitDisconnect() => _connection.add(false);

  void emitAdvertisement(BleScanEntry entry) => _scan.add(entry);

  @override
  Future<BleAvailability> availability() async => availability_;

  @override
  Stream<BleScanEntry> scan({
    List<String> withServices = const <String>[],
    List<String> withNamePrefix = const <String>[],
  }) {
    scheduleMicrotask(() {
      for (final e in _seed) {
        _scan.add(e);
      }
    });
    return _scan.stream;
  }

  @override
  Future<void> stopScan() async => scanStopped = true;

  @override
  Future<void> connect(String deviceId, {Duration? timeout}) async {
    connectAttempts++;
    if (failConnectTimes > 0) {
      failConnectTimes--;
      throw BleAdapterException(failConnectWith, 'scripted connect failure');
    }
    _connection.add(true);
  }

  @override
  Future<void> disconnect(String deviceId) async {
    disconnected = true;
    _connection.add(false);
  }

  @override
  Stream<bool> connectionChanges(String deviceId) => _connection.stream;

  @override
  Future<void> discoverServices(String deviceId) async => discovered = true;

  @override
  Future<int> requestMtu(String deviceId, int expectedMtu) async {
    if (mtu < 0) {
      throw const BleAdapterException(
        BleFailure.unknown,
        'platform will not report an MTU',
      );
    }
    return mtu;
  }

  @override
  Future<void> subscribe(
    String deviceId, {
    required String service,
    required String characteristic,
  }) async {
    final failure = failSubscribeWith;
    if (failure != null) {
      failSubscribeWith = null;
      throw BleAdapterException(failure, 'scripted subscribe failure');
    }
  }

  @override
  Stream<Uint8List> notifications(
    String deviceId, {
    required String service,
    required String characteristic,
  }) => _controllerFor(characteristic).stream;

  @override
  Future<void> write(
    String deviceId, {
    required String service,
    required String characteristic,
    required Uint8List value,
    bool withResponse = true,
  }) async {
    final failure = failWriteWith;
    if (failure != null) {
      failWriteWith = null;
      throw BleAdapterException(failure, 'scripted write failure');
    }
    writes.add(Uint8List.fromList(value));
    writtenCharacteristics.add(characteristic);
    writeWithResponse.add(withResponse);
  }

  @override
  Future<void> pair(String deviceId) async {
    pairCalls++;
    if (!pairSucceeds) {
      throw const BleAdapterException(
        BleFailure.insufficientAuthentication,
        'scripted pair failure',
      );
    }
  }

  @override
  Future<bool?> isPaired(String deviceId) async => pairSucceeds;

  Future<void> dispose() async {
    await _scan.close();
    await _connection.close();
    for (final c in _notify.values) {
      await c.close();
    }
  }
}
```

- [ ] **Step 7: Export and run**

Add to `lib/chameleon_flutter.dart`:

```dart
export 'src/ble/ble_adapter.dart';
export 'src/ble/ble_failure.dart' show BleAdapterException, BleFailure;
export 'src/ble/universal_ble_adapter.dart';
```

```bash
cd packages/chameleon_flutter && flutter test && flutter analyze
```

Expected: PASS, 5 new tests; analyzer clean.

- [ ] **Step 8: Commit**

```bash
git add packages/chameleon_flutter
git commit -m "feat(chameleon_flutter): add the BleAdapter seam over universal_ble

universal_ble only works behind a plugin channel, so the transport talks to
an interface this package owns and a scripted fake stands in for the radio
in tests. The 61 universal_ble error codes collapse to the eight
distinctions the transport makes."
```

---

### Task 5: BleTransport

**Files:**
- Create: `lib/src/ble/ble_transport.dart`
- Modify: `lib/chameleon_flutter.dart`
- Test: `test/ble/ble_transport_test.dart`

**Interfaces:**
- Consumes: `BleAdapter`, `BleAdapterException`, `BleFailure`, `BleAvailability`, `NusUuids`, `HostPlatform`, `TransportGuidance`, `GuidedTransport`, `FakeBleAdapter`, and from `package:chameleon/chameleon.dart`: `Transport`, `TransportKind`, `TransportState` and its variants, `CloseCause`, `Disconnected`, `PermissionDenied`, `PairingRequired`, `AdapterOff`, `DeviceNotFound`.
- Produces:

```dart
final class BleTransport implements Transport, GuidedTransport {
  BleTransport({
    required String deviceId,
    required BleAdapter adapter,
    HostPlatform? platform,
    int connectAttempts = 5,
    Duration initialBackoff = const Duration(milliseconds: 250),
    Duration maxBackoff = const Duration(seconds: 4),
    int requestedMtu = 247,
    int fallbackMaxWrite = 20,
  });
  final String deviceId;
  int get maxWriteLength;             // valid only after open()
  @override TransportKind get kind;   // TransportKind.ble
  @override TransportGuidance? get guidance;
  @override Future<void> open();
  @override Future<void> close();
  @override Stream<Uint8List> get incoming;
  @override Future<void> write(Uint8List bytes);
  @override Stream<TransportState> get state;
  @override TransportState get currentState;
}
```

- [ ] **Step 1: Write the failing tests**

```dart
// test/ble/ble_transport_test.dart
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:chameleon_flutter/src/ble/ble_adapter.dart';
import 'package:chameleon_flutter/src/ble/ble_failure.dart';
import 'package:chameleon_flutter/src/ble/ble_transport.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_ble_adapter.dart';

BleTransport build(
  FakeBleAdapter adapter, {
  HostPlatform platform = HostPlatform.macos,
  int attempts = 5,
}) => BleTransport(
  deviceId: 'AA:BB:CC:DD:EE:FF',
  adapter: adapter,
  platform: platform,
  connectAttempts: attempts,
  initialBackoff: const Duration(milliseconds: 1),
  maxBackoff: const Duration(milliseconds: 4),
);

void main() {
  test('open goes opening -> open and subscribes to notify', () async {
    final adapter = FakeBleAdapter();
    final t = build(adapter);
    final seen = <TransportState>[];
    t.state.listen(seen.add);
    await t.open();
    await Future<void>.delayed(Duration.zero);
    expect(seen.map((s) => s.runtimeType).toList(),
        [TransportOpening, TransportOpen]);
    expect(t.currentState, isA<TransportOpen>());
    expect(adapter.discovered, isTrue);
    await t.close();
    await adapter.dispose();
  });

  test('the write length comes from the negotiated MTU, never assumed', () async {
    final adapter = FakeBleAdapter(mtu: 104);
    final t = build(adapter);
    await t.open();
    expect(t.maxWriteLength, 101); // mtu - 3
    await t.close();
    await adapter.dispose();
  });

  test('an MTU the platform will not report falls back to 20', () async {
    final adapter = FakeBleAdapter(mtu: -1);
    final t = build(adapter);
    await t.open();
    expect(t.maxWriteLength, 20);
    await t.close();
    await adapter.dispose();
  });

  test('writes are chunked at the write length, with response, to 6E400002',
      () async {
    final adapter = FakeBleAdapter(mtu: 23); // -> 20 byte chunks
    final t = build(adapter);
    await t.open();
    await t.write(Uint8List.fromList(List<int>.generate(50, (i) => i)));
    expect(adapter.writes.map((c) => c.length).toList(), [20, 20, 10]);
    expect(adapter.writes.expand((c) => c).toList(),
        List<int>.generate(50, (i) => i));
    expect(adapter.writtenCharacteristics.toSet(), {NusUuids.write});
    expect(adapter.writeWithResponse, everyElement(isTrue));
    await t.close();
    await adapter.dispose();
  });

  test('notifications on 6E400003 arrive on incoming', () async {
    final adapter = FakeBleAdapter();
    final t = build(adapter);
    final got = <List<int>>[];
    t.incoming.listen((b) => got.add(b.toList()));
    await t.open();
    adapter.emitNotification(NusUuids.notify, const [1, 2, 3]);
    await Future<void>.delayed(Duration.zero);
    expect(got, [
      [1, 2, 3]
    ]);
    await t.close();
    await adapter.dispose();
  });

  test('connect retries up to five times with growing backoff', () async {
    final adapter = FakeBleAdapter()
      ..failConnectTimes = 4
      ..failConnectWith = BleFailure.timeout;
    final t = build(adapter);
    await t.open();
    expect(adapter.connectAttempts, 5);
    expect(t.currentState, isA<TransportOpen>());
    await t.close();
    await adapter.dispose();
  });

  test('a sixth failure gives up with DeviceNotFound and closes', () async {
    final adapter = FakeBleAdapter()
      ..failConnectTimes = 99
      ..failConnectWith = BleFailure.deviceNotFound;
    final t = build(adapter);
    await expectLater(t.open(), throwsA(isA<DeviceNotFound>()));
    expect(adapter.connectAttempts, 5);
    expect(t.currentState, isA<TransportClosed>());
    expect(t.guidance, TransportGuidance.portNotFound);
    await adapter.dispose();
  });

  test('a powered-off adapter reports adapterOff without connecting', () async {
    final adapter = FakeBleAdapter(availability_: BleAvailability.poweredOff);
    final t = build(adapter);
    final seen = <TransportState>[];
    t.state.listen(seen.add);
    await expectLater(t.open(), throwsA(isA<AdapterOff>()));
    await Future<void>.delayed(Duration.zero);
    expect(seen.any((s) => s is TransportAdapterOff), isTrue);
    expect(adapter.connectAttempts, 0);
    expect(t.guidance, TransportGuidance.bluetoothAdapterOff);
    await adapter.dispose();
  });

  test('an unauthorized adapter reports permissionDenied with platform guidance',
      () async {
    final adapter = FakeBleAdapter(availability_: BleAvailability.unauthorized);
    final t = build(adapter, platform: HostPlatform.android);
    final seen = <TransportState>[];
    t.state.listen(seen.add);
    await expectLater(t.open(), throwsA(isA<PermissionDenied>()));
    await Future<void>.delayed(Duration.zero);
    expect(seen.any((s) => s is TransportPermissionDenied), isTrue);
    expect(t.guidance, TransportGuidance.androidBluetoothPermission);
    await adapter.dispose();
  });

  test('insufficient authentication on subscribe pairs, then succeeds',
      () async {
    final adapter = FakeBleAdapter()
      ..failSubscribeWith = BleFailure.insufficientAuthentication
      ..pairSucceeds = true;
    final t = build(adapter, platform: HostPlatform.windows);
    await t.open();
    expect(adapter.pairCalls, 1);
    expect(t.currentState, isA<TransportOpen>());
    await t.close();
    await adapter.dispose();
  });

  test('a failed pair reports pairingRequired with the platform reason',
      () async {
    final adapter = FakeBleAdapter()
      ..failSubscribeWith = BleFailure.insufficientAuthentication
      ..pairSucceeds = false;
    final t = build(adapter, platform: HostPlatform.linux);
    final seen = <TransportState>[];
    t.state.listen(seen.add);
    await expectLater(t.open(), throwsA(isA<PairingRequired>()));
    await Future<void>.delayed(Duration.zero);
    expect(seen.any((s) => s is TransportPairingRequired), isTrue);
    expect(t.guidance, TransportGuidance.linuxPairFromSettings);
    await adapter.dispose();
  });

  test('a dropped link closes with linkLost', () async {
    final adapter = FakeBleAdapter();
    final t = build(adapter);
    await t.open();
    adapter.emitDisconnect();
    await Future<void>.delayed(Duration.zero);
    final state = t.currentState;
    expect(state, isA<TransportClosed>());
    expect((state as TransportClosed).cause, CloseCause.linkLost);
    expect(state.error, isA<Disconnected>());
    await adapter.dispose();
  });

  test('close is requested, idempotent, and refuses later writes', () async {
    final adapter = FakeBleAdapter();
    final t = build(adapter);
    await t.open();
    await t.close();
    await t.close();
    expect((t.currentState as TransportClosed).cause, CloseCause.requested);
    await expectLater(
      t.write(Uint8List.fromList(const [1])),
      throwsA(isA<Disconnected>()),
    );
    await adapter.dispose();
  });

  test('writing before open throws Disconnected', () async {
    final adapter = FakeBleAdapter();
    final t = build(adapter);
    await expectLater(
      t.write(Uint8List.fromList(const [1])),
      throwsA(isA<Disconnected>()),
    );
    await adapter.dispose();
  });
}
```

- [ ] **Step 2: Run to verify they fail**

```bash
cd packages/chameleon_flutter && flutter test test/ble/ble_transport_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: '.../ble_transport.dart'`.

- [ ] **Step 3: Implement**

```dart
// lib/src/ble/ble_transport.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';

import '../guidance.dart';
import '../host_platform.dart';
import 'ble_adapter.dart';
import 'ble_failure.dart';
import 'ble_uuids.dart';

/// The Nordic UART link to a Chameleon in application mode (spec 5.1).
///
/// Retries connect up to [connectAttempts] times with exponential backoff,
/// subscribes to [NusUuids.notify], and writes to [NusUuids.write] with
/// response in chunks of the platform-reported maximum write length. The
/// firmware asks for MTU 247 but this class never assumes it: it asks, and
/// falls back to [fallbackMaxWrite] if the platform will not answer.
///
/// hardware-validate: MTU negotiation, pairing prompts and device sleep are
/// not observable against a fake. See docs/hardware-checklist.md H1.
final class BleTransport implements Transport, GuidedTransport {
  BleTransport({
    required this.deviceId,
    required BleAdapter adapter,
    HostPlatform? platform,
    this.connectAttempts = 5,
    this.initialBackoff = const Duration(milliseconds: 250),
    this.maxBackoff = const Duration(seconds: 4),
    this.requestedMtu = 247,
    this.fallbackMaxWrite = 20,
  }) : _adapter = adapter,
       _platform = platform ?? currentHostPlatform();

  final String deviceId;
  final BleAdapter _adapter;
  final HostPlatform _platform;
  final int connectAttempts;
  final Duration initialBackoff;
  final Duration maxBackoff;
  final int requestedMtu;
  final int fallbackMaxWrite;

  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();
  final StreamController<TransportState> _state =
      StreamController<TransportState>.broadcast();

  TransportState _current = const TransportClosed(CloseCause.requested);
  TransportGuidance? _guidance;
  StreamSubscription<Uint8List>? _notifySub;
  StreamSubscription<bool>? _connectionSub;
  int _maxWriteLength = 20;
  Future<void>? _opening;

  /// The chunk size writes are split at. Meaningful only once open.
  int get maxWriteLength => _maxWriteLength;

  @override
  TransportKind get kind => TransportKind.ble;

  @override
  TransportGuidance? get guidance => _guidance;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  Stream<TransportState> get state => _state.stream;

  @override
  TransportState get currentState => _current;

  void _set(TransportState s) {
    _current = s;
    if (!_state.isClosed) _state.add(s);
  }

  @override
  Future<void> open() => _opening ??= _open().whenComplete(() {
    _opening = null;
  });

  Future<void> _open() async {
    if (_current is TransportOpen) return;
    _guidance = null;
    _set(const TransportOpening());

    final availability = await _adapter.availability();
    switch (availability) {
      case BleAvailability.poweredOn:
        break;
      case BleAvailability.unauthorized:
        _guidance = _permissionGuidance();
        _set(const TransportPermissionDenied());
        throw const PermissionDenied('Bluetooth permission was refused');
      case BleAvailability.poweredOff:
      case BleAvailability.unsupported:
      case BleAvailability.resetting:
      case BleAvailability.unknown:
        _guidance = TransportGuidance.bluetoothAdapterOff;
        _set(const TransportAdapterOff());
        throw const AdapterOff('the Bluetooth adapter is not powered on');
    }

    await _connectWithRetry();

    _connectionSub = _adapter.connectionChanges(deviceId).listen((connected) {
      if (!connected && _current is! TransportClosed) {
        _finish(const TransportClosed(CloseCause.linkLost,
            error: Disconnected('the BLE link dropped')));
      }
    });

    try {
      await _adapter.discoverServices(deviceId);
      await _subscribeWithPairing();
      _maxWriteLength = await _negotiateWriteLength();
    } on ChameleonException {
      rethrow;
    }

    _notifySub = _adapter
        .notifications(deviceId,
            service: NusUuids.service, characteristic: NusUuids.notify)
        .listen(_incoming.add, onError: _incoming.addError);

    _set(const TransportOpen());
  }

  Future<void> _connectWithRetry() async {
    var backoff = initialBackoff;
    for (var attempt = 1; attempt <= connectAttempts; attempt++) {
      try {
        await _adapter.connect(deviceId);
        return;
      } on BleAdapterException catch (e) {
        final fatal = switch (e.failure) {
          BleFailure.permissionDenied || BleFailure.adapterOff => true,
          _ => false,
        };
        if (fatal || attempt == connectAttempts) {
          _failOpen(e);
        }
        await Future<void>.delayed(backoff);
        final next = backoff * 2;
        backoff = next > maxBackoff ? maxBackoff : next;
      }
    }
  }

  Never _failOpen(BleAdapterException e) {
    switch (e.failure) {
      case BleFailure.permissionDenied:
        _guidance = _permissionGuidance();
        _finish(const TransportPermissionDenied());
        throw PermissionDenied(e.message);
      case BleFailure.adapterOff:
        _guidance = TransportGuidance.bluetoothAdapterOff;
        _finish(const TransportAdapterOff());
        throw AdapterOff(e.message);
      case BleFailure.insufficientAuthentication:
        _guidance = _pairingGuidance();
        _finish(const TransportPairingRequired());
        throw PairingRequired(e.message);
      case BleFailure.deviceNotFound:
      case BleFailure.timeout:
        _guidance = TransportGuidance.portNotFound;
        _finish(TransportClosed(CloseCause.linkLost,
            error: DeviceNotFound(e.message)));
        throw DeviceNotFound(e.message);
      case BleFailure.disconnected:
      case BleFailure.writeFailed:
      case BleFailure.unknown:
        _finish(TransportClosed(CloseCause.linkLost,
            error: Disconnected(e.message)));
        throw Disconnected(e.message);
    }
  }

  /// Spec 5.1: `pairingRequired` is detected from an insufficient-
  /// authentication error on subscribe. On Windows and Linux the transport
  /// drives pairing itself; everywhere else the OS has already prompted, so
  /// a retry after [BleAdapter.pair] is still the right move.
  Future<void> _subscribeWithPairing() async {
    try {
      await _adapter.subscribe(deviceId,
          service: NusUuids.service, characteristic: NusUuids.notify);
      return;
    } on BleAdapterException catch (e) {
      if (e.failure != BleFailure.insufficientAuthentication) _failOpen(e);
    }
    try {
      await _adapter.pair(deviceId);
      await _adapter.subscribe(deviceId,
          service: NusUuids.service, characteristic: NusUuids.notify);
    } on BleAdapterException catch (e) {
      _guidance = _pairingGuidance();
      _finish(const TransportPairingRequired());
      throw PairingRequired(e.message);
    }
  }

  Future<int> _negotiateWriteLength() async {
    try {
      final mtu = await _adapter.requestMtu(deviceId, requestedMtu);
      // ATT overhead is three bytes: opcode plus handle.
      final usable = mtu - 3;
      return usable < fallbackMaxWrite ? fallbackMaxWrite : usable;
    } on BleAdapterException {
      return fallbackMaxWrite;
    }
  }

  TransportGuidance _permissionGuidance() => switch (_platform) {
    HostPlatform.android => TransportGuidance.androidBluetoothPermission,
    _ => TransportGuidance.applePairingPrompt,
  };

  TransportGuidance _pairingGuidance() => switch (_platform) {
    HostPlatform.windows => TransportGuidance.windowsPairDevice,
    HostPlatform.linux => TransportGuidance.linuxPairFromSettings,
    _ => TransportGuidance.applePairingPrompt,
  };

  @override
  Future<void> write(Uint8List bytes) async {
    if (_current is! TransportOpen) {
      throw const Disconnected('the BLE transport is not open');
    }
    for (var offset = 0; offset < bytes.length; offset += _maxWriteLength) {
      final end = offset + _maxWriteLength;
      final chunk = Uint8List.sublistView(
        bytes,
        offset,
        end > bytes.length ? bytes.length : end,
      );
      try {
        await _adapter.write(deviceId,
            service: NusUuids.service,
            characteristic: NusUuids.write,
            value: chunk,
            withResponse: true);
      } on BleAdapterException catch (e) {
        if (e.failure == BleFailure.insufficientAuthentication) {
          _guidance = _pairingGuidance();
          _set(const TransportPairingRequired());
          throw PairingRequired(e.message);
        }
        _finish(TransportClosed(CloseCause.linkLost,
            error: Disconnected(e.message)));
        throw Disconnected(e.message);
      }
    }
  }

  @override
  Future<void> close() async {
    if (_current is TransportClosed) return;
    _finish(const TransportClosed(CloseCause.requested));
    try {
      await _adapter.disconnect(deviceId);
    } on BleAdapterException {
      // Already gone; the state is what matters.
    }
  }

  void _finish(TransportState closed) {
    unawaited(_notifySub?.cancel());
    _notifySub = null;
    unawaited(_connectionSub?.cancel());
    _connectionSub = null;
    _set(closed);
  }
}
```

- [ ] **Step 4: Run to verify they pass**

```bash
cd packages/chameleon_flutter && flutter test test/ble/ble_transport_test.dart
```

Expected: PASS, 14 tests.

- [ ] **Step 5: Export and commit**

Add `export 'src/ble/ble_transport.dart';` to `lib/chameleon_flutter.dart`, then:

```bash
cd packages/chameleon_flutter && flutter analyze && dart format .
git add packages/chameleon_flutter
git commit -m "feat(chameleon_flutter): add BleTransport

Implements spec 5.1: five connect attempts with backoff, notify on
6E400003, writes with response to 6E400002 chunked at the negotiated MTU
minus three, and permission, adapter and pairing states the app can route
on. Pairing is detected from an insufficient-authentication error."
```

---

### Task 6: BleScanner

**Files:**
- Create: `lib/src/ble/ble_scanner.dart`
- Modify: `lib/chameleon_flutter.dart`
- Test: `test/ble/ble_scanner_test.dart`

**Interfaces:**
- Consumes: `BleAdapter`, `BleScanEntry`, `NusUuids`, `NordicDfuUuids`, `ChameleonBleNames`, `normalizeUuid`, `DeviceScanner`, `DiscoveredDevice`, `TransportKind`, `FakeBleAdapter`.
- Produces:

```dart
/// True when this advertisement is a Chameleon in application or bootloader mode.
bool isChameleonAdvertisement(BleScanEntry entry);

/// True when this advertisement is the Nordic bootloader (spec 5.5).
bool isBootloaderAdvertisement(BleScanEntry entry);

final class BleScanner implements DeviceScanner {
  BleScanner({required BleAdapter adapter});
  @override TransportKind get kind;                     // TransportKind.ble
  @override Stream<List<DiscoveredDevice>> scan();
}
```

- [ ] **Step 1: Write the failing test**

```dart
// test/ble/ble_scanner_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:chameleon_flutter/src/ble/ble_adapter.dart';
import 'package:chameleon_flutter/src/ble/ble_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_ble_adapter.dart';

const nus = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';

void main() {
  test('an Ultra advertising NUS matches and is not a bootloader', () {
    const e = BleScanEntry(
      deviceId: '1',
      name: 'ChameleonUltra',
      services: [nus],
    );
    expect(isChameleonAdvertisement(e), isTrue);
    expect(isBootloaderAdvertisement(e), isFalse);
  });

  test('a Lite matches on its name prefix alone', () {
    const e = BleScanEntry(deviceId: '2', name: 'ChameleonLite_1234');
    expect(isChameleonAdvertisement(e), isTrue);
  });

  test('CU and CL are bootloaders (spec 5.5)', () {
    for (final name in const ['CU', 'CL']) {
      final e = BleScanEntry(deviceId: '3', name: name);
      expect(isChameleonAdvertisement(e), isTrue, reason: name);
      expect(isBootloaderAdvertisement(e), isTrue, reason: name);
    }
  });

  test('the FE59 DFU service marks a bootloader whatever the name', () {
    const e = BleScanEntry(deviceId: '4', name: 'Unnamed', services: ['fe59']);
    expect(isBootloaderAdvertisement(e), isTrue);
  });

  test('an unrelated device is ignored', () {
    const e = BleScanEntry(deviceId: '5', name: 'Someone AirPods');
    expect(isChameleonAdvertisement(e), isFalse);
    expect(isChameleonAdvertisement(const BleScanEntry(deviceId: '6', name: null)),
        isFalse);
  });

  test('scan emits a growing, de-duplicated list of DiscoveredDevices',
      () async {
    final adapter = FakeBleAdapter();
    final scanner = BleScanner(adapter: adapter);
    final emissions = <List<DiscoveredDevice>>[];
    final sub = scanner.scan().listen(emissions.add);
    adapter.emitAdvertisement(
      const BleScanEntry(deviceId: 'A', name: 'ChameleonUltra', services: [nus]),
    );
    adapter.emitAdvertisement(const BleScanEntry(deviceId: 'B', name: 'CU'));
    adapter.emitAdvertisement(const BleScanEntry(deviceId: 'Z', name: 'TV'));
    adapter.emitAdvertisement(
      const BleScanEntry(deviceId: 'A', name: 'ChameleonUltra', services: [nus]),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(emissions.last.length, 2);
    expect(emissions.last.first,
        const DiscoveredDevice(name: 'ChameleonUltra', kind: TransportKind.ble, transportId: 'A'));
    expect(emissions.last.last.isBootloader, isTrue);
    expect(scanner.kind, TransportKind.ble);
    await sub.cancel();
    expect(adapter.scanStopped, isTrue);
    await adapter.dispose();
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd packages/chameleon_flutter && flutter test test/ble/ble_scanner_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: '.../ble_scanner.dart'`.

- [ ] **Step 3: Implement**

```dart
// lib/src/ble/ble_scanner.dart
import 'dart:async';

import 'package:chameleon/chameleon.dart';

import 'ble_adapter.dart';
import 'ble_uuids.dart';

/// Spec 5.5: the bootloader advertises as `CU` or `CL` and exposes the
/// Nordic DFU service. Either signal is enough.
bool isBootloaderAdvertisement(BleScanEntry entry) {
  final name = entry.name?.trim();
  if (name != null && ChameleonBleNames.bootloaderNames.contains(name)) {
    return true;
  }
  return entry.services
      .map(normalizeUuid)
      .contains(normalizeUuid(NordicDfuUuids.service));
}

/// Spec 5.1: match on the Nordic UART service or an application name
/// prefix; spec 5.5 adds the bootloader.
bool isChameleonAdvertisement(BleScanEntry entry) {
  if (isBootloaderAdvertisement(entry)) return true;
  if (entry.services
      .map(normalizeUuid)
      .contains(normalizeUuid(NusUuids.service))) {
    return true;
  }
  final name = entry.name;
  if (name == null) return false;
  return ChameleonBleNames.applicationPrefixes.any(name.startsWith);
}

/// Emits the growing list of Chameleons visible over BLE (spec 4.2).
///
/// The adapter-level filter is a hint only — platforms honour ScanFilter
/// inconsistently, and the bootloader advertises neither NUS nor the
/// application name — so [isChameleonAdvertisement] is the authority.
final class BleScanner implements DeviceScanner {
  BleScanner({required BleAdapter adapter}) : _adapter = adapter;

  final BleAdapter _adapter;

  @override
  TransportKind get kind => TransportKind.ble;

  @override
  Stream<List<DiscoveredDevice>> scan() {
    final found = <String, DiscoveredDevice>{};
    final controller = StreamController<List<DiscoveredDevice>>();
    StreamSubscription<BleScanEntry>? sub;

    controller.onListen = () {
      sub = _adapter
          .scan(
            withServices: <String>[NusUuids.service, NordicDfuUuids.service],
            withNamePrefix: <String>[
              ...ChameleonBleNames.applicationPrefixes,
              ...ChameleonBleNames.bootloaderNames,
            ],
          )
          .listen(
            (entry) {
              if (!isChameleonAdvertisement(entry)) return;
              final device = DiscoveredDevice(
                name: entry.name ?? entry.deviceId,
                kind: TransportKind.ble,
                transportId: entry.deviceId,
                isBootloader: isBootloaderAdvertisement(entry),
              );
              if (found[entry.deviceId] == device &&
                  found[entry.deviceId]!.name == device.name) {
                return;
              }
              found[entry.deviceId] = device;
              controller.add(List<DiscoveredDevice>.unmodifiable(found.values));
            },
            onError: controller.addError,
          );
    };

    controller.onCancel = () async {
      await sub?.cancel();
      await _adapter.stopScan();
      await controller.close();
    };

    return controller.stream;
  }
}
```

- [ ] **Step 4: Run to verify it passes**

```bash
cd packages/chameleon_flutter && flutter test test/ble/ble_scanner_test.dart
```

Expected: PASS, 6 tests.

- [ ] **Step 5: Export and commit**

Add `export 'src/ble/ble_scanner.dart';` to the barrel.

```bash
git add packages/chameleon_flutter
git commit -m "feat(chameleon_flutter): add BleScanner

Matches on the Nordic UART service or the ChameleonUltra/ChameleonLite
name prefixes, and flags CU/CL and the FE59 service as bootloaders so the
connect screen can offer recovery (spec 4.2, 5.5)."
```

---

### Task 7: The SerialPortAdapter seam, error mapping and a scripted fake

Same reasoning as Task 4: `libserialport_plus` is FFI over a real device node, so the transport talks to an interface this package owns. `SerialPortException` carries a native `code` (errno on POSIX, a Win32 error on Windows) and a `message`; mapping it is the one piece of platform knowledge worth a unit test.

**Files:**
- Create: `lib/src/serial/serial_failure.dart`, `lib/src/serial/serial_adapter.dart`, `lib/src/serial/libserialport_adapter.dart`, `test/support/fake_serial_adapter.dart`
- Modify: `lib/chameleon_flutter.dart`
- Test: `test/serial/serial_failure_test.dart`

**Interfaces:**
- Produces:

```dart
enum SerialFailure { permissionDenied, portBusy, notFound, disconnected, unknown }

final class SerialAdapterException implements Exception {
  const SerialAdapterException(this.failure, this.message);
  final SerialFailure failure;
  final String message;
}

/// The two candidate control-line configurations from spec 5.2.
enum SerialControlLineMode { dtrOnly, hardwareFlowControl }

final class SerialPortDescriptor {
  const SerialPortDescriptor({
    required String path, required String description,
    int? vid, int? pid, String? manufacturer, String? product,
  });
  final String path; final String description;
  final int? vid; final int? pid;
  final String? manufacturer; final String? product;
}

abstract interface class SerialPortHandle {
  Stream<Uint8List> get incoming;
  Future<void> write(Uint8List bytes);
  Future<void> close();
}

abstract interface class SerialPortAdapter {
  List<SerialPortDescriptor> listPorts();
  Future<SerialPortHandle> open(
    String path, {
    int baudRate = ChameleonUsbIds.baudRate,
    SerialControlLineMode controlLines = SerialControlLineMode.dtrOnly,
  });
}

SerialFailure serialFailureFrom({required int code, required String message, required HostPlatform platform});
```

- Produces (test double, used by Tasks 9, 10, 11 and 14): `FakeSerialAdapter` and `FakeSerialHandle` in `test/support/fake_serial_adapter.dart`:

```dart
final class FakeSerialAdapter implements SerialPortAdapter {
  FakeSerialAdapter({List<SerialPortDescriptor> ports = const []});
  List<SerialPortDescriptor> ports;
  SerialFailure? failOpenWith;
  int openCalls;
  String? lastPath;
  int? lastBaudRate;
  SerialControlLineMode? lastControlLines;
  FakeSerialHandle? handle;                  // the handle the last open returned
}

final class FakeSerialHandle implements SerialPortHandle {
  final List<Uint8List> writes;
  bool closed;
  SerialFailure? failWriteWith;
  void emit(List<int> bytes);
  void dropLink();                           // errors the incoming stream
}
```

- [ ] **Step 1: Write the failing test**

```dart
// test/serial/serial_failure_test.dart
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:chameleon_flutter/src/serial/serial_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('POSIX errnos map to the right failure', () {
    expect(
      serialFailureFrom(code: 13, message: 'Permission denied', platform: HostPlatform.linux),
      SerialFailure.permissionDenied,
    );
    expect(
      serialFailureFrom(code: 16, message: 'Device or resource busy', platform: HostPlatform.linux),
      SerialFailure.portBusy,
    );
    expect(
      serialFailureFrom(code: 2, message: 'No such file or directory', platform: HostPlatform.macos),
      SerialFailure.notFound,
    );
    expect(
      serialFailureFrom(code: 1, message: 'Operation not permitted', platform: HostPlatform.macos),
      SerialFailure.permissionDenied,
    );
  });

  test('Win32 codes map to the right failure', () {
    expect(
      serialFailureFrom(code: 5, message: 'Access is denied.', platform: HostPlatform.windows),
      SerialFailure.permissionDenied,
    );
    expect(
      serialFailureFrom(code: 32, message: 'The process cannot access the file', platform: HostPlatform.windows),
      SerialFailure.portBusy,
    );
    expect(
      serialFailureFrom(code: 2, message: 'The system cannot find the file', platform: HostPlatform.windows),
      SerialFailure.notFound,
    );
  });

  test('an unknown code falls back to the message text', () {
    expect(
      serialFailureFrom(code: 999, message: 'Permission denied', platform: HostPlatform.linux),
      SerialFailure.permissionDenied,
    );
    expect(
      serialFailureFrom(code: 999, message: 'Resource busy', platform: HostPlatform.macos),
      SerialFailure.portBusy,
    );
    expect(
      serialFailureFrom(code: 999, message: 'something else entirely', platform: HostPlatform.linux),
      SerialFailure.unknown,
    );
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd packages/chameleon_flutter && flutter test test/serial/serial_failure_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: '.../serial_failure.dart'`.

- [ ] **Step 3: Implement the failure mapping**

```dart
// lib/src/serial/serial_failure.dart
import '../host_platform.dart';

/// The distinctions the serial transport makes (spec 5.2).
enum SerialFailure {
  /// The process may not open the port: Linux group/udev, Windows
  /// access-denied, macOS sandbox without the serial entitlement.
  permissionDenied,

  /// Another process holds the port. ModemManager on Linux is the usual
  /// cause; on Windows it is a terminal left open.
  portBusy,

  /// The port does not exist any more.
  notFound,

  /// The link dropped after it was open: the cable was pulled.
  disconnected,

  unknown,
}

final class SerialAdapterException implements Exception {
  const SerialAdapterException(this.failure, this.message);
  final SerialFailure failure;
  final String message;

  @override
  String toString() => 'SerialAdapterException(${failure.name}): $message';
}

/// Maps a native error to a [SerialFailure].
///
/// [code] is errno on POSIX and a Win32 error on Windows, which is why the
/// platform has to be passed in. When the code is not one we recognise the
/// message text is the fallback, because libserialport sometimes reports a
/// generic code with a specific string.
SerialFailure serialFailureFrom({
  required int code,
  required String message,
  required HostPlatform platform,
}) {
  final byCode = switch (platform) {
    HostPlatform.windows => switch (code) {
      5 => SerialFailure.permissionDenied, // ERROR_ACCESS_DENIED
      32 => SerialFailure.portBusy, // ERROR_SHARING_VIOLATION
      2 || 3 => SerialFailure.notFound, // FILE_NOT_FOUND / PATH_NOT_FOUND
      _ => null,
    },
    _ => switch (code) {
      1 => SerialFailure.permissionDenied, // EPERM (macOS sandbox)
      13 => SerialFailure.permissionDenied, // EACCES
      16 => SerialFailure.portBusy, // EBUSY
      2 => SerialFailure.notFound, // ENOENT
      6 || 19 => SerialFailure.disconnected, // ENXIO / ENODEV
      _ => null,
    },
  };
  if (byCode != null) return byCode;

  final text = message.toLowerCase();
  if (text.contains('permission denied') ||
      text.contains('access is denied') ||
      text.contains('operation not permitted')) {
    return SerialFailure.permissionDenied;
  }
  if (text.contains('busy') || text.contains('cannot access the file')) {
    return SerialFailure.portBusy;
  }
  if (text.contains('no such file') || text.contains('cannot find the file')) {
    return SerialFailure.notFound;
  }
  return SerialFailure.unknown;
}
```

- [ ] **Step 4: Declare the adapter interface**

```dart
// lib/src/serial/serial_adapter.dart
import 'dart:typed_data';

import 'serial_failure.dart';
import 'serial_ids.dart';

/// The two candidate control-line configurations. The research notes
/// disagree on which the Chameleon needs, so spec 5.2 says try both.
///
/// hardware-validate: which mode works is decided by the user's H1 report;
/// see docs/hardware-checklist.md.
enum SerialControlLineMode {
  /// Assert DTR, ignore CTS/DSR, no hardware flow control. The default,
  /// matching `docs/research/chameleon-protocol.md` ("Assert DTR after
  /// open. No flow control.").
  dtrOnly,

  /// RTS/CTS and DTR/DSR hardware flow control.
  hardwareFlowControl,
}

/// One enumerated serial port.
final class SerialPortDescriptor {
  const SerialPortDescriptor({
    required this.path,
    required this.description,
    this.vid,
    this.pid,
    this.manufacturer,
    this.product,
  });

  final String path;
  final String description;
  final int? vid;
  final int? pid;
  final String? manufacturer;
  final String? product;
}

/// An open port. Every method throws [SerialAdapterException] and nothing
/// else.
abstract interface class SerialPortHandle {
  Stream<Uint8List> get incoming;
  Future<void> write(Uint8List bytes);
  Future<void> close();
}

/// The seam over the native serial stack: libserialport_plus on desktop,
/// usb_serial on Android.
abstract interface class SerialPortAdapter {
  List<SerialPortDescriptor> listPorts();

  Future<SerialPortHandle> open(
    String path, {
    int baudRate = ChameleonUsbIds.baudRate,
    SerialControlLineMode controlLines = SerialControlLineMode.dtrOnly,
  });
}
```

- [ ] **Step 5: Implement it over libserialport_plus**

```dart
// lib/src/serial/libserialport_adapter.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:libserialport_plus/libserialport_plus.dart';

import '../host_platform.dart';
import 'serial_adapter.dart';
import 'serial_failure.dart';
import 'serial_ids.dart';

/// The only file in Spectra that imports libserialport_plus (1.0.4).
///
/// Enumeration and the VID/PID/manufacturer fields are as validated in
/// Spike A (`docs/research/spikes.md`).
final class LibSerialPortAdapter implements SerialPortAdapter {
  LibSerialPortAdapter({HostPlatform? platform})
    : _platform = platform ?? currentHostPlatform();

  final HostPlatform _platform;

  SerialAdapterException _map(SerialPortException e) => SerialAdapterException(
    serialFailureFrom(code: e.code, message: e.message, platform: _platform),
    e.message,
  );

  @override
  List<SerialPortDescriptor> listPorts() {
    final List<String> names;
    try {
      names = SerialPort.getAvailablePorts();
    } on SerialPortException catch (e) {
      throw _map(e);
    }
    final out = <SerialPortDescriptor>[];
    for (final name in names) {
      final port = SerialPort(name);
      try {
        final info = port.getInfo();
        out.add(
          SerialPortDescriptor(
            path: info.name,
            description: info.description,
            vid: info.usbVid,
            pid: info.usbPid,
            manufacturer: info.usbManufacturer,
            product: info.usbProduct,
          ),
        );
      } on SerialPortException {
        // A port we cannot describe is still a port the user may pick by
        // hand; list it with what we have.
        out.add(SerialPortDescriptor(path: name, description: name));
      } finally {
        port.dispose();
      }
    }
    return out;
  }

  @override
  Future<SerialPortHandle> open(
    String path, {
    int baudRate = ChameleonUsbIds.baudRate,
    SerialControlLineMode controlLines = SerialControlLineMode.dtrOnly,
  }) async {
    final port = SerialPort(path);
    try {
      port.open();
      port.setConfig(_configFor(baudRate, controlLines));
    } on SerialPortException catch (e) {
      port.dispose();
      throw _map(e);
    }
    return _LibSerialPortHandle(port, _map);
  }

  /// 115200 8N1 (spec 5.2). `dtrOnly` asserts DTR and disables every flow
  /// control; `hardwareFlowControl` turns on RTS/CTS and DTR/DSR.
  ///
  /// hardware-validate: which mode the Chameleon needs is H1.
  SerialPortConfig _configFor(int baudRate, SerialControlLineMode mode) =>
      switch (mode) {
        SerialControlLineMode.dtrOnly => SerialPortConfig(
          baudRate: baudRate,
          bits: ChameleonUsbIds.dataBits,
          parity: SerialPortParity.none,
          stopBits: ChameleonUsbIds.stopBits,
          dtr: SerialPortDtr.on,
          dsr: SerialPortDsr.ignore,
          rts: SerialPortRts.off,
          cts: SerialPortCts.ignore,
          xonXoff: SerialPortXonXoff.disabled,
        ),
        SerialControlLineMode.hardwareFlowControl => SerialPortConfig(
          baudRate: baudRate,
          bits: ChameleonUsbIds.dataBits,
          parity: SerialPortParity.none,
          stopBits: ChameleonUsbIds.stopBits,
          dtr: SerialPortDtr.on,
          dsr: SerialPortDsr.flowControl,
          rts: SerialPortRts.flowControl,
          cts: SerialPortCts.flowControl,
          xonXoff: SerialPortXonXoff.disabled,
        ),
      };
}

final class _LibSerialPortHandle implements SerialPortHandle {
  _LibSerialPortHandle(this._port, this._map)
    : _reader = SerialPortReader(_port) {
    _sub = _reader.stream.listen(
      _incoming.add,
      onError: (Object e, StackTrace s) {
        if (e is SerialPortException) {
          _incoming.addError(_map(e), s);
        } else {
          _incoming.addError(e, s);
        }
      },
    );
  }

  final SerialPort _port;
  final SerialPortReader _reader;
  final SerialAdapterException Function(SerialPortException) _map;
  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List>? _sub;
  bool _closed = false;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  Future<void> write(Uint8List bytes) async {
    if (_closed) {
      throw const SerialAdapterException(
        SerialFailure.disconnected,
        'the port is closed',
      );
    }
    try {
      // libserialport's write is synchronous and returns the byte count.
      var offset = 0;
      while (offset < bytes.length) {
        final written = _port.write(Uint8List.sublistView(bytes, offset));
        if (written <= 0) {
          throw const SerialAdapterException(
            SerialFailure.disconnected,
            'the port accepted no bytes',
          );
        }
        offset += written;
      }
    } on SerialPortException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _sub?.cancel();
    await _reader.close();
    try {
      _port.close();
    } on SerialPortException {
      // Already gone.
    } finally {
      _port.dispose();
    }
    await _incoming.close();
  }
}
```

- [ ] **Step 6: Write the scripted fake**

```dart
// test/support/fake_serial_adapter.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:chameleon_flutter/src/serial/serial_adapter.dart';
import 'package:chameleon_flutter/src/serial/serial_failure.dart';
import 'package:chameleon_flutter/src/serial/serial_ids.dart';

/// A [SerialPortAdapter] whose every outcome is set by the test.
final class FakeSerialAdapter implements SerialPortAdapter {
  FakeSerialAdapter({this.ports = const <SerialPortDescriptor>[]});

  List<SerialPortDescriptor> ports;
  SerialFailure? failOpenWith;

  int openCalls = 0;
  String? lastPath;
  int? lastBaudRate;
  SerialControlLineMode? lastControlLines;
  FakeSerialHandle? handle;

  @override
  List<SerialPortDescriptor> listPorts() => ports;

  @override
  Future<SerialPortHandle> open(
    String path, {
    int baudRate = ChameleonUsbIds.baudRate,
    SerialControlLineMode controlLines = SerialControlLineMode.dtrOnly,
  }) async {
    openCalls++;
    lastPath = path;
    lastBaudRate = baudRate;
    lastControlLines = controlLines;
    final failure = failOpenWith;
    if (failure != null) {
      throw SerialAdapterException(failure, 'scripted open failure');
    }
    return handle = FakeSerialHandle();
  }
}

final class FakeSerialHandle implements SerialPortHandle {
  final List<Uint8List> writes = <Uint8List>[];
  bool closed = false;
  SerialFailure? failWriteWith;

  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  void emit(List<int> bytes) => _incoming.add(Uint8List.fromList(bytes));

  /// The cable was pulled: the reader errors out.
  void dropLink() => _incoming.addError(
    const SerialAdapterException(SerialFailure.disconnected, 'cable pulled'),
  );

  @override
  Future<void> write(Uint8List bytes) async {
    final failure = failWriteWith;
    if (failure != null) {
      throw SerialAdapterException(failure, 'scripted write failure');
    }
    writes.add(Uint8List.fromList(bytes));
  }

  @override
  Future<void> close() async {
    closed = true;
    await _incoming.close();
  }
}
```

- [ ] **Step 7: Export, run and commit**

Add to the barrel:

```dart
export 'src/serial/libserialport_adapter.dart';
export 'src/serial/serial_adapter.dart';
export 'src/serial/serial_failure.dart' show SerialAdapterException, SerialFailure;
```

```bash
cd packages/chameleon_flutter && flutter test && flutter analyze
git add packages/chameleon_flutter
git commit -m "feat(chameleon_flutter): add the SerialPortAdapter seam

libserialport_plus is FFI over a device node, so the transport talks to an
interface this package owns and a scripted fake stands in for the port in
tests. Native errnos and Win32 codes collapse to the four distinctions
spec 5.2 needs, with the message text as a fallback."
```

---

### Task 8: UsbSerialAdapter for Android and the platform factory

**Files:**
- Create: `lib/src/serial/usb_serial_adapter.dart`, `lib/src/serial/serial_adapter_factory.dart`
- Modify: `lib/chameleon_flutter.dart`
- Test: `test/serial/serial_adapter_factory_test.dart`

**Interfaces:**
- Consumes: `SerialPortAdapter`, `SerialPortHandle`, `SerialPortDescriptor`, `SerialControlLineMode`, `SerialAdapterException`, `SerialFailure`, `ChameleonUsbIds`, `HostPlatform`, `LibSerialPortAdapter`.
- Produces: `final class UsbSerialAdapter implements SerialPortAdapter { UsbSerialAdapter(); }`
- Produces: `SerialPortAdapter? defaultSerialPortAdapter({HostPlatform? platform})` — `UsbSerialAdapter` on Android, `LibSerialPortAdapter` on macOS/Windows/Linux, **null on iOS** (spec 5.4: iOS has no serial).

- [ ] **Step 1: Write the failing test**

```dart
// test/serial/serial_adapter_factory_test.dart
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:chameleon_flutter/src/serial/libserialport_adapter.dart';
import 'package:chameleon_flutter/src/serial/serial_adapter_factory.dart';
import 'package:chameleon_flutter/src/serial/usb_serial_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop gets libserialport', () {
    for (final p in const [
      HostPlatform.macos,
      HostPlatform.windows,
      HostPlatform.linux,
    ]) {
      expect(defaultSerialPortAdapter(platform: p), isA<LibSerialPortAdapter>(),
          reason: p.name);
    }
  });

  test('Android gets usb_serial', () {
    expect(defaultSerialPortAdapter(platform: HostPlatform.android),
        isA<UsbSerialAdapter>());
  });

  test('iOS has no serial at all (spec 5.4)', () {
    expect(defaultSerialPortAdapter(platform: HostPlatform.ios), isNull);
    expect(defaultSerialPortAdapter(platform: HostPlatform.unknown), isNull);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd packages/chameleon_flutter && flutter test test/serial/serial_adapter_factory_test.dart
```

Expected: FAIL — missing `serial_adapter_factory.dart` and `usb_serial_adapter.dart`.

- [ ] **Step 3: Implement the Android adapter**

```dart
// lib/src/serial/usb_serial_adapter.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:usb_serial/usb_serial.dart';

import 'serial_adapter.dart';
import 'serial_failure.dart';
import 'serial_ids.dart';

/// The only file in Spectra that imports usb_serial (0.5.2). Android only
/// (spec 5.4).
///
/// usb_serial enumerates asynchronously, but [SerialPortAdapter.listPorts]
/// is synchronous because libserialport's is. The device list is therefore
/// refreshed by [refresh] — the scanner calls it before each enumeration —
/// and cached here.
final class UsbSerialAdapter implements SerialPortAdapter {
  UsbSerialAdapter();

  List<UsbDevice> _devices = const <UsbDevice>[];

  /// Re-reads the attached USB devices. Call before [listPorts].
  Future<void> refresh() async {
    _devices = await UsbSerial.listDevices();
  }

  @override
  List<SerialPortDescriptor> listPorts() => <SerialPortDescriptor>[
    for (final d in _devices)
      SerialPortDescriptor(
        path: d.deviceName,
        description: d.productName ?? d.deviceName,
        vid: d.vid,
        pid: d.pid,
        manufacturer: d.manufacturerName,
        product: d.productName,
      ),
  ];

  @override
  Future<SerialPortHandle> open(
    String path, {
    int baudRate = ChameleonUsbIds.baudRate,
    SerialControlLineMode controlLines = SerialControlLineMode.dtrOnly,
  }) async {
    if (_devices.isEmpty) await refresh();
    final device = _devices.where((d) => d.deviceName == path).firstOrNull;
    if (device == null) {
      throw SerialAdapterException(SerialFailure.notFound, 'no device at $path');
    }
    // A null port means the user declined the Android USB permission dialog.
    final UsbPort? port;
    try {
      port = await device.create();
    } on Exception catch (e) {
      throw SerialAdapterException(SerialFailure.unknown, e.toString());
    }
    if (port == null) {
      throw const SerialAdapterException(
        SerialFailure.permissionDenied,
        'USB device permission was refused',
      );
    }
    if (!await port.open()) {
      throw const SerialAdapterException(
        SerialFailure.permissionDenied,
        'the USB device could not be opened',
      );
    }
    await port.setPortParameters(
      baudRate,
      UsbPort.DATABITS_8,
      UsbPort.STOPBITS_1,
      UsbPort.PARITY_NONE,
    );
    // hardware-validate: which control lines the Chameleon needs is H1.
    await port.setDTR(true);
    await port.setRTS(controlLines == SerialControlLineMode.hardwareFlowControl);
    return _UsbSerialHandle(port);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

final class _UsbSerialHandle implements SerialPortHandle {
  _UsbSerialHandle(this._port) {
    final input = _port.inputStream;
    if (input != null) {
      _sub = input.listen(_incoming.add, onError: _incoming.addError);
    }
  }

  final UsbPort _port;
  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List>? _sub;
  bool _closed = false;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  Future<void> write(Uint8List bytes) async {
    if (_closed) {
      throw const SerialAdapterException(
        SerialFailure.disconnected,
        'the port is closed',
      );
    }
    try {
      await _port.write(bytes);
    } on Exception catch (e) {
      throw SerialAdapterException(SerialFailure.disconnected, e.toString());
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _sub?.cancel();
    await _port.close();
    await _incoming.close();
  }
}
```

- [ ] **Step 4: Implement the factory**

```dart
// lib/src/serial/serial_adapter_factory.dart
import '../host_platform.dart';
import 'libserialport_adapter.dart';
import 'serial_adapter.dart';
import 'usb_serial_adapter.dart';

/// The serial stack for this platform, or null where there is none.
///
/// Spec 5.4: libserialport_plus on Windows, macOS and Linux; usb_serial on
/// Android; iOS has no serial transport at all.
SerialPortAdapter? defaultSerialPortAdapter({HostPlatform? platform}) =>
    switch (platform ?? currentHostPlatform()) {
      HostPlatform.macos ||
      HostPlatform.windows ||
      HostPlatform.linux => LibSerialPortAdapter(platform: platform),
      HostPlatform.android => UsbSerialAdapter(),
      HostPlatform.ios || HostPlatform.unknown => null,
    };
```

- [ ] **Step 5: Run and commit**

```bash
cd packages/chameleon_flutter && flutter test test/serial/serial_adapter_factory_test.dart && flutter analyze
```

Expected: PASS, 3 tests. Add `export 'src/serial/serial_adapter_factory.dart';` and `export 'src/serial/usb_serial_adapter.dart';` to the barrel.

```bash
git add packages/chameleon_flutter
git commit -m "feat(chameleon_flutter): add the Android USB serial adapter

usb_serial backs the same SerialPortAdapter interface as libserialport, so
SerialTransport is one class on all four serial platforms. iOS returns no
adapter at all, matching the spec 5.4 matrix."
```

---

### Task 9: SerialTransport

**Files:**
- Create: `lib/src/serial/serial_transport.dart`
- Modify: `lib/chameleon_flutter.dart`
- Test: `test/serial/serial_transport_test.dart`

**Interfaces:**
- Consumes: `SerialPortAdapter`, `SerialPortHandle`, `SerialAdapterException`, `SerialFailure`, `SerialControlLineMode`, `ChameleonUsbIds`, `HostPlatform`, `TransportGuidance`, `GuidedTransport`, `defaultSerialPortAdapter`, `FakeSerialAdapter`, `FakeSerialHandle`, and from `package:chameleon/chameleon.dart`: `Transport`, `TransportKind`, the `TransportState` variants, `CloseCause`, `Disconnected`, `PermissionDenied`, `PortBusy`, `DeviceNotFound`.
- Produces:

```dart
final class SerialTransport implements Transport, GuidedTransport {
  SerialTransport({
    required String path,
    required SerialPortAdapter adapter,
    SerialControlLineMode controlLines = SerialControlLineMode.dtrOnly,
    int baudRate = ChameleonUsbIds.baudRate,
    HostPlatform? platform,
  });

  /// Manual port entry on desktop (spec 5.2): the user types a path.
  /// Throws [DeviceNotFound] where the platform has no serial stack.
  factory SerialTransport.fromPath(
    String path, {
    SerialControlLineMode controlLines = SerialControlLineMode.dtrOnly,
    HostPlatform? platform,
  });

  final String path;
  final SerialControlLineMode controlLines;
  @override TransportKind get kind;            // TransportKind.usb
  @override TransportGuidance? get guidance;
  // ... the Transport members
}
```

- [ ] **Step 1: Write the failing tests**

```dart
// test/serial/serial_transport_test.dart
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:chameleon_flutter/src/serial/serial_adapter.dart';
import 'package:chameleon_flutter/src/serial/serial_failure.dart';
import 'package:chameleon_flutter/src/serial/serial_transport.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_serial_adapter.dart';

SerialTransport build(
  FakeSerialAdapter adapter, {
  HostPlatform platform = HostPlatform.macos,
  SerialControlLineMode mode = SerialControlLineMode.dtrOnly,
}) => SerialTransport(
  path: '/dev/cu.usbmodem1',
  adapter: adapter,
  platform: platform,
  controlLines: mode,
);

void main() {
  test('open goes opening -> open at 115200 with the chosen control lines',
      () async {
    final adapter = FakeSerialAdapter();
    final t = build(adapter);
    final seen = <TransportState>[];
    t.state.listen(seen.add);
    await t.open();
    await Future<void>.delayed(Duration.zero);
    expect(seen.map((s) => s.runtimeType).toList(),
        [TransportOpening, TransportOpen]);
    expect(adapter.lastPath, '/dev/cu.usbmodem1');
    expect(adapter.lastBaudRate, 115200);
    expect(adapter.lastControlLines, SerialControlLineMode.dtrOnly);
    expect(t.kind, TransportKind.usb);
    await t.close();
  });

  test('the control-line mode is a constructor choice, not a constant',
      () async {
    final adapter = FakeSerialAdapter();
    final t = build(adapter, mode: SerialControlLineMode.hardwareFlowControl);
    await t.open();
    expect(adapter.lastControlLines, SerialControlLineMode.hardwareFlowControl);
    await t.close();
  });

  test('bytes flow both ways', () async {
    final adapter = FakeSerialAdapter();
    final t = build(adapter);
    final got = <List<int>>[];
    t.incoming.listen((b) => got.add(b.toList()));
    await t.open();
    await t.write(Uint8List.fromList(const [0x11, 0xEF]));
    adapter.handle!.emit(const [0x11, 0xEF, 0x03]);
    await Future<void>.delayed(Duration.zero);
    expect(adapter.handle!.writes.single, [0x11, 0xEF]);
    expect(got, [
      [0x11, 0xEF, 0x03]
    ]);
    await t.close();
  });

  test('a permission failure on Linux carries the group guidance', () async {
    final adapter = FakeSerialAdapter()
      ..failOpenWith = SerialFailure.permissionDenied;
    final t = build(adapter, platform: HostPlatform.linux);
    final seen = <TransportState>[];
    t.state.listen(seen.add);
    await expectLater(t.open(), throwsA(isA<PermissionDenied>()));
    await Future<void>.delayed(Duration.zero);
    expect(seen.any((s) => s is TransportPermissionDenied), isTrue);
    expect(t.guidance, TransportGuidance.linuxSerialGroup);
  });

  test('a permission failure elsewhere carries the platform guidance',
      () async {
    for (final (platform, expected) in const [
      (HostPlatform.windows, TransportGuidance.windowsPortAccessDenied),
      (HostPlatform.macos, TransportGuidance.macosSerialEntitlement),
      (HostPlatform.android, TransportGuidance.androidUsbPermission),
    ]) {
      final adapter = FakeSerialAdapter()
        ..failOpenWith = SerialFailure.permissionDenied;
      final t = build(adapter, platform: platform);
      await expectLater(t.open(), throwsA(isA<PermissionDenied>()));
      expect(t.guidance, expected, reason: platform.name);
    }
  });

  test('a busy port is PortBusy, and on Linux points at ModemManager',
      () async {
    final adapter = FakeSerialAdapter()..failOpenWith = SerialFailure.portBusy;
    final t = build(adapter, platform: HostPlatform.linux);
    await expectLater(t.open(), throwsA(isA<PortBusy>()));
    expect(t.guidance, TransportGuidance.linuxModemManager);
    expect(t.currentState, isA<TransportClosed>());
  });

  test('a missing port is DeviceNotFound', () async {
    final adapter = FakeSerialAdapter()..failOpenWith = SerialFailure.notFound;
    final t = build(adapter);
    await expectLater(t.open(), throwsA(isA<DeviceNotFound>()));
    expect(t.guidance, TransportGuidance.portNotFound);
  });

  test('a pulled cable closes with linkLost', () async {
    final adapter = FakeSerialAdapter();
    final t = build(adapter);
    await t.open();
    adapter.handle!.dropLink();
    await Future<void>.delayed(Duration.zero);
    final state = t.currentState;
    expect(state, isA<TransportClosed>());
    expect((state as TransportClosed).cause, CloseCause.linkLost);
    expect(state.error, isA<Disconnected>());
  });

  test('close is requested, idempotent, and refuses later writes', () async {
    final adapter = FakeSerialAdapter();
    final t = build(adapter);
    await t.open();
    await t.close();
    await t.close();
    expect((t.currentState as TransportClosed).cause, CloseCause.requested);
    expect(adapter.handle!.closed, isTrue);
    await expectLater(
      t.write(Uint8List.fromList(const [1])),
      throwsA(isA<Disconnected>()),
    );
  });

  test('writing before open throws Disconnected', () async {
    final t = build(FakeSerialAdapter());
    await expectLater(
      t.write(Uint8List.fromList(const [1])),
      throwsA(isA<Disconnected>()),
    );
  });

  test('fromPath refuses a platform with no serial stack', () {
    expect(
      () => SerialTransport.fromPath('/dev/x', platform: HostPlatform.ios),
      throwsA(isA<DeviceNotFound>()),
    );
    expect(
      SerialTransport.fromPath('/dev/x', platform: HostPlatform.macos).path,
      '/dev/x',
    );
  });
}
```

- [ ] **Step 2: Run to verify they fail**

```bash
cd packages/chameleon_flutter && flutter test test/serial/serial_transport_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: '.../serial_transport.dart'`.

- [ ] **Step 3: Implement**

```dart
// lib/src/serial/serial_transport.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';

import '../guidance.dart';
import '../host_platform.dart';
import 'serial_adapter.dart';
import 'serial_adapter_factory.dart';
import 'serial_failure.dart';
import 'serial_ids.dart';

/// The CDC-ACM link to a Chameleon over USB (spec 5.2).
///
/// One class for all four serial platforms: the platform difference lives
/// behind [SerialPortAdapter]. Opens at 115200 8N1 and applies
/// [controlLines].
///
/// hardware-validate: whether the device needs DTR only or RTS/CTS plus
/// DTR/DSR is unresolved in the research notes and is decided by the user's
/// H1 report. See docs/hardware-checklist.md.
final class SerialTransport implements Transport, GuidedTransport {
  SerialTransport({
    required this.path,
    required SerialPortAdapter adapter,
    this.controlLines = SerialControlLineMode.dtrOnly,
    this.baudRate = ChameleonUsbIds.baudRate,
    HostPlatform? platform,
  }) : _adapter = adapter,
       _platform = platform ?? currentHostPlatform();

  /// Manual port entry (spec 5.2): the user types a path the scanner did
  /// not offer. Uses the platform's own adapter.
  factory SerialTransport.fromPath(
    String path, {
    SerialControlLineMode controlLines = SerialControlLineMode.dtrOnly,
    HostPlatform? platform,
  }) {
    final resolved = platform ?? currentHostPlatform();
    final adapter = defaultSerialPortAdapter(platform: resolved);
    if (adapter == null) {
      throw const DeviceNotFound('this platform has no serial transport');
    }
    return SerialTransport(
      path: path,
      adapter: adapter,
      controlLines: controlLines,
      platform: resolved,
    );
  }

  final String path;
  final SerialControlLineMode controlLines;
  final int baudRate;
  final SerialPortAdapter _adapter;
  final HostPlatform _platform;

  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();
  final StreamController<TransportState> _state =
      StreamController<TransportState>.broadcast();

  TransportState _current = const TransportClosed(CloseCause.requested);
  TransportGuidance? _guidance;
  SerialPortHandle? _handle;
  StreamSubscription<Uint8List>? _sub;
  Future<void>? _opening;

  @override
  TransportKind get kind => TransportKind.usb;

  @override
  TransportGuidance? get guidance => _guidance;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  Stream<TransportState> get state => _state.stream;

  @override
  TransportState get currentState => _current;

  void _set(TransportState s) {
    _current = s;
    if (!_state.isClosed) _state.add(s);
  }

  @override
  Future<void> open() => _opening ??= _open().whenComplete(() {
    _opening = null;
  });

  Future<void> _open() async {
    if (_current is TransportOpen) return;
    _guidance = null;
    _set(const TransportOpening());
    final SerialPortHandle handle;
    try {
      handle = await _adapter.open(
        path,
        baudRate: baudRate,
        controlLines: controlLines,
      );
    } on SerialAdapterException catch (e) {
      _failOpen(e);
    }
    _handle = handle;
    _sub = handle.incoming.listen(
      _incoming.add,
      onError: (Object e, StackTrace s) {
        _finish(
          TransportClosed(
            CloseCause.linkLost,
            error: e is SerialAdapterException
                ? Disconnected(e.message)
                : Disconnected('$e'),
          ),
        );
      },
    );
    _set(const TransportOpen());
  }

  Never _failOpen(SerialAdapterException e) {
    switch (e.failure) {
      case SerialFailure.permissionDenied:
        _guidance = switch (_platform) {
          HostPlatform.linux => TransportGuidance.linuxSerialGroup,
          HostPlatform.windows => TransportGuidance.windowsPortAccessDenied,
          HostPlatform.macos => TransportGuidance.macosSerialEntitlement,
          HostPlatform.android => TransportGuidance.androidUsbPermission,
          _ => TransportGuidance.linuxSerialGroup,
        };
        _set(const TransportPermissionDenied());
        throw PermissionDenied(e.message);
      case SerialFailure.portBusy:
        _guidance = _platform == HostPlatform.linux
            ? TransportGuidance.linuxModemManager
            : TransportGuidance.windowsPortAccessDenied;
        _set(TransportClosed(CloseCause.linkLost, error: PortBusy(e.message)));
        throw PortBusy(e.message);
      case SerialFailure.notFound:
        _guidance = TransportGuidance.portNotFound;
        _set(TransportClosed(
          CloseCause.linkLost,
          error: DeviceNotFound(e.message),
        ));
        throw DeviceNotFound(e.message);
      case SerialFailure.disconnected:
      case SerialFailure.unknown:
        _set(TransportClosed(
          CloseCause.linkLost,
          error: Disconnected(e.message),
        ));
        throw Disconnected(e.message);
    }
  }

  @override
  Future<void> write(Uint8List bytes) async {
    final handle = _handle;
    if (handle == null || _current is! TransportOpen) {
      throw const Disconnected('the serial transport is not open');
    }
    try {
      await handle.write(bytes);
    } on SerialAdapterException catch (e) {
      _finish(TransportClosed(
        CloseCause.linkLost,
        error: Disconnected(e.message),
      ));
      throw Disconnected(e.message);
    }
  }

  @override
  Future<void> close() async {
    if (_current is TransportClosed) return;
    final handle = _handle;
    _finish(const TransportClosed(CloseCause.requested));
    await handle?.close();
  }

  void _finish(TransportState closed) {
    if (_current is TransportClosed) return;
    unawaited(_sub?.cancel());
    _sub = null;
    _handle = null;
    _set(closed);
  }
}
```

- [ ] **Step 4: Run to verify they pass**

```bash
cd packages/chameleon_flutter && flutter test test/serial/serial_transport_test.dart
```

Expected: PASS, 11 tests.

- [ ] **Step 5: Export and commit**

Add `export 'src/serial/serial_transport.dart';` to the barrel.

```bash
cd packages/chameleon_flutter && flutter analyze && dart format .
git add packages/chameleon_flutter
git commit -m "feat(chameleon_flutter): add SerialTransport

One class for all four serial platforms behind SerialPortAdapter. The
control-line mode is a constructor choice because the research notes
disagree; H1 decides the default. Permission and busy failures carry
platform-specific guidance values, not text."
```

---

### Task 10: SerialScanner

**Files:**
- Create: `lib/src/serial/serial_scanner.dart`
- Modify: `lib/chameleon_flutter.dart`
- Test: `test/serial/serial_scanner_test.dart`

**Interfaces:**
- Consumes: `SerialPortAdapter`, `SerialPortDescriptor`, `UsbSerialAdapter`, `ChameleonUsbIds`, `DeviceScanner`, `DiscoveredDevice`, `TransportKind`, `FakeSerialAdapter`.
- Produces:

```dart
/// True when the descriptor is a Chameleon in application mode.
bool isChameleonPort(SerialPortDescriptor port);

/// True when the descriptor is the Nordic bootloader (spec 5.5).
bool isBootloaderPort(SerialPortDescriptor port);

final class SerialScanner implements DeviceScanner {
  SerialScanner({
    required SerialPortAdapter adapter,
    Duration pollInterval = const Duration(seconds: 2),
  });
  @override TransportKind get kind;                     // TransportKind.usb
  @override Stream<List<DiscoveredDevice>> scan();

  /// One enumeration, for a manual refresh button.
  Future<List<DiscoveredDevice>> enumerate();
}
```

- [ ] **Step 1: Write the failing test**

```dart
// test/serial/serial_scanner_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:chameleon_flutter/src/serial/serial_adapter.dart';
import 'package:chameleon_flutter/src/serial/serial_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_serial_adapter.dart';

const ultra = SerialPortDescriptor(
  path: '/dev/cu.usbmodem1',
  description: 'ChameleonUltra',
  vid: 0x6868,
  pid: 0x8686,
  manufacturer: 'Proxgrind',
  product: 'ChameleonUltra: hw_v1, fw_v2',
);

const bootloader = SerialPortDescriptor(
  path: '/dev/cu.usbmodem2',
  description: 'ChameleonUltra DFU',
  vid: 0x1915,
  pid: 0x521F,
  manufacturer: 'Nordic Semiconductor',
);

const bluetoothPort = SerialPortDescriptor(
  path: '/dev/cu.Bluetooth-Incoming-Port',
  description: 'Bluetooth-Incoming-Port',
);

void main() {
  test('the application VID/PID matches', () {
    expect(isChameleonPort(ultra), isTrue);
    expect(isBootloaderPort(ultra), isFalse);
  });

  test('the Proxgrind manufacturer alone matches, for a re-flashed VID', () {
    const p = SerialPortDescriptor(
      path: '/dev/cu.x',
      description: 'x',
      manufacturer: 'Proxgrind',
    );
    expect(isChameleonPort(p), isTrue);
  });

  test('the bootloader VID/PID is flagged, not ignored (spec 5.5)', () {
    expect(isChameleonPort(bootloader), isTrue);
    expect(isBootloaderPort(bootloader), isTrue);
  });

  test('an unrelated port is ignored', () {
    expect(isChameleonPort(bluetoothPort), isFalse);
  });

  test('enumerate returns one DiscoveredDevice per matching port', () async {
    final adapter = FakeSerialAdapter(ports: const [ultra, bluetoothPort, bootloader]);
    final scanner = SerialScanner(adapter: adapter);
    final found = await scanner.enumerate();
    expect(found.length, 2);
    expect(found.first, const DiscoveredDevice(
      name: 'ChameleonUltra: hw_v1, fw_v2',
      kind: TransportKind.usb,
      transportId: '/dev/cu.usbmodem1',
    ));
    expect(found.first.isBootloader, isFalse);
    expect(found.last.isBootloader, isTrue);
    expect(found.last.transportId, '/dev/cu.usbmodem2');
    expect(scanner.kind, TransportKind.usb);
  });

  test('a port with no product string falls back to its description',
      () async {
    final adapter = FakeSerialAdapter(ports: const [bootloader]);
    final found = await SerialScanner(adapter: adapter).enumerate();
    expect(found.single.name, 'ChameleonUltra DFU');
  });

  test('scan polls and re-emits only when the set changes', () async {
    final adapter = FakeSerialAdapter(ports: const [ultra]);
    final scanner = SerialScanner(
      adapter: adapter,
      pollInterval: const Duration(milliseconds: 5),
    );
    final emissions = <List<DiscoveredDevice>>[];
    final sub = scanner.scan().listen(emissions.add);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(emissions.length, 1, reason: 'an unchanged port list re-emits nothing');
    adapter.ports = const [ultra, bootloader];
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(emissions.length, 2);
    expect(emissions.last.length, 2);
    await sub.cancel();
  });

  test('an enumeration failure is an error on the stream, not a crash',
      () async {
    final adapter = _ThrowingAdapter();
    final scanner = SerialScanner(
      adapter: adapter,
      pollInterval: const Duration(milliseconds: 5),
    );
    await expectLater(scanner.scan().first, throwsA(isA<Exception>()));
  });
}

final class _ThrowingAdapter extends FakeSerialAdapter {
  @override
  List<SerialPortDescriptor> listPorts() => throw Exception('enumeration blew up');
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd packages/chameleon_flutter && flutter test test/serial/serial_scanner_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: '.../serial_scanner.dart'`. (`FakeSerialAdapter` must be `base`-free and non-`final` for `_ThrowingAdapter` to extend it; if the analyzer objects, drop `final` from `FakeSerialAdapter` in `test/support/fake_serial_adapter.dart`.)

- [ ] **Step 3: Implement**

```dart
// lib/src/serial/serial_scanner.dart
import 'dart:async';

import 'package:chameleon/chameleon.dart';

import 'serial_adapter.dart';
import 'serial_ids.dart';
import 'usb_serial_adapter.dart';

/// Spec 5.5: the Nordic bootloader enumerates as VID 0x1915 / PID 0x521F.
bool isBootloaderPort(SerialPortDescriptor port) =>
    port.vid == ChameleonUsbIds.bootloaderVid &&
    port.pid == ChameleonUsbIds.bootloaderPid;

/// Spec 5.2: filter on VID 0x6868 / PID 0x8686 and manufacturer
/// "Proxgrind". The manufacturer alone is enough, and the bootloader counts
/// too so a device stuck in DFU still shows up.
bool isChameleonPort(SerialPortDescriptor port) {
  if (isBootloaderPort(port)) return true;
  if (port.vid == ChameleonUsbIds.applicationVid &&
      port.pid == ChameleonUsbIds.applicationPid) {
    return true;
  }
  return port.manufacturer == ChameleonUsbIds.manufacturer;
}

/// Polls the serial ports and reports the Chameleons among them (spec 4.2).
///
/// Serial has no attach event on desktop, so this polls. [pollInterval] is
/// two seconds, and an unchanged port list re-emits nothing.
final class SerialScanner implements DeviceScanner {
  SerialScanner({
    required SerialPortAdapter adapter,
    this.pollInterval = const Duration(seconds: 2),
  }) : _adapter = adapter;

  final SerialPortAdapter _adapter;
  final Duration pollInterval;

  @override
  TransportKind get kind => TransportKind.usb;

  /// One enumeration pass, for a manual refresh.
  Future<List<DiscoveredDevice>> enumerate() async {
    final adapter = _adapter;
    // usb_serial enumerates asynchronously; refresh its cache first.
    if (adapter is UsbSerialAdapter) await adapter.refresh();
    return <DiscoveredDevice>[
      for (final port in adapter.listPorts())
        if (isChameleonPort(port))
          DiscoveredDevice(
            name: port.product ?? port.description,
            kind: TransportKind.usb,
            transportId: port.path,
            isBootloader: isBootloaderPort(port),
          ),
    ];
  }

  @override
  Stream<List<DiscoveredDevice>> scan() {
    Timer? timer;
    List<String>? previous;
    final controller = StreamController<List<DiscoveredDevice>>();

    Future<void> poll() async {
      try {
        final devices = await enumerate();
        final key = devices
            .map((d) => '${d.transportId}|${d.name}|${d.isBootloader}')
            .toList(growable: false);
        if (previous != null && _sameList(previous!, key)) return;
        previous = key;
        if (!controller.isClosed) {
          controller.add(List<DiscoveredDevice>.unmodifiable(devices));
        }
      } on Object catch (e, s) {
        if (!controller.isClosed) controller.addError(e, s);
      }
    }

    controller.onListen = () {
      unawaited(poll());
      timer = Timer.periodic(pollInterval, (_) => unawaited(poll()));
    };
    controller.onCancel = () async {
      timer?.cancel();
      await controller.close();
    };
    return controller.stream;
  }

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
```

- [ ] **Step 4: Run to verify it passes**

```bash
cd packages/chameleon_flutter && flutter test test/serial/serial_scanner_test.dart
```

Expected: PASS, 8 tests.

- [ ] **Step 5: Export and commit**

Add `export 'src/serial/serial_scanner.dart';` to the barrel.

```bash
git add packages/chameleon_flutter
git commit -m "feat(chameleon_flutter): add SerialScanner

Filters on VID 0x6868 / PID 0x8686 and the Proxgrind manufacturer string,
and flags VID 0x1915 / PID 0x521F as the bootloader so a device stuck in
DFU still appears with a recover action (spec 5.2, 5.5)."
```

---

### Task 11: The SLIP codec and SlipSerialDfuChannel

**Read `packages/chameleon/lib/src/dfu/dfu_channel.dart` first** and follow the landed `DfuChannel` signature; the code below targets Phase 1 Task 19's declared shape (`maxDataWrite`, `writeControl`, `writeData`, `responses`, `close`). If `responses` landed under another name, rename the override and the tests to match and note it in the commit body.

**Files:**
- Create: `lib/src/dfu/slip.dart`, `lib/src/dfu/slip_serial_dfu_channel.dart`
- Modify: `lib/chameleon_flutter.dart`
- Test: `test/dfu/slip_test.dart`, `test/dfu/slip_serial_dfu_channel_test.dart`

**Interfaces:**
- Consumes: `Transport` and `Disconnected` from `package:chameleon/chameleon.dart`, `DfuChannel` from the same barrel, `FakeDevice` for a stand-in transport in tests.
- Produces:

```dart
abstract final class Slip {
  static const int end = 0xC0;
  static const int esc = 0xDB;
  static const int escEnd = 0xDC;
  static const int escEsc = 0xDD;

  /// Escapes [payload] and appends the END byte.
  static Uint8List encode(List<int> payload);
}

/// Reassembles SLIP frames across arbitrary chunk boundaries.
final class SlipDecoder {
  Iterable<Uint8List> add(List<int> chunk);
  void reset();
}

final class SlipSerialDfuChannel implements DfuChannel {
  SlipSerialDfuChannel(Transport transport, {int maxDataWrite = 64, bool ownsTransport = false});
  @override int get maxDataWrite;
  @override Future<void> writeControl(Uint8List bytes);
  @override Future<void> writeData(Uint8List bytes);
  @override Stream<Uint8List> get responses;
  @override Future<void> close();
}
```

- [ ] **Step 1: Write the failing SLIP test**

```dart
// test/dfu/slip_test.dart
import 'package:chameleon_flutter/src/dfu/slip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a plain payload is the bytes plus END', () {
    expect(Slip.encode(const [1, 2, 3]), [1, 2, 3, 0xC0]);
  });

  test('END and ESC inside the payload are escaped', () {
    expect(Slip.encode(const [0xC0]), [0xDB, 0xDC, 0xC0]);
    expect(Slip.encode(const [0xDB]), [0xDB, 0xDD, 0xC0]);
    expect(Slip.encode(const [1, 0xC0, 2, 0xDB, 3]),
        [1, 0xDB, 0xDC, 2, 0xDB, 0xDD, 3, 0xC0]);
  });

  test('an empty payload is a bare END', () {
    expect(Slip.encode(const []), [0xC0]);
  });

  test('the decoder round-trips every payload', () {
    final decoder = SlipDecoder();
    const payloads = [
      <int>[1, 2, 3],
      <int>[0xC0, 0xDB, 0xC0],
      <int>[0],
    ];
    final wire = <int>[for (final p in payloads) ...Slip.encode(p)];
    expect(decoder.add(wire).map((f) => f.toList()).toList(), payloads);
  });

  test('a frame split across chunks is reassembled', () {
    final decoder = SlipDecoder();
    final wire = Slip.encode(const [1, 0xC0, 2]);
    expect(decoder.add(wire.sublist(0, 2)), isEmpty);
    expect(decoder.add(wire.sublist(2, 3)), isEmpty);
    expect(decoder.add(wire.sublist(3)).single, [1, 0xC0, 2]);
  });

  test('an escape split across chunks is still decoded', () {
    final decoder = SlipDecoder();
    expect(decoder.add(const [1, 0xDB]), isEmpty);
    expect(decoder.add(const [0xDC, 0xC0]).single, [1, 0xC0]);
  });

  test('empty frames from back-to-back ENDs are dropped', () {
    expect(SlipDecoder().add(const [0xC0, 0xC0, 1, 0xC0]).single, [1]);
  });

  test('reset drops a partial frame', () {
    final decoder = SlipDecoder()..add(const [1, 2]);
    decoder.reset();
    expect(decoder.add(const [3, 0xC0]).single, [3]);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd packages/chameleon_flutter && flutter test test/dfu/slip_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: '.../slip.dart'`.

- [ ] **Step 3: Implement the codec**

```dart
// lib/src/dfu/slip.dart
import 'dart:typed_data';

/// RFC 1055 SLIP framing, as Nordic's serial DFU transport uses it
/// (spec 5.3). Frames are terminated, not delimited: a frame ends with END.
abstract final class Slip {
  static const int end = 0xC0;
  static const int esc = 0xDB;
  static const int escEnd = 0xDC;
  static const int escEsc = 0xDD;

  /// [payload] with END and ESC escaped, followed by a terminating END.
  static Uint8List encode(List<int> payload) {
    final out = BytesBuilder(copy: false);
    for (final b in payload) {
      switch (b) {
        case end:
          out.addByte(esc);
          out.addByte(escEnd);
        case esc:
          out.addByte(esc);
          out.addByte(escEsc);
        default:
          out.addByte(b);
      }
    }
    out.addByte(end);
    return out.toBytes();
  }
}

/// Feeds arbitrary byte chunks in, gets whole SLIP frames out.
///
/// A serial read can split a frame anywhere, including between an ESC and
/// the byte it escapes, so both the partial frame and the pending-escape
/// flag are carried between calls.
final class SlipDecoder {
  final BytesBuilder _frame = BytesBuilder(copy: false);
  bool _escaped = false;

  /// Every complete frame in [chunk]. Empty frames (back-to-back ENDs, which
  /// Nordic's transport emits as padding) are dropped.
  Iterable<Uint8List> add(List<int> chunk) {
    final frames = <Uint8List>[];
    for (final b in chunk) {
      if (_escaped) {
        _escaped = false;
        _frame.addByte(switch (b) {
          Slip.escEnd => Slip.end,
          Slip.escEsc => Slip.esc,
          // An invalid escape: keep the byte rather than lose the frame.
          _ => b,
        });
        continue;
      }
      switch (b) {
        case Slip.esc:
          _escaped = true;
        case Slip.end:
          if (_frame.isNotEmpty) frames.add(_frame.takeBytes());
        default:
          _frame.addByte(b);
      }
    }
    return frames;
  }

  /// Drops any partially received frame.
  void reset() {
    _frame.clear();
    _escaped = false;
  }
}
```

- [ ] **Step 4: Write the failing channel test**

```dart
// test/dfu/slip_serial_dfu_channel_test.dart
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/src/dfu/slip.dart';
import 'package:chameleon_flutter/src/dfu/slip_serial_dfu_channel.dart';
import 'package:flutter_test/flutter_test.dart';

/// A byte pipe standing in for an open serial link.
final class _LoopbackTransport implements Transport {
  final List<Uint8List> written = <Uint8List>[];
  final _incoming = StreamController<Uint8List>.broadcast();
  bool closed = false;

  void deliver(List<int> bytes) => _incoming.add(Uint8List.fromList(bytes));

  @override
  TransportKind get kind => TransportKind.usb;
  @override
  Stream<Uint8List> get incoming => _incoming.stream;
  @override
  Stream<TransportState> get state => const Stream<TransportState>.empty();
  @override
  TransportState get currentState => const TransportOpen();
  @override
  Future<void> open() async {}
  @override
  Future<void> close() async {
    closed = true;
    await _incoming.close();
  }

  @override
  Future<void> write(Uint8List bytes) async =>
      written.add(Uint8List.fromList(bytes));
}

void main() {
  test('control writes are SLIP-encoded verbatim', () async {
    final t = _LoopbackTransport();
    final channel = SlipSerialDfuChannel(t);
    await channel.writeControl(Uint8List.fromList(const [0x06, 0x01]));
    expect(t.written.single, Slip.encode(const [0x06, 0x01]));
  });

  test('data writes carry the 0x08 opcode and a little-endian length',
      () async {
    final t = _LoopbackTransport();
    final channel = SlipSerialDfuChannel(t);
    await channel.writeData(Uint8List.fromList(List<int>.filled(300, 0xAB)));
    // 300 = 0x012C -> 0x2C, 0x01.
    expect(t.written.single,
        Slip.encode(<int>[0x08, 0x2C, 0x01, ...List<int>.filled(300, 0xAB)]));
  });

  test('a payload containing END survives the framing', () async {
    final t = _LoopbackTransport();
    final channel = SlipSerialDfuChannel(t);
    await channel.writeControl(Uint8List.fromList(const [0xC0, 0xDB]));
    expect(t.written.single, [0xDB, 0xDC, 0xDB, 0xDD, 0xC0]);
  });

  test('responses are decoded frames, reassembled across chunks', () async {
    final t = _LoopbackTransport();
    final channel = SlipSerialDfuChannel(t);
    final got = <List<int>>[];
    channel.responses.listen((f) => got.add(f.toList()));
    final wire = Slip.encode(const [0x60, 0x06, 0x01]);
    t.deliver(wire.sublist(0, 2));
    t.deliver(wire.sublist(2));
    await Future<void>.delayed(Duration.zero);
    expect(got, [
      [0x60, 0x06, 0x01]
    ]);
  });

  test('maxDataWrite defaults to 64 and is settable', () {
    expect(SlipSerialDfuChannel(_LoopbackTransport()).maxDataWrite, 64);
    expect(
      SlipSerialDfuChannel(_LoopbackTransport(), maxDataWrite: 128).maxDataWrite,
      128,
    );
  });

  test('close leaves a borrowed transport open and closes an owned one',
      () async {
    final borrowed = _LoopbackTransport();
    await SlipSerialDfuChannel(borrowed).close();
    expect(borrowed.closed, isFalse);

    final owned = _LoopbackTransport();
    await SlipSerialDfuChannel(owned, ownsTransport: true).close();
    expect(owned.closed, isTrue);
  });

  test('writing after close throws Disconnected', () async {
    final channel = SlipSerialDfuChannel(_LoopbackTransport());
    await channel.close();
    await expectLater(
      channel.writeControl(Uint8List.fromList(const [1])),
      throwsA(isA<Disconnected>()),
    );
  });
}
```

Add `import 'dart:async';` at the top of that test file for `StreamController`.

- [ ] **Step 5: Implement the channel**

```dart
// lib/src/dfu/slip_serial_dfu_channel.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';

import 'slip.dart';

/// Nordic Secure DFU over a serial link (spec 5.3): desktop USB and Android
/// USB. Every message in both directions is one SLIP frame.
///
/// Control messages go on the wire as-is. Data goes out under the serial
/// transport's write opcode 0x08 followed by a little-endian uint16 length,
/// which is how nrfutil's serial DFU transport frames a data packet.
///
/// hardware-validate: the serial DFU framing is exercised against the fake
/// bootloader only. Real bootloader behaviour is hardware handoff H2; see
/// docs/hardware-checklist.md.
final class SlipSerialDfuChannel implements DfuChannel {
  SlipSerialDfuChannel(
    this._transport, {
    this.maxDataWrite = 64,
    bool ownsTransport = false,
  }) : _ownsTransport = ownsTransport {
    _sub = _transport.incoming.listen(
      (chunk) {
        for (final frame in _decoder.add(chunk)) {
          if (!_responses.isClosed) _responses.add(frame);
        }
      },
      onError: (Object e, StackTrace s) {
        if (!_responses.isClosed) _responses.addError(e, s);
      },
    );
  }

  /// The serial DFU write opcode: `[0x08, len_lo, len_hi, ...payload]`.
  static const int _writeObjectOpcode = 0x08;

  final Transport _transport;
  final bool _ownsTransport;
  final SlipDecoder _decoder = SlipDecoder();
  final StreamController<Uint8List> _responses =
      StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List>? _sub;
  bool _closed = false;

  @override
  final int maxDataWrite;

  @override
  Stream<Uint8List> get responses => _responses.stream;

  @override
  Future<void> writeControl(Uint8List bytes) => _send(bytes);

  @override
  Future<void> writeData(Uint8List bytes) => _send(
    Uint8List.fromList(<int>[
      _writeObjectOpcode,
      bytes.length & 0xFF,
      (bytes.length >> 8) & 0xFF,
      ...bytes,
    ]),
  );

  Future<void> _send(Uint8List payload) async {
    if (_closed) {
      throw const Disconnected('the DFU channel is closed');
    }
    await _transport.write(Slip.encode(payload));
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _sub?.cancel();
    _sub = null;
    await _responses.close();
    if (_ownsTransport) await _transport.close();
  }
}
```

- [ ] **Step 6: Run both test files**

```bash
cd packages/chameleon_flutter && flutter test test/dfu/
```

Expected: PASS, 15 tests.

- [ ] **Step 7: Export and commit**

Add `export 'src/dfu/slip.dart';` and `export 'src/dfu/slip_serial_dfu_channel.dart';` to the barrel.

```bash
git add packages/chameleon_flutter
git commit -m "feat(chameleon_flutter): add the SLIP codec and serial DFU channel

Spec 5.3's SlipSerialDfuChannel: a pure-Dart SLIP codec that survives
chunk boundaries mid-escape, and a DfuChannel that frames Nordic's serial
DFU messages over any Transport. Real bootloader behaviour is H2."
```

---

### Task 12: BleDfuChannel

**Files:**
- Create: `lib/src/dfu/ble_dfu_channel.dart`
- Modify: `lib/chameleon_flutter.dart`
- Test: `test/dfu/ble_dfu_channel_test.dart`

**Interfaces:**
- Consumes: `BleAdapter`, `BleAdapterException`, `BleFailure`, `NordicDfuUuids`, `HostPlatform`, `FakeBleAdapter`, `DfuChannel` and `Disconnected` from `package:chameleon/chameleon.dart`.
- Produces:

```dart
final class BleDfuChannel implements DfuChannel {
  BleDfuChannel({
    required String deviceId,
    required BleAdapter adapter,
    HostPlatform? platform,
    int requestedMtu = 247,
    int appleMaxWrite = 20,
  });

  /// Connects, discovers, subscribes to the control point and settles the
  /// write size. Must be awaited before any write.
  Future<void> open();

  @override int get maxDataWrite;
  @override Future<void> writeControl(Uint8List bytes);
  @override Future<void> writeData(Uint8List bytes);
  @override Stream<Uint8List> get responses;
  @override Future<void> close();
}
```

- [ ] **Step 1: Write the failing test**

```dart
// test/dfu/ble_dfu_channel_test.dart
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:chameleon_flutter/src/dfu/ble_dfu_channel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_ble_adapter.dart';

BleDfuChannel build(
  FakeBleAdapter adapter, {
  HostPlatform platform = HostPlatform.linux,
}) => BleDfuChannel(
  deviceId: 'AA:BB:CC:DD:EE:FF',
  adapter: adapter,
  platform: platform,
);

void main() {
  test('open connects, discovers and subscribes to the control point',
      () async {
    final adapter = FakeBleAdapter();
    final channel = build(adapter);
    await channel.open();
    expect(adapter.connectAttempts, 1);
    expect(adapter.discovered, isTrue);
    await channel.close();
    await adapter.dispose();
  });

  test('iOS and macOS write 20 bytes whatever the MTU says', () async {
    for (final p in const [HostPlatform.ios, HostPlatform.macos]) {
      final adapter = FakeBleAdapter(mtu: 247);
      final channel = build(adapter, platform: p);
      await channel.open();
      expect(channel.maxDataWrite, 20, reason: p.name);
      await channel.close();
      await adapter.dispose();
    }
  });

  test('elsewhere the write size is the negotiated MTU minus three',
      () async {
    final adapter = FakeBleAdapter(mtu: 247);
    final channel = build(adapter, platform: HostPlatform.android);
    await channel.open();
    expect(channel.maxDataWrite, 244);
    await channel.close();
    await adapter.dispose();
  });

  test('control writes go to 8EC90001 with response, unchunked', () async {
    final adapter = FakeBleAdapter(mtu: 23);
    final channel = build(adapter);
    await channel.open();
    await channel.writeControl(Uint8List.fromList(const [0x06, 0x01]));
    expect(adapter.writtenCharacteristics.single, NordicDfuUuids.controlPoint);
    expect(adapter.writes.single, [0x06, 0x01]);
    expect(adapter.writeWithResponse.single, isTrue);
    await channel.close();
    await adapter.dispose();
  });

  test('data writes go to 8EC90002 without response, chunked at maxDataWrite',
      () async {
    final adapter = FakeBleAdapter(mtu: 23); // -> 20 bytes
    final channel = build(adapter);
    await channel.open();
    await channel.writeData(Uint8List.fromList(List<int>.generate(45, (i) => i)));
    expect(adapter.writtenCharacteristics.toSet(), {NordicDfuUuids.packet});
    expect(adapter.writes.map((c) => c.length).toList(), [20, 20, 5]);
    expect(adapter.writes.expand((c) => c).toList(),
        List<int>.generate(45, (i) => i));
    expect(adapter.writeWithResponse, everyElement(isFalse));
    await channel.close();
    await adapter.dispose();
  });

  test('notifications from the control point become responses', () async {
    final adapter = FakeBleAdapter();
    final channel = build(adapter);
    final got = <List<int>>[];
    channel.responses.listen((f) => got.add(f.toList()));
    await channel.open();
    adapter.emitNotification(NordicDfuUuids.controlPoint, const [0x60, 0x06, 0x01]);
    await Future<void>.delayed(Duration.zero);
    expect(got, [
      [0x60, 0x06, 0x01]
    ]);
    await channel.close();
    await adapter.dispose();
  });

  test('a write before open, or after close, throws Disconnected', () async {
    final adapter = FakeBleAdapter();
    final channel = build(adapter);
    await expectLater(
      channel.writeControl(Uint8List.fromList(const [1])),
      throwsA(isA<Disconnected>()),
    );
    await channel.open();
    await channel.close();
    await expectLater(
      channel.writeData(Uint8List.fromList(const [1])),
      throwsA(isA<Disconnected>()),
    );
    await adapter.dispose();
  });

  test('close disconnects the device', () async {
    final adapter = FakeBleAdapter();
    final channel = build(adapter);
    await channel.open();
    await channel.close();
    expect(adapter.disconnected, isTrue);
    await adapter.dispose();
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd packages/chameleon_flutter && flutter test test/dfu/ble_dfu_channel_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: '.../ble_dfu_channel.dart'`.

- [ ] **Step 3: Implement**

```dart
// lib/src/dfu/ble_dfu_channel.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';

import '../ble/ble_adapter.dart';
import '../ble/ble_failure.dart';
import '../ble/ble_uuids.dart';
import '../host_platform.dart';

/// Nordic Secure DFU over BLE (spec 5.3): service FE59, control point
/// 8EC90001, packet 8EC90002.
///
/// Control messages are written with response and are never split — a
/// Secure DFU request always fits. Firmware data is written without
/// response in [maxDataWrite] chunks: 20 bytes on iOS and macOS, where
/// CoreBluetooth's write-without-response limit is not reliably reported,
/// and the negotiated MTU minus three everywhere else.
///
/// hardware-validate: BLE DFU is gated behind the `dfuOverBleEnabled` flag
/// until hardware handoff H2 passes. See docs/hardware-checklist.md.
final class BleDfuChannel implements DfuChannel {
  BleDfuChannel({
    required this.deviceId,
    required BleAdapter adapter,
    HostPlatform? platform,
    this.requestedMtu = 247,
    this.appleMaxWrite = 20,
  }) : _adapter = adapter,
       _platform = platform ?? currentHostPlatform();

  final String deviceId;
  final BleAdapter _adapter;
  final HostPlatform _platform;
  final int requestedMtu;
  final int appleMaxWrite;

  final StreamController<Uint8List> _responses =
      StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List>? _sub;
  int _maxDataWrite = 20;
  bool _open = false;
  bool _closed = false;

  @override
  int get maxDataWrite => _maxDataWrite;

  @override
  Stream<Uint8List> get responses => _responses.stream;

  /// Connects and prepares the channel. Await before writing.
  Future<void> open() async {
    if (_open) return;
    if (_closed) throw const Disconnected('the DFU channel is closed');
    try {
      await _adapter.connect(deviceId);
      await _adapter.discoverServices(deviceId);
      await _adapter.subscribe(
        deviceId,
        service: NordicDfuUuids.service,
        characteristic: NordicDfuUuids.controlPoint,
      );
    } on BleAdapterException catch (e) {
      throw Disconnected(e.message);
    }
    _maxDataWrite = await _resolveWriteSize();
    _sub = _adapter
        .notifications(
          deviceId,
          service: NordicDfuUuids.service,
          characteristic: NordicDfuUuids.controlPoint,
        )
        .listen(
          _responses.add,
          onError: (Object e, StackTrace s) => _responses.addError(e, s),
        );
    _open = true;
  }

  Future<int> _resolveWriteSize() async {
    if (_platform == HostPlatform.ios || _platform == HostPlatform.macos) {
      return appleMaxWrite;
    }
    try {
      final mtu = await _adapter.requestMtu(deviceId, requestedMtu);
      final usable = mtu - 3;
      return usable < appleMaxWrite ? appleMaxWrite : usable;
    } on BleAdapterException {
      return appleMaxWrite;
    }
  }

  @override
  Future<void> writeControl(Uint8List bytes) async {
    _requireOpen();
    await _write(NordicDfuUuids.controlPoint, bytes, withResponse: true);
  }

  @override
  Future<void> writeData(Uint8List bytes) async {
    _requireOpen();
    for (var offset = 0; offset < bytes.length; offset += _maxDataWrite) {
      final end = offset + _maxDataWrite;
      await _write(
        NordicDfuUuids.packet,
        Uint8List.sublistView(bytes, offset, end > bytes.length ? bytes.length : end),
        withResponse: false,
      );
    }
  }

  void _requireOpen() {
    if (!_open || _closed) {
      throw const Disconnected('the DFU channel is not open');
    }
  }

  Future<void> _write(
    String characteristic,
    Uint8List value, {
    required bool withResponse,
  }) async {
    try {
      await _adapter.write(
        deviceId,
        service: NordicDfuUuids.service,
        characteristic: characteristic,
        value: value,
        withResponse: withResponse,
      );
    } on BleAdapterException catch (e) {
      throw Disconnected(e.message);
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _open = false;
    await _sub?.cancel();
    _sub = null;
    await _responses.close();
    try {
      await _adapter.disconnect(deviceId);
    } on BleAdapterException {
      // Already gone.
    }
  }
}
```

- [ ] **Step 4: Run to verify it passes**

```bash
cd packages/chameleon_flutter && flutter test test/dfu/ble_dfu_channel_test.dart
```

Expected: PASS, 8 tests.

- [ ] **Step 5: Export and commit**

Add `export 'src/dfu/ble_dfu_channel.dart';` to the barrel.

```bash
cd packages/chameleon_flutter && flutter analyze && dart format .
git add packages/chameleon_flutter
git commit -m "feat(chameleon_flutter): add BleDfuChannel

Spec 5.3: FE59 with control point 8EC90001 written with response and
packet 8EC90002 written without, chunked at 20 bytes on iOS and macOS and
at the negotiated MTU minus three elsewhere. Stays behind
dfuOverBleEnabled until H2."
```

---

### Task 13: ChameleonTransports, the per-platform scanner list

**Files:**
- Create: `lib/src/transports.dart`
- Modify: `lib/chameleon_flutter.dart`
- Test: `test/transports_test.dart`

**Interfaces:**
- Consumes: `BleScanner`, `SerialScanner`, `BleTransport`, `SerialTransport`, `BleAdapter`, `UniversalBleAdapter`, `SerialPortAdapter`, `defaultSerialPortAdapter`, `SerialControlLineMode`, `HostPlatform`, and `DeviceScanner`, `DiscoveredDevice`, `TransportKind`, `Transport`, `FakeScanner`, `FakeDevice`, `DeviceNotFound` from `package:chameleon/chameleon.dart`.
- Produces (spec 8.2 — a plain list, no registry, no plugin system):

```dart
abstract final class ChameleonTransports {
  /// The scanners to run concurrently on this platform. `emulator: true`
  /// prepends the SDK's FakeScanner (spec 7.5).
  static List<DeviceScanner> defaultScanners({
    bool emulator = false,
    HostPlatform? platform,
    BleAdapter? bleAdapter,
    SerialPortAdapter? serialAdapter,
  });

  /// A transport for a device a scanner reported.
  static Transport transportFor(
    DiscoveredDevice device, {
    HostPlatform? platform,
    BleAdapter? bleAdapter,
    SerialPortAdapter? serialAdapter,
    SerialControlLineMode controlLines = SerialControlLineMode.dtrOnly,
  });
}
```

- [ ] **Step 1: Write the failing test**

```dart
// test/transports_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:chameleon_flutter/src/ble/ble_scanner.dart';
import 'package:chameleon_flutter/src/ble/ble_transport.dart';
import 'package:chameleon_flutter/src/serial/serial_scanner.dart';
import 'package:chameleon_flutter/src/serial/serial_transport.dart';
import 'package:chameleon_flutter/src/transports.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_ble_adapter.dart';
import 'support/fake_serial_adapter.dart';

List<DeviceScanner> scanners(HostPlatform platform, {bool emulator = false}) =>
    ChameleonTransports.defaultScanners(
      platform: platform,
      emulator: emulator,
      bleAdapter: FakeBleAdapter(),
      serialAdapter: FakeSerialAdapter(),
    );

void main() {
  test('desktop and Android scan BLE and serial', () {
    for (final p in const [
      HostPlatform.macos,
      HostPlatform.windows,
      HostPlatform.linux,
      HostPlatform.android,
    ]) {
      final list = scanners(p);
      expect(list.map((s) => s.runtimeType).toList(),
          [BleScanner, SerialScanner], reason: p.name);
    }
  });

  test('iOS scans BLE only (spec 5.4)', () {
    expect(scanners(HostPlatform.ios).map((s) => s.runtimeType).toList(),
        [BleScanner]);
  });

  test('emulator mode prepends the SDK FakeScanner (spec 7.5)', () {
    final list = scanners(HostPlatform.macos, emulator: true);
    expect(list.first, isA<FakeScanner>());
    expect(list.length, 3);
  });

  test('transportFor picks the transport the discovery kind implies', () {
    final ble = ChameleonTransports.transportFor(
      const DiscoveredDevice(
        name: 'ChameleonUltra',
        kind: TransportKind.ble,
        transportId: 'AA:BB',
      ),
      platform: HostPlatform.macos,
      bleAdapter: FakeBleAdapter(),
      serialAdapter: FakeSerialAdapter(),
    );
    expect(ble, isA<BleTransport>());

    final usb = ChameleonTransports.transportFor(
      const DiscoveredDevice(
        name: 'ChameleonUltra',
        kind: TransportKind.usb,
        transportId: '/dev/cu.usbmodem1',
      ),
      platform: HostPlatform.macos,
      bleAdapter: FakeBleAdapter(),
      serialAdapter: FakeSerialAdapter(),
    );
    expect(usb, isA<SerialTransport>());
    expect((usb as SerialTransport).path, '/dev/cu.usbmodem1');
  });

  test('a fake discovery yields a FakeDevice, so emulator mode connects', () {
    final t = ChameleonTransports.transportFor(
      FakeScanner.emulatedUltra,
      platform: HostPlatform.macos,
      bleAdapter: FakeBleAdapter(),
      serialAdapter: FakeSerialAdapter(),
    );
    expect(t, isA<FakeDevice>());
  });

  test('asking for serial where there is none is DeviceNotFound', () {
    expect(
      () => ChameleonTransports.transportFor(
        const DiscoveredDevice(
          name: 'x',
          kind: TransportKind.usb,
          transportId: '/dev/x',
        ),
        platform: HostPlatform.ios,
        bleAdapter: FakeBleAdapter(),
      ),
      throwsA(isA<DeviceNotFound>()),
    );
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd packages/chameleon_flutter && flutter test test/transports_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: '.../transports.dart'`.

- [ ] **Step 3: Implement**

```dart
// lib/src/transports.dart
import 'package:chameleon/chameleon.dart';

import 'ble/ble_adapter.dart';
import 'ble/ble_scanner.dart';
import 'ble/ble_transport.dart';
import 'ble/universal_ble_adapter.dart';
import 'host_platform.dart';
import 'serial/serial_adapter.dart';
import 'serial/serial_adapter_factory.dart';
import 'serial/serial_scanner.dart';
import 'serial/serial_transport.dart';

/// Where the app gets its scanners and transports (spec 8.2).
///
/// Deliberately a plain list and a switch, not a registry: adding a
/// transport means editing this file, which is exactly the amount of
/// ceremony a five-platform app needs.
abstract final class ChameleonTransports {
  /// The scanners to run concurrently on this platform. Their results are
  /// merged by the app (spec 4.2).
  ///
  /// [emulator] prepends the SDK's [FakeScanner] so the app's emulator mode
  /// works with no device attached (spec 7.5). The adapter parameters exist
  /// for tests; production passes none.
  static List<DeviceScanner> defaultScanners({
    bool emulator = false,
    HostPlatform? platform,
    BleAdapter? bleAdapter,
    SerialPortAdapter? serialAdapter,
  }) {
    final resolved = platform ?? currentHostPlatform();
    final serial =
        serialAdapter ?? defaultSerialPortAdapter(platform: resolved);
    return <DeviceScanner>[
      if (emulator) FakeScanner(),
      BleScanner(adapter: bleAdapter ?? UniversalBleAdapter()),
      if (serial != null && resolved != HostPlatform.ios)
        SerialScanner(adapter: serial),
    ];
  }

  /// A transport for a device one of those scanners reported.
  static Transport transportFor(
    DiscoveredDevice device, {
    HostPlatform? platform,
    BleAdapter? bleAdapter,
    SerialPortAdapter? serialAdapter,
    SerialControlLineMode controlLines = SerialControlLineMode.dtrOnly,
  }) {
    final resolved = platform ?? currentHostPlatform();
    switch (device.kind) {
      case TransportKind.fake:
        return FakeDevice();
      case TransportKind.ble:
        return BleTransport(
          deviceId: device.transportId,
          adapter: bleAdapter ?? UniversalBleAdapter(),
          platform: resolved,
        );
      case TransportKind.usb:
        final serial =
            serialAdapter ?? defaultSerialPortAdapter(platform: resolved);
        if (serial == null) {
          throw const DeviceNotFound('this platform has no serial transport');
        }
        return SerialTransport(
          path: device.transportId,
          adapter: serial,
          controlLines: controlLines,
          platform: resolved,
        );
    }
  }
}
```

- [ ] **Step 4: Run to verify it passes**

```bash
cd packages/chameleon_flutter && flutter test test/transports_test.dart
```

Expected: PASS, 6 tests.

- [ ] **Step 5: Export and commit**

Add `export 'src/transports.dart';` to the barrel.

```bash
cd packages/chameleon_flutter && flutter analyze && dart format .
git add packages/chameleon_flutter
git commit -m "feat(chameleon_flutter): add ChameleonTransports

One place the app asks for the scanners and transports this platform has,
including the SDK FakeScanner in emulator mode. A plain list and a switch,
per spec 8.2's rule against a registry."
```

---

### Task 14: The transport contract suite

Spec 5.8: "A transport contract suite that any `Transport` must pass. CI runs it against `FakeDevice`; it is also run against real hardware with the `hardware` tag." One shared test body, two call sites. The body must hold for a byte pipe to a real device, so it drives the wire: it writes a real GET_APP_VERSION request frame (command 1000) and asserts bytes come back — true of `FakeDevice` and of a Chameleon over serial or BLE alike.

**Files:**
- Create: `test/contract/transport_contract.dart`, `test/contract/fake_device_contract_test.dart`, `test/contract/hardware_contract_test.dart`
- Test: the two files above

**Interfaces:**
- Consumes: `Transport`, `TransportState` variants, `CloseCause`, `Disconnected`, `Frame`, `FakeDevice` from `package:chameleon/chameleon.dart`; `ChameleonTransports`, `SerialScanner`, `BleScanner`, `defaultSerialPortAdapter`, `UniversalBleAdapter`.
- Produces:

```dart
/// The behaviours every Transport must have (spec 5.8).
///
/// [make] returns a fresh, unopened transport each call.
void transportContractTests(String description, Transport Function() make);
```

- [ ] **Step 1: Write the contract body**

```dart
// test/contract/transport_contract.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';

/// GET_APP_VERSION: every firmware and the fake answer it, and it needs no
/// prior state, which makes it the right probe for a byte-level contract.
Uint8List _getAppVersionRequest() => Frame(command: 1000).encode();

/// The behaviours every [Transport] must have, whatever it is talking to
/// (spec 4.1, 5.8).
///
/// [make] must return a fresh, unopened transport on each call.
void transportContractTests(String description, Transport Function() make) {
  group('Transport contract: $description', () {
    test('open moves opening -> open and settles on TransportOpen', () async {
      final t = make();
      final seen = <TransportState>[];
      final sub = t.state.listen(seen.add);
      await t.open();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(seen.whereType<TransportOpening>(), isNotEmpty);
      expect(seen.last, isA<TransportOpen>());
      expect(t.currentState, isA<TransportOpen>());
      await sub.cancel();
      await t.close();
    });

    test('open is idempotent', () async {
      final t = make();
      await t.open();
      await t.open();
      expect(t.currentState, isA<TransportOpen>());
      await t.close();
    });

    test('writing before open throws Disconnected', () async {
      final t = make();
      await expectLater(
        t.write(Uint8List.fromList(const <int>[0x11])),
        throwsA(isA<Disconnected>()),
      );
    });

    test('a written request produces incoming bytes', () async {
      final t = make();
      final received = Completer<Uint8List>();
      final sub = t.incoming.listen((bytes) {
        if (!received.isCompleted) received.complete(bytes);
      });
      await t.open();
      await t.write(_getAppVersionRequest());
      final bytes = await received.future.timeout(const Duration(seconds: 2));
      expect(bytes, isNotEmpty);
      await sub.cancel();
      await t.close();
    });

    test('incoming is a broadcast stream: two listeners both get bytes',
        () async {
      final t = make();
      final a = Completer<void>();
      final b = Completer<void>();
      final subA = t.incoming.listen((_) {
        if (!a.isCompleted) a.complete();
      });
      final subB = t.incoming.listen((_) {
        if (!b.isCompleted) b.complete();
      });
      await t.open();
      await t.write(_getAppVersionRequest());
      await Future.wait(<Future<void>>[a.future, b.future])
          .timeout(const Duration(seconds: 2));
      await subA.cancel();
      await subB.cancel();
      await t.close();
    });

    test('close reports CloseCause.requested', () async {
      final t = make();
      await t.open();
      await t.close();
      final state = t.currentState;
      expect(state, isA<TransportClosed>());
      expect((state as TransportClosed).cause, CloseCause.requested);
    });

    test('close is idempotent', () async {
      final t = make();
      await t.open();
      await t.close();
      await t.close();
      expect(t.currentState, isA<TransportClosed>());
    });

    test('writing after close throws Disconnected', () async {
      final t = make();
      await t.open();
      await t.close();
      await expectLater(
        t.write(_getAppVersionRequest()),
        throwsA(isA<Disconnected>()),
      );
    });

    test('no TransportOpen is emitted after a requested close', () async {
      final t = make();
      await t.open();
      final after = <TransportState>[];
      final sub = t.state.listen(after.add);
      await t.close();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(after.whereType<TransportOpen>(), isEmpty);
      await sub.cancel();
    });
  });
}
```

- [ ] **Step 2: Write the CI call site**

```dart
// test/contract/fake_device_contract_test.dart
import 'package:chameleon/chameleon.dart';

import 'transport_contract.dart';

void main() {
  transportContractTests('FakeDevice', FakeDevice.new);
  transportContractTests(
    'FakeDevice with latency and small chunks',
    () => FakeDevice(
      latency: const Duration(milliseconds: 1),
      chunkSize: 8,
    ),
  );
}
```

- [ ] **Step 3: Run it**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd packages/chameleon_flutter && flutter test test/contract/fake_device_contract_test.dart
```

Expected: PASS, 18 tests (nine behaviours, two configurations). If one fails, the bug is real: fix `FakeDevice` in `packages/chameleon` rather than weakening the contract, and say so in the commit body.

- [ ] **Step 4: Write the hardware call site**

```dart
// test/contract/hardware_contract_test.dart
@Tags(<String>['hardware'])
library;

import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:chameleon_flutter/src/serial/serial_adapter.dart';
import 'package:chameleon_flutter/src/serial/serial_adapter_factory.dart';
import 'package:chameleon_flutter/src/serial/serial_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

import 'transport_contract.dart';

/// The same contract, against a device that is actually attached.
///
/// Skipped unless run as `flutter test --tags hardware` with a Chameleon
/// plugged in. Nothing here is proof of anything until the user reports
/// hardware handoff H1; see docs/hardware-checklist.md.
///
/// Set SPECTRA_SERIAL_CONTROL_LINES=hardwareFlowControl to run the suite in
/// the other control-line mode; H1 asks the user which one works.
void main() {
  final adapter = defaultSerialPortAdapter();
  if (adapter == null) {
    test('no serial stack on this platform', () {}, skip: true);
    return;
  }

  final mode =
      const String.fromEnvironment('SPECTRA_SERIAL_CONTROL_LINES') ==
              'hardwareFlowControl'
          ? SerialControlLineMode.hardwareFlowControl
          : SerialControlLineMode.dtrOnly;

  late List<DiscoveredDevice> found;

  setUpAll(() async {
    found = await SerialScanner(adapter: adapter).enumerate();
  });

  test('a Chameleon is attached over USB', () {
    expect(found, isNotEmpty,
        reason: 'plug in a Chameleon Ultra before running --tags hardware');
    // ignore: avoid_print
    print('hardware: found ${found.map((d) => d.transportId).join(', ')}');
  });

  transportContractTests(
    'SerialTransport on real hardware (${mode.name})',
    () => SerialTransport(
      path: found.firstWhere((d) => !d.isBootloader).transportId,
      adapter: adapter,
      controlLines: mode,
    ),
  );
}
```

BLE is not in this file: it needs a device id the runner cannot know, and pairing prompts a headless test cannot answer. The BLE half of H1 is driven from the example app instead (Task 15).

- [ ] **Step 5: Verify the hardware tests are skipped by default and selectable**

```bash
cd packages/chameleon_flutter && flutter test
```

Expected: PASS; the output names `hardware_contract_test.dart` as skipped (the `dart_test.yaml` `skip:` from Task 2).

```bash
cd packages/chameleon_flutter && flutter test --tags hardware
```

Expected without a device attached: the "a Chameleon is attached over USB" test FAILS with the "plug in a Chameleon Ultra" reason. That failure is the correct outcome with no device; **do not** record it as a pass or a problem. Note in the commit body that the hardware run is unverified pending H1.

- [ ] **Step 6: Commit**

```bash
git add packages/chameleon_flutter
git commit -m "test(chameleon_flutter): add the transport contract suite

Spec 5.8: one body of nine behaviours every Transport must have, run
against FakeDevice in CI and against a real serial link under --tags
hardware. The hardware run is unverified until the user reports H1."
```

---

### Task 15: The transport example app, the CI matrix and the H1 checklist

Spike A left `packages/chameleon_flutter/example` as `serial_probe`; this turns it into the transport example spec 5.8's hardware run needs, and it is the only way the user can exercise BLE connect, pairing, the handshake and a slot round trip on their own device.

**Files:**
- Modify: `packages/chameleon_flutter/example/pubspec.yaml`, `example/lib/main.dart`, `tool/src/dep_rules.dart`, `.github/workflows/ci.yml`, `docs/hardware-checklist.md`
- Create: `example/lib/scan_page.dart`, `example/lib/session_page.dart`, `example/test/scan_page_test.dart`
- Modify: root `pubspec.yaml` if the workspace member path changes (it does not — only the package name does)

**Interfaces:**
- Consumes: `ChameleonTransports.defaultScanners`, `ChameleonTransports.transportFor`, `SerialControlLineMode`, `TransportGuidance`, `GuidedTransport`, `DiscoveredDevice`, `DeviceSession`, `SessionReady`.
- Produces: `class TransportExampleApp extends StatelessWidget`, `class ScanPage extends StatefulWidget`, `class SessionPage extends StatefulWidget { const SessionPage({required DiscoveredDevice device, required SerialControlLineMode controlLines, super.key}); }`, and `Stream<List<DiscoveredDevice>> mergedScan(List<DeviceScanner> scanners)`.

- [ ] **Step 1: Rename the example and add its dependencies**

In `packages/chameleon_flutter/example/pubspec.yaml` set `name: transport_example`, keep `resolution: workspace`, and set the dependencies to `flutter`, `chameleon`, `chameleon_flutter` (drop the direct `libserialport_plus` dependency — the example now goes through the package):

```yaml
name: transport_example
description: "Exercises the Spectra transports, scanners and a DeviceSession."
publish_to: none
resolution: workspace
version: 1.0.0+1

environment:
  sdk: ^3.13.0

dependencies:
  flutter:
    sdk: flutter
  chameleon: ^0.1.0
  chameleon_flutter: ^0.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
```

In `tool/src/dep_rules.dart`, replace the `serial_probe` allowlist entry with:

```dart
  'transport_example': {'flutter', 'chameleon', 'chameleon_flutter'},
```

The example also needs an Android target for the manifest work to mean anything there:

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd packages/chameleon_flutter/example && flutter create --platforms=android .
```

Then apply the same permission block, USB intent filter and `res/xml/device_filter.xml` from Task 3 to `example/android/app/src/main/AndroidManifest.xml`.

- [ ] **Step 2: Write the failing widget test**

```dart
// example/test/scan_page_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_example/scan_page.dart';

void main() {
  testWidgets('shows the emulated device from the FakeScanner', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ScanPage(scanners: <DeviceScanner>[])),
    );
    // With no scanners the page still builds and says so.
    await tester.pump();
    expect(find.text('No devices found'), findsOneWidget);
  });

  testWidgets('merged results from several scanners appear as rows',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ScanPage(scanners: <DeviceScanner>[FakeScanner()])),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Emulated Chameleon Ultra'), findsOneWidget);
  });

  test('mergedScan unions the scanners and de-duplicates by identity',
      () async {
    final stream = mergedScan(<DeviceScanner>[
      FakeScanner(),
      FakeScanner(devices: const <DiscoveredDevice>[
        FakeScanner.emulatedBootloader,
      ]),
    ]);
    final last = await stream
        .take(2)
        .last
        .timeout(const Duration(seconds: 2));
    expect(last.length, 2);
    expect(last.any((d) => d.isBootloader), isTrue);
  });
}
```

Add `import 'package:flutter/material.dart';` at the top of that test file.

- [ ] **Step 3: Run to verify it fails**

```bash
cd packages/chameleon_flutter/example && flutter test
```

Expected: FAIL — `Target of URI doesn't exist: 'package:transport_example/scan_page.dart'`.

- [ ] **Step 4: Write the example**

```dart
// example/lib/main.dart
// The Spectra transport example.
//
// Lists what every scanner on this platform can see, opens a transport for
// the row you tap, runs a DeviceSession handshake and offers a slot rename
// round trip. This is the app hardware handoff H1 is run from; see
// docs/hardware-checklist.md.

import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter/material.dart';

import 'scan_page.dart';

void main() {
  runApp(const TransportExampleApp());
}

class TransportExampleApp extends StatelessWidget {
  const TransportExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'transport_example',
    home: ScanPage(
      scanners: ChameleonTransports.defaultScanners(emulator: true),
    ),
  );
}
```

```dart
// example/lib/scan_page.dart
import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter/material.dart';

import 'session_page.dart';

/// The union of every scanner's latest result list, de-duplicated by
/// [DiscoveredDevice] identity (transport kind plus transport id) — the
/// merge the connect screen will do properly in Phase 4 (spec 4.2).
Stream<List<DiscoveredDevice>> mergedScan(List<DeviceScanner> scanners) {
  final latest = <int, List<DiscoveredDevice>>{};
  final controller = StreamController<List<DiscoveredDevice>>();
  final subs = <StreamSubscription<List<DiscoveredDevice>>>[];

  controller.onListen = () {
    for (var i = 0; i < scanners.length; i++) {
      final index = i;
      subs.add(
        scanners[i].scan().listen(
          (devices) {
            latest[index] = devices;
            final merged = <DiscoveredDevice, DiscoveredDevice>{};
            for (final list in latest.values) {
              for (final d in list) {
                merged[d] = d;
              }
            }
            if (!controller.isClosed) {
              controller.add(List<DiscoveredDevice>.unmodifiable(merged.values));
            }
          },
          onError: (Object e, StackTrace s) => controller.addError(e, s),
        ),
      );
    }
  };
  controller.onCancel = () async {
    for (final s in subs) {
      await s.cancel();
    }
    await controller.close();
  };
  return controller.stream;
}

class ScanPage extends StatefulWidget {
  const ScanPage({required this.scanners, super.key});

  final List<DeviceScanner> scanners;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  SerialControlLineMode _mode = SerialControlLineMode.dtrOnly;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('transport_example'),
      actions: <Widget>[
        DropdownButton<SerialControlLineMode>(
          value: _mode,
          onChanged: (m) => setState(() => _mode = m ?? _mode),
          items: <DropdownMenuItem<SerialControlLineMode>>[
            for (final m in SerialControlLineMode.values)
              DropdownMenuItem<SerialControlLineMode>(
                value: m,
                child: Text(m.name),
              ),
          ],
        ),
      ],
    ),
    body: StreamBuilder<List<DiscoveredDevice>>(
      stream: mergedScan(widget.scanners),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: SelectableText('Scan failed: ${snapshot.error}'));
        }
        final devices = snapshot.data ?? const <DiscoveredDevice>[];
        if (devices.isEmpty) {
          return const Center(child: Text('No devices found'));
        }
        return ListView(
          children: <Widget>[
            for (final device in devices)
              ListTile(
                title: Text(device.name),
                subtitle: Text('${device.kind.name} · ${device.transportId}'),
                trailing: device.isBootloader
                    ? const Chip(label: Text('bootloader'))
                    : null,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        SessionPage(device: device, controlLines: _mode),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
```

```dart
// example/lib/session_page.dart
import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter/material.dart';

/// Opens a transport, runs the handshake and shows what came back, plus a
/// slot rename round trip. Hardware handoff H1 is observed here.
class SessionPage extends StatefulWidget {
  const SessionPage({
    required this.device,
    required this.controlLines,
    super.key,
  });

  final DiscoveredDevice device;
  final SerialControlLineMode controlLines;

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  final List<String> _log = <String>[];
  DeviceSession? _session;

  @override
  void initState() {
    super.initState();
    unawaited(_connect());
  }

  void _say(String line) {
    // ignore: avoid_print
    print('[transport_example] $line');
    if (mounted) setState(() => _log.add(line));
  }

  Future<void> _connect() async {
    Transport? transport;
    try {
      transport = ChameleonTransports.transportFor(
        widget.device,
        controlLines: widget.controlLines,
      );
      _say('transport: ${transport.runtimeType} (${widget.controlLines.name})');
      final session = DeviceSession(transport);
      _session = session;
      await session.open();
      _say('connection state: ${session.connectionState.value}');
      final info = session.deviceInfo.value;
      _say('device: ${info?.model} firmware ${info?.firmwareVersion}');
      _say('chip id: ${info?.chipId}');
    } on ChameleonException catch (e) {
      final guidance =
          transport is GuidedTransport ? transport.guidance?.name : null;
      _say('failed: $e${guidance == null ? '' : ' (guidance: $guidance)'}');
    }
  }

  /// H1's slot round trip: rename slot 1, read it back.
  Future<void> _renameSlot() async {
    final session = _session;
    if (session == null) return;
    final nick = 'H1 ${DateTime.now().toIso8601String()}';
    try {
      await session.slots.setNickname(slot: 0, nickname: nick);
      final slots = session.slotsState.value;
      _say('slot 1 nickname now: ${slots.isEmpty ? '?' : slots.first.nickname}');
      _say(slots.isNotEmpty && slots.first.nickname == nick
          ? 'slot round trip OK'
          : 'slot round trip MISMATCH');
    } on ChameleonException catch (e) {
      _say('slot round trip failed: $e');
    }
  }

  @override
  void dispose() {
    unawaited(_session?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.device.name)),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _renameSlot,
      label: const Text('Rename slot 1'),
      icon: const Icon(Icons.edit),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        for (final line in _log)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SelectableText(line),
          ),
      ],
    ),
  );
}
```

Add `import 'dart:async';` to `session_page.dart` for `unawaited`. **The facade call `session.slots.setNickname(slot:, nickname:)` and the `DeviceInfo` field names (`model`, `firmwareVersion`, `chipId`) come from Phase 1** — open `packages/chameleon/lib/src/session/facades/slots.dart` and `lib/src/model/models.dart` and use the landed names; adjust the example rather than the SDK.

- [ ] **Step 5: Run the example's tests and build it**

```bash
cd packages/chameleon_flutter/example && flutter test && flutter build macos --debug
```

Expected: PASS, 3 tests; `✓ Built build/macos/Build/Products/Debug/transport_example.app`.

- [ ] **Step 6: Add the example to the CI build matrix**

The roadmap deferred this from Phase 0. In `.github/workflows/ci.yml`, add two entries to the `build` job matrix. They need a `working-directory` different from the existing `app`, so add a `dir` key with a default of `app`:

```yaml
          - os: ubuntu-latest
            target: linux
            cmd: flutter build linux --debug
            dir: app
```

…giving every existing entry `dir: app`, then appending:

```yaml
          - os: windows-latest
            target: example-windows
            cmd: flutter build windows --debug
            dir: packages/chameleon_flutter/example
          - os: ubuntu-latest
            target: example-linux
            cmd: flutter build linux --debug
            dir: packages/chameleon_flutter/example
```

and changing the final step to `working-directory: ${{ matrix.dir }}`. Guard the Linux apt step with `if: startsWith(matrix.target, 'linux') || startsWith(matrix.target, 'example-linux')` — or simply `if: runner.os == 'Linux'`, which is clearer.

- [ ] **Step 7: Fill in the H1 checklist**

Replace the H1 section of `docs/hardware-checklist.md` with the following. Every box stays `- [ ] pending` — this section is a request to the user, not a record of anything the executor ran.

````markdown
## H1 (after Phase 3): USB serial, BLE, handshake, slot round trip

Run these on the Mac with the Chameleon Ultra to hand. Report back what you
see; the agent records the results here. Nothing below may be ticked from
inference or from a green CI run.

Set up the shell once:

```bash
cd /path/to/spectra
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
```

**Serial**

- [ ] pending: **enumeration.** Plug the device in over USB, then
      `cd packages/chameleon_flutter/example && flutter run -d macos`.
      Expect a row reading roughly
      `ChameleonUltra: hw_v1, fw_vN · usb · /dev/cu.usbmodemXXXX`.
      Report the exact row, and confirm the log line shows vid=0x6868
      pid=0x8686 mfr=Proxgrind.
- [ ] pending: **control lines.** With the app running, set the dropdown in
      the app bar to `dtrOnly`, tap the device row, and report whether the
      page reaches `connection state: SessionReady`. Then go back, set the
      dropdown to `hardwareFlowControl` and tap the row again. **Report
      which of the two modes works** (both may). This decides the default
      in `SerialControlLineMode`.
- [ ] pending: **handshake.** On whichever mode worked, report the
      `device:` and `chip id:` lines the page prints.
- [ ] pending: **slot round trip.** On the session page, tap
      "Rename slot 1" and report whether the last line reads
      `slot round trip OK` or `slot round trip MISMATCH`.
- [ ] pending: **the contract suite on hardware.** With the device attached:
      `cd packages/chameleon_flutter && flutter test --tags hardware`.
      Report the summary line. To test the other control-line mode:
      `flutter test --tags hardware --dart-define=SPECTRA_SERIAL_CONTROL_LINES=hardwareFlowControl`.
- [ ] pending: **the serial entitlement.** Spike A found enumeration works
      without `com.apple.security.device.serial`, but opening a port is
      expected to need it. Remove that key from
      `packages/chameleon_flutter/example/macos/Runner/DebugProfile.entitlements`,
      re-run `flutter run -d macos`, tap the device and report whether the
      open fails (and with what message). **Put the key back afterwards.**

**BLE**

- [ ] pending: **scan.** Unplug USB, press a button on the device to wake it
      (it sleeps eight seconds after losing a connection), then
      `flutter run -d macos` in the example. Report whether a row appears
      with kind `ble`.
- [ ] pending: **connect and pairing.** Tap the BLE row. Report whether
      macOS shows a pairing prompt, whether accepting it leads to
      `connection state: SessionReady`, and — if it fails — the `failed:`
      line including the `(guidance: ...)` value.
- [ ] pending: **handshake over BLE.** Report the `device:` and `chip id:`
      lines, and whether they match the USB run.
````

Leave the H2 and H3 sections untouched.

- [ ] **Step 8: Run the full check and commit**

```bash
cd /path/to/worktree && dart run melos run check:all
```

Expected: every step green, including `lint:deps` with the renamed `transport_example` allowlist.

```bash
git add packages/chameleon_flutter tool/src/dep_rules.dart .github/workflows/ci.yml docs/hardware-checklist.md
git commit -m "feat(chameleon_flutter): turn the spike probe into the transport example

Spike A's serial_probe becomes transport_example: it merges every
scanner's results, opens a transport for the row you tap and runs a
DeviceSession handshake with a slot round trip. It is how the user runs
hardware handoff H1, which is now written out with exact commands. CI
builds it on Windows and Linux, closing the Phase 0 deferral."
```

---

### Task 16: Close-out

**Files:**
- Modify: `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md`, `AGENTS.md`, `tasks/lessons.md`, `docs/research/DECISIONS.md`
- Test: the full check suite

- [ ] **Step 1: Run the whole check suite from the worktree root**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart run melos run check:all
```

Expected: `format`, `analyze`, `lint:deps`, `test:root`, `check:codegen`, `test:dart` and `test:flutter` all green. Paste the summary counts into the commit body. If anything fails, fix it here — the phase gate is this command.

- [ ] **Step 2: Confirm the phase gate**

The roadmap's Phase 3 gate is "contract suite green against FakeDevice; H1 section written to docs/hardware-checklist.md". Verify both, explicitly:

```bash
cd packages/chameleon_flutter && flutter test test/contract/fake_device_contract_test.dart
grep -c "pending" ../../docs/hardware-checklist.md
```

Expected: the contract file passes, and the H1 section has nine `pending` items. **The gate does not include any hardware result** — H1 stays open until the user reports.

- [ ] **Step 3: Tick the roadmap**

In `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md`, change `- [ ] Phase 3` to `- [x] Phase 3`, and in the phase table change the Phase 3 `Plan` cell to `` `2026-09-03-phase-3-transports.md` (written) ``.

- [ ] **Step 4: Update AGENTS.md**

Replace the "Current status" section's date and body so a fresh session knows where things stand: Phase 3 complete, `packages/chameleon_flutter` has BLE and serial transports, both scanners, both DFU channels and the contract suite; hardware handoff H1 is written and **pending the user's report**; the control-line default is `dtrOnly` and may change when H1 comes back; BLE DFU stays behind `dfuOverBleEnabled` until H2. Add the Phase 3 plan to the plans list and note that Phase 4 is written next from spec 7.1-7.5, 8.3, 8.4 and 9.

- [ ] **Step 5: Record the decisions**

Append to `docs/research/DECISIONS.md`:

```markdown
- **`TransportState` gained `TransportPermissionDenied` and
  `TransportAdapterOff`.** Spec 5.1 requires the BLE transport to report
  both, and the app routes on `TransportState`, so they belong in the SDK's
  sealed family rather than in a side channel. Additive: nothing switches
  exhaustively on `TransportState`.
- **Every native package sits behind an adapter interface.** `BleAdapter`,
  `SerialPortAdapter` and `SerialPortHandle` are declared in
  `chameleon_flutter`; `universal_ble`, `libserialport_plus` and
  `usb_serial` are each imported by exactly one file. This is what makes
  chunking, retry, backoff, state mapping, error mapping and pairing
  detection unit-testable with no device and no plugin channel. The cost is
  one thin wrapper class per package; the alternative was leaving the whole
  of spec 5.1 and 5.2 untested until hardware existed.
- **Native error codes collapse at the adapter boundary.**
  `universal_ble`'s 61 `UniversalBleErrorCode` values map to eight
  `BleFailure` values, and `SerialPortException`'s platform-dependent
  numeric codes to five `SerialFailure` values (with the message text as a
  fallback, because libserialport sometimes reports a generic code with a
  specific string). Transports map those to the SDK's `TransportError`
  types plus a `TransportGuidance` value.
- **User-facing guidance is a typed enum, not text.** `TransportGuidance`
  says *which* instruction to show (Linux dialout group, ModemManager,
  Windows pairing, macOS serial entitlement, ...); the wording lives in the
  app's ARB files per spec 7.6, so `chameleon_flutter` ships no strings.
- **The serial control-line default is `SerialControlLineMode.dtrOnly`,
  provisionally.** `docs/research/chameleon-protocol.md` says "Assert DTR
  after open. No flow control.", which the reference-app notes contradict.
  The mode is a constructor parameter and both are exercised; H1 asks the
  user which works, and the default changes if the answer says so. Until
  then this is `hardware-validate`, not settled.
- **Package versions pinned in Phase 3:** `universal_ble` 2.2.0,
  `usb_serial` 0.5.2, `libserialport_plus` 1.0.4 (unchanged from Spike A).
```

- [ ] **Step 6: Record the lessons**

Append to `tasks/lessons.md` whatever actually bit during the phase. At minimum, if they held true:

```markdown
- **Never assume a BLE MTU.** The Chameleon firmware requests 247 but the
  platform decides. Ask with `requestMtu`, use `mtu - 3` for the ATT
  overhead, and fall back to 20 when the platform will not answer.
- **A plugin package cannot own the app's platform files.** Spec 5.7 assigns
  the manifest, plist and entitlements to `chameleon_flutter`, but they can
  only live in `app/` and in the example. A workspace-root test that reads
  the files is the enforcement.
- **`universal_ble` and `usb_serial` cannot be unit-tested directly.** Both
  go through a plugin channel that throws `MissingPluginException` under
  `flutter test`. Wrap them in an interface this repo owns; the wrapper is
  the untestable part, and it is a dozen lines with no logic.
```

- [ ] **Step 7: Commit and push**

```bash
git add AGENTS.md tasks/lessons.md docs/research/DECISIONS.md docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md
git commit -m "docs: close out Phase 3

Phase 3 is complete against its gate: the contract suite is green against
FakeDevice and the H1 section is written. Every H1 item is still pending
the user's hardware report, and the serial control-line default stays
provisional until it arrives."
git push
```

- [ ] **Step 8: Watch CI**

```bash
gh run list --limit 3
gh run watch <run-id>
```

Expected: the `check` job and all seven `build` matrix entries green, including the two new example builds. Fix any failure here rather than reporting the phase done.

---

## Self-review

**Spec coverage.** 5.1 BLE transport: Task 5 (universal_ble via Task 4's adapter, NUS scan filter in Task 6, five retries with backoff, notify subscribe, write-with-response chunked at the reported max length, `permissionDenied`/`adapterOff` states via Task 1, pairing detected from insufficient authentication, Windows/Linux/Apple pairing guidance). Device sleep is documented in the H1 checklist rather than coded — it is device behaviour, not transport behaviour. 5.2 serial: Tasks 7-9 (libserialport_plus desktop, usb_serial Android, one `SerialTransport` behind one `SerialPortAdapter`, 115200 8N1, control-line mode as a constructor parameter tagged `hardware-validate`, permission/busy mapping with per-platform guidance, `SerialTransport.fromPath` for manual entry). 5.3 DFU channels: Tasks 11 and 12. 5.4 platform matrix: Tasks 8 and 13. 5.5 bootloader discovery: Tasks 6 and 10. 5.6 recovery guarantee: honoured by the `hardware-validate` markers and the H2 note on `BleDfuChannel`; the flag itself is Phase 8's, per the roadmap. 5.7 platform setup: Task 3. 5.8 testing: Task 14 plus the per-class unit tests. 4.1: Task 1 and every transport. 4.2: Tasks 6, 10 and the example's `mergedScan`. 8.2: Task 13.

**Placeholder scan.** No TBD, no "add error handling", no "similar to Task N", no test described without its code. Three places deliberately tell the implementer to read a landed file instead of trusting this plan: the `DfuChannel` signature (Tasks 11, 12), the Phase 1 facade and model names used by the example (Task 15), and the Phase 1 barrel exports (Task 1). Those are instructions with a named file and a named fallback, not placeholders.

**Type consistency.** `BleAdapter`, `BleScanEntry`, `BleAvailability`, `BleFailure`, `BleAdapterException`, `bleFailureFromCode`, `FakeBleAdapter` are declared in Task 4 and used unchanged in 5, 6, 12, 13. `SerialPortAdapter`, `SerialPortHandle`, `SerialPortDescriptor`, `SerialControlLineMode`, `SerialFailure`, `SerialAdapterException`, `serialFailureFrom`, `FakeSerialAdapter`/`FakeSerialHandle` are declared in Task 7 and used unchanged in 8, 9, 10, 13, 15. `HostPlatform`/`currentHostPlatform`, `TransportGuidance`/`GuidedTransport`, `NusUuids`, `NordicDfuUuids`, `ChameleonBleNames`, `normalizeUuid`, `ChameleonUsbIds` are declared in Task 2 and used unchanged throughout. `TransportPermissionDenied`/`TransportAdapterOff` are declared in Task 1 and used in Tasks 5 and 9. `maxDataWrite`/`writeControl`/`writeData`/`responses`/`close` match across Tasks 11 and 12.
