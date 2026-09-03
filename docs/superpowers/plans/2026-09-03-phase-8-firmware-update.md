# Phase 8: Firmware Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the firmware update feature — pick an nrfutil DFU package, flash a connected device or one already sitting in its bootloader, watch the progress, come back to a working app — with USB DFU on by default and BLE/iOS DFU built in full behind `dfuOverBleEnabled` (default off) until hardware handoff H2 passes.

**Architecture:** The whole DFU protocol already exists in `packages/chameleon` (`DfuPackage`, `SecureDfu`, `DfuOrchestrator`) and both channels exist in `packages/chameleon_flutter` (`SlipSerialDfuChannel`, `BleDfuChannel`). Phase 8 closes the two SDK gaps Phase 3 parked (a pre-stream throw escaping `DfuOrchestrator.run()` as a raw stream error; no `GetSerialMTU` query, so serial writes stay at 64 bytes), then builds the app layer on top: a firmware package source, a `core/dfu/` runtime that decides which channel and which scanners a run uses, an `UpdateController` async notifier that drives `DfuOrchestrator` and reports phases/progress/cancellation, the navigation lock and wakelock spec 7.4 asks for, and the update screen itself — both entry points (a connected device, and the `?recover=` bootloader entry the connect screen links to).

**Tech Stack:** Dart 3.13 / Flutter 3.47.2 via mise; `chameleon` (pure Dart, `archive` + `crypto`); `chameleon_flutter` (universal_ble, libserialport_plus, usb_serial); `app` (riverpod 3.4.2 + riverpod_generator, go_router 18, drift, wakelock_plus, material_ui 1.1.1, spectra_ui); tests: `dart test`, `flutter test`, `integration_test`.

**Spec:** `docs/superpowers/specs/2026-09-02-spectra-design.md` (sections 4.5, 5.3, 5.5, 5.6, 7.2, 7.4, 7.7 step 6, 9, 10). Roadmap row: `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md`, Phase 8. Wire facts: `docs/research/chameleon-protocol.md` ("DFU").

## Global Constraints

- Toolchain pinned in `mise.toml`: Flutter 3.47.2 (bundles Dart 3.13). On this Mac, run
  `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"` in the *same* shell
  command before any `dart`, `flutter` or `melos` invocation (AGENTS.md).
- `dart run melos run check:all` must be green at every commit (format, analyze `--fatal-infos`,
  `lint:deps`, `test:root`, `check:codegen`, `test:dart`, `test:flutter`).
- TDD for every task: failing test, minimal code, passing test, commit. Commit messages:
  imperative subject, short body explaining why, trailer
  `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Generated code (freezed, riverpod_generator, drift) is committed; after touching any
  `@riverpod`-annotated file run
  `cd app && dart run build_runner build --delete-conflicting-outputs` and commit the `.g.dart`.
- Package boundaries (spec 2, enforced by `tool/dep_lint.dart`): `chameleon` never imports
  Flutter; `chameleon_flutter` never imports `spectra_ui` or `app`; `app/lib/features/*` never
  import another feature's internals (only `features/<other>/<other>.dart`) and never
  `package:flutter/material.dart`; Drift only under `app/lib/data/`.
- All user-facing strings go through `app/lib/l10n/app_en.arb` (spec 7.6); the string lint scans
  `lib/features/*/ui/` only.
- This is a git worktree. Never use bare `git stash`.
- Never claim hardware behaviour works without the user running `docs/hardware-checklist.md`.
  Anything spec-tagged `hardware-validate` stays "pending hardware" in code comments and in the
  checklist.
- Spec 5.6 is honoured by the flag, not by waiting: USB DFU on desktop ships enabled; BLE DFU and
  iOS DFU are built in full but sit behind `FeatureFlags.dfuOverBleEnabled`, which defaults off
  and stays off this phase. The update screen shows the pending-hardware notice while it is off.
- At the end of the phase: update `AGENTS.md` "Current status", add lessons to
  `tasks/lessons.md`, tick Phase 8 in the roadmap.

### Standing rulings (repeat in every task brief)

- **Phase 7 must be fully landed before any Phase 8 task starts.** Re-read every shared file at
  task start; never paste a whole file over the top.
- The ARB is single-writer **across phases**. Phase 8 has exactly one ARB task (Task 9); no other
  task edits `app/lib/l10n/app_en.arb`, and Task 9 commits the regenerated
  `app_localizations*.dart` from `cd app && flutter gen-l10n`.
- A new `DeviceSession` per connect attempt; sessions are single-use. Tests pass
  `transport: (_) => FakeDevice()` — a fresh fake per attempt.
- **Ruling 20 (Phase 4):** an autoDispose stream/async provider read outside a mounted app needs
  `keepAlive(tester, provider)` held first, then a pump, then the read.
- **Ruling 22 (Phase 5):** `FakeDevice` replies on a real `Timer` — start the operation, pump,
  then await. Never await before pumping.
- **R25:** guard every post-`await` `state =` with `ref.mounted`.
- **R27:** one shared `core/errors/problem_view.dart`; no per-feature or per-sheet copy.
- **R28:** `core/format/tag_labels.dart` names tag types and senses (`tagTypeLabel`/`senseLabel`,
  never `TagType.name`); the slots barrel exports `showSlotPicker`, `SlotView`,
  `slotViewsProvider`, `slotNicknameMaxBytes` and nothing else.
- Drop, do not queue: a plain `bool _inFlight` distinct from the state's own busy flag, and the
  screen disables its controls while busy. A notifier a test must force into failure ships
  `@visibleForTesting void debugFail(Object error)`.
- `material_ui` only under `features/`, never `package:flutter/material.dart`; `hide
  ConnectionState` on any features file that also imports `package:chameleon/chameleon.dart` —
  and **no unused import anywhere**, `analyze` fails on warnings.
- Finders inside an open sheet are `find.descendant`-scoped to `find.byType(SpectraBottomSheet)`,
  including icon finders; no `.first`/`.at(n)` arithmetic over widgets a screen may grow more of.
- The harness (`app/test/support/app_harness.dart`) is edited by **nobody** this phase; use its
  `pumpFrames(tester, count:)`, `useDesktopSurface`, `keepAlive`, `readProvider`,
  `testWidgetsApp`, `connectToEmulator`, `openUpdate`, `pumpTestApp`,
  `pumpTestAppWithBootloader`, `StaticScanner`. Integration tests go through
  `app/integration_test/support.dart`; never a fourth override block.
- App code never builds a `Command`; nothing outside `chameleon` imports `package:chameleon/src/…`.
- Every byte layout cites its source: `docs/research/chameleon-protocol.md`, the SDK file it
  came from, or the named nrfutil / nRF5 SDK function. No invented wire formats.
- Foreground test runs only.
- **Cite landed source for every name.** If a symbol is not in the Interfaces block or in a file
  this plan quotes, go read it before using it.

### Resolved spec ambiguity (do not re-open)

Spec 7.7 step 6 lists "release feed check, download or local zip". Phase 8 ships **local zip
only**: the user pastes or types the path of an nrfutil `.zip` (`ultra-dfu-app.zip`,
`lite-dfu-app.zip`, `*-dfu-full.zip` — `docs/research/chameleon-protocol.md`, "DFU"), and the
screen names the official releases URL so they know where to get one. No network client is
added. Reasons, recorded in `docs/research/DECISIONS.md` by Task 14:

1. The app has no HTTP dependency and no network/telemetry policy yet; spec 2's dependency table
   does not list one, and adding one is a release-phase decision (signing, update channels).
2. Spec 5.6's recovery guarantee is about completing an update from a desktop over USB with a
   package in hand — a feed cannot be a prerequisite for it.
3. H2 is run against a real release zip the user downloads by hand anyway.

The release feed and in-app download move to Phase 10 (release) alongside signing and channels.

---

## File Structure

**`packages/chameleon` (SDK, pure Dart)**

- `lib/src/dfu/dfu_orchestrator.dart` — modify: pre-stream failures in `_transfer` report as
  `DfuFailed` (Task 1).
- `lib/src/dfu/dfu_opcodes.dart` — modify: `DfuOp.getSerialMtu` (Task 2).
- `lib/src/dfu/serial_mtu.dart` — new: `DfuSerialMtu` request/parse/chunk arithmetic (Task 2).
- `lib/src/dfu/fake_bootloader.dart` — modify: answers `GetSerialMTU` (Task 2).
- `lib/chameleon.dart` — modify: export `serial_mtu.dart` (Task 2).

**`packages/chameleon_flutter`**

- `lib/src/dfu/slip_serial_dfu_channel.dart` — modify: `open()` negotiates the MTU (Task 3).
- `test/dfu/dfu_channel_flash_test.dart` — new: both channel types flash a `FakeBootloader`
  end to end (Task 4; the roadmap gate's "both channel types" half).

**`app` — core**

- `lib/core/dfu/dfu_runtime.dart` — new: `dfuActivityProvider`, `dfuChannelOpenerProvider`,
  `dfuScanners`, `emulatorBootloaderProvider`, `dfuScanTimeoutProvider` (Task 6).
- `lib/core/routing/redirect.dart`, `lib/core/routing/router.dart` — modify: navigation lock
  while a flash runs (Task 8).
- `lib/core/lifecycle/wakelock.dart` — modify: hold the wakelock for a recovery flash that has no
  session (Task 8).

**`app` — feature (`features/tools`)**

- `lib/features/tools/state/firmware_package_source.dart` — new (Task 5).
- `lib/features/tools/state/update_controller.dart` — new (Task 7).
- `lib/features/tools/state/update_steps.dart` — new: phase → step index and labels (Task 9).
- `lib/features/tools/ui/update_page.dart` — rewritten across Tasks 10, 11, 12.
- `lib/features/tools/tools.dart` — unchanged (already exports `ui/update_page.dart`).

**`app` — tests**

- `test/fixtures/dfu_package_fixture.dart` — new: builds nrfutil-shaped zips (Task 5).
- `test/features/tools/firmware_package_source_test.dart` (Task 5),
  `test/core/dfu/dfu_runtime_test.dart` (Task 6),
  `test/features/tools/update_controller_test.dart` (Task 7),
  `test/core/routing/update_lock_test.dart` (Task 8),
  `test/features/tools/update_page_test.dart` (Tasks 10, 11),
  `test/features/tools/update_recovery_test.dart` (Task 12),
  `test/flows/firmware_update_flow_test.dart` + `integration_test/firmware_update_flow_test.dart`
  (Task 13).

**Docs (Task 14):** `docs/hardware-checklist.md`, `docs/research/DECISIONS.md`, `AGENTS.md`,
`tasks/lessons.md`, the roadmap.

---

## Task 1: `DfuOrchestrator.run()` never leaks a raw stream error

Phase 3 ledger, "Phase 8 note": *a throw inside `DfuOrchestrator._transfer`'s pre-stream section
(incl. the new `channel.open()`) escapes `run()` as a raw stream error, not `DfuFailed` — wrap it
so it reports through `onFailure`.* `yield*` forwards an inner stream's errors straight to the
consumer, so `run()`'s own `try/catch` never sees them, and the app — which routes on the event,
not on an escaped throw — would show nothing at all.

**Files:**
- Modify: `packages/chameleon/lib/src/dfu/dfu_orchestrator.dart` (the `_transfer` method)
- Test: `packages/chameleon/test/dfu/dfu_orchestrator_test.dart`

**Interfaces:**
- Consumes: `DfuOrchestrator({required List<DeviceScanner> scanners, required DfuChannelOpener
  openChannel, Duration scanTimeout})`; `Stream<DfuEvent> run({required DfuPackage package,
  DeviceSession? session, DiscoveredDevice? bootloader, CancelToken? cancel})`; `DfuFailed(
  ChameleonException error)`; `PortBusy([String message])`; `DfuError(String message,
  {int? opcode, int? result})`; test helpers `buildInitPacket({required Uint8List bin, int
  hwVersion, int fwVersion, int type, bool reverseHash})` and `buildZip({required Uint8List bin,
  required Uint8List dat, String binName, String datName, String key, bool includeBin})` from
  `packages/chameleon/test/dfu/proto_builder.dart`.
- Produces: no API change. Every path out of `run()` still ends in exactly one `DfuCompleted` or
  `DfuFailed`; Task 7 relies on that.

- [ ] **Step 1: Write the failing tests**

Append to `packages/chameleon/test/dfu/dfu_orchestrator_test.dart` (inside the existing
`main()`; reuse whatever package helper the file already has — if it builds its package inline,
copy that shape):

```dart
  group('a failure before the transfer starts', () {
    DfuPackage packageOf() {
      final bin = Uint8List.fromList(List<int>.generate(64, (i) => i));
      return DfuPackage.fromZip(
        buildZip(bin: bin, dat: buildInitPacket(bin: bin)),
      );
    }

    const bootloader = DiscoveredDevice(
      name: 'CU',
      kind: TransportKind.usb,
      transportId: '/dev/tty.bootloader',
      isBootloader: true,
    );

    test('an opener that throws reports DfuFailed, not a stream error', () async {
      final orchestrator = DfuOrchestrator(
        scanners: const <DeviceScanner>[],
        openChannel: (_) async => throw const PortBusy('held by ModemManager'),
      );
      final events = await orchestrator
          .run(package: packageOf(), bootloader: bootloader)
          .toList();
      expect(events.last, isA<DfuFailed>());
      expect((events.last as DfuFailed).error, isA<PortBusy>());
    });

    test('a channel whose open() throws reports DfuFailed', () async {
      final orchestrator = DfuOrchestrator(
        scanners: const <DeviceScanner>[],
        openChannel: (_) async => _UnopenableChannel(),
      );
      final events = await orchestrator
          .run(package: packageOf(), bootloader: bootloader)
          .toList();
      expect(events.last, isA<DfuFailed>());
      expect((events.last as DfuFailed).error, isA<DfuError>());
    });
  });
```

and, at the bottom of the same file:

```dart
/// A channel that opens onto nothing: `open()` is where every real channel
/// does its connect, and a failure there used to escape `run()`.
final class _UnopenableChannel implements DfuChannel {
  @override
  int get maxDataWrite => 20;
  @override
  Future<void> open() async => throw StateError('the bootloader went away');
  @override
  Future<void> writeControl(Uint8List bytes) async {}
  @override
  Future<void> writeData(Uint8List bytes) async {}
  @override
  Stream<Uint8List> get responses => const Stream<Uint8List>.empty();
  @override
  Future<void> close() async {}
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"; cd packages/chameleon && dart test test/dfu/dfu_orchestrator_test.dart -n 'before the transfer starts'`
Expected: FAIL — the errors surface as thrown exceptions out of `toList()` (`PortBusy` /
`StateError`) instead of a `DfuFailed` event.

- [ ] **Step 3: Wrap the pre-stream section**

In `dfu_orchestrator.dart`, `_transfer`, add a catch beside the existing `finally` (nothing else
in the method changes):

```dart
    DfuChannel? channel;
    try {
      channel = await open();
      await channel.open();
      final events = StreamController<DfuEvent>();
      final dfu = SecureDfu(channel);
      final done = Future(() async {
        for (final image in package.images) {
          await dfu.run(
            image,
            cancel: cancel,
            onProgress: (p) => events.add(DfuProgressed(p)),
          );
        }
      }).then<void>((_) {}, onError: onFailure).whenComplete(events.close);
      yield* events.stream;
      await done;
    } on Object catch (e, s) {
      // Everything before `yield*` throws into this generator, and `yield*`
      // hands a generator's error straight to the consumer — past `run()`'s
      // own try/catch. Reporting it through [onFailure] is what keeps the
      // promise that a run always ends in exactly one DfuFailed. Nothing
      // after `yield*` can get here: the transfer's own failure is already
      // routed to [onFailure] by `then(onError:)`, so `await done` never
      // throws, and a double report is impossible.
      onFailure(e, s);
    } finally {
      await channel?.close();
    }
```

Update the method's doc comment: the open is inside the same try *and* its failure is reported
through `onFailure` rather than thrown out of the stream.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"; cd packages/chameleon && dart test test/dfu`
Expected: PASS, whole DFU suite included (no existing test relied on the throw escaping).

- [ ] **Step 5: Commit**

```bash
git add packages/chameleon/lib/src/dfu/dfu_orchestrator.dart packages/chameleon/test/dfu/dfu_orchestrator_test.dart
git commit -m "fix: report a pre-transfer DFU failure as DfuFailed

A throw in _transfer's pre-stream section (the opener, channel.open())
reached the consumer as a raw stream error, past run()'s try/catch, so
the app would see no event at all. Parked in Phase 3; the app layer
lands on it now."
```

---

## Task 2: `GetSerialMTU` in the SDK

Phase 3 parked the serial chunk size at a conservative 64 bytes because `SecureDfu` had no way to
ask. nrfutil's `DfuTransportSerial.open` (`nordicsemi/dfu/dfu_transport_serial.py`) sends opcode
`0x07`, reads a little-endian `uint16` MTU out of the response payload, and uses
`(mtu - 1) // 2 - 1` as the data chunk — the halving is what makes a worst-case all-escapes SLIP
payload still fit the bootloader's buffer. The Chameleon's USB CDC bootloader reports
`SLIP_MTU = 2 * (1024 + 1) + 1 = 2051`, i.e. 1024-byte writes
(`packages/chameleon_flutter/lib/src/dfu/slip_serial_dfu_channel.dart` doc comment;
`docs/hardware-checklist.md` H2).

**Files:**
- Create: `packages/chameleon/lib/src/dfu/serial_mtu.dart`
- Modify: `packages/chameleon/lib/src/dfu/dfu_opcodes.dart`,
  `packages/chameleon/lib/src/dfu/fake_bootloader.dart`, `packages/chameleon/lib/chameleon.dart`
- Test: `packages/chameleon/test/dfu/serial_mtu_test.dart`

**Interfaces:**
- Consumes: `DfuOp.{response, resultSuccess, resultOpcodeNotSupported}` and `FakeBootloader`'s
  existing `handleControl(Uint8List req)` shape (`ok([payload])` / `fail(result)` locals, the
  `sizes` map of minimum request lengths).
- Produces:
  - `const int DfuOp.getSerialMtu = 0x07;`
  - `abstract final class DfuSerialMtu` with
    `static Uint8List request()`,
    `static int? parse(Uint8List response)` (null when the response is not a successful `0x07`
    reply), and
    `static int chunkSize(int mtu)`.
  - `FakeBootloader` gains `int serialMtu` (default 2051) and `bool supportsSerialMtu`
    (default true) — Task 3 and Task 4 script both.

- [ ] **Step 1: Write the failing test**

Create `packages/chameleon/test/dfu/serial_mtu_test.dart`:

```dart
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:test/test.dart';

void main() {
  test('the request is the bare opcode', () {
    expect(DfuSerialMtu.request(), <int>[0x07]);
  });

  test('parses a little-endian uint16 out of a success response', () {
    // [0x60 response, 0x07 opcode, 0x01 success, mtu lo, mtu hi] — nrfutil's
    // DfuTransportSerial.__get_mtu reads the payload after the three-byte
    // header as '<H'. 2051 = 0x0803.
    final r = Uint8List.fromList(<int>[0x60, 0x07, 0x01, 0x03, 0x08]);
    expect(DfuSerialMtu.parse(r), 2051);
  });

  test('returns null for an unsupported or mismatched response', () {
    expect(
      DfuSerialMtu.parse(Uint8List.fromList(<int>[0x60, 0x07, 0x02])),
      isNull,
    );
    expect(
      DfuSerialMtu.parse(Uint8List.fromList(<int>[0x60, 0x06, 0x01, 3, 8])),
      isNull,
    );
    expect(DfuSerialMtu.parse(Uint8List.fromList(<int>[0x60])), isNull);
  });

  test('chunk size follows nrfutil: (mtu - 1) // 2 - 1', () {
    expect(DfuSerialMtu.chunkSize(2051), 1024);
    expect(DfuSerialMtu.chunkSize(131), 64);
  });

  test('the fake bootloader answers GetSerialMTU', () {
    final b = FakeBootloader()..serialMtu = 2051;
    final r = b.handleControl(DfuSerialMtu.request());
    expect(DfuSerialMtu.parse(r), 2051);
  });

  test('a bootloader without the opcode answers not-supported', () {
    final b = FakeBootloader()..supportsSerialMtu = false;
    final r = b.handleControl(DfuSerialMtu.request());
    expect(r[2], 0x02); // NRF_DFU_RES_CODE_OP_CODE_NOT_SUPPORTED
    expect(DfuSerialMtu.parse(r), isNull);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"; cd packages/chameleon && dart test test/dfu/serial_mtu_test.dart`
Expected: FAIL — `DfuSerialMtu` is undefined.

- [ ] **Step 3: Implement**

`dfu_opcodes.dart`, beside the other opcodes:

```dart
  /// Serial transport only: ask the bootloader for its SLIP MTU. nrfutil's
  /// `DfuTransportSerial.__get_mtu` sends this and reads a little-endian
  /// uint16 back; the BLE bootloader answers "opcode not supported".
  static const int getSerialMtu = 0x07;
```

Create `packages/chameleon/lib/src/dfu/serial_mtu.dart`:

```dart
import 'dart:typed_data';

import 'dfu_opcodes.dart';

/// The `GetSerialMTU` exchange, used by the serial DFU channel to size its
/// data writes (spec 4.5, 5.3).
///
/// Layout and arithmetic are nrfutil's
/// (`nordicsemi/dfu/dfu_transport_serial.py`): `DfuTransportSerial.open`
/// sends the bare opcode, `__get_mtu` reads a little-endian uint16 from the
/// response payload, and the data chunk is `(mtu - 1) // 2 - 1` — halved
/// because SLIP escaping can double a payload, so a worst-case frame still
/// fits the bootloader's buffer.
///
/// Kept here rather than in `chameleon_flutter`: `SecureDfu` is the only DFU
/// protocol implementation (spec 4.5), so the wire knowledge stays in the
/// SDK and the channel only performs the exchange.
abstract final class DfuSerialMtu {
  /// The control request: the opcode with no parameters.
  static Uint8List request() =>
      Uint8List.fromList(<int>[DfuOp.getSerialMtu]);

  /// The MTU in [response], or null when it is not a successful reply to
  /// [request] — a bootloader that does not implement the opcode answers
  /// `NRF_DFU_RES_CODE_OP_CODE_NOT_SUPPORTED`, which is a normal outcome,
  /// not an error.
  static int? parse(Uint8List response) {
    if (response.length < 5) return null;
    if (response[0] != DfuOp.response) return null;
    if (response[1] != DfuOp.getSerialMtu) return null;
    if (response[2] != DfuOp.resultSuccess) return null;
    return response[3] | (response[4] << 8);
  }

  /// The largest data payload one SLIP frame may carry for [mtu].
  static int chunkSize(int mtu) => (mtu - 1) ~/ 2 - 1;
}
```

`fake_bootloader.dart` — two fields beside `maxObjectSize`:

```dart
  /// What [DfuOp.getSerialMtu] reports. The Chameleon's USB CDC bootloader
  /// sizes its SLIP buffer at `2 * (1024 + 1) + 1`.
  int serialMtu = 2051;

  /// False models a bootloader without the opcode (the BLE one): the request
  /// is answered "opcode not supported".
  bool supportsSerialMtu = true;
```

and a case in `handleControl`'s switch, above `default:`:

```dart
      case DfuOp.getSerialMtu:
        if (!supportsSerialMtu) return fail(DfuOp.resultOpcodeNotSupported);
        return ok([serialMtu & 0xFF, (serialMtu >> 8) & 0xFF]);
```

(The `sizes` map needs no entry: the request is one byte, which is the map's own default.)

`lib/chameleon.dart`, in the DFU export block, keeping the block alphabetical:

```dart
export 'src/dfu/secure_dfu.dart' show SecureDfu;
export 'src/dfu/serial_mtu.dart';
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"; cd packages/chameleon && dart test`
Expected: PASS (whole package — `FakeBootloader` is used across the DFU suite).

- [ ] **Step 5: Commit**

```bash
git add packages/chameleon/lib packages/chameleon/test/dfu/serial_mtu_test.dart
git commit -m "feat: add the GetSerialMTU exchange to the SDK

Serial DFU has been chunking at a hard-coded 64 bytes because nothing
could ask the bootloader. The opcode, the little-endian parse and
nrfutil's chunk arithmetic live in the SDK so the channel only performs
the exchange."
```

---

## Task 3: `SlipSerialDfuChannel` negotiates its write size

**Files:**
- Modify: `packages/chameleon_flutter/lib/src/dfu/slip_serial_dfu_channel.dart`
- Test: `packages/chameleon_flutter/test/dfu/slip_serial_dfu_channel_test.dart`

**Interfaces:**
- Consumes: `DfuSerialMtu.{request, parse, chunkSize}` (Task 2); `Transport.{write, incoming,
  state, currentState, maxWriteLength, close}`; `Slip.encode`, `SlipDecoder`;
  `Disconnected([String message])`.
- Produces: `SlipSerialDfuChannel(Transport transport, {int maxDataWrite = 64, bool negotiateMtu
  = true, Duration mtuTimeout = const Duration(seconds: 2), bool ownsTransport = false})` —
  `maxDataWrite` is now the **fallback**, exposed as a getter that `open()` may raise; every
  existing call site keeps compiling. Task 6's opener constructs it with defaults.

- [ ] **Step 1: Write the failing test**

Append to `packages/chameleon_flutter/test/dfu/slip_serial_dfu_channel_test.dart`. It needs a
transport that answers the MTU request; the file's existing `_LoopbackTransport` records writes
and lets a test `deliver` bytes, so drive it by hand:

```dart
  test('open() raises maxDataWrite from the bootloader MTU', () async {
    final t = _LoopbackTransport();
    final channel = SlipSerialDfuChannel(t);
    expect(channel.maxDataWrite, 64);
    final opened = channel.open();
    await pumpEventQueue();
    // The channel asked, SLIP-framed, before anything else went out.
    expect(t.written.single, Slip.encode(<int>[0x07]));
    // 2051 = 0x0803, little-endian in the response payload.
    t.deliver(Slip.encode(<int>[0x60, 0x07, 0x01, 0x03, 0x08]));
    await opened;
    expect(channel.maxDataWrite, 1024);
    await channel.close();
  });

  test('a bootloader without the opcode keeps the fallback', () async {
    final t = _LoopbackTransport();
    final channel = SlipSerialDfuChannel(t);
    final opened = channel.open();
    await pumpEventQueue();
    t.deliver(Slip.encode(<int>[0x60, 0x07, 0x02]));
    await opened;
    expect(channel.maxDataWrite, 64);
    await channel.close();
  });

  test('a silent bootloader keeps the fallback and does not hang', () async {
    final t = _LoopbackTransport();
    final channel = SlipSerialDfuChannel(
      t,
      mtuTimeout: const Duration(milliseconds: 10),
    );
    await channel.open();
    expect(channel.maxDataWrite, 64);
    await channel.close();
  });

  test('the negotiated size never outgrows the transport write limit', () async {
    // 2 * (payload + 1) + 1 <= maxWriteLength is the worst-case SLIP frame,
    // so a 261-byte limit caps the payload at 129 even though the device
    // offered 1024.
    final t = _LoopbackTransport(maxWriteLength: 261);
    final channel = SlipSerialDfuChannel(t);
    final opened = channel.open();
    await pumpEventQueue();
    t.deliver(Slip.encode(<int>[0x60, 0x07, 0x01, 0x03, 0x08]));
    await opened;
    expect(channel.maxDataWrite, 129);
    await channel.close();
  });

  test('negotiateMtu: false writes nothing on open', () async {
    final t = _LoopbackTransport();
    final channel = SlipSerialDfuChannel(t, negotiateMtu: false);
    await channel.open();
    expect(t.written, isEmpty);
    expect(channel.maxDataWrite, 64);
    await channel.close();
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"; cd packages/chameleon_flutter && flutter test test/dfu/slip_serial_dfu_channel_test.dart`
Expected: FAIL — `negotiateMtu`/`mtuTimeout` are not parameters, and `open()` writes nothing.

- [ ] **Step 3: Implement**

In `slip_serial_dfu_channel.dart`: change the constructor and the field, and fill in `open()`.

```dart
  SlipSerialDfuChannel(
    this._transport, {
    int maxDataWrite = 64,
    this.negotiateMtu = true,
    this.mtuTimeout = const Duration(seconds: 2),
    this._ownsTransport = false,
  }) : _maxDataWrite = maxDataWrite {
    // …existing subscription wiring, unchanged…
  }

  /// Ask the bootloader for its SLIP MTU in [open] and size the writes from
  /// the answer. False keeps the fallback and writes nothing on open — for a
  /// test driving the channel by hand.
  final bool negotiateMtu;

  /// How long the MTU answer is waited for. A bootloader that never replies
  /// is not an error: the fallback stands and the first real request is the
  /// gate that reports a dead link.
  final Duration mtuTimeout;

  int _maxDataWrite;
  bool _negotiated = false;

  /// Largest payload one WriteObject frame carries: the constructor's
  /// fallback until [open] negotiates, then nrfutil's
  /// `(mtu - 1) // 2 - 1` for the MTU the bootloader reported, capped so the
  /// worst-case SLIP-escaped frame still fits [Transport.maxWriteLength].
  @override
  int get maxDataWrite => _maxDataWrite;
```

Replace the no-op `open()`:

```dart
  /// Negotiates the write size and nothing else: the transport is already
  /// open when the channel is built, and the constructor has done the
  /// wiring. Idempotent (the negotiation runs once); throws once the channel
  /// is closed. Part of the [DfuChannel] lifecycle (ruling F33) so every
  /// caller can open, write and close the same way.
  ///
  /// Every failure here is swallowed on purpose: a bootloader that answers
  /// "opcode not supported", answers nothing, or drops the link leaves the
  /// conservative fallback in place, and the first real DFU request is what
  /// reports a link that is actually gone.
  @override
  Future<void> open() async {
    if (_closed) {
      throw const Disconnected('the DFU channel is closed');
    }
    if (!negotiateMtu || _negotiated) return;
    _negotiated = true;
    // Subscribe before writing: `responses` is broadcast and buffers nothing
    // for a late listener.
    final reply = responses.first;
    try {
      await writeControl(DfuSerialMtu.request());
      final mtu = DfuSerialMtu.parse(await reply.timeout(mtuTimeout));
      if (mtu == null) return;
      final chunk = DfuSerialMtu.chunkSize(mtu);
      if (chunk <= 0) return;
      _maxDataWrite = chunk < _transportChunkLimit
          ? chunk
          : _transportChunkLimit;
    } on Object {
      // Deliberately ignored; see the doc comment.
    }
  }

  /// The largest payload whose worst-case SLIP frame — every byte escaped,
  /// plus the WriteObject opcode and the terminating END:
  /// `2 * (payload + 1) + 1` — still fits the transport's write limit.
  int get _transportChunkLimit => (_transport.maxWriteLength - 1) ~/ 2 - 1;
```

Also update the class doc comment: the "Follow-up: `SecureDfu` has no GetSerialMTU request yet"
paragraph is now wrong — replace it with a sentence saying `open()` negotiates and the 64-byte
value is the fallback, and keep the `hardware-validate` paragraph (H2 still owns the real
bootloader's answer).

- [ ] **Step 4: Run the tests to verify they pass**

Run: `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"; cd packages/chameleon_flutter && flutter test`
Expected: PASS. If an existing test calls `open()` on a transport that cannot answer, pass
`negotiateMtu: false` there rather than changing the production default.

- [ ] **Step 5: Commit**

```bash
git add packages/chameleon_flutter/lib/src/dfu/slip_serial_dfu_channel.dart packages/chameleon_flutter/test/dfu/slip_serial_dfu_channel_test.dart
git commit -m "feat: negotiate the serial DFU write size on open

The Chameleon's USB CDC bootloader reports SLIP_MTU 2051, which is a
1024-byte chunk against our hard-coded 64. open() now asks and sizes
from the answer, capped by the transport's own write limit; a silent or
unsupporting bootloader keeps the fallback."
```

---

## Task 4: both channel types flash the fake bootloader

The roadmap gate is "integration test on the fake bootloader over both channel types". A widget
test cannot reach a radio or a serial port, so the *channel* half of the gate lives here, in
`chameleon_flutter`, where both channels can be driven against a real `SecureDfu` and a real
`FakeBootloader`; Task 13 owns the app half.

**Files:**
- Create: `packages/chameleon_flutter/test/dfu/dfu_channel_flash_test.dart`

**Interfaces:**
- Consumes: `SecureDfu(DfuChannel channel, {Duration responseTimeout})` and
  `Future<void> run(DfuImage image, {void Function(DfuProgress)? onProgress, CancelToken?
  cancel})`; `FakeBootloader({int maxObjectSize, int expectedHwVersion})` with `handleControl`,
  `handleData`, `flashed`, `completed`, `bytesReceived`, `serialMtu`, `supportsSerialMtu`;
  `DfuPackage.fromZip`, `DfuImage.bin`; `Slip.encode`, `SlipDecoder`; `SlipSerialDfuChannel`
  (Task 3); `BleDfuChannel({required String deviceId, required BleAdapter adapter, HostPlatform?
  platform, int requestedMtu, int appleMaxWrite})`; `NordicDfuUuids.{service, controlPoint,
  packet}`; `FakeBleAdapter` from `packages/chameleon_flutter/test/support/fake_ble_adapter.dart`
  (`base class`, so extendable; `emitNotification(String characteristic, List<int> bytes)`,
  `mtu`, `write(...)` override point); `HostPlatform.linux`.
- Produces: nothing importable. It is the proof both channels carry a whole image.

- [ ] **Step 1: Write the failing test**

Create `packages/chameleon_flutter/test/dfu/dfu_channel_flash_test.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:chameleon_flutter/src/ble/ble_adapter.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_ble_adapter.dart';

/// A serial link whose other end is [bootloader]: every SLIP frame written
/// is decoded and dispatched, and every reply is SLIP-framed back.
///
/// The WriteObject opcode and the "opcode plus raw data, no length prefix"
/// layout are the channel's own (`slip_serial_dfu_channel.dart`, taken from
/// nrfutil's `__stream_data`).
final class _BootloaderSerialTransport implements Transport {
  _BootloaderSerialTransport(this.bootloader, {this.maxWriteLength = 4105});

  static const int _writeObjectOpcode = 0x08;

  final FakeBootloader bootloader;
  final SlipDecoder _decoder = SlipDecoder();
  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();
  final StreamController<TransportState> _state =
      StreamController<TransportState>.broadcast();
  TransportState _current = const TransportOpen();
  bool _closed = false;

  @override
  TransportKind get kind => TransportKind.usb;
  @override
  Stream<Uint8List> get incoming => _incoming.stream;
  @override
  Stream<TransportState> get state => _state.stream;
  @override
  TransportState get currentState => _current;
  @override
  final int maxWriteLength;
  @override
  Future<void> open() async {}

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _current = const TransportClosed(CloseCause.requested);
    if (!_state.isClosed) {
      _state.add(_current);
      await _state.close();
    }
    if (!_incoming.isClosed) await _incoming.close();
  }

  @override
  Future<void> write(Uint8List bytes) async {
    for (final frame in _decoder.add(bytes)) {
      if (frame.isNotEmpty && frame[0] == _writeObjectOpcode) {
        bootloader.handleData(Uint8List.sublistView(frame, 1));
        continue;
      }
      final reply = bootloader.handleControl(frame);
      scheduleMicrotask(() {
        if (!_incoming.isClosed) _incoming.add(Slip.encode(reply));
      });
    }
  }
}

/// A BLE adapter whose DFU service is [bootloader].
base class _BootloaderBleAdapter extends FakeBleAdapter {
  _BootloaderBleAdapter(this.bootloader);

  final FakeBootloader bootloader;

  @override
  Future<void> write(
    String deviceId, {
    required String service,
    required String characteristic,
    required Uint8List value,
    bool withResponse = true,
  }) async {
    await super.write(
      deviceId,
      service: service,
      characteristic: characteristic,
      value: value,
      withResponse: withResponse,
    );
    if (characteristic == NordicDfuUuids.packet) {
      bootloader.handleData(value);
      return;
    }
    final reply = bootloader.handleControl(value);
    scheduleMicrotask(
      () => emitNotification(NordicDfuUuids.controlPoint, reply),
    );
  }
}

/// nrfutil stores the SHA-256 of the image byte-reversed in the init packet
/// (`packages/chameleon/lib/src/dfu/dfu_package.dart`, `DfuImage.hashMatches`;
/// hardware-validate, H2). Mirrors `packages/chameleon/test/dfu/proto_builder.dart`.
Uint8List _varint(int v) {
  final out = <int>[];
  var rest = v;
  while (rest >= 0x80) {
    out.add((rest & 0x7F) | 0x80);
    rest >>= 7;
  }
  out.add(rest);
  return Uint8List.fromList(out);
}

Uint8List _field(int number, int wire, List<int> payload) =>
    Uint8List.fromList(<int>[..._varint((number << 3) | wire), ...payload]);

Uint8List _varintField(int number, int v) => _field(number, 0, _varint(v));

Uint8List _bytesField(int number, List<int> b) =>
    _field(number, 2, <int>[..._varint(b.length), ...b]);

Uint8List _initPacket(Uint8List bin, {int hwVersion = 0}) {
  final hash = sha256.convert(bin).bytes.reversed.toList();
  final hashMsg = <int>[..._varintField(1, 3), ..._bytesField(2, hash)];
  final init = <int>[
    ..._varintField(1, 1),
    ..._varintField(2, hwVersion),
    ..._bytesField(3, _varint(0x0100)),
    ..._varintField(4, 4),
    ..._varintField(7, bin.length),
    ..._bytesField(8, hashMsg),
  ];
  final command = <int>[..._varintField(1, 1), ..._bytesField(2, init)];
  final signed = <int>[
    ..._bytesField(1, command),
    ..._varintField(2, 0),
    ..._bytesField(3, List<int>.filled(64, 0)),
  ];
  return _bytesField(2, signed);
}

Uint8List _zip(Uint8List bin) {
  final manifest = jsonEncode(<String, Object>{
    'manifest': <String, Object>{
      'application': <String, String>{
        'bin_file': 'app.bin',
        'dat_file': 'app.dat',
      },
    },
  });
  final archive = Archive()
    ..add(
      ArchiveFile.bytes(
        'manifest.json',
        Uint8List.fromList(utf8.encode(manifest)),
      ),
    )
    ..add(ArchiveFile.bytes('app.bin', bin))
    ..add(ArchiveFile.bytes('app.dat', _initPacket(bin)));
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}

void main() {
  final Uint8List image = Uint8List.fromList(
    List<int>.generate(5000, (i) => i & 0xFF),
  );
  final DfuImage dfuImage = DfuPackage.fromZip(_zip(image)).images.single;

  test('SlipSerialDfuChannel flashes the whole image', () async {
    final bootloader = FakeBootloader();
    final transport = _BootloaderSerialTransport(bootloader);
    final channel = SlipSerialDfuChannel(transport);
    await channel.open();
    // The bootloader offered SLIP_MTU 2051, so writes grew to 1024.
    expect(channel.maxDataWrite, 1024);

    final progress = <int>[];
    await SecureDfu(channel).run(
      dfuImage,
      onProgress: (p) => progress.add(p.bytesSent),
    );
    await channel.close();

    expect(bootloader.completed, isTrue);
    expect(bootloader.flashed, image);
    expect(progress.last, image.length);
  });

  test('BleDfuChannel flashes the whole image', () async {
    final bootloader = FakeBootloader()..supportsSerialMtu = false;
    final adapter = _BootloaderBleAdapter(bootloader);
    final channel = BleDfuChannel(
      deviceId: 'CU',
      adapter: adapter,
      platform: HostPlatform.linux,
    );
    await channel.open();

    await SecureDfu(channel).run(dfuImage);
    await channel.close();

    expect(bootloader.completed, isTrue);
    expect(bootloader.flashed, image);
    await adapter.dispose();
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"; cd packages/chameleon_flutter && flutter test test/dfu/dfu_channel_flash_test.dart`
Expected: FAIL — the file does not exist yet; after creating it, it must pass with **no**
production change. If it does not, the failure is a real defect in Task 1–3's work: fix the
production code, not the test.

- [ ] **Step 3: Make it pass**

No new production code is expected. `archive` and `crypto` must be dev dependencies of
`chameleon_flutter`; if `flutter pub get` reports them missing, add
`archive: ^4.2.0` and `crypto: ^3.0.7` to its `dev_dependencies` (versions copied from
`packages/chameleon/pubspec.yaml`). Test-only imports are exempt from the dependency lint
(`tool/src/dep_rules.dart`, `_isTestPath`), but keep them in `dev_dependencies` so
`lint:deps` never sees them in `lib/`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"; cd packages/chameleon_flutter && flutter test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/chameleon_flutter/test/dfu/dfu_channel_flash_test.dart packages/chameleon_flutter/pubspec.yaml
git commit -m "test: flash the fake bootloader over both DFU channels

The phase gate asks for both channel types. A widget test cannot reach a
radio or a port, so the channel half of the gate lives beside the
channels: real SecureDfu, real FakeBootloader, one fake transport and one
fake adapter."
```

---

## Task 5: the firmware package source

Spec 7.7 step 6 and the resolved ambiguity above: v1 takes a local nrfutil `.zip` by path.
`DfuPackage.fromZip` already parses and validates it; this task is the seam that gets bytes off
disk and the value object the screen renders.

**Files:**
- Create: `app/lib/features/tools/state/firmware_package_source.dart`
- Create: `app/test/fixtures/dfu_package_fixture.dart`
- Test: `app/test/features/tools/firmware_package_source_test.dart`
- Modify: `app/pubspec.yaml` (dev dependencies for the fixture)

**Interfaces:**
- Consumes: `DfuPackage.fromZip(Uint8List zip)`, `DfuPackage.{images, hardwareVersion,
  targetModel}`, `DfuImage.{kind, bin}`, `DfuImageKind`, `DeviceModel.{ultra, lite}`,
  `DfuError(String message)`.
- Produces:
  - `const String firmwareReleasesUrl`
  - `abstract interface class FirmwarePackageSource { Future<Uint8List> read(String path); }`
  - `final class FileFirmwarePackageSource implements FirmwarePackageSource` (const constructor)
  - `firmwarePackageSourceProvider` (keepAlive, `FirmwarePackageSource`)
  - `final class LoadedFirmwarePackage` with `String path`, `DfuPackage package`,
    `String get fileName`, `int get totalBytes`, `DeviceModel? get targetModel`,
    `int get imageCount`
  - `Future<LoadedFirmwarePackage> loadFirmwarePackage(FirmwarePackageSource source, String path)`
  - fixture: `Uint8List buildDfuZip({int size, int hwVersion, bool reverseHash})` and
    `Uint8List buildBin(int size)` in `app/test/fixtures/dfu_package_fixture.dart`.

- [ ] **Step 1: Write the failing test**

Create `app/test/fixtures/dfu_package_fixture.dart` (a copy of
`packages/chameleon/test/dfu/proto_builder.dart`'s shape — the app cannot import another
package's test files):

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

/// Builds nrfutil-shaped DFU zips for the app's tests. Mirrors
/// `packages/chameleon/test/dfu/proto_builder.dart`; the init packet is a
/// dfu-cc.proto `SignedCommand` whose SHA-256 is stored byte-reversed, which
/// is the only order `DfuImage.hashMatches` accepts (hardware-validate, H2).
Uint8List buildBin(int size) =>
    Uint8List.fromList(List<int>.generate(size, (i) => i & 0xFF));

Uint8List _varint(int v) {
  final out = <int>[];
  var rest = v;
  while (rest >= 0x80) {
    out.add((rest & 0x7F) | 0x80);
    rest >>= 7;
  }
  out.add(rest);
  return Uint8List.fromList(out);
}

Uint8List _field(int number, int wire, List<int> payload) =>
    Uint8List.fromList(<int>[..._varint((number << 3) | wire), ...payload]);

Uint8List _varintField(int number, int v) => _field(number, 0, _varint(v));

Uint8List _bytesField(int number, List<int> b) =>
    _field(number, 2, <int>[..._varint(b.length), ...b]);

Uint8List buildInitPacket(
  Uint8List bin, {
  int hwVersion = 0,
  bool reverseHash = true,
}) {
  final digest = sha256.convert(bin).bytes;
  final hash = reverseHash ? digest.reversed.toList() : digest;
  final hashMsg = <int>[..._varintField(1, 3), ..._bytesField(2, hash)];
  final init = <int>[
    ..._varintField(1, 1),
    ..._varintField(2, hwVersion),
    ..._bytesField(3, _varint(0x0100)),
    ..._varintField(4, 4),
    ..._varintField(7, bin.length),
    ..._bytesField(8, hashMsg),
  ];
  final command = <int>[..._varintField(1, 1), ..._bytesField(2, init)];
  final signed = <int>[
    ..._bytesField(1, command),
    ..._varintField(2, 0),
    ..._bytesField(3, List<int>.filled(64, 0)),
  ];
  return _bytesField(2, signed);
}

/// A one-application-image package of [size] bytes for [hwVersion]
/// (0 Ultra, 1 Lite — `docs/research/chameleon-protocol.md`, "DFU").
Uint8List buildDfuZip({
  int size = 2048,
  int hwVersion = 0,
  bool reverseHash = true,
}) {
  final bin = buildBin(size);
  final manifest = jsonEncode(<String, Object>{
    'manifest': <String, Object>{
      'application': <String, String>{
        'bin_file': 'app.bin',
        'dat_file': 'app.dat',
      },
    },
  });
  final archive = Archive()
    ..add(
      ArchiveFile.bytes(
        'manifest.json',
        Uint8List.fromList(utf8.encode(manifest)),
      ),
    )
    ..add(ArchiveFile.bytes('app.bin', bin))
    ..add(
      ArchiveFile.bytes(
        'app.dat',
        buildInitPacket(bin, hwVersion: hwVersion, reverseHash: reverseHash),
      ),
    );
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}
```

Create `app/test/features/tools/firmware_package_source_test.dart`:

```dart
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/features/tools/state/firmware_package_source.dart';

import '../../fixtures/dfu_package_fixture.dart';

final class _MemorySource implements FirmwarePackageSource {
  _MemorySource(this.files);
  final Map<String, Uint8List> files;

  @override
  Future<Uint8List> read(String path) async {
    final bytes = files[path.trim()];
    if (bytes == null) throw DfuError('no file at $path');
    return bytes;
  }
}

void main() {
  test('loads an Ultra package and summarises it', () async {
    final source = _MemorySource(<String, Uint8List>{
      '/tmp/ultra-dfu-app.zip': buildDfuZip(size: 4096),
    });

    final loaded = await loadFirmwarePackage(source, ' /tmp/ultra-dfu-app.zip ');

    expect(loaded.fileName, 'ultra-dfu-app.zip');
    expect(loaded.targetModel, DeviceModel.ultra);
    expect(loaded.totalBytes, 4096);
    expect(loaded.imageCount, 1);
  });

  test('a Lite package reports the Lite as its target', () async {
    final source = _MemorySource(<String, Uint8List>{
      'lite.zip': buildDfuZip(hwVersion: 1),
    });
    final loaded = await loadFirmwarePackage(source, 'lite.zip');
    expect(loaded.targetModel, DeviceModel.lite);
  });

  test('a missing file fails as a DfuError', () async {
    final source = _MemorySource(const <String, Uint8List>{});
    expect(
      () => loadFirmwarePackage(source, 'nope.zip'),
      throwsA(isA<DfuError>()),
    );
  });

  test('something that is not a zip fails as a DfuError', () async {
    final source = _MemorySource(<String, Uint8List>{
      'x.zip': Uint8List.fromList(<int>[1, 2, 3, 4]),
    });
    expect(
      () => loadFirmwarePackage(source, 'x.zip'),
      throwsA(isA<DfuError>()),
    );
  });

  test('a Windows path still yields a file name', () async {
    final source = _MemorySource(<String, Uint8List>{
      r'C:\Users\me\ultra-dfu-full.zip': buildDfuZip(),
    });
    final loaded = await loadFirmwarePackage(
      source,
      r'C:\Users\me\ultra-dfu-full.zip',
    );
    expect(loaded.fileName, 'ultra-dfu-full.zip');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"; cd app && flutter test test/features/tools/firmware_package_source_test.dart`
Expected: FAIL — `firmware_package_source.dart` does not exist.

- [ ] **Step 3: Implement**

Add to `app/pubspec.yaml` `dev_dependencies` (fixture only; `_isTestPath` exempts test files from
the dependency lint):

```yaml
  # Test fixtures only: building an nrfutil-shaped DFU zip
  # (app/test/fixtures/dfu_package_fixture.dart).
  archive: ^4.2.0
  crypto: ^3.0.7
```

Create `app/lib/features/tools/state/firmware_package_source.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'firmware_package_source.g.dart';

/// Where release packages come from. v1 takes a local zip; the release feed
/// and in-app download are Phase 10 (see the plan's resolved ambiguity).
const String firmwareReleasesUrl =
    'https://github.com/RfidResearchGroup/ChameleonUltra/releases';

/// Reads the bytes of a DFU package. A seam (spec 8.6) so tests never touch
/// the file system.
abstract interface class FirmwarePackageSource {
  Future<Uint8List> read(String path);
}

final class FileFirmwarePackageSource implements FirmwarePackageSource {
  const FileFirmwarePackageSource();

  @override
  Future<Uint8List> read(String path) async {
    final file = File(path.trim());
    // A typed failure, not a raw FileSystemException: the error catalog is
    // keyed by the sealed SDK types (spec 9) and a plain OS error would fall
    // through to "something went wrong".
    if (!file.existsSync()) throw DfuError('no file at ${path.trim()}');
    try {
      return await file.readAsBytes();
    } on FileSystemException catch (e) {
      throw DfuError('could not read ${path.trim()}: ${e.message}');
    }
  }
}

@Riverpod(keepAlive: true)
FirmwarePackageSource firmwarePackageSource(Ref ref) =>
    const FileFirmwarePackageSource();

/// One parsed package, plus what the screen says about it.
final class LoadedFirmwarePackage {
  const LoadedFirmwarePackage({required this.path, required this.package});

  final String path;
  final DfuPackage package;

  /// The last path segment, on either separator: a Windows path is typed by
  /// hand as often as a POSIX one.
  String get fileName => path.split(RegExp(r'[/\\]')).last;

  /// Firmware bytes across every image — what the progress bar counts.
  int get totalBytes =>
      package.images.fold<int>(0, (sum, image) => sum + image.bin.length);

  int get imageCount => package.images.length;

  /// Null when the package declares a hardware version that is neither 0
  /// (Ultra) nor 1 (Lite); `DfuOrchestrator` then leaves the check to the
  /// bootloader.
  DeviceModel? get targetModel => package.targetModel;
}

/// Reads and parses [path]. Every failure is a [DfuError], so the screen has
/// one thing to catch and the catalog one thing to describe.
Future<LoadedFirmwarePackage> loadFirmwarePackage(
  FirmwarePackageSource source,
  String path,
) async {
  final bytes = await source.read(path);
  return LoadedFirmwarePackage(
    path: path.trim(),
    package: DfuPackage.fromZip(bytes),
  );
}
```

- [ ] **Step 4: Run codegen and the tests**

Run:
```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter pub get && dart run build_runner build --delete-conflicting-outputs && flutter test test/features/tools/firmware_package_source_test.dart
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/tools/state/firmware_package_source.dart app/lib/features/tools/state/firmware_package_source.g.dart app/test/fixtures/dfu_package_fixture.dart app/test/features/tools/firmware_package_source_test.dart app/pubspec.yaml app/pubspec.lock
git commit -m "feat: read a local nrfutil DFU package

v1 takes a local zip by path; the release feed and download wait for
Phase 10, where the network and signing policy is settled. Every failure
is a DfuError so the spec 9 catalog has one type to describe."
```

---

## Task 6: the DFU runtime — activity flag, channel opener, scanners

`DfuOrchestrator` needs two things the SDK cannot supply: a `DfuChannelOpener` (transport
specific, spec 4.5) and the scanners to find the bootloader and then the device again. Both
depend on app state — the feature flag, emulator mode, the active session — so they live in
`core/`, not in the feature.

**Files:**
- Create: `app/lib/core/dfu/dfu_runtime.dart`
- Test: `app/test/core/dfu/dfu_runtime_test.dart`

**Interfaces:**
- Consumes: `DfuChannelOpener` (`Future<DfuChannel> Function(DiscoveredDevice)`),
  `DiscoveredDevice.{kind, transportId, isBootloader}`, `TransportKind.{fake, usb, ble}`,
  `FakeDevice.{openDfuChannel, inBootloader, firmware}`, `FakeFirmware.bootloaderRequested`,
  `FakeScanner()` / `FakeScanner.forDevice(FakeDevice)`, `DeviceScanner`, `DeviceSession.transport`,
  `SlipSerialDfuChannel(Transport, {…, bool ownsTransport})` (Task 3),
  `BleDfuChannel({required String deviceId, required BleAdapter adapter})`,
  `UniversalBleAdapter()`, `DfuError`, `buildEmulatedDevice()` and `emulatorAwareTransport`
  (`app/lib/core/emulator/demo_cards.dart`), `transportFactoryProvider`, `scannersProvider`,
  `activeSessionProvider`, `ActiveSession.session`, `featureFlagsProvider`,
  `FeatureFlags.dfuOverBleEnabled`.
- Produces:
  - `dfuActivityProvider` — `DfuActivity extends _$DfuActivity` with `bool build()` and
    `void setRunning(bool value)` (keepAlive). Task 7 sets it; Task 8 reads it.
  - `emulatorBootloaderProvider` — keepAlive `FakeDevice`, already in bootloader mode.
  - `dfuChannelOpenerProvider` — keepAlive `DfuChannelOpener`.
  - `dfuScanTimeoutProvider` — keepAlive `Duration` (30 s; tests override it).
  - `List<DeviceScanner> dfuScanners(Ref ref, {DiscoveredDevice? target, DeviceSession? session})`.

- [ ] **Step 1: Write the failing test**

Create `app/test/core/dfu/dfu_runtime_test.dart`:

```dart
import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/dfu/dfu_runtime.dart';
import 'package:spectra/core/flags/feature_flags.dart';
import 'package:spectra/data/repository_providers.dart';
import 'package:spectra/data/memory/in_memory_repositories.dart';

ProviderContainer _container({bool bleEnabled = false}) {
  final container = ProviderContainer(
    overrides: <Override>[
      preferencesRepositoryProvider.overrideWithValue(
        InMemoryPreferencesRepository(),
      ),
      if (bleEnabled)
        featureFlagsProvider.overrideWithValue(
          const FeatureFlags(dfuOverBleEnabled: true),
        ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  const fakeBootloader = DiscoveredDevice(
    name: 'CU',
    kind: TransportKind.fake,
    transportId: 'fake-bootloader',
    isBootloader: true,
  );
  const bleBootloader = DiscoveredDevice(
    name: 'CU',
    kind: TransportKind.ble,
    transportId: 'AA:BB:CC:DD:EE:FF',
    isBootloader: true,
  );

  test('the activity flag starts false and toggles', () {
    final container = _container();
    expect(container.read(dfuActivityProvider), isFalse);
    container.read(dfuActivityProvider.notifier).setRunning(true);
    expect(container.read(dfuActivityProvider), isTrue);
  });

  test('the emulator bootloader is a fake device already in DFU mode', () {
    final container = _container();
    final device = container.read(emulatorBootloaderProvider);
    expect(device.inBootloader, isTrue);
    expect(identical(container.read(emulatorBootloaderProvider), device), isTrue);
  });

  test('a fake bootloader opens a channel onto that same fake', () async {
    final container = _container();
    final opener = container.read(dfuChannelOpenerProvider);
    final channel = await opener(fakeBootloader);
    expect(channel, isA<FakeDfuChannel>());
    await channel.close();
  });

  test('a BLE bootloader is refused while the flag is off', () async {
    final container = _container();
    final opener = container.read(dfuChannelOpenerProvider);
    expect(() => opener(bleBootloader), throwsA(isA<DfuError>()));
  });

  test('a BLE bootloader opens a BleDfuChannel once the flag is on', () async {
    final container = _container(bleEnabled: true);
    final opener = container.read(dfuChannelOpenerProvider);
    final channel = await opener(bleBootloader);
    expect(channel, isA<BleDfuChannel>());
    await channel.close();
  });

  test('a fake target scans through the fake it will flash', () {
    final container = _container();
    final scanners = container.read(
      dfuScannersProvider(const DfuTarget(bootloader: fakeBootloader)),
    );
    expect(scanners.single, isA<FakeScanner>());
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"; cd app && flutter test test/core/dfu/dfu_runtime_test.dart`
Expected: FAIL — `dfu_runtime.dart` does not exist.

- [ ] **Step 3: Implement**

Create `app/lib/core/dfu/dfu_runtime.dart`:

```dart
import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../discovery/scanners.dart';
import '../emulator/demo_cards.dart';
import '../flags/feature_flags.dart';
import '../session/active_device.dart';
import '../session/sessions.dart'; // transportFactoryProvider

part 'dfu_runtime.g.dart';

/// True while a flash is running. Spec 7.4 and 5.6: the app holds a wakelock
/// and blocks navigation for as long as this is set. Lives in core because
/// two core rules (the router's redirect, the wakelock controller) read it
/// and the feature that sets it must not be imported by either.
@Riverpod(keepAlive: true)
class DfuActivity extends _$DfuActivity {
  @override
  bool build() => false;

  void setRunning(bool value) => state = value;
}

/// Budget for each of `DfuOrchestrator`'s scans and for the reboot before the
/// first of them. A seam so a widget test does not sit out 30 seconds when a
/// scan is meant to fail.
@Riverpod(keepAlive: true)
Duration dfuScanTimeout(Ref ref) => const Duration(seconds: 30);

/// The emulated device behind `FakeScanner.emulatedBootloader`: a fake that
/// is already in DFU mode, so the recovery path (spec 5.5) has something to
/// flash in emulator mode. Created lazily — nothing reads it unless a fake
/// bootloader is actually the target — and kept alive so the scan that
/// follows the flash sees the *same* device leave the bootloader.
@Riverpod(keepAlive: true)
FakeDevice emulatorBootloader(Ref ref) {
  final device = buildEmulatedDevice();
  device.firmware.bootloaderRequested = true;
  ref.onDispose(() => device.close());
  return device;
}

/// Which device a run is aimed at: a bootloader picked on the connect screen
/// (spec 5.5's recovery entry), or nothing — meaning the active session's
/// device, which the orchestrator reboots itself.
final class DfuTarget {
  const DfuTarget({this.bootloader});
  final DiscoveredDevice? bootloader;

  @override
  bool operator ==(Object other) =>
      other is DfuTarget && other.bootloader == bootloader;

  @override
  int get hashCode => bootloader.hashCode;
}

/// Opens a DFU channel to a discovered bootloader (spec 4.5's
/// `DfuChannelOpener`, spec 5.3's two channels).
///
/// USB is enabled everywhere it exists; BLE is refused while
/// `dfuOverBleEnabled` is off (roadmap H2), which is belt and braces beside
/// the screen never offering it — the flag is the single gate spec 5.6 asks
/// for, and it has to hold even if a caller gets here another way.
@Riverpod(keepAlive: true)
DfuChannelOpener dfuChannelOpener(Ref ref) => (DiscoveredDevice bootloader) async {
  switch (bootloader.kind) {
    case TransportKind.fake:
      // The session's own fake if it is the one that just rebooted;
      // otherwise the standing emulator bootloader (the recovery entry,
      // where nothing is connected).
      final transport = ref.read(activeSessionProvider)?.session.transport;
      if (transport is FakeDevice && transport.inBootloader) {
        return transport.openDfuChannel();
      }
      return ref.read(emulatorBootloaderProvider).openDfuChannel();
    case TransportKind.usb:
      // The channel owns the transport: nothing else holds the port, and
      // closing the channel has to release it whichever way the run ended.
      final transport = ref.read(transportFactoryProvider)(bootloader);
      await transport.open();
      return SlipSerialDfuChannel(transport, ownsTransport: true);
    case TransportKind.ble:
      if (!ref.read(featureFlagsProvider).dfuOverBleEnabled) {
        throw DfuError(
          'Bluetooth firmware update is disabled until hardware handoff H2 '
          'passes (dfuOverBleEnabled)',
        );
      }
      return BleDfuChannel(
        deviceId: bootloader.transportId,
        adapter: UniversalBleAdapter(),
      );
  }
};

/// The scanners one run uses to find the bootloader and then the device
/// again.
///
/// In emulator mode a plain `FakeScanner` reports a static list, so it would
/// never show the device as a bootloader after the reboot — and never show it
/// back in the application after the flash. `FakeScanner.forDevice` follows
/// one fake's actual mode, which is exactly what the orchestrator's two scans
/// need. Real devices use the app's own scanner list unchanged.
@Riverpod(keepAlive: true)
List<DeviceScanner> dfuScanners(Ref ref, DfuTarget target) {
  final transport = ref.watch(activeSessionProvider)?.session.transport;
  if (transport is FakeDevice) {
    return <DeviceScanner>[FakeScanner.forDevice(transport)];
  }
  final bootloader = target.bootloader;
  if (bootloader != null && bootloader.kind == TransportKind.fake) {
    return <DeviceScanner>[
      FakeScanner.forDevice(ref.read(emulatorBootloaderProvider)),
    ];
  }
  return ref.watch(scannersProvider);
}
```

- [ ] **Step 4: Run codegen and the tests**

Run:
```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && dart run build_runner build --delete-conflicting-outputs && flutter test test/core/dfu/dfu_runtime_test.dart
```
Expected: PASS. (`InMemoryPreferencesRepository` is the existing in-memory repo from
`app/lib/data/memory/in_memory_repositories.dart`; if its name differs, use the one that file
actually exports.)

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/dfu app/test/core/dfu
git commit -m "feat: add the DFU runtime seams

The orchestrator needs a channel opener and scanners, and both depend on
app state — the BLE flag, emulator mode, the active session. They sit in
core because the router and the wakelock read the activity flag and
neither may import a feature."
```

---

## Task 7: `UpdateController`

**Files:**
- Create: `app/lib/features/tools/state/update_controller.dart`
- Test: `app/test/features/tools/update_controller_test.dart`

**Interfaces:**
- Consumes: `DfuOrchestrator`, `DfuEvent`/`DfuPhaseChanged`/`DfuProgressed`/`DfuCompleted`/
  `DfuFailed`, `DfuPhase`, `DfuProgress.{stage, bytesSent, bytesTotal, fraction}`, `CancelToken`,
  `DfuError`; Task 5's `loadFirmwarePackage`, `LoadedFirmwarePackage`,
  `firmwarePackageSourceProvider`; Task 6's `dfuChannelOpenerProvider`, `dfuScannersProvider`,
  `DfuTarget`, `dfuScanTimeoutProvider`, `dfuActivityProvider`; `activeSessionProvider`,
  `ActiveSession.{identity, session}`, `sessionsProvider` (`Sessions.connect`,
  `Sessions.disconnect`), `activeDeviceProvider` (`ActiveDevice.select`),
  `featureFlagsProvider`.
- Produces:
  - `final class UpdateState` — `LoadedFirmwarePackage? package`, `DfuPhase? phase`,
    `DfuProgress? progress`, `Object? error`, `bool running`, `bool completed`, `bool loading`;
    `UpdateState copyWith({...})` with `_unset` sentinels for the three nullable fields;
    `double? get fraction`.
  - `updateControllerProvider` — `UpdateController extends _$UpdateController` (keepAlive) with
    `UpdateState build()`, `Future<void> loadPackage(String path)`,
    `Future<void> start({DiscoveredDevice? bootloader})`, `void cancel()`, `void reset()`,
    `@visibleForTesting void debugFail(Object error)`.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/tools/update_controller_test.dart`:

```dart
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/dfu/dfu_runtime.dart';
import 'package:spectra/features/tools/state/firmware_package_source.dart';
import 'package:spectra/features/tools/state/update_controller.dart';

import '../../fixtures/dfu_package_fixture.dart';
import '../../support/app_harness.dart';

final class _MemorySource implements FirmwarePackageSource {
  _MemorySource(this.bytes);
  final Uint8List bytes;
  @override
  Future<Uint8List> read(String path) async => bytes;
}

void main() {
  testWidgetsApp('loads a package and reports its target', (tester) async {
    await tester.pumpWidget(
      buildTestApp(source: _MemorySource(buildDfuZip(size: 4096))),
    );
    await tester.pump();

    final controller = readProvider(tester, updateControllerProvider.notifier);
    await controller.loadPackage('ultra-dfu-app.zip');
    await pumpFrames(tester);

    final state = readProvider(tester, updateControllerProvider);
    expect(state.package?.targetModel, DeviceModel.ultra);
    expect(state.error, isNull);
  });

  testWidgetsApp('a bad package leaves an error and no package', (tester) async {
    await tester.pumpWidget(
      buildTestApp(source: _MemorySource(Uint8List.fromList(<int>[1, 2, 3]))),
    );
    await tester.pump();

    final controller = readProvider(tester, updateControllerProvider.notifier);
    await controller.loadPackage('broken.zip');
    await pumpFrames(tester);

    final state = readProvider(tester, updateControllerProvider);
    expect(state.package, isNull);
    expect(state.error, isA<DfuError>());
  });

  testWidgetsApp('start with no package and no device does nothing bad', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(source: _MemorySource(buildDfuZip())),
    );
    await tester.pump();

    final controller = readProvider(tester, updateControllerProvider.notifier);
    await controller.start();
    await pumpFrames(tester);

    expect(readProvider(tester, updateControllerProvider).running, isFalse);
    expect(readProvider(tester, dfuActivityProvider), isFalse);
  });

  testWidgetsApp('a recovery run flashes the emulated bootloader', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(source: _MemorySource(buildDfuZip(size: 4096))),
    );
    await tester.pump();

    final controller = readProvider(tester, updateControllerProvider.notifier);
    await controller.loadPackage('ultra-dfu-app.zip');
    await pumpFrames(tester);

    final run = controller.start(bootloader: FakeScanner.emulatedBootloader);
    await pumpFrames(tester, count: 60);
    await run;

    final state = readProvider(tester, updateControllerProvider);
    expect(state.completed, isTrue);
    expect(state.error, isNull);
    expect(state.phase, DfuPhase.done);
    expect(state.progress?.bytesSent, 4096);
    expect(readProvider(tester, dfuActivityProvider), isFalse);
  });

  testWidgetsApp('debugFail puts the controller in a failed state', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(source: _MemorySource(buildDfuZip())));
    await tester.pump();
    readProvider(tester, updateControllerProvider.notifier)
        .debugFail(DfuError('scripted'));
    await tester.pump();
    expect(readProvider(tester, updateControllerProvider).error, isA<DfuError>());
  });
}
```

Add the small builder this file uses at its top (a local helper, not a harness edit — the harness
is frozen this phase):

```dart
/// `testApp` plus the package source and a short scan budget: the harness
/// owns the app root's overrides (ruling: nobody edits it), and a test-local
/// `ProviderScope` on top of it would be a second root. `appOverrides` is the
/// documented way to compose one more override.
Widget buildTestApp({required FirmwarePackageSource source}) => ProviderScope(
  overrides: <Override>[
    ...appOverrides(transport: (_) => FakeDevice()),
    firmwarePackageSourceProvider.overrideWithValue(source),
    dfuScanTimeoutProvider.overrideWithValue(const Duration(seconds: 2)),
  ],
  child: const SpectraRoot(),
);
```

(imports: `package:flutter/widgets.dart` for `Widget`, `package:flutter_riverpod/flutter_riverpod.dart`
for `ProviderScope`/`Override`, `package:spectra/app.dart` for `SpectraRoot`.)

- [ ] **Step 2: Run the test to verify it fails**

Run: `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"; cd app && flutter test test/features/tools/update_controller_test.dart`
Expected: FAIL — `update_controller.dart` does not exist.

- [ ] **Step 3: Implement**

Create `app/lib/features/tools/state/update_controller.dart`:

```dart
import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/dfu/dfu_runtime.dart';
import '../../../core/flags/feature_flags.dart';
import '../../../core/session/active_device.dart';
import '../../../core/session/active_session.dart';
import '../../../core/session/sessions.dart';
import 'firmware_package_source.dart';

part 'update_controller.g.dart';

/// Distinguishes "leave it alone" from "clear it" in [UpdateState.copyWith],
/// since null is a meaningful value for all three nullable fields.
const Object _unset = Object();

/// What the update screen shows (spec 7.7 step 6).
final class UpdateState {
  const UpdateState({
    this.package,
    this.phase,
    this.progress,
    this.error,
    this.running = false,
    this.completed = false,
    this.loading = false,
  });

  final LoadedFirmwarePackage? package;

  /// The orchestrator's last phase, or null before a run starts.
  final DfuPhase? phase;
  final DfuProgress? progress;

  /// The failure of the last load or run. Cleared when either starts again.
  final Object? error;

  /// A flash is running: every control on the screen is disabled and
  /// navigation is locked (spec 5.6).
  final bool running;

  /// The last run finished successfully.
  final bool completed;

  /// A package is being read and parsed.
  final bool loading;

  /// 0..1 for the bar, or null while there is nothing to report.
  double? get fraction => progress?.fraction;

  UpdateState copyWith({
    Object? package = _unset,
    Object? phase = _unset,
    Object? progress = _unset,
    Object? error = _unset,
    bool? running,
    bool? completed,
    bool? loading,
  }) => UpdateState(
    package: identical(package, _unset)
        ? this.package
        : package as LoadedFirmwarePackage?,
    phase: identical(phase, _unset) ? this.phase : phase as DfuPhase?,
    progress: identical(progress, _unset)
        ? this.progress
        : progress as DfuProgress?,
    error: identical(error, _unset) ? this.error : error,
    running: running ?? this.running,
    completed: completed ?? this.completed,
    loading: loading ?? this.loading,
  );
}

/// Drives `DfuOrchestrator` for the update screen (spec 4.5, 7.7 step 6).
///
/// Two entry points, one run: a connected device (the orchestrator sends
/// ENTER_BOOTLOADER itself and the session moves to `SessionUpdating`), and a
/// device already sitting in its bootloader — the recovery path spec 5.6
/// guarantees, reached from the connect screen's "Recover" action.
///
/// Cancellation goes through the [CancelToken], never by cancelling the
/// subscription: unsubscribing closes the channel under an in-flight transfer
/// and leaves a half-written image on the device (`DfuOrchestrator`'s own doc).
@Riverpod(keepAlive: true)
class UpdateController extends _$UpdateController {
  CancelToken? _cancel;
  StreamSubscription<DfuEvent>? _events;

  /// Drop, do not queue: a second start while one is in flight is ignored.
  bool _inFlight = false;

  @override
  UpdateState build() {
    ref.onDispose(() {
      _cancel?.cancel();
      unawaited(_events?.cancel());
    });
    return const UpdateState();
  }

  /// Reads and parses the package at [path]. A failure leaves the previous
  /// package in place: a mistyped path should not clear a good one.
  Future<void> loadPackage(String path) async {
    if (state.running || state.loading) return;
    state = state.copyWith(loading: true, error: null, completed: false);
    try {
      final loaded = await loadFirmwarePackage(
        ref.read(firmwarePackageSourceProvider),
        path,
      );
      if (!ref.mounted) return;
      state = state.copyWith(package: loaded, loading: false);
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, error: e);
    }
  }

  /// Runs the whole update. With [bootloader] the device is already in DFU
  /// mode; without it the active session's device is rebooted first.
  Future<void> start({DiscoveredDevice? bootloader}) async {
    if (_inFlight) return;
    final package = state.package;
    if (package == null) return;
    final active = ref.read(activeSessionProvider);
    if (bootloader == null && active == null) {
      state = state.copyWith(
        error: DfuError('connect a device, or choose one in the bootloader'),
      );
      return;
    }
    if (bootloader?.kind == TransportKind.ble &&
        !ref.read(featureFlagsProvider).dfuOverBleEnabled) {
      state = state.copyWith(
        error: DfuError(
          'Bluetooth firmware update is disabled until hardware handoff H2 '
          'passes (dfuOverBleEnabled)',
        ),
      );
      return;
    }

    _inFlight = true;
    final cancel = CancelToken();
    _cancel = cancel;
    ref.read(dfuActivityProvider.notifier).setRunning(true);
    state = state.copyWith(
      running: true,
      completed: false,
      error: null,
      phase: null,
      progress: null,
    );

    final orchestrator = DfuOrchestrator(
      scanners: ref.read(dfuScannersProvider(DfuTarget(bootloader: bootloader))),
      openChannel: ref.read(dfuChannelOpenerProvider),
      scanTimeout: ref.read(dfuScanTimeoutProvider),
    );

    DiscoveredDevice? found;
    Object? failure;
    final done = Completer<void>();
    _events =
        orchestrator
            .run(
              package: package.package,
              session: bootloader == null ? active!.session : null,
              bootloader: bootloader,
              cancel: cancel,
            )
            .listen(
              (event) {
                if (!ref.mounted) return;
                switch (event) {
                  case DfuPhaseChanged(:final phase):
                    state = state.copyWith(phase: phase);
                  case DfuProgressed(:final progress):
                    state = state.copyWith(progress: progress);
                  case DfuCompleted(:final device):
                    found = device;
                  case DfuFailed(:final error):
                    failure = error;
                }
              },
              // `run()` ends every path in one DfuCompleted or DfuFailed
              // (Task 1), so this is only a bug net.
              onError: (Object e) => failure = e,
              onDone: done.complete,
            );
    await done.future;
    await _events?.cancel();
    _events = null;
    _cancel = null;
    _inFlight = false;

    if (failure == null) await _reconnect(previous: active, device: found);
    ref.read(dfuActivityProvider.notifier).setRunning(false);
    if (!ref.mounted) return;
    state = state.copyWith(
      running: false,
      completed: failure == null,
      error: failure,
    );
  }

  /// Closes the session the flash left in `SessionUpdating` and opens one on
  /// the device the orchestrator found coming back (spec 4.5: the reconnect
  /// is the app's, not the orchestrator's).
  ///
  /// A reconnect that fails is not an update failure: the image is written.
  /// The session is gone either way, so routing puts the connect screen one
  /// tap away and the user retries there.
  Future<void> _reconnect({
    required ActiveSession? previous,
    required DiscoveredDevice? device,
  }) async {
    final sessions = ref.read(sessionsProvider.notifier);
    if (previous != null) await sessions.disconnect(previous.identity);
    if (device == null || !ref.mounted) return;
    try {
      final identity = await sessions.connect(device);
      if (!ref.mounted) return;
      ref.read(activeDeviceProvider.notifier).select(identity);
    } on Object {
      // Deliberately ignored; see the doc comment.
    }
  }

  /// Stops the transfer at the next packet boundary. The device stays in the
  /// bootloader, which is what makes the run retryable (spec 5.6).
  void cancel() => _cancel?.cancel();

  /// Clears the last result, keeping the loaded package.
  void reset() =>
      state = state.copyWith(error: null, completed: false, phase: null, progress: null);

  @visibleForTesting
  void debugFail(Object error) =>
      state = state.copyWith(error: error, running: false);
}
```

- [ ] **Step 4: Run codegen and the tests**

Run:
```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && dart run build_runner build --delete-conflicting-outputs && flutter test test/features/tools/update_controller_test.dart
```
Expected: PASS. If the recovery run's pump loop is short, widen `pumpFrames(count:)` — never
`pumpAndSettle` (ruling 22).

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/tools/state/update_controller.dart app/lib/features/tools/state/update_controller.g.dart app/test/features/tools/update_controller_test.dart
git commit -m "feat: drive DFU from an update controller

One controller for both entry points: a connected device the orchestrator
reboots, and a device already in its bootloader. Cancellation goes through
the CancelToken, never by unsubscribing, so a stopped transfer leaves a
recoverable device."
```

---

## Task 8: navigation lock and wakelock during a flash

Spec 5.6: *the app keeps a wakelock and blocks navigation during a flash.* Spec 7.2 already locks
navigation for a `SessionUpdating` session, and `sessionNeedsWakelock` already holds the wakelock
for one — but the recovery path has **no session at all**, and that is exactly the run that must
not be interrupted.

**Files:**
- Modify: `app/lib/core/routing/redirect.dart`, `app/lib/core/routing/router.dart`,
  `app/lib/core/lifecycle/wakelock.dart`
- Test: `app/test/core/routing/update_lock_test.dart`

**Interfaces:**
- Consumes: `dfuActivityProvider` (Task 6); `redirectFor({required ConnectionState state,
  required String location})`; `AppRoutes.{update, connect, device}`; `RouterRefresh`;
  `sessionNeedsWakelock(DeviceSession? session, ConnectionState state)`; `WakelockController`.
- Produces: `redirectFor({required ConnectionState state, required String location, bool
  updating = false})` — a defaulted parameter, so existing call sites and tests keep compiling.

- [ ] **Step 1: Write the failing test**

Create `app/test/core/routing/update_lock_test.dart`:

```dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/routing/redirect.dart';
import 'package:spectra/core/routing/routes.dart';

void main() {
  const disconnected = SessionDisconnected(DisconnectCause.requested);

  test('a running flash pins every location to the update screen', () {
    expect(
      redirectFor(
        state: disconnected,
        location: AppRoutes.connect,
        updating: true,
      ),
      AppRoutes.update,
    );
    expect(
      redirectFor(
        state: const SessionReady(),
        location: AppRoutes.slots,
        updating: true,
      ),
      AppRoutes.update,
    );
  });

  test('the update screen itself is where it stays', () {
    expect(
      redirectFor(
        state: disconnected,
        location: AppRoutes.update,
        updating: true,
      ),
      isNull,
    );
  });

  test('with no flash running the connection state still decides', () {
    expect(
      redirectFor(state: disconnected, location: AppRoutes.slots),
      AppRoutes.connect,
    );
  });
}
```

Add to `app/test/core/lifecycle/wakelock_test.dart` (the file already exists from Phase 4; if a
name differs, follow the file):

```dart
  test('a recovery flash with no session still holds the wakelock', () {
    // The recovery path has no DeviceSession at all: nothing is connected,
    // the device sits in its bootloader. Spec 5.6 still wants the screen
    // awake, so the flash flag has to be an input of its own.
    expect(
      sessionNeedsWakelock(null, const SessionDisconnected(DisconnectCause.requested)),
      isFalse,
    );
  });
```

and a controller-level test proving the composed predicate:

```dart
  test('the composed predicate holds while a flash runs', () {
    var flashing = false;
    final controller = WakelockController(
      gateway: gateway,
      shouldHold: () =>
          sessionNeedsWakelock(null, const SessionDisconnected(DisconnectCause.requested)) ||
          flashing,
    );
    flashing = true;
    unawaited(controller.poll());
    expect(controller.held, isTrue);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"; cd app && flutter test test/core/routing/update_lock_test.dart test/core/lifecycle/wakelock_test.dart`
Expected: FAIL — `redirectFor` has no `updating` parameter.

- [ ] **Step 3: Implement**

`redirect.dart`:

```dart
/// Spec 7.2, whole: routing is driven by the connection state. Pure, so the
/// rule is tested without a widget tree and go_router only has to call it.
///
/// [updating] is a flash in flight (`dfuActivityProvider`). It outranks the
/// connection state because the recovery path (spec 5.6) has no session at
/// all: nothing is connected, the device is in its bootloader, and leaving
/// the screen mid-transfer is the one thing that must not happen.
///
/// Returns the location to go to, or null to stay where we are.
String? redirectFor({
  required ConnectionState state,
  required String location,
  bool updating = false,
}) {
  if (updating) {
    return location == AppRoutes.update ? null : AppRoutes.update;
  }
  switch (state) {
    // …the existing switch, unchanged…
```

`router.dart`:

```dart
import '../dfu/dfu_runtime.dart';
…
final class RouterRefresh extends ChangeNotifier {
  RouterRefresh(Ref ref) {
    ref.listen(connectionStatusProvider, (_, _) => notifyListeners());
    // A flash starting or finishing changes what is reachable, exactly as a
    // connection-state change does.
    ref.listen(dfuActivityProvider, (_, _) => notifyListeners());
  }
}
…
    redirect: (context, state) => redirectFor(
      state: ref.read(connectionStatusProvider),
      location: state.uri.path,
      updating: ref.read(dfuActivityProvider),
    ),
```

`wakelock.dart` — extend the composed predicate only (leave `sessionNeedsWakelock` alone: it
answers a question about a session, and the flash flag is not one):

```dart
import '../dfu/dfu_runtime.dart';
…
@Riverpod(keepAlive: true)
WakelockController wakelock(Ref ref) {
  final controller = WakelockController(
    gateway: ref.read(wakelockGatewayProvider),
    // Spec 7.4 and 5.6: a session that is updating, a reader lease or a busy
    // session — plus a recovery flash, which has no session to ask.
    shouldHold: () =>
        sessionNeedsWakelock(
          ref.read(activeSessionProvider)?.session,
          ref.read(connectionStatusProvider),
        ) ||
        ref.read(dfuActivityProvider),
  );
  controller.start();
  ref.onDispose(controller.stop);
  return controller;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"; cd app && flutter test test/core`
Expected: PASS, including every existing routing test (the new parameter is defaulted).

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/routing/redirect.dart app/lib/core/routing/router.dart app/lib/core/lifecycle/wakelock.dart app/lib/core/lifecycle/wakelock.g.dart app/test/core
git commit -m "feat: lock navigation and hold the wakelock during a flash

SessionUpdating covered the connected path only. The recovery path has no
session at all, and that is precisely the run that must not be
interrupted, so the flash flag outranks the connection state."
```

---

## Task 9: the update screen's strings

Single ARB writer for the phase. Nothing else in Phase 8 touches `app_en.arb`.

**Files:**
- Modify: `app/lib/l10n/app_en.arb`, and the regenerated
  `app/lib/l10n/app_localizations.dart` / `app_localizations_en.dart`
- Create: `app/lib/features/tools/state/update_steps.dart`
- Test: `app/test/features/tools/update_steps_test.dart`

**Interfaces:**
- Consumes: `AppLocalizations`, `DfuPhase`.
- Produces:
  - ARB keys (all new): `updatePackageSection`, `updatePackagePathLabel`, `updatePackagePathHint`,
    `updateLoadPackage`, `updateReleasesHint`, `updatePackageSummary`, `updatePackageForUltra`,
    `updatePackageForLite`, `updatePackageForUnknown`, `updateStart`, `updateNoTarget`,
    `updateTargetConnected`, `updateStepChecking`, `updateStepBootloader`,
    `updateStepFindingBootloader`, `updateStepTransferring`, `updateStepFindingDevice`,
    `updateStepDone`, `updateProgressLabel`, `updateProgressDetail`, `updateSucceeded`,
    `updateDoNotDisconnect`, `updateBleDisabled`.
    `comingSoonUpdate` is **deleted** (Task 11 removes its last use).
  - `List<String> updateStepLabels(AppLocalizations l10n)` and
    `int updateStepIndex(DfuPhase? phase)` in `update_steps.dart`.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/tools/update_steps_test.dart`:

```dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/features/tools/state/update_steps.dart';
import 'package:spectra/l10n/app_localizations.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('every phase maps into the step list', () {
    final labels = updateStepLabels(l10n);
    for (final phase in DfuPhase.values) {
      final index = updateStepIndex(phase);
      expect(index, inInclusiveRange(0, labels.length - 1));
    }
    expect(updateStepIndex(null), 0);
    expect(updateStepIndex(DfuPhase.done), labels.length - 1);
  });

  test('the labels are the six orchestrator phases, in order', () {
    expect(updateStepLabels(l10n), hasLength(DfuPhase.values.length));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"; cd app && flutter test test/features/tools/update_steps_test.dart`
Expected: FAIL — `update_steps.dart` and the new keys do not exist.

- [ ] **Step 3: Add the strings and the mapping**

In `app/lib/l10n/app_en.arb`, beside the existing `update*` keys, **delete** `comingSoonUpdate`
and its `@comingSoonUpdate`, then add:

```json
  "updatePackageSection": "Firmware package",
  "@updatePackageSection": {"description": "Heading of the package-picking section."},
  "updatePackagePathLabel": "Package file",
  "@updatePackagePathLabel": {"description": "Label of the field taking a path to a DFU zip."},
  "updatePackagePathHint": "/path/to/ultra-dfu-app.zip",
  "@updatePackagePathHint": {"description": "Placeholder in the package path field."},
  "updateLoadPackage": "Load package",
  "@updateLoadPackage": {"description": "Reads and validates the package at the typed path."},
  "updateReleasesHint": "Download a release package from {url}, then load it here.",
  "@updateReleasesHint": {
    "description": "Where release zips come from; v1 has no in-app download.",
    "placeholders": {"url": {"type": "String"}}
  },
  "updatePackageSummary": "{name} · {images, plural, =1{1 image} other{{images} images}} · {bytes} bytes",
  "@updatePackageSummary": {
    "description": "Summary of the loaded package.",
    "placeholders": {
      "name": {"type": "String"},
      "images": {"type": "int"},
      "bytes": {"type": "int"}
    }
  },
  "updatePackageForUltra": "Built for the Chameleon Ultra.",
  "@updatePackageForUltra": {"description": "Package hardware version 0."},
  "updatePackageForLite": "Built for the Chameleon Lite.",
  "@updatePackageForLite": {"description": "Package hardware version 1."},
  "updatePackageForUnknown": "This package does not name a known model; the bootloader will decide.",
  "@updatePackageForUnknown": {"description": "Package hardware version is neither 0 nor 1."},
  "updateStart": "Install firmware",
  "@updateStart": {"description": "Starts the update."},
  "updateNoTarget": "Connect a device, or choose a device in the bootloader on the connect screen.",
  "@updateNoTarget": {"description": "Shown when there is nothing to update."},
  "updateTargetConnected": "Updating {name}.",
  "@updateTargetConnected": {
    "description": "Names the connected device the update will flash.",
    "placeholders": {"name": {"type": "String"}}
  },
  "updateStepChecking": "Checking the package",
  "@updateStepChecking": {"description": "DfuPhase.checking."},
  "updateStepBootloader": "Rebooting into the bootloader",
  "@updateStepBootloader": {"description": "DfuPhase.enteringBootloader."},
  "updateStepFindingBootloader": "Finding the bootloader",
  "@updateStepFindingBootloader": {"description": "DfuPhase.findingBootloader."},
  "updateStepTransferring": "Writing the firmware",
  "@updateStepTransferring": {"description": "DfuPhase.transferring."},
  "updateStepFindingDevice": "Waiting for the device",
  "@updateStepFindingDevice": {"description": "DfuPhase.findingDevice."},
  "updateStepDone": "Done",
  "@updateStepDone": {"description": "DfuPhase.done."},
  "updateProgressLabel": "Updating firmware",
  "@updateProgressLabel": {"description": "Label of the progress bar."},
  "updateProgressDetail": "{sent} of {total} bytes",
  "@updateProgressDetail": {
    "description": "Byte counter under the progress bar.",
    "placeholders": {"sent": {"type": "int"}, "total": {"type": "int"}}
  },
  "updateSucceeded": "Firmware installed.",
  "@updateSucceeded": {"description": "The update finished."},
  "updateDoNotDisconnect": "Keep the device connected and powered until this finishes.",
  "@updateDoNotDisconnect": {"description": "Shown while a flash is running."},
  "updateBleDisabled": "Bluetooth updates are switched off in this build. Update over USB.",
  "@updateBleDisabled": {"description": "A BLE bootloader was chosen while dfuOverBleEnabled is off."},
```

Create `app/lib/features/tools/state/update_steps.dart`:

```dart
import 'package:chameleon/chameleon.dart';

import '../../../l10n/app_localizations.dart';

/// The six `DfuPhase`s as step labels, in the order the orchestrator reports
/// them (`DfuOrchestrator`'s `DfuPhase` enum: checking, enteringBootloader,
/// findingBootloader, transferring, findingDevice, done).
List<String> updateStepLabels(AppLocalizations l10n) => <String>[
  l10n.updateStepChecking,
  l10n.updateStepBootloader,
  l10n.updateStepFindingBootloader,
  l10n.updateStepTransferring,
  l10n.updateStepFindingDevice,
  l10n.updateStepDone,
];

/// Where [phase] sits in [updateStepLabels]. Null — nothing reported yet —
/// is the first step, because the run is about to begin there.
int updateStepIndex(DfuPhase? phase) => switch (phase) {
  null => 0,
  DfuPhase.checking => 0,
  DfuPhase.enteringBootloader => 1,
  DfuPhase.findingBootloader => 2,
  DfuPhase.transferring => 3,
  DfuPhase.findingDevice => 4,
  DfuPhase.done => 5,
};
```

- [ ] **Step 4: Regenerate and run the tests**

Run:
```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter gen-l10n && flutter test test/features/tools/update_steps_test.dart
```
Expected: PASS. `flutter analyze` will still flag `comingSoonUpdate`'s removal at its call site in
`update_page.dart` — Task 10 rewrites that file; if this task must leave the tree green, replace
that one `Text(l10n.comingSoonUpdate)` line with `Text(l10n.updateNoTarget)` here and let Task 10
take it from there.

- [ ] **Step 5: Commit**

```bash
git add app/lib/l10n app/lib/features/tools/state/update_steps.dart app/test/features/tools/update_steps_test.dart app/lib/features/tools/ui/update_page.dart
git commit -m "feat: add the firmware-update strings

Single ARB writer for the phase. The step labels are the orchestrator's
six phases so the screen never invents a stage the SDK does not report."
```

---

## Task 10: the update screen — pick a package

**Files:**
- Modify: `app/lib/features/tools/ui/update_page.dart`
- Test: `app/test/features/tools/update_page_test.dart`

**Interfaces:**
- Consumes: `updateControllerProvider` and `UpdateState` (Task 7); `firmwareReleasesUrl`,
  `LoadedFirmwarePackage.{fileName, imageCount, totalBytes, targetModel}` (Task 5);
  `featureFlagsProvider`; `activeSessionProvider`, `ActiveSession.device`,
  `DiscoveredDevice.name`; `SubPageScaffold({required String title, required Widget body})`;
  `SpectraCard`, `SpectraButton({required String label, required VoidCallback? onPressed,
  SpectraButtonVariant variant, IconData? icon, bool busy})`, `SpectraTextField({required String
  label, TextEditingController? controller, String? hint, ValueChanged<String>? onChanged})`,
  `SpectraSectionHeader({required String title})`, `SpectraSpacing`; `ProblemView({required
  Object error, required VoidCallback onAction, String? instructions,
  SpectraButtonVariant? variant})`.
- Produces: `UpdatePage({String? recoverTransportId, Key? key})` — now a
  `ConsumerStatefulWidget` (it owns the path field's `TextEditingController`). The constructor
  signature is unchanged, so `app_sections.dart` needs no edit.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/tools/update_page_test.dart`:

```dart
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/app.dart';
import 'package:spectra/core/dfu/dfu_runtime.dart';
import 'package:spectra/core/errors/problem_view.dart';
import 'package:spectra/features/tools/state/firmware_package_source.dart';
import 'package:spectra/features/tools/state/update_controller.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../fixtures/dfu_package_fixture.dart';
import '../../support/app_harness.dart';

final class _MemorySource implements FirmwarePackageSource {
  _MemorySource(this.bytes);
  final Uint8List bytes;
  @override
  Future<Uint8List> read(String path) async => bytes;
}

Widget buildTestApp({required FirmwarePackageSource source}) => ProviderScope(
  overrides: <Override>[
    ...appOverrides(transport: (_) => FakeDevice()),
    firmwarePackageSourceProvider.overrideWithValue(source),
    dfuScanTimeoutProvider.overrideWithValue(const Duration(seconds: 2)),
  ],
  child: const SpectraRoot(),
);

void main() {
  testWidgetsApp('loading a package shows what it is', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      buildTestApp(source: _MemorySource(buildDfuZip(size: 4096))),
    );
    await tester.pump();
    await connectToEmulator(tester);
    await openUpdate(tester);

    expect(find.text('Firmware package'), findsOneWidget);
    expect(find.text('Install firmware'), findsOneWidget);

    await tester.enterText(
      find.byType(SpectraTextField).first,
      '/tmp/ultra-dfu-app.zip',
    );
    await tester.pump();
    await tester.tap(find.text('Load package'));
    await pumpFrames(tester);

    expect(find.textContaining('ultra-dfu-app.zip'), findsOneWidget);
    expect(find.text('Built for the Chameleon Ultra.'), findsOneWidget);
  });

  testWidgetsApp('a package that will not parse shows the problem', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      buildTestApp(source: _MemorySource(Uint8List.fromList(<int>[1, 2, 3]))),
    );
    await tester.pump();
    await connectToEmulator(tester);
    await openUpdate(tester);

    await tester.enterText(find.byType(SpectraTextField).first, 'broken.zip');
    await tester.pump();
    await tester.tap(find.text('Load package'));
    await pumpFrames(tester);

    expect(find.byType(ProblemView), findsOneWidget);
  });

  testWidgetsApp('with nothing connected the screen says so', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      buildTestApp(source: _MemorySource(buildDfuZip())),
    );
    await tester.pump();
    // No connect: routing allows /tools/update with no session (spec 5.6).
    expect(find.text('Install firmware'), findsNothing);
  });
}
```

(The last expectation is about the connect screen still being up; it is a cheap guard that the
route rule from Phase 4 has not moved.)

- [ ] **Step 2: Run the test to verify it fails**

Run: `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"; cd app && flutter test test/features/tools/update_page_test.dart`
Expected: FAIL — the page still renders the Phase 4 placeholder.

- [ ] **Step 3: Implement**

Rewrite `app/lib/features/tools/ui/update_page.dart`:

```dart
// `hide ConnectionState` on the material_ui side, as every other features/ui
// file that imports both does (e.g. features/cards/ui/read_page.dart).
import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/problem_view.dart';
import '../../../core/flags/feature_flags.dart';
import '../../../core/routing/sub_page_scaffold.dart';
import '../../../core/session/active_device.dart';
import '../../../l10n/app_localizations.dart';
import '../state/firmware_package_source.dart';
import '../state/update_controller.dart';

/// Firmware update (spec 7.7 step 6, 4.5, 5.6).
///
/// Two entry points: the Tools tab with a device connected, and the connect
/// screen's "Recover" action, which passes the bootloader's transport id in
/// [recoverTransportId] (Task 12 wires that half).
class UpdatePage extends ConsumerStatefulWidget {
  const UpdatePage({this.recoverTransportId, super.key});

  /// The bootloader a "Recover" action named, from `?recover=`.
  final String? recoverTransportId;

  @override
  ConsumerState<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends ConsumerState<UpdatePage> {
  final TextEditingController _path = TextEditingController();

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final UpdateState state = ref.watch(updateControllerProvider);
    final UpdateController controller = ref.read(
      updateControllerProvider.notifier,
    );
    final FeatureFlags flags = ref.watch(featureFlagsProvider);
    final LoadedFirmwarePackage? package = state.package;
    final String? deviceName = ref.watch(activeSessionProvider)?.device.name;
    final bool busy = state.running || state.loading;

    return SubPageScaffold(
      title: l10n.updateTitle,
      body: ListView(
        padding: const EdgeInsets.all(SpectraSpacing.lg),
        children: <Widget>[
          SpectraSectionHeader(title: l10n.updatePackageSection),
          SpectraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.updateReleasesHint(firmwareReleasesUrl)),
                const SizedBox(height: SpectraSpacing.md),
                SpectraTextField(
                  label: l10n.updatePackagePathLabel,
                  hint: l10n.updatePackagePathHint,
                  controller: _path,
                  enabled: !busy,
                ),
                const SizedBox(height: SpectraSpacing.md),
                SpectraButton(
                  label: l10n.updateLoadPackage,
                  variant: SpectraButtonVariant.secondary,
                  busy: state.loading,
                  onPressed: busy
                      ? null
                      : () => controller.loadPackage(_path.text),
                ),
              ],
            ),
          ),
          if (package != null) ...<Widget>[
            const SizedBox(height: SpectraSpacing.md),
            SpectraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.updatePackageSummary(
                      package.fileName,
                      package.imageCount,
                      package.totalBytes,
                    ),
                  ),
                  const SizedBox(height: SpectraSpacing.sm),
                  Text(switch (package.targetModel) {
                    DeviceModel.ultra => l10n.updatePackageForUltra,
                    DeviceModel.lite => l10n.updatePackageForLite,
                    null => l10n.updatePackageForUnknown,
                  }),
                ],
              ),
            ),
          ],
          if (state.error != null) ...<Widget>[
            const SizedBox(height: SpectraSpacing.md),
            ProblemView(
              error: state.error!,
              variant: SpectraButtonVariant.secondary,
              onAction: controller.reset,
            ),
          ],
          const SizedBox(height: SpectraSpacing.md),
          if (deviceName != null)
            SpectraCard(child: Text(l10n.updateTargetConnected(deviceName)))
          else
            SpectraCard(child: Text(l10n.updateNoTarget)),
          const SizedBox(height: SpectraSpacing.md),
          SpectraButton(
            label: l10n.updateStart,
            onPressed: package == null || busy || deviceName == null
                ? null
                : () => controller.start(),
          ),
          if (!flags.dfuOverBleEnabled) ...<Widget>[
            const SizedBox(height: SpectraSpacing.md),
            SpectraCard(child: Text(l10n.updateBleNotice)),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"; cd app && flutter test test/features/tools`
Expected: PASS. Also run `dart run melos run lint:strings` if it is a separate script (otherwise
`melos run check:all` covers it): every literal on this screen must come from the ARB.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/tools/ui/update_page.dart app/test/features/tools/update_page_test.dart
git commit -m "feat: pick and validate a firmware package on the update screen

A path, a Load button, and what the package turns out to be — the model
check the orchestrator will repeat, shown before anything is sent."
```

---

## Task 11: the update screen — run, progress, result, cancel

**Files:**
- Modify: `app/lib/features/tools/ui/update_page.dart`
- Test: `app/test/features/tools/update_page_test.dart`

**Interfaces:**
- Consumes: everything Task 10 consumes, plus `updateStepLabels(AppLocalizations)` /
  `updateStepIndex(DfuPhase?)` (Task 9), `SpectraStepIndicator({required List<String> steps,
  required int currentIndex, bool failed})`, `SpectraProgressIndicator({required String label,
  double? value, String? detail, VoidCallback? onCancel})`, `UpdateController.cancel`,
  `UpdateState.{running, completed, phase, progress, fraction}`.
- Produces: no new API; the same `UpdatePage`.

- [ ] **Step 1: Write the failing test**

Append to `app/test/features/tools/update_page_test.dart`:

```dart
  testWidgetsApp('a run shows the steps, the bar and a cancel', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      buildTestApp(source: _MemorySource(buildDfuZip(size: 8192))),
    );
    await tester.pump();
    await connectToEmulator(tester);
    await openUpdate(tester);

    await tester.enterText(
      find.byType(SpectraTextField).first,
      '/tmp/ultra-dfu-app.zip',
    );
    await tester.pump();
    await tester.tap(find.text('Load package'));
    await pumpFrames(tester);

    await tester.tap(find.text('Install firmware'));
    await tester.pump();
    // Mid-flight: the progress bar and the step indicator are up.
    expect(find.byType(SpectraProgressIndicator), findsOneWidget);
    expect(find.byType(SpectraStepIndicator), findsOneWidget);
    expect(find.text('Keep the device connected and powered until this finishes.'),
        findsOneWidget);

    await pumpFrames(tester, count: 80);
    expect(find.text('Firmware installed.'), findsOneWidget);
    expect(find.byType(SpectraProgressIndicator), findsNothing);
  });

  testWidgetsApp('a failed run shows the problem and offers a retry', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      buildTestApp(source: _MemorySource(buildDfuZip())),
    );
    await tester.pump();
    await connectToEmulator(tester);
    await openUpdate(tester);

    readProvider(tester, updateControllerProvider.notifier)
        .debugFail(DfuError('scripted failure'));
    await pumpFrames(tester);

    expect(find.byType(ProblemView), findsOneWidget);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"; cd app && flutter test test/features/tools/update_page_test.dart`
Expected: FAIL — no progress indicator, no step indicator, no success line.

- [ ] **Step 3: Implement**

In `update_page.dart`, insert between the target card and the Start button, and gate the Start
button on `!state.running`:

```dart
          if (state.running) ...<Widget>[
            SpectraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SpectraStepIndicator(
                    steps: updateStepLabels(l10n),
                    currentIndex: updateStepIndex(state.phase),
                  ),
                  const SizedBox(height: SpectraSpacing.md),
                  SpectraProgressIndicator(
                    label: l10n.updateProgressLabel,
                    // Null until the transfer reports its first byte count:
                    // the reboot and the two scans have no fraction to show,
                    // and an indeterminate bar says exactly that.
                    value: state.fraction,
                    detail: state.progress == null
                        ? null
                        : l10n.updateProgressDetail(
                            state.progress!.bytesSent,
                            state.progress!.bytesTotal,
                          ),
                    onCancel: controller.cancel,
                  ),
                  const SizedBox(height: SpectraSpacing.md),
                  Text(l10n.updateDoNotDisconnect),
                ],
              ),
            ),
            const SizedBox(height: SpectraSpacing.md),
          ],
          if (state.completed) ...<Widget>[
            SpectraCard(child: Text(l10n.updateSucceeded)),
            const SizedBox(height: SpectraSpacing.md),
          ],
```

The Start button becomes:

```dart
          if (!state.running)
            SpectraButton(
              label: l10n.updateStart,
              onPressed: package == null || busy || deviceName == null
                  ? null
                  : () => controller.start(),
            ),
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"; cd app && flutter test test/features/tools`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/tools/ui/update_page.dart app/test/features/tools/update_page_test.dart
git commit -m "feat: show DFU progress, the result and a cancel

The six orchestrator phases as a step indicator, the byte counter as a
bar, and one cancel that goes through the CancelToken so a stopped
transfer leaves a device that can be recovered."
```

---

## Task 12: the recovery flow

Spec 5.5: *bootloader devices appear on the connect screen with a "recover" action that starts the
DFU orchestrator directly.* Phase 4 landed the route (`AppRoutes.recover(transportId)` →
`/tools/update?recover=…`); this task makes the screen act on it.

**Files:**
- Modify: `app/lib/features/tools/ui/update_page.dart`
- Create: `app/lib/features/tools/state/recover_target.dart`
- Test: `app/test/features/tools/update_recovery_test.dart`

**Interfaces:**
- Consumes: `discoveryProvider` (`AsyncValue<DiscoveryState>`, `DiscoveryState.devices`),
  `DiscoveredDevice.{transportId, isBootloader, kind, name}`, `updateControllerProvider`,
  `FakeScanner.emulatedBootloader`, harness `pumpTestAppWithBootloader`, `StaticScanner`.
- Produces: `DiscoveredDevice? recoverTarget(List<DiscoveredDevice> devices, String?
  transportId)` in `recover_target.dart` — the pure rule, tested without a widget tree.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/tools/update_recovery_test.dart`:

```dart
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/app.dart';
import 'package:spectra/core/dfu/dfu_runtime.dart';
import 'package:spectra/features/tools/state/firmware_package_source.dart';
import 'package:spectra/features/tools/state/recover_target.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../fixtures/dfu_package_fixture.dart';
import '../../support/app_harness.dart';

final class _MemorySource implements FirmwarePackageSource {
  _MemorySource(this.bytes);
  final Uint8List bytes;
  @override
  Future<Uint8List> read(String path) async => bytes;
}

void main() {
  group('recoverTarget', () {
    const bootloader = DiscoveredDevice(
      name: 'CU',
      kind: TransportKind.usb,
      transportId: '/dev/tty.usb',
      isBootloader: true,
    );
    const application = DiscoveredDevice(
      name: 'ChameleonUltra',
      kind: TransportKind.usb,
      transportId: '/dev/tty.app',
    );

    test('finds the named bootloader', () {
      expect(
        recoverTarget(<DiscoveredDevice>[application, bootloader], '/dev/tty.usb'),
        bootloader,
      );
    });

    test('refuses a device that is not a bootloader', () {
      expect(
        recoverTarget(<DiscoveredDevice>[application], '/dev/tty.app'),
        isNull,
      );
    });

    test('null id, or nothing visible, is no target', () {
      expect(recoverTarget(<DiscoveredDevice>[bootloader], null), isNull);
      expect(recoverTarget(const <DiscoveredDevice>[], '/dev/tty.usb'), isNull);
    });
  });

  testWidgetsApp('recovering the emulated bootloader flashes it', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ...appOverrides(
            transport: (_) => FakeDevice(),
            scanners: <DeviceScanner>[
              const StaticScanner(<DiscoveredDevice>[
                FakeScanner.emulatedBootloader,
              ]),
            ],
          ),
          firmwarePackageSourceProvider.overrideWithValue(
            _MemorySource(buildDfuZip(size: 4096)),
          ),
          dfuScanTimeoutProvider.overrideWithValue(const Duration(seconds: 2)),
        ],
        child: const SpectraRoot(),
      ),
    );
    await pumpFrames(tester);

    // The connect screen offers "Recover" for a bootloader row (spec 5.5).
    await tester.tap(find.text('Recover'));
    await pumpFrames(tester);
    expect(find.text('Firmware package'), findsOneWidget);

    await tester.enterText(
      find.byType(SpectraTextField).first,
      '/tmp/ultra-dfu-app.zip',
    );
    await tester.pump();
    await tester.tap(find.text('Load package'));
    await pumpFrames(tester);

    await tester.tap(find.text('Install firmware'));
    await pumpFrames(tester, count: 80);

    expect(find.text('Firmware installed.'), findsOneWidget);
  });
}
```

(If the connect row's action label is not exactly `Recover`, read it from the ARB key
`connectRecover` — do not change the copy.)

- [ ] **Step 2: Run the test to verify it fails**

Run: `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"; cd app && flutter test test/features/tools/update_recovery_test.dart`
Expected: FAIL — `recover_target.dart` does not exist and the page ignores `recoverTransportId`.

- [ ] **Step 3: Implement**

Create `app/lib/features/tools/state/recover_target.dart`:

```dart
import 'package:chameleon/chameleon.dart';

/// The bootloader a `?recover=` link names, if it is still visible.
///
/// Only a device flagged `isBootloader` qualifies: the query parameter comes
/// off a URL and a run started against a device in application mode would
/// hang on a channel that never answers.
DiscoveredDevice? recoverTarget(
  List<DiscoveredDevice> devices,
  String? transportId,
) {
  if (transportId == null) return null;
  for (final device in devices) {
    if (device.transportId == transportId && device.isBootloader) return device;
  }
  return null;
}
```

In `update_page.dart`: resolve the target, prefer it over the connected device, and pass it to
`start`.

```dart
    final DiscoveredDevice? recover = recoverTarget(
      ref.watch(discoveryProvider).value?.devices ?? const <DiscoveredDevice>[],
      widget.recoverTransportId,
    );
    final String? targetName = recover?.name ?? deviceName;
```

- the target card becomes
  `targetName != null ? Text(l10n.updateTargetConnected(targetName)) : Text(l10n.updateNoTarget)`,
  and when `widget.recoverTransportId != null` the existing
  `Text(l10n.updateRecoverTarget(widget.recoverTransportId!))` and
  `Text(l10n.updateRecoverInstructions)` cards stay (Phase 4 wrote both keys);
- the Start button's guard becomes `package == null || busy || targetName == null`;
- the tap becomes `() => controller.start(bootloader: recover)` — null for the connected path,
  which is exactly what `UpdateController.start` expects.

Add the import of `../../../core/discovery/discovery_provider.dart` and of `recover_target.dart`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"; cd app && flutter test test/features/tools`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/tools app/test/features/tools/update_recovery_test.dart
git commit -m "feat: flash a device found already in its bootloader

Spec 5.6's guarantee, end to end: the connect screen's Recover action
names a bootloader, the update screen resolves it against what is visible
and runs the orchestrator straight at it, with no session involved."
```

---

## Task 13: the phase gate — flow and integration tests

Roadmap gate: *integration test on the fake bootloader over both channel types.* Task 4 covered
both channel types at the channel level; this task covers the app flow, as a widget test and on a
real engine.

**Files:**
- Create: `app/test/flows/firmware_update_flow_test.dart`
- Create: `app/integration_test/firmware_update_flow_test.dart`

**Interfaces:**
- Consumes: the harness (`appOverrides`, `pumpFrames`, `testApp`, `useDesktopSurface`,
  `connectToEmulator`, `openUpdate`, `StaticScanner`, `testWidgetsApp`), `integration_test`
  support re-export, `buildDfuZip`, `firmwarePackageSourceProvider`, `dfuScanTimeoutProvider`,
  `FakeScanner.{emulatedUltra, emulatedBootloader}`.
- Produces: the gate. Nothing imports it.

- [ ] **Step 1: Write the failing tests**

`app/test/flows/firmware_update_flow_test.dart`:

```dart
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/app.dart';
import 'package:spectra/core/dfu/dfu_runtime.dart';
import 'package:spectra/features/tools/state/firmware_package_source.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../fixtures/dfu_package_fixture.dart';
import '../support/app_harness.dart';

final class _MemorySource implements FirmwarePackageSource {
  _MemorySource(this.bytes);
  final Uint8List bytes;
  @override
  Future<Uint8List> read(String path) async => bytes;
}

Widget _app({List<DeviceScanner>? scanners}) => ProviderScope(
  overrides: <Override>[
    ...appOverrides(transport: (_) => FakeDevice(), scanners: scanners),
    firmwarePackageSourceProvider.overrideWithValue(
      _MemorySource(buildDfuZip(size: 8192)),
    ),
    dfuScanTimeoutProvider.overrideWithValue(const Duration(seconds: 2)),
  ],
  child: const SpectraRoot(),
);

Future<void> _loadAndStart(WidgetTester tester) async {
  await tester.enterText(
    find.byType(SpectraTextField).first,
    '/tmp/ultra-dfu-app.zip',
  );
  await tester.pump();
  await tester.tap(find.text('Load package'));
  await pumpFrames(tester);
  await tester.tap(find.text('Install firmware'));
  await pumpFrames(tester, count: 100);
}

void main() {
  testWidgetsApp('update a connected device end to end', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(_app());
    await tester.pump();
    await connectToEmulator(tester);
    await openUpdate(tester);

    await _loadAndStart(tester);

    expect(find.text('Firmware installed.'), findsOneWidget);
  });

  testWidgetsApp('recover a device left in the bootloader', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      _app(
        scanners: <DeviceScanner>[
          const StaticScanner(<DiscoveredDevice>[
            FakeScanner.emulatedBootloader,
          ]),
        ],
      ),
    );
    await pumpFrames(tester);

    await tester.tap(find.text('Recover'));
    await pumpFrames(tester);
    await _loadAndStart(tester);

    expect(find.text('Firmware installed.'), findsOneWidget);
  });
}
```

`app/integration_test/firmware_update_flow_test.dart` — the same connected-device flow on a real
engine, through `support.dart` (never a second override block):

```dart
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/app.dart';
import 'package:spectra/core/dfu/dfu_runtime.dart';
import 'package:spectra/features/tools/state/firmware_package_source.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../test/fixtures/dfu_package_fixture.dart';
import 'support.dart';

final class _MemorySource implements FirmwarePackageSource {
  _MemorySource(this.bytes);
  final Uint8List bytes;
  @override
  Future<Uint8List> read(String path) async => bytes;
}

/// The Phase 8 gate on a real engine: flash the fake bootloader in emulator
/// mode. No hardware is touched, and none is needed.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('update the emulated device', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ...appOverrides(transport: (_) => FakeDevice()),
          firmwarePackageSourceProvider.overrideWithValue(
            _MemorySource(buildDfuZip(size: 8192)),
          ),
          dfuScanTimeoutProvider.overrideWithValue(const Duration(seconds: 2)),
        ],
        child: const SpectraRoot(),
      ),
    );
    Future<void> settle([int frames = 20]) => pumpFrames(tester, count: frames);

    await tester.pump();
    await tester.tap(find.text(FakeScanner.emulatedUltra.name));
    await settle(30);
    expect(find.byType(SpectraAppShell), findsOneWidget);

    await tester.tap(find.text('Tools').last);
    await settle();
    await tester.tap(find.text('Firmware update'));
    await settle();

    await tester.enterText(
      find.byType(SpectraTextField).first,
      '/tmp/ultra-dfu-app.zip',
    );
    await tester.pump();
    await tester.tap(find.text('Load package'));
    await settle();
    await tester.tap(find.text('Install firmware'));
    await settle(100);

    expect(find.text('Firmware installed.'), findsOneWidget);
  });
}
```

`integration_test/support.dart` re-exports `appOverrides, pumpFrames, testApp`; if `StaticScanner`
is needed there later, widen that `show` clause rather than importing the harness twice.

- [ ] **Step 2: Run the flow test to verify it fails**

Run: `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"; cd app && flutter test test/flows/firmware_update_flow_test.dart`
Expected: FAIL only if Tasks 5–12 left a gap; the flow is meant to pass on landed code. Diagnose
any failure as a defect, not a test to soften.

- [ ] **Step 3: Fix whatever the flow exposes**

Most likely candidates, in order: the pump budget (widen `count:`, never `pumpAndSettle`); the
scan after the flash not finding the device (check `dfuScanners` picked
`FakeScanner.forDevice`); the reconnect leaving the router on the connect screen (the flash still
succeeded — assert on the success card, which is what the gate is about).

- [ ] **Step 4: Run both levels**

Run:
```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/flows/firmware_update_flow_test.dart
cd app && flutter test integration_test/firmware_update_flow_test.dart -d macos
```
Expected: PASS at both levels.

- [ ] **Step 5: Commit**

```bash
git add app/test/flows/firmware_update_flow_test.dart app/integration_test/firmware_update_flow_test.dart
git commit -m "test: the Phase 8 gate, both entry points

Flash a connected emulated device and recover one left in its bootloader,
as a flow test and on a real engine. The channel half of the gate is
packages/chameleon_flutter/test/dfu/dfu_channel_flash_test.dart."
```

---

## Task 14: close-out

**Files:**
- Modify: `docs/hardware-checklist.md`, `docs/research/DECISIONS.md`, `AGENTS.md`,
  `tasks/lessons.md`, `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md`

**Interfaces:**
- Consumes: everything above. Produces: no code.

- [ ] **Step 1: Extend H2 in `docs/hardware-checklist.md`**

Keep every existing H2 item (they are still pending), amend the two Phase 8 changed:

- the serial `maxDataWrite` item: strike "`SecureDfu` has no GetSerialMTU request yet" and replace
  with "`SlipSerialDfuChannel.open()` now asks with opcode `0x07` and sizes from the answer,
  capped by the transport's write limit; **report the MTU the real bootloader returns and the
  chunk it produces**, and confirm a full image transfers at that size."

and add, under "USB first — BLE and iOS are blocked on the flag":

```markdown
- [ ] pending: **USB first.** Flash a real Ultra over USB from macOS with a
      release zip downloaded by hand (`ultra-dfu-app.zip`): Tools → Firmware
      update, paste the path, Load package, Install firmware. Expect the model
      line to say "Built for the Chameleon Ultra", the six steps to advance in
      order, and the app to reconnect on its own afterwards. Report the app
      version shown on the dashboard before and after.
- [ ] pending: a package built for the *other* model is refused before
      anything is sent (`DfuOrchestrator._checkModel`). Try `lite-dfu-app.zip`
      against the Ultra and confirm the failure names the mismatch and the
      device never reboots.
- [ ] pending: the wakelock is held and navigation is locked for the whole
      flash (spec 5.6): the screen does not sleep, and the tab bar does not
      navigate away mid-transfer.
- [ ] pending: cancel mid-transfer leaves the device in the bootloader and the
      same package finishes it on a second run (the resume path).
- [ ] **blocked on the flag:** BLE DFU. Everything below stays untested until
      USB DFU above passes; only then flip `dfuOverBleEnabled` (Settings, or
      the `flag.dfuOverBleEnabled` preference) and run: BLE DFU completes;
      then a deliberately interrupted BLE DFU is recovered over USB. iOS DFU
      is gated with BLE — iOS has no serial transport (spec 5.4), so it has no
      USB path of its own and must not be enabled before both BLE items pass.
```

- [ ] **Step 2: Record the decisions**

In `docs/research/DECISIONS.md`, a Phase 8 section: the local-zip resolution and its three
reasons (verbatim from this plan's "Resolved spec ambiguity"), the release feed deferred to Phase
10, the GetSerialMTU negotiation and its nrfutil source, and the `dfuActivityProvider` /
`redirectFor(updating:)` lock.

- [ ] **Step 3: Update `AGENTS.md` and the roadmap**

`AGENTS.md` "Current status": Phase 8 complete — firmware update over a local nrfutil package,
both entry points, USB enabled and BLE/iOS behind `dfuOverBleEnabled` (still off, H2 pending);
next is Phase 9. Roadmap: tick `- [x] Phase 8`.

- [ ] **Step 4: Lessons and the full check**

Add this phase's lessons to `tasks/lessons.md`, then run:

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd /Users/bcraig/orca/workspaces/spectra/chinook && dart run melos run check:all
```
Expected: green.

- [ ] **Step 5: Commit**

```bash
git add docs AGENTS.md tasks/lessons.md
git commit -m "docs: close out Phase 8

H2 gains the flow-level USB items and states plainly that BLE and iOS
stay blocked on the flag until USB DFU passes on hardware."
```

---

## Self-review notes (for the executor)

- **Spec coverage.** 4.5 → Tasks 1, 2, 6, 7. 5.3 → Tasks 3, 4, 6. 5.5 → Task 12. 5.6 → Tasks 6
  (flag gate), 8 (wakelock + lock), 12 (recovery), 14 (H2 order). 7.2 → Task 8. 7.4 → Task 8.
  7.6 → Task 9. 7.7 step 6 → Tasks 5, 7, 10, 11, 12 (release feed deferred; see the resolved
  ambiguity). 9 → `ProblemView` + the existing `DfuError` catalog entry (Tasks 10, 11). 10 →
  Tasks 4, 13.
- **Names.** Every symbol used here is either quoted from a landed file in this plan or defined in
  an Interfaces block. The only names the plan *creates* are: `DfuSerialMtu`, `DfuOp.getSerialMtu`,
  `FakeBootloader.{serialMtu, supportsSerialMtu}`, `SlipSerialDfuChannel.{negotiateMtu, mtuTimeout}`,
  `firmwareReleasesUrl`, `FirmwarePackageSource`, `FileFirmwarePackageSource`,
  `firmwarePackageSourceProvider`, `LoadedFirmwarePackage`, `loadFirmwarePackage`, `buildDfuZip`,
  `buildBin`, `buildInitPacket`, `DfuActivity`/`dfuActivityProvider`, `dfuScanTimeoutProvider`,
  `emulatorBootloaderProvider`, `DfuTarget`, `dfuChannelOpenerProvider`, `dfuScannersProvider`,
  `UpdateState`, `UpdateController`/`updateControllerProvider`, `updateStepLabels`,
  `updateStepIndex`, `recoverTarget`, and the ARB keys listed in Task 9.
- **Byte layouts.** `GetSerialMTU` (opcode, uint16 LE, `(mtu - 1) // 2 - 1`) cites nrfutil's
  `dfu_transport_serial.py`; the WriteObject frame cites `slip_serial_dfu_channel.dart`'s own
  header; the init-packet hash order cites `dfu_package.dart`; the bootloader ids and advertised
  names cite `docs/research/chameleon-protocol.md`, "DFU", via `ble_uuids.dart`.
