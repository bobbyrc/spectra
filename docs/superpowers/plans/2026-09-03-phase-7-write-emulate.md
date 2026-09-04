# Phase 7: Write and emulate — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Spec 7.7 step 5 — load a saved card into one of the device's eight slots, write a saved card back onto a physical card for the types the SDK supports, and emulate a card straight off the read screen in one step.

**Architecture:** No new feature module. All three flows start from a card the user is already looking at (a saved card on `/cards/:id`, or the result on `/cards/read`), so they land in `app/lib/features/cards/` as new `state/` controllers under new `ui/` sheets, and reach the device through the SDK facades the session already exposes. The one cross-feature need — "which slot?" — is the Slots feature's published `showSlotPicker`, imported through `features/slots/slots.dart`, which is exactly what spec 8.3 defines barrels for and what that function's own doc comment says Phase 7 will call. **The dependency runs one way, `cards → slots`, and it must stay that way:** a symmetric entry from the slot editor would need `slots → cards` for `showCardPicker` and make the two barrels mutually recursive, so this phase does not add one (`showCardPicker`, landed in Phase 6 Task 11, stays the published API for a later phase). Two SDK gaps are filled first, in `packages/chameleon`, because app code may never build a `Command`: `ReaderFacade.mf1WriteDump` (the mirror of the landed `mf1ReadDump`) and `ReaderFacade.em410xWriteToT55xx` (the facade method for the already-landed `Em410xWriteToT55xx` command), plus the fake handler that makes the second one testable.

**Tech Stack:** Flutter 3.47.2 / Dart 3.13, riverpod 3.4.2 + riverpod_generator 4.0.8, go_router 18, `material_ui` 1.1.1, `package:spectra_ui`, `package:chameleon` (`SlotsFacade`, `EmulatorFacade`, `ReaderFacade`, `DumpFormats`, `MifareGeometry`, `FakeDevice`).

**Spec:** `docs/superpowers/specs/2026-09-02-spectra-design.md` (sections 4.3, 6.2, 7.4, 7.7 step 5, 8.1, 8.3–8.6, 9, 10). Roadmap row: `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md`, Phase 7 — deliverable "Load to slot, write to card, quick emulate", gate "integration test on emulator".

## Global Constraints

Every task's requirements implicitly include this section.

- Toolchain: Flutter 3.47.2 / Dart 3.13, pinned by `mise.toml`. On this Mac `mise x --` is not enough, because fvm's Dart precedes it on PATH. Prefix every shell command that runs `dart`, `flutter` or `melos` with:
  `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"`
- TDD for every task: failing test, run it and watch it fail, minimal code, run it and watch it pass, commit. Commit messages: imperative subject, short body explaining why, trailer:
  ```
  Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
  ```
- `dart run melos run check:all` must be green at every commit. **Foreground test runs only** — never background a test command.
- This is a git worktree. Never use bare `git stash`.
- Generated code (riverpod_generator, drift, freezed) is committed. After adding or changing an `@riverpod` provider, run `cd app && dart run build_runner build --delete-conflicting-outputs` and commit the `.g.dart` files. `tool/check_codegen.sh` must pass.
- Package boundaries are enforced by `tool/dep_lint.dart` (`dart run melos run lint:deps`): `app/lib/features/*` may not import another feature's internals — **only `features/<other>/<other>.dart`**, the barrel — may not import `package:flutter/material.dart`, and may not import Drift outside `lib/data/`. Nothing outside `chameleon` may import `package:chameleon/src/...` (tests *inside* `packages/chameleon` may, and the landed session tests do).
- **`material_ui` only** under `app/lib/features/**`: `import 'package:material_ui/material_ui.dart';`, with `hide ConnectionState` on any features file that also imports `package:chameleon/chameleon.dart` (both libraries declare that name). Never leave an unused `package:chameleon` import behind — `melos run analyze` fails on warnings (Phase 6 ruling 3).
- All user-facing copy goes through `app/lib/l10n/app_en.arb` and `flutter gen-l10n`. The string-literal lint (`tool/src/string_rules.dart`) scans `lib/features/*/ui/` at any depth; `state/` is out of scope. **Technical field names are exempt** the way tag-type product names are: see `app/lib/core/format/tag_labels.dart`'s doc comment.
- **The ARB is a single-writer resource.** Tasks that append to `app_en.arb` are serialised: never run two of them concurrently. Each such task runs `cd app && flutter gen-l10n` and commits the regenerated `app/lib/l10n/app_localizations*.dart` alongside its ARB edit. In this plan the ARB-owning tasks are **4, 6, 9, 10** — in that order, one at a time.
- **Tag types reaching the UI go through `tagTypeLabel(type, l10n)`** (`core/format/tag_labels.dart`), never `TagType.name` (Phase 6 ruling 5).
- **One shared `ProblemView`** (`app/lib/core/errors/problem_view.dart`, R27). No per-feature or per-sheet copy of the catalog lookup, the disclosure and the recovery-label switch. Its signature is `ProblemView({required Object error, required VoidCallback onAction, String? instructions, SpectraButtonVariant? variant})`.
- Riverpod 3.4.2 API notes:
  - `Override` and `ProviderListenable` come from `package:flutter_riverpod/misc.dart`, not the main library.
  - There is no `valueOrNull`. Use `.value` on an `AsyncValue` (null while loading).
  - Do not read `state` inside `ref.onDispose` — the element is already torn down. Mirror what you need in a field.
  - `Notifier.state` is `@visibleForTesting @protected`; assigning it from a test is an analyzer warning and `melos run analyze` fails on warnings. A notifier that needs a test to force a failure ships `@visibleForTesting void debugFail(Object error)` (Phase 5 ruling 3).
  - **R25 / Phase 6 ruling 2: guard every post-`await` `state =` with `ref.mounted`.** Every notifier in this phase is autoDispose and every one of them lives under a sheet the user can dismiss mid-write; the device write still runs to completion, there is simply no longer anywhere to report it.
  - **Ruling 20 (Phase 4):** an autoDispose stream/async provider read outside a mounted app needs `keepAlive(tester, provider)` held first, then a pump, then the read.
  - **Ruling 22 (Phase 5):** `FakeDevice` replies via a real `Timer` — *start* the operation, *pump*, then *await*. Never `await` before pumping.
- **Drop, do not queue** (the `SlotEditor` pattern): a controller that mutates the device guards re-entry with a plain `bool _inFlight` field, distinct from `state.isLoading`/`state.busy`, and the screen disables its controls while busy so a dropped call is never the only thing between a tap and the change it was meant to make. A notifier that needs a test to force a failure ships `@visibleForTesting void debugFail(Object error)`.
- A new `DeviceSession` is constructed per connect attempt; sessions are single-use. Tests pass `transport: (_) => FakeDevice()` — a fresh fake per attempt.
- **The test harness (`app/test/support/app_harness.dart`) is edited by nobody this phase.** Use its `testWidgetsApp`, `pumpTestApp`, `connectToEmulator`, `keepAlive`, `readProvider`, `pumpFrames(tester, count: …)` (Phase 6 ruling 7 — never a local positional copy), `useDesktopSurface(tester)` (ruling 8 — never the three-line `tester.view` incantation), `openSlots`, `openSlot`.
- **Finders inside an open sheet are `find.descendant`-scoped** to `find.byType(SpectraBottomSheet)`; no `.first`/`.at(n)` index arithmetic across the whole tree (Phase 6 ruling 10).
- Integration tests reuse the shared override list through `app/integration_test/support.dart`, which re-exports `appOverrides`, `pumpFrames` and `testApp` from the harness (Phase 6 ruling 9). Never inline a fourth copy of the override block.
- **Cite landed source for every name you use.** If a symbol in this plan does not match the landed code, the landed code wins — report it rather than inventing an adapter. Phase 6 is landing concurrently in `app/lib/features/cards/**`; Tasks 7, 9 and 10 modify files that phase also touched, so **read the file as it stands before editing and add to it — never paste a whole file over the top.**
- **No wakelock code in this phase, and there must not be any.** Spec 7.4's "hold the screen awake during a flash or a reader lease" is already satisfied: `sessionNeedsWakelock` (`app/lib/core/lifecycle/wakelock.dart`) polls `session.readerLeaseCount > 0 || session.isBusy`, every `ReaderFacade` method takes its own lease, `mf1ReadDump`/`mf1WriteDump` wrap the whole run in one lease *and* one `DeviceSession.busy`, and every `SlotsFacade` mutation except `setActive` runs inside `busy`. The load-to-slot controller's long stretch is covered because `EmulatorFacade.writeMf1Blocks` and `readMf1Blocks` run inside `busy` too.
- **Never claim hardware behaviour works.** Writing a **physical** card is `hardware-validate`: it is proven only against `FakeDevice` here. Every such claim gets a `hardware-validate` note in the doc comment and a checkbox in `docs/hardware-checklist.md` (Task 13). The write-to-card sheet shows a standing "not verified on hardware yet" notice.

## File structure

New, in `packages/chameleon`:

| File | Responsibility |
|---|---|
| `lib/src/dump/mf1_dump_write_result.dart` | `Mf1DumpWriteResult`: what one dump write put onto the card |
| `test/session/reader_write_test.dart` | `mf1WriteDump` and `em410xWriteToT55xx` against `FakeDevice` |

New, in `app/lib/`:

| File | Responsibility |
|---|---|
| `core/errors/app_failures.dart` | `SlotLoadVerificationFailed` — the app's own typed failure for a read-back mismatch |
| `features/cards/state/write_target.dart` | Pure: which write/load method a `TagType` supports, the slot nickname for a card name, the anti-collision a Classic dump implies |
| `features/cards/state/load_to_slot_controller.dart` | `SlotLoader` notifier: select, set type, write emulator data, name, enable, verify |
| `features/cards/state/write_card_controller.dart` | `CardWriter` notifier: write a dump onto a physical card, progress, cancel |
| `features/cards/ui/load_to_slot_sheet.dart` | `showLoadToSlotSheet`: confirm, progress, done, error |
| `features/cards/ui/write_card_sheet.dart` | `showWriteToCardSheet`: hardware notice, confirm, progress + cancel, summary |

New tests:

| File | Responsibility |
|---|---|
| `app/test/features/cards/write_target_test.dart` | The pure functions |
| `app/test/features/cards/load_to_slot_test.dart` | The controller and the sheet against `FakeDevice` |
| `app/test/features/cards/write_card_test.dart` | The controller and the sheet against `FakeDevice` |
| `app/test/flows/write_emulate_flow_test.dart` | Read → save → load into a slot, through the app |
| `app/integration_test/load_to_slot_flow_test.dart` | **The phase gate**, on a real engine |

Modified: `packages/chameleon/lib/chameleon.dart`, `packages/chameleon/lib/src/session/facades/reader.dart`, `packages/chameleon/lib/src/fake/fake_reader_handlers.dart`, `app/lib/core/errors/error_catalog.dart`, `app/lib/features/cards/state/default_keys.dart`, `app/lib/features/cards/ui/card_detail_page.dart`, `app/lib/features/cards/ui/read_page.dart`, `app/lib/l10n/app_en.arb`, `docs/hardware-checklist.md`, `AGENTS.md`, `tasks/lessons.md`, `docs/research/DECISIONS.md`, `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md`.

---

### Task 1: `ReaderFacade.mf1WriteDump`

Spec 8.1: "app code never sends raw commands", and "multi-command workflows are one method". Writing a whole MIFARE Classic is the mirror of the landed `mf1ReadDump` (`packages/chameleon/lib/src/session/facades/reader.dart`): find one key per sector from the caller's dictionary, then write the blocks that may be written, under one reader lease and one `DeviceSession.busy`.

**Files:**
- Create: `packages/chameleon/lib/src/dump/mf1_dump_write_result.dart`
- Modify: `packages/chameleon/lib/src/session/facades/reader.dart`, `packages/chameleon/lib/chameleon.dart`
- Test: `packages/chameleon/test/session/reader_write_test.dart`

**Interfaces:**
- Consumes (all landed, all in `reader.dart` already): the private `_keysForDump(int sectors, List<Uint8List> candidateKeys, CancelToken? cancel) → Future<List<SectorKeys>>`, `_throwIfCancelled(CancelToken?)`, `DeviceSession.send`, `DeviceSession.withReaderMode`, `DeviceSession.busy`; `MifareGeometry.sectorCount/blockCount/firstBlockOf/blocksInSector/trailerOf`; the command `Mf1WriteOneBlock(KeyType type, int block, Uint8List key, Uint8List data)` (`lib/src/commands/hf_reader.dart`); `SectorKeys` and `KeyType` from the model; `DeviceError` from `lib/src/protocol/errors.dart`.
- Produces, relied on by Tasks 8 and 9:
  - `final class Mf1DumpWriteResult` with `Mf1DumpWriteResult({required List<bool> writeMask, required List<bool> attemptMask, required List<SectorKeys> keys})`, and getters `int get blockCount`, `int get writtenBlockCount`, `int get attemptedBlockCount`, `int get failedBlockCount`, `bool get isComplete`.
  - `Future<Mf1DumpWriteResult> ReaderFacade.mf1WriteDump({required TagType type, required Uint8List blocks, required List<Uint8List> candidateKeys, bool writeTrailers = false, void Function(int done, int total)? onProgress, CancelToken? cancel})`.
  - Both exported from `package:chameleon/chameleon.dart`.

- [ ] **Step 1: Write the failing test**

```dart
// packages/chameleon/test/session/reader_write_test.dart
import 'dart:typed_data';

import 'package:chameleon/src/fake/fake_card.dart';
import 'package:chameleon/src/fake/fake_device.dart';
import 'package:chameleon/src/model/enums.dart';
import 'package:chameleon/src/session/device_session.dart';
import 'package:test/test.dart';

import 'session_helpers.dart';

Uint8List b(List<int> l) => Uint8List.fromList(l);

/// A 1K dump whose every data block is filled with [fill], with a valid
/// block 0 (UID + BCC) and the transport trailers a blank card ships with.
Uint8List dump1k(int fill) {
  final Uint8List blocks = Uint8List(64 * 16);
  for (int block = 0; block < 64; block++) {
    if (block % 4 == 3 || block == 0) continue;
    blocks.fillRange(block * 16, block * 16 + 16, fill);
  }
  return blocks;
}

void main() {
  late FakeDevice device;
  late DeviceSession s;

  setUp(() async {
    device = FakeDevice();
    s = sessionFor(device);
    await s.open();
    await awaitBackgroundLoad(s);
  });

  tearDown(() => s.close());

  test('mf1WriteDump writes every data block and skips block 0', () async {
    final FakeMf1Card card = FakeMf1Card.classic1k(
      uid: b(<int>[0x11, 0x22, 0x33, 0x44]),
    );
    device.firmware.present(card);

    final result = await s.reader.mf1WriteDump(
      type: TagType.mifare1k,
      blocks: dump1k(0xAB),
      candidateKeys: <Uint8List>[FakeMf1Card.defaultKey],
    );

    // 64 blocks, minus block 0 and the 16 trailers = 47 attempted.
    expect(result.blockCount, 64);
    expect(result.attemptedBlockCount, 47);
    expect(result.writtenBlockCount, 47);
    expect(result.failedBlockCount, 0);
    expect(result.isComplete, isTrue);
    expect(result.writeMask[0], isFalse);
    expect(result.writeMask[3], isFalse); // trailer of sector 0
    expect(card.blocks.sublist(16, 32), everyElement(0xAB));
    // Block 0 was left exactly as the card had it.
    expect(card.blocks.sublist(0, 4), b(<int>[0x11, 0x22, 0x33, 0x44]));
  });

  test('mf1WriteDump writes trailers when asked', () async {
    final FakeMf1Card card = FakeMf1Card.classic1k(uid: b(<int>[1, 2, 3, 4]));
    device.firmware.present(card);
    final Uint8List blocks = dump1k(0x01);
    blocks.fillRange(3 * 16, 4 * 16, 0x77);

    final result = await s.reader.mf1WriteDump(
      type: TagType.mifare1k,
      blocks: blocks,
      candidateKeys: <Uint8List>[FakeMf1Card.defaultKey],
      writeTrailers: true,
    );

    expect(result.attemptedBlockCount, 63);
    expect(card.blocks.sublist(3 * 16, 4 * 16), everyElement(0x77));
  });

  test('a sector with no known key fails its blocks, not the run', () async {
    final FakeMf1Card card = FakeMf1Card.classic1k(uid: b(<int>[1, 2, 3, 4]));
    // Lock sector 1 behind a key the dictionary does not carry.
    card.keys[FakeMf1Card.keyId(1, KeyType.a)] = b(<int>[9, 9, 9, 9, 9, 9]);
    card.keys[FakeMf1Card.keyId(1, KeyType.b)] = b(<int>[9, 9, 9, 9, 9, 9]);
    device.firmware.present(card);

    final result = await s.reader.mf1WriteDump(
      type: TagType.mifare1k,
      blocks: dump1k(0x5A),
      candidateKeys: <Uint8List>[FakeMf1Card.defaultKey],
    );

    expect(result.isComplete, isFalse);
    expect(result.failedBlockCount, 3); // blocks 4, 5, 6
    expect(result.writeMask[4], isFalse);
    expect(result.writeMask[8], isTrue);
    expect(card.blocks.sublist(4 * 16, 5 * 16), everyElement(0x00));
  });

  test('mf1WriteDump reports progress per sector and ends in emulator mode', () async {
    device.firmware.present(
      FakeMf1Card.classic1k(uid: b(<int>[1, 2, 3, 4])),
    );
    final List<(int, int)> seen = <(int, int)>[];

    await s.reader.mf1WriteDump(
      type: TagType.mifare1k,
      blocks: dump1k(0x10),
      candidateKeys: <Uint8List>[FakeMf1Card.defaultKey],
      onProgress: (int done, int total) => seen.add((done, total)),
    );

    expect(seen.length, 16);
    expect(seen.last, (16, 16));
    expect(s.readerLeaseCount, 0);
    expect(s.mode.value, DeviceMode.emulator);
  });

  test('mf1WriteDump refuses a dump of the wrong length', () {
    expect(
      () => s.reader.mf1WriteDump(
        type: TagType.mifare1k,
        blocks: Uint8List(16),
        candidateKeys: <Uint8List>[FakeMf1Card.defaultKey],
      ),
      throwsArgumentError,
    );
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd packages/chameleon && dart test test/session/reader_write_test.dart
```

Expected: FAIL — `The method 'mf1WriteDump' isn't defined for the type 'ReaderFacade'`.

- [ ] **Step 3: Write the result type**

```dart
// packages/chameleon/lib/src/dump/mf1_dump_write_result.dart
import '../model/models.dart';

/// What one `ReaderFacade.mf1WriteDump` run put onto the card.
///
/// Two masks, not one: a block can be *skipped* (block 0, and the sector
/// trailers unless the caller asked for them) or *attempted and refused*
/// (no key for that sector, or a card that would not take the write). Only
/// the second is a failure, so completeness is measured against what was
/// attempted rather than against the whole card.
final class Mf1DumpWriteResult {
  Mf1DumpWriteResult({
    required this.writeMask,
    required this.attemptMask,
    required this.keys,
  });

  /// One entry per block of the card, true when that block was written.
  final List<bool> writeMask;

  /// One entry per block, true when a write was attempted for it.
  final List<bool> attemptMask;

  /// The key found for each sector, in the shape `mf1ReadDump` reports.
  final List<SectorKeys> keys;

  int get blockCount => writeMask.length;
  int get writtenBlockCount => writeMask.where((bool b) => b).length;
  int get attemptedBlockCount => attemptMask.where((bool b) => b).length;
  int get failedBlockCount => attemptedBlockCount - writtenBlockCount;

  /// Every block that was attempted was written.
  bool get isComplete => failedBlockCount == 0;
}
```

- [ ] **Step 4: Add the facade method**

In `packages/chameleon/lib/src/session/facades/reader.dart`, add the import beside the existing `import '../../dump/mf1_dump_read_result.dart';`:

```dart
import '../../dump/mf1_dump_write_result.dart';
```

and the matching re-export beside the existing `export '../../dump/mf1_dump_read_result.dart';`:

```dart
export '../../dump/mf1_dump_write_result.dart';
```

Then, directly after the landed `mf1ReadDump` method, add:

```dart
  /// Writes [blocks] onto the MIFARE Classic in the field: the mirror of
  /// [mf1ReadDump], and it holds the same guarantees — keys found once from
  /// [candidateKeys], one lease and one [DeviceSession.busy] for the whole
  /// run, [onProgress] called with the sectors finished and the sectors
  /// total after each sector, and [cancel] honoured between sectors and by
  /// each command in flight.
  ///
  /// Block 0 is never written: it is the manufacturer block, and only a
  /// "magic" card accepts a write there. Sector trailers are skipped unless
  /// [writeTrailers] is set, because writing a trailer with access bits the
  /// card cannot satisfy locks that sector for good. Skipped blocks are
  /// false in both masks of the result, which is why
  /// [Mf1DumpWriteResult.isComplete] measures written against *attempted*.
  ///
  /// A block the card refuses is left false rather than throwing, so one bad
  /// block costs one block and not the whole write.
  ///
  /// `hardware-validate` (checklist H3): which key a data block accepts for
  /// a write depends on its access bits, so the key A then key B order used
  /// here is only proven on a real card. Against `FakeDevice` both keys are
  /// the transport key and the order never shows.
  Future<Mf1DumpWriteResult> mf1WriteDump({
    required TagType type,
    required Uint8List blocks,
    required List<Uint8List> candidateKeys,
    bool writeTrailers = false,
    void Function(int done, int total)? onProgress,
    CancelToken? cancel,
  }) {
    final int sectors = MifareGeometry.sectorCount(type);
    final int totalBlocks = MifareGeometry.blockCount(type);
    if (blocks.length != totalBlocks * 16) {
      throw ArgumentError.value(
        blocks.length,
        'blocks',
        'must be ${totalBlocks * 16} bytes for $type',
      );
    }
    return _s.withReaderMode(
      () => _s.busy(
        () => _writeDump(
          sectors,
          totalBlocks,
          blocks,
          candidateKeys,
          writeTrailers,
          onProgress,
          cancel,
        ),
      ),
    );
  }
```

and, beside the private `_readDump`, its counterpart:

```dart
  Future<Mf1DumpWriteResult> _writeDump(
    int sectors,
    int totalBlocks,
    Uint8List blocks,
    List<Uint8List> candidateKeys,
    bool writeTrailers,
    void Function(int done, int total)? onProgress,
    CancelToken? cancel,
  ) async {
    final written = List<bool>.filled(totalBlocks, false);
    final attempted = List<bool>.filled(totalBlocks, false);
    final keys = await _keysForDump(sectors, candidateKeys, cancel);
    for (var sector = 0; sector < sectors; sector++) {
      _throwIfCancelled(cancel);
      final first = MifareGeometry.firstBlockOf(sector);
      final end = first + MifareGeometry.blocksInSector(sector);
      final trailer = MifareGeometry.trailerOf(sector);
      for (var block = first; block < end; block++) {
        if (block == 0) continue;
        if (block == trailer && !writeTrailers) continue;
        attempted[block] = true;
        written[block] = await _writeOneBlock(
          block,
          keys[sector],
          Uint8List.sublistView(blocks, block * 16, block * 16 + 16),
          cancel,
        );
      }
      onProgress?.call(sector + 1, sectors);
    }
    return Mf1DumpWriteResult(
      writeMask: written,
      attemptMask: attempted,
      keys: keys,
    );
  }

  /// Key A first, then key B. A data block whose access bits refuse key A
  /// can still be written with key B, and a refusal of one key says nothing
  /// about the other, so both are tried before the block is given up on.
  Future<bool> _writeOneBlock(
    int block,
    SectorKeys k,
    Uint8List data,
    CancelToken? cancel,
  ) async {
    for (final (KeyType, Uint8List) candidate in <(KeyType, Uint8List)>[
      if (k.keyA case final Uint8List a) (KeyType.a, a),
      if (k.keyB case final Uint8List b) (KeyType.b, b),
    ]) {
      try {
        await _s.send(
          Mf1WriteOneBlock(candidate.$1, block, candidate.$2, data),
          cancel: cancel,
        );
        return true;
      } on DeviceError {
        // Wrong key for this block, or a card that would not take it:
        // try the other key, then give this one block up.
      }
    }
    return false;
  }
```

Export the result type from the library. In `packages/chameleon/lib/chameleon.dart`, in the "Dump formats" block, beside `export 'src/dump/mf1_dump_read_result.dart';`:

```dart
export 'src/dump/mf1_dump_write_result.dart';
```

- [ ] **Step 5: Run the tests and watch them pass**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd packages/chameleon && dart test
```

Expected: PASS, including the landed `test/public_api_test.dart`.

- [ ] **Step 6: Commit**

```bash
git add packages/chameleon/lib packages/chameleon/test
git commit -m "feat(sdk): write a whole MIFARE Classic through the reader facade

Spec 8.1 keeps commands private to the SDK, so writing a dump back onto a
card has to be one facade method, with the lease, busy, progress and
cancellation mf1ReadDump already guarantees. Block 0 and the sector
trailers are skipped by default: both are one-way mistakes on a real card.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RsoXVLpXo5zoScmBLSMFw5"
```

---

### Task 2: `ReaderFacade.em410xWriteToT55xx` and the fake that answers it

The command is landed and unit-tested (`Em410xWriteToT55xx`, id 3001, `packages/chameleon/lib/src/commands/lf_reader.dart`; `docs/research/chameleon-protocol.md` line 33: `3001 EM410X_WRITE_TO_T55XX id(5) newkey(4) oldkeys(4xN)`), but nothing exposes it and the fake answers `NotImplemented`. Both are needed before the app can offer an LF write.

**Files:**
- Modify: `packages/chameleon/lib/src/session/facades/reader.dart`, `packages/chameleon/lib/src/fake/fake_reader_handlers.dart`
- Test: `packages/chameleon/test/session/reader_write_test.dart` (append)

**Interfaces:**
- Consumes: `Em410xWriteToT55xx({required Uint8List cardId, required Uint8List newKey, required List<Uint8List> oldKeys})`; `FakeLfCard(int scanCommandId, Uint8List idBytes)` (`lib/src/fake/fake_card.dart`); `FakeFirmware.lfCard`, `okFrame`, `statusFrame`, `Status.lfTagNoFound`.
- Produces, relied on by Task 8:
  - `Future<void> ReaderFacade.em410xWriteToT55xx({required Uint8List id, required Uint8List newKey, required List<Uint8List> oldKeys})`.
  - `FakeFirmware` answers command 3001: it rewrites the presented `FakeLfCard`'s id when that card answers EM410X_SCAN, and returns `LF_TAG_NO_FOUND` otherwise — so a test writes an id and then scans it back.

- [ ] **Step 1: Write the failing test**

Append to `packages/chameleon/test/session/reader_write_test.dart` (inside `main`):

```dart
  test('em410xWriteToT55xx rewrites the card the reader then scans', () async {
    device.firmware.present(
      FakeLfCard(3000, b(<int>[0x11, 0x22, 0x33, 0x44, 0x55])),
    );

    await s.reader.em410xWriteToT55xx(
      id: b(<int>[0xAA, 0xBB, 0xCC, 0xDD, 0xEE]),
      newKey: b(<int>[0x20, 0x20, 0x66, 0x66]),
      oldKeys: <Uint8List>[b(<int>[0x51, 0x24, 0x36, 0x48])],
    );

    expect(await s.reader.scanEm410x(), b(<int>[0xAA, 0xBB, 0xCC, 0xDD, 0xEE]));
    expect(s.readerLeaseCount, 0);
  });

  test('em410xWriteToT55xx with no card in the field is LfTagNotFound', () async {
    await expectLater(
      s.reader.em410xWriteToT55xx(
        id: b(<int>[1, 2, 3, 4, 5]),
        newKey: b(<int>[0x20, 0x20, 0x66, 0x66]),
        oldKeys: const <Uint8List>[],
      ),
      throwsA(isA<LfTagNotFound>()),
    );
  });
```

and add the two imports the new tests need at the top of the file:

```dart
import 'package:chameleon/src/protocol/errors.dart';
```

(`FakeLfCard` already comes from the `fake_card.dart` import added in Task 1.)

- [ ] **Step 2: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd packages/chameleon && dart test test/session/reader_write_test.dart
```

Expected: FAIL — `The method 'em410xWriteToT55xx' isn't defined for the type 'ReaderFacade'`.

- [ ] **Step 3: Add the facade method**

In `packages/chameleon/lib/src/session/facades/reader.dart`, after the four `scan*` LF methods:

```dart
  /// Writes an EM410x [id] onto the T55xx card in the field
  /// (EM410X_WRITE_TO_T55XX).
  ///
  /// Keys are parameters here as everywhere on this facade (spec 8.1): the
  /// SDK keeps no password list of its own. [newKey] is the four-byte
  /// password the card is left with, and [oldKeys] are the passwords tried
  /// to unlock it first — an empty list is a card with no password set.
  ///
  /// `hardware-validate` (checklist H3): the fake accepts the command and
  /// rewrites the card it is presenting, but which passwords a blank T55xx
  /// actually answers to, and whether a card takes the write at all, is
  /// only proven on real hardware.
  Future<void> em410xWriteToT55xx({
    required Uint8List id,
    required Uint8List newKey,
    required List<Uint8List> oldKeys,
  }) => _s.withReaderMode(
    () => _s.send(
      Em410xWriteToT55xx(cardId: id, newKey: newKey, oldKeys: oldKeys),
    ),
  );
```

- [ ] **Step 4: Teach the fake to answer 3001**

In `packages/chameleon/lib/src/fake/fake_reader_handlers.dart`, in `handleLfReader`, add a case before the `default:`:

```dart
      case 3001:
        final id = r.bytes(5);
        r.bytes(4); // newKey: the fake keeps no password.
        final c = lfCard;
        // Only a card that answers EM410X_SCAN can be rewritten as one; a
        // field with nothing in it, or a HID/Viking/PAC card, is a miss.
        if (c is! FakeLfCard || c.scanCommandId != 3000) {
          return statusFrame(cmd, Status.lfTagNoFound);
        }
        c.idBytes.setRange(0, 5, id);
        return okFrame(cmd);
```

Then widen the doc comment on `FakeLfCard` in `packages/chameleon/lib/src/fake/fake_card.dart` so the mutation is not a surprise:

```dart
/// An LF card answering one scan command id (3000 EM410X, 3002 HID Prox,
/// 3004 Viking, 3014 PAC) with fixed id bytes.
///
/// [idBytes] is rewritten in place by EM410X_WRITE_TO_T55XX (3001), so a
/// test can write an id and then scan it back. Give it a mutable list —
/// `Uint8List.fromList` — not a view of a shared constant.
```

- [ ] **Step 5: Run the tests and watch them pass**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd packages/chameleon && dart test
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add packages/chameleon/lib packages/chameleon/test
git commit -m "feat(sdk): write an EM410x id to a T55xx through the reader facade

The command has been in the catalog since Phase 1 with nothing exposing it
and a fake that answered NotImplemented, so the app could not offer an LF
write at all. The fake now rewrites the card it presents, which is what
makes the app's write flow testable without hardware.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RsoXVLpXo5zoScmBLSMFw5"
```

---

### Task 3: What a tag type supports — the pure decisions

Everything this phase does branches on the tag type: which emulator write loads a slot, which reader write puts it on a card, and what the nickname is. Those decisions are pure and belong in `state/`, tested with no widget and no device — the shape `state/card_codec.dart` and `state/read_state.dart` already set.

**Files:**
- Create: `app/lib/features/cards/state/write_target.dart`
- Test: `app/test/features/cards/write_target_test.dart`

**Interfaces:**
- Consumes: `TagType`, `TagFamily`, `Hf14aTag` from `package:chameleon/chameleon.dart`; `DumpFormats.ultralightPageCount(TagType)`; `MifareGeometry.blockCount(TagType)`; `slotNicknameMaxBytes` (`app/lib/features/slots/state/slot_nickname.dart`, exported in Step 4 below from `features/slots/slots.dart`).
- Produces, relied on by Tasks 5, 6, 8, 9, 10:
  - `enum SlotLoadMethod { mifareClassicBlocks, ultralightPages, em410xId, unsupported }` and `SlotLoadMethod slotLoadMethodFor(TagType type)`.
  - `enum CardWriteMethod { mifareClassicBlocks, em410xT55xx, unsupported }` and `CardWriteMethod writeMethodFor(TagType type)`.
  - `int expectedDumpLength(TagType type)` — 0 when the type has no known length.
  - `String slotNicknameFor(String cardName)` — UTF-8-safe truncation to `slotNicknameMaxBytes`.
  - `Hf14aTag antiCollForClassic(Uint8List blocks)`.
- Also produces (Step 4): `features/slots/slots.dart` additionally exports `slotNicknameMaxBytes`, `SlotNicknameError` and `validateSlotNickname`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/cards/write_target_test.dart
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/features/cards/state/write_target.dart';

void main() {
  group('slotLoadMethodFor', () {
    test('names the emulator write for each supported family', () {
      expect(
        slotLoadMethodFor(TagType.mifare1k),
        SlotLoadMethod.mifareClassicBlocks,
      );
      expect(
        slotLoadMethodFor(TagType.mifare4k),
        SlotLoadMethod.mifareClassicBlocks,
      );
      expect(
        slotLoadMethodFor(TagType.ntag215),
        SlotLoadMethod.ultralightPages,
      );
      expect(slotLoadMethodFor(TagType.em410x), SlotLoadMethod.em410xId);
    });

    test('every other type is unsupported, not a guess', () {
      expect(slotLoadMethodFor(TagType.hidProx), SlotLoadMethod.unsupported);
      expect(slotLoadMethodFor(TagType.hf14a4), SlotLoadMethod.unsupported);
      expect(slotLoadMethodFor(TagType.undefined), SlotLoadMethod.unsupported);
    });
  });

  group('writeMethodFor', () {
    test('MIFARE Classic writes blocks and EM410x writes a T55xx', () {
      expect(
        writeMethodFor(TagType.mifare1k),
        CardWriteMethod.mifareClassicBlocks,
      );
      expect(writeMethodFor(TagType.em410x), CardWriteMethod.em410xT55xx);
    });

    test('Ultralight has no reader write in the SDK, so it is unsupported', () {
      expect(writeMethodFor(TagType.ntag215), CardWriteMethod.unsupported);
      expect(writeMethodFor(TagType.mf0icu1), CardWriteMethod.unsupported);
    });
  });

  group('expectedDumpLength', () {
    test('is the dump size the device expects', () {
      expect(expectedDumpLength(TagType.mifare1k), 64 * 16);
      expect(expectedDumpLength(TagType.mifare4k), 256 * 16);
      expect(expectedDumpLength(TagType.ntag215), 135 * 4);
      expect(expectedDumpLength(TagType.em410x), 5);
      expect(expectedDumpLength(TagType.hidProx), 0);
    });
  });

  group('slotNicknameFor', () {
    test('passes a short name through unchanged', () {
      expect(slotNicknameFor('Front door'), 'Front door');
    });

    test('truncates to 32 UTF-8 bytes', () {
      final String nick = slotNicknameFor('x' * 50);
      expect(nick.length, 32);
    });

    test('never splits a multi-byte character', () {
      // 11 four-byte emoji is 44 bytes; 8 of them fit in 32.
      final String nick = slotNicknameFor('😀' * 11);
      expect(nick, '😀' * 8);
    });
  });

  group('antiCollForClassic', () {
    test('reads UID, SAK and ATQA out of block 0', () {
      final Uint8List blocks = Uint8List(64 * 16);
      blocks.setRange(0, 4, <int>[0xDE, 0xAD, 0xBE, 0xEF]);
      blocks[4] = 0xDE ^ 0xAD ^ 0xBE ^ 0xEF;
      blocks[5] = 0x08;
      blocks[6] = 0x04;
      blocks[7] = 0x00;

      final Hf14aTag tag = antiCollForClassic(blocks);
      expect(tag.uid, Uint8List.fromList(<int>[0xDE, 0xAD, 0xBE, 0xEF]));
      expect(tag.sak, 0x08);
      expect(tag.atqa, Uint8List.fromList(<int>[0x00, 0x04]));
      expect(tag.ats, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/cards/write_target_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: 'package:spectra/features/cards/state/write_target.dart'`.

- [ ] **Step 3: Write the pure module**

```dart
// app/lib/features/cards/state/write_target.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';

import '../../slots/slots.dart' show slotNicknameMaxBytes;

/// What a tag type supports, on the device and on a card (spec 7.7 step 5).
///
/// Every branch in this phase reads one of these two enums, so "Spectra
/// cannot do that yet" is a typed state the UI renders rather than a null,
/// an exception or a disabled button with no explanation. Spec 8.5's
/// one-public-type rule is knowingly relaxed for this file: these are one
/// cohesive concern — what may be written where — and splitting them would
/// add files without adding clarity.

/// How a dump is loaded into an emulation slot, through `EmulatorFacade`.
enum SlotLoadMethod {
  /// `EmulatorFacade.writeMf1Blocks` plus `setAntiColl`.
  mifareClassicBlocks,

  /// `EmulatorFacade.writeNtagPages`. No anti-collision call: the firmware
  /// derives the emulated UID from pages 0-2 of the data itself.
  ultralightPages,

  /// `EmulatorFacade.setLfId(TagType.em410x, id)`.
  em410xId,

  /// The device has no emulation for this type, or the SDK has no way to
  /// fill it. A typed state, not an error.
  unsupported,
}

/// How a dump is written back onto a physical card, through `ReaderFacade`.
enum CardWriteMethod {
  /// `ReaderFacade.mf1WriteDump`.
  mifareClassicBlocks,

  /// `ReaderFacade.em410xWriteToT55xx` — the id goes onto a T55xx blank,
  /// which is what "write an EM410x" means in practice: an EM4100 itself is
  /// read-only.
  em410xT55xx,

  /// No reader write exists for this type. Ultralight is here: spec 8.1's
  /// `ReaderFacade` has no Ultralight write operation, and
  /// `EmulatorFacade.writeNtagPages` writes the *device's* emulation memory,
  /// not a card in the field. Adding one is spec 8.2's extension point —
  /// one command plus one facade method — not an app-side workaround.
  unsupported,
}

SlotLoadMethod slotLoadMethodFor(TagType type) => switch (type.family) {
  TagFamily.mifareClassic => SlotLoadMethod.mifareClassicBlocks,
  TagFamily.ultralight => SlotLoadMethod.ultralightPages,
  TagFamily.lf =>
    type == TagType.em410x ? SlotLoadMethod.em410xId : SlotLoadMethod.unsupported,
  TagFamily.undefined ||
  TagFamily.iso14443_4 ||
  TagFamily.seos => SlotLoadMethod.unsupported,
};

CardWriteMethod writeMethodFor(TagType type) => switch (type.family) {
  TagFamily.mifareClassic => CardWriteMethod.mifareClassicBlocks,
  TagFamily.lf =>
    type == TagType.em410x ? CardWriteMethod.em410xT55xx : CardWriteMethod.unsupported,
  TagFamily.ultralight ||
  TagFamily.undefined ||
  TagFamily.iso14443_4 ||
  TagFamily.seos => CardWriteMethod.unsupported,
};

/// The dump length this type's device-side memory expects, or 0 when there
/// is no known length. Both write paths check the bytes they were handed
/// against this before touching the device: a dump of the wrong size is a
/// stored row that was never valid, not a device failure.
int expectedDumpLength(TagType type) => switch (slotLoadMethodFor(type)) {
  SlotLoadMethod.mifareClassicBlocks => MifareGeometry.blockCount(type) * 16,
  SlotLoadMethod.ultralightPages => DumpFormats.ultralightPageCount(type) * 4,
  SlotLoadMethod.em410xId => 5,
  SlotLoadMethod.unsupported => 0,
};

/// A card name as a slot nickname: SET_SLOT_TAG_NICK takes at most
/// [slotNicknameMaxBytes] UTF-8 bytes and the SDK enforces that with an
/// `ArgumentError` — which is not a `ChameleonException` and would reach the
/// error catalog as "something unexpected went wrong". A card name is free
/// text, so it is truncated here rather than rejected.
///
/// Truncation walks runes, not code units: cutting a UTF-8 sequence in half
/// would produce bytes the firmware cannot decode, and a surrogate pair
/// (every emoji) is two code units. A combining mark can still be separated
/// from its base character at the cut — a grapheme-cluster walk would need
/// `package:characters` for a case that costs one odd-looking nickname, so
/// this deliberately stops at runes.
String slotNicknameFor(String cardName) {
  final String trimmed = cardName.trim();
  if (utf8.encode(trimmed).length <= slotNicknameMaxBytes) return trimmed;
  final StringBuffer out = StringBuffer();
  int used = 0;
  for (final int rune in trimmed.runes) {
    final String char = String.fromCharCode(rune);
    final int size = utf8.encode(char).length;
    if (used + size > slotNicknameMaxBytes) break;
    out.write(char);
    used += size;
  }
  return out.toString();
}

/// The anti-collision answer a MIFARE Classic dump implies.
///
/// Block 0 carries UID, BCC, SAK and ATQA in that order, which is the same
/// layout `MifareClassicFormat.describe` reads (`packages/chameleon/lib/src/
/// dump/mifare_classic.dart`): bytes 0-3 UID, 4 BCC, 5 SAK, 6-7 ATQA
/// little-endian on the wire. A 7-byte-UID card lays block 0 out
/// differently and is `hardware-validate` (checklist H1) — the same caveat
/// `MifareClassicDump.uid` already carries.
Hf14aTag antiCollForClassic(Uint8List blocks) => Hf14aTag(
  uid: Uint8List.fromList(blocks.sublist(0, 4)),
  atqa: Uint8List.fromList(<int>[blocks[7], blocks[6]]),
  sak: blocks[5],
  ats: Uint8List(0),
);
```

No new dependency: `String.runes` is `dart:core`, and `utf8` is `dart:convert`, which this file already imports.

- [ ] **Step 4: Publish the nickname limit from the Slots barrel**

`slot_nickname.dart` is a Slots *internal*; `features/cards/**` may only import `features/slots/slots.dart` (`tool/src/dep_rules.dart`, rule `feature-internals`). Add the three names to `app/lib/features/slots/slots.dart`, beside the existing exports:

```dart
export 'state/slot_nickname.dart'
    show SlotNicknameError, slotNicknameMaxBytes, validateSlotNickname;
```

and extend that file's library doc comment with one line:

```dart
/// The firmware's nickname limit travels with the picker: a feature that
/// loads a card into a slot has to name that slot, and it must apply the
/// same 32-byte rule the slot editor applies (Phase 7).
```

- [ ] **Step 5: Run the tests and watch them pass**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/cards/write_target_test.dart
cd .. && dart run melos run check:all
```

Expected: PASS, and `lint:deps` green — the cards feature reaches Slots only through its barrel.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features app/test/features/cards/write_target_test.dart
git commit -m "feat(cards): decide per tag type what can be loaded and written

Every branch in the write-and-emulate work is the same question asked
twice, so it is answered once, purely, and 'Spectra cannot do that yet'
becomes a typed state instead of a disabled button with no explanation.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RsoXVLpXo5zoScmBLSMFw5"
```

---

### Task 4: A typed failure for a read-back that does not match (owns the ARB)

Spec 7.7 step 5 asks for a load that can be trusted, so the loader reads the slot back and compares. A mismatch is not a `ChameleonException` — no transport reported anything — but it must reach the user through the same spec 9 card as everything else. `NoKnownDeviceVisible` (`app/lib/core/session/reconnect.dart`) is the landed precedent for an app-owned typed failure the catalog knows.

**Files:**
- Create: `app/lib/core/errors/app_failures.dart`
- Modify: `app/lib/core/errors/error_catalog.dart`, `app/lib/l10n/app_en.arb`
- Test: `app/test/core/errors/error_catalog_test.dart` (append; create the file only if the landed suite has no catalog test — check first with `ls app/test/core/errors`)

**Interfaces:**
- Consumes: `ErrorPresentation({required String message, required ErrorRecovery recovery, required String detail, String? instructions})` and `ErrorRecovery` (`app/lib/core/errors/error_presentation.dart`); `ErrorCatalog(AppLocalizations).describe(Object)`.
- Produces, relied on by Task 5:
  - `final class SlotLoadVerificationFailed implements Exception` with `const SlotLoadVerificationFailed(this.what)`, `final String what`, and a `toString()` of `'SlotLoadVerificationFailed: the device stored different $what'`.
  - ARB key `errorSlotVerify`, mapped by `ErrorCatalog` with `ErrorRecovery.retry`.

- [ ] **Step 1: Write the failing test**

Append inside `main()` of the catalog test (or create the file with this content plus the imports it names):

```dart
// app/test/core/errors/error_catalog_test.dart
  testWidgets('a failed slot verification gets its own words', (tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final ErrorPresentation p = ErrorCatalog(
      l10n,
    ).describe(const SlotLoadVerificationFailed('the emulated blocks'));

    expect(p.message, l10n.errorSlotVerify);
    expect(p.recovery, ErrorRecovery.retry);
    expect(p.detail, contains('the emulated blocks'));
  });
```

Imports for a newly created file:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/errors/app_failures.dart';
import 'package:spectra/core/errors/error_catalog.dart';
import 'package:spectra/core/errors/error_presentation.dart';
import 'package:spectra/l10n/app_localizations.dart';
```

(`package:flutter/material.dart` is fine here: the no-material rule applies to `lib/features/**`, not to tests — `tool/src/dep_rules.dart` skips test paths.)

- [ ] **Step 2: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/core/errors/error_catalog_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: '.../app_failures.dart'`.

- [ ] **Step 3: Add the ARB string and regenerate**

Insert next to the other `error*` keys near the top of `app/lib/l10n/app_en.arb`:

```json
  "errorSlotVerify": "The device stored something different from what Spectra sent.",
  "@errorSlotVerify": {"description": "Shown when the slot read back after a load does not match the card."},
```

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter gen-l10n
```

- [ ] **Step 4: Write the failure type and the catalog branch**

```dart
// app/lib/core/errors/app_failures.dart
/// The app's own typed failures (spec 9).
///
/// Not `ChameleonException`s: no transport reported them, the app concluded
/// them. `ErrorCatalog` handles each one ahead of its
/// `error is! ChameleonException` fallback, so they reach the user through
/// the same `ProblemView` as everything else instead of as "something
/// unexpected went wrong". `NoKnownDeviceVisible`
/// (`core/session/reconnect.dart`) is the same idea, kept next to the
/// provider that raises it.

/// A slot was written and read back, and what came back is not what went in.
///
/// [what] names the data that did not match ('the emulated blocks', 'the
/// stored id'), and is the whole of the raw detail line spec 9 puts one tap
/// away — the bytes themselves are not put in an error message.
final class SlotLoadVerificationFailed implements Exception {
  const SlotLoadVerificationFailed(this.what);

  final String what;

  @override
  String toString() =>
      'SlotLoadVerificationFailed: the device stored different $what';
}
```

In `app/lib/core/errors/error_catalog.dart`, add the import:

```dart
import 'app_failures.dart';
```

and a branch directly after the landed `NoKnownDeviceVisible` branch, before the `if (error is! ChameleonException)` fallback:

```dart
    if (error is SlotLoadVerificationFailed) {
      return ErrorPresentation(
        message: _l10n.errorSlotVerify,
        recovery: ErrorRecovery.retry,
        detail: error.toString(),
      );
    }
```

- [ ] **Step 5: Run the tests and watch them pass**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/core
cd .. && dart run melos run check:all
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/lib/core app/lib/l10n app/test/core
git commit -m "feat(core): give a failed slot verification its own words

Loading a card into a slot reads the slot back; a mismatch is the app's own
conclusion, not a device error, and spec 9 still wants one plain sentence
with the raw line one tap away rather than the unexpected-error fallback.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RsoXVLpXo5zoScmBLSMFw5"
```

---

### Task 5: The `SlotLoader` notifier

Spec 7.7 step 5, first half: put a dump into one of the eight slots. Six device steps in order, then a read-back. All of it through `SlotsFacade` and `EmulatorFacade` — no raw commands, no wakelock code (Global Constraints).

**Files:**
- Create: `app/lib/features/cards/state/load_to_slot_controller.dart`
- Test: `app/test/features/cards/load_to_slot_test.dart`

**Interfaces:**
- Consumes: `activeSessionProvider` → `ActiveSession?` with `.session` (`app/lib/core/session/active_device.dart`, `active_session.dart`); `DeviceSession.slots` → `SlotsFacade.setActive(int)`, `.resetToDefault(int, TagType)`, `.rename(int, Sense, String)`, `.setEnabled(int, Sense, bool)`; `DeviceSession.emulator` → `EmulatorFacade.writeMf1Blocks(int start, Uint8List data)`, `.readMf1Blocks(int start, int count)`, `.writeNtagPages(int start, Uint8List data)`, `.readNtagPages(int start, int count)`, `.setLfId(TagType, Uint8List)`, `.getLfId(TagType)`, `.setAntiColl(Hf14aTag)`; `SessionNotReady` from the SDK; `SlotLoadVerificationFailed` (Task 4); `SlotLoadMethod`, `slotLoadMethodFor`, `expectedDumpLength`, `slotNicknameFor`, `antiCollForClassic` (Task 3).
- Produces, relied on by Tasks 6, 11, 12:
  - `final class SlotLoadState` with `const SlotLoadState({bool busy = false, double? progress, bool done = false, Object? error, bool unsupported = false})` and those five final fields.
  - `@riverpod class SlotLoader extends _$SlotLoader` — generated provider `slotLoaderProvider`, notifier read as `ref.read(slotLoaderProvider.notifier)`:
    - `SlotLoadState build()`
    - `Future<void> load({required int slotIndex, required TagType type, required Uint8List bytes, required String name})`
    - `void reset()`
    - `@visibleForTesting void debugFail(Object error)`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/cards/load_to_slot_test.dart
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/features/cards/state/load_to_slot_controller.dart';
import 'package:spectra/features/slots/slots.dart';

import '../../support/app_harness.dart';

Uint8List classic1k(int fill) {
  final Uint8List blocks = Uint8List(64 * 16);
  blocks.setRange(0, 4, <int>[0xDE, 0xAD, 0xBE, 0xEF]);
  blocks[4] = 0xDE ^ 0xAD ^ 0xBE ^ 0xEF;
  blocks[5] = 0x08;
  blocks[6] = 0x04;
  blocks[7] = 0x00;
  blocks.fillRange(16, blocks.length, fill);
  return blocks;
}

Future<SlotLoader> openLoader(WidgetTester tester) async {
  useDesktopSurface(tester);
  await pumpTestApp(tester, transport: (_) => FakeDevice());
  await connectToEmulator(tester);
  keepAlive(tester, slotLoaderProvider);
  keepAlive(tester, slotViewsProvider);
  await pumpFrames(tester);
  return readProvider(tester, slotLoaderProvider.notifier);
}

void main() {
  testWidgetsApp('loads a MIFARE Classic dump into a slot and verifies it', (
    tester,
  ) async {
    final SlotLoader loader = await openLoader(tester);

    final Future<void> pending = loader.load(
      slotIndex: 2,
      type: TagType.mifare1k,
      bytes: classic1k(0x5A),
      name: 'Office badge',
    );
    await pumpFrames(tester, count: 30);
    await pending;
    await pumpFrames(tester);

    final SlotLoadState state = readProvider(tester, slotLoaderProvider);
    expect(state.done, isTrue);
    expect(state.busy, isFalse);
    expect(state.error, isNull);
    expect(state.progress, 1);

    final List<SlotView> views = readProvider(tester, slotViewsProvider);
    expect(views[2].slot.hfType, TagType.mifare1k);
    expect(views[2].slot.hfNick, 'Office badge');
    expect(views[2].slot.hfEnabled, isTrue);
    expect(views[2].isActive, isTrue);
  });

  testWidgetsApp('loads an EM410x id into a slot', (tester) async {
    final SlotLoader loader = await openLoader(tester);

    final Future<void> pending = loader.load(
      slotIndex: 4,
      type: TagType.em410x,
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4, 5]),
      name: 'Gate fob',
    );
    await pumpFrames(tester, count: 30);
    await pending;
    await pumpFrames(tester);

    expect(readProvider(tester, slotLoaderProvider).done, isTrue);
    final List<SlotView> views = readProvider(tester, slotViewsProvider);
    expect(views[4].slot.lfType, TagType.em410x);
    expect(views[4].slot.lfNick, 'Gate fob');
  });

  testWidgetsApp('an unsupported type never touches the device', (tester) async {
    final SlotLoader loader = await openLoader(tester);

    final Future<void> pending = loader.load(
      slotIndex: 1,
      type: TagType.hidProx,
      bytes: Uint8List(13),
      name: 'Badge',
    );
    await pumpFrames(tester);
    await pending;

    final SlotLoadState state = readProvider(tester, slotLoaderProvider);
    expect(state.unsupported, isTrue);
    expect(state.done, isFalse);
    expect(state.error, isNull);
    final List<SlotView> views = readProvider(tester, slotViewsProvider);
    expect(views[1].slot.lfType, TagType.undefined);
  });

  testWidgetsApp('a dump of the wrong length is refused before any write', (
    tester,
  ) async {
    final SlotLoader loader = await openLoader(tester);

    final Future<void> pending = loader.load(
      slotIndex: 1,
      type: TagType.mifare1k,
      bytes: Uint8List(32),
      name: 'Short',
    );
    await pumpFrames(tester);
    await pending;

    final SlotLoadState state = readProvider(tester, slotLoaderProvider);
    expect(state.error, isA<ArgumentError>());
    final List<SlotView> views = readProvider(tester, slotViewsProvider);
    expect(views[1].slot.hfType, TagType.undefined);
  });

  testWidgetsApp('a long card name is truncated to a legal nickname', (
    tester,
  ) async {
    final SlotLoader loader = await openLoader(tester);

    final Future<void> pending = loader.load(
      slotIndex: 0,
      type: TagType.mifare1k,
      bytes: classic1k(0x11),
      name: 'y' * 60,
    );
    await pumpFrames(tester, count: 30);
    await pending;
    await pumpFrames(tester);

    final List<SlotView> views = readProvider(tester, slotViewsProvider);
    expect(views[0].slot.hfNick.length, 32);
  });

  testWidgetsApp('reset clears a failure so the sheet can offer it again', (
    tester,
  ) async {
    final SlotLoader loader = await openLoader(tester);
    loader.debugFail(const SessionNotReady('nope'));
    await pumpFrames(tester, count: 2);
    expect(readProvider(tester, slotLoaderProvider).error, isNotNull);

    loader.reset();
    await pumpFrames(tester, count: 2);
    expect(readProvider(tester, slotLoaderProvider).error, isNull);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/cards/load_to_slot_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: '.../load_to_slot_controller.dart'`.

- [ ] **Step 3: Write the controller**

```dart
// app/lib/features/cards/state/load_to_slot_controller.dart
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/app_failures.dart';
import '../../../core/session/active_device.dart';
import '../../../core/session/active_session.dart';
import 'write_target.dart';

part 'load_to_slot_controller.g.dart';

/// The load's whole state. Deliberately without a `copyWith`: every
/// transition builds a complete new value, so there is no "unchanged versus
/// explicitly null" sentinel to get wrong (the shape `ReadState` set).
final class SlotLoadState {
  const SlotLoadState({
    this.busy = false,
    this.progress,
    this.done = false,
    this.error,
    this.unsupported = false,
  });

  /// True from the first command until the load ends, however it ends.
  final bool busy;

  /// 0..1 across the six device steps and the read-back. Not a byte count:
  /// the steps are commands of very different sizes, so the fraction is a
  /// position in the sequence, which is what the sheet's bar shows.
  final double? progress;

  /// The slot now holds the card, and the read-back agreed.
  final bool done;

  /// The typed error the last load ended with, rendered through the spec 9
  /// catalog. Never a string.
  final Object? error;

  /// This tag type has no emulation Spectra can fill (`SlotLoadMethod
  /// .unsupported`). A state, not an error: nothing went wrong, there is
  /// simply nothing to do.
  final bool unsupported;
}

/// Spec 7.7 step 5: load a dump into one of the eight slots.
///
/// The order matters and is the device's, not a preference: select the slot
/// (so every `EmulatorFacade` call lands on it — that facade always operates
/// on the *active* slot), reset it to the target type (which sets the type
/// and clears that sense's old data in one command, so no byte of the
/// previous card survives), write the data, set the anti-collision, name it,
/// enable it. Every `SlotsFacade` mutation ends in SLOT_DATA_CONFIG_SAVE on
/// its own, so nothing here has to save.
///
/// The load then reads the slot back and compares. A device that stores
/// something else is a [SlotLoadVerificationFailed], which the error catalog
/// has words for — silently reporting success for a slot that will not
/// emulate is the one outcome worth spending an extra round trip to avoid.
///
/// There is no wakelock code here and there must not be: `writeMf1Blocks`
/// and `readMf1Blocks` run inside `DeviceSession.busy`, as does every
/// `SlotsFacade` mutation but `setActive`, and `sessionNeedsWakelock`
/// (`core/lifecycle/wakelock.dart`) polls exactly that.
///
/// A call made while another is in flight is dropped, not queued
/// (`_inFlight`); the sheet disables its button while `state.busy`. This
/// notifier is autoDispose and lives under a sheet the user can dismiss, so
/// every assignment to [state] after an `await` is guarded with `ref.mounted`
/// (R25) — the device write still runs to completion, there is simply no
/// longer anywhere to report it.
@riverpod
class SlotLoader extends _$SlotLoader {
  @override
  SlotLoadState build() {
    ref.onDispose(() {
      // Not `state` — the element is gone by now (Global Constraints).
      _inFlight = false;
    });
    return const SlotLoadState();
  }

  bool _inFlight = false;

  Future<void> load({
    required int slotIndex,
    required TagType type,
    required Uint8List bytes,
    required String name,
  }) async {
    if (_inFlight) return;
    final SlotLoadMethod method = slotLoadMethodFor(type);
    if (method == SlotLoadMethod.unsupported) {
      state = const SlotLoadState(unsupported: true);
      return;
    }
    final ActiveSession? active = ref.read(activeSessionProvider);
    if (active == null) {
      state = const SlotLoadState(error: SessionNotReady('no active session'));
      return;
    }
    final int expected = expectedDumpLength(type);
    if (bytes.length != expected) {
      // Before anything is sent: a stored row of the wrong size was never a
      // valid dump, and half-writing it would leave the slot worse than it
      // started.
      state = SlotLoadState(
        error: ArgumentError.value(
          bytes.length,
          'bytes',
          'a $type dump is $expected bytes',
        ),
      );
      return;
    }

    _inFlight = true;
    state = const SlotLoadState(busy: true, progress: 0);
    try {
      await _load(active.session, slotIndex, type, bytes, name, method);
      if (ref.mounted) {
        state = const SlotLoadState(done: true, progress: 1);
      }
    } on Object catch (error) {
      if (ref.mounted) state = SlotLoadState(error: error);
    } finally {
      _inFlight = false;
    }
  }

  /// Back to the empty state, so the sheet's "Try again" offers the load
  /// again rather than leaving a `ProblemView` up forever.
  void reset() => state = const SlotLoadState();

  /// Lets a test drive an error state without a facade that throws.
  /// `Notifier.state` is `@protected`; this is the narrow door around that.
  @visibleForTesting
  void debugFail(Object error) => state = SlotLoadState(error: error);

  Future<void> _load(
    DeviceSession session,
    int slotIndex,
    TagType type,
    Uint8List bytes,
    String name,
    SlotLoadMethod method,
  ) async {
    final SlotsFacade slots = session.slots;
    final EmulatorFacade emulator = session.emulator;

    await slots.setActive(slotIndex);
    _publish(0.15);
    await slots.resetToDefault(slotIndex, type);
    _publish(0.3);

    switch (method) {
      case SlotLoadMethod.mifareClassicBlocks:
        await emulator.writeMf1Blocks(0, bytes);
        _publish(0.55);
        await emulator.setAntiColl(antiCollForClassic(bytes));
      case SlotLoadMethod.ultralightPages:
        // No anti-collision call: the firmware answers an Ultralight
        // anti-collision out of pages 0-2, which are part of the dump.
        await emulator.writeNtagPages(0, bytes);
      case SlotLoadMethod.em410xId:
        await emulator.setLfId(TagType.em410x, bytes);
      case SlotLoadMethod.unsupported:
        return; // Unreachable: refused by the caller.
    }
    _publish(0.65);

    await slots.rename(slotIndex, type.sense, slotNicknameFor(name));
    _publish(0.8);
    await slots.setEnabled(slotIndex, type.sense, true);
    _publish(0.9);

    final Uint8List stored = await _readBack(emulator, method, bytes.length);
    if (!_sameBytes(stored, bytes)) {
      throw SlotLoadVerificationFailed(switch (method) {
        SlotLoadMethod.mifareClassicBlocks => 'the emulated blocks',
        SlotLoadMethod.ultralightPages => 'the emulated pages',
        SlotLoadMethod.em410xId ||
        SlotLoadMethod.unsupported => 'the stored id',
      });
    }
  }

  Future<Uint8List> _readBack(
    EmulatorFacade emulator,
    SlotLoadMethod method,
    int length,
  ) => switch (method) {
    SlotLoadMethod.mifareClassicBlocks => emulator.readMf1Blocks(
      0,
      length ~/ 16,
    ),
    SlotLoadMethod.ultralightPages => emulator.readNtagPages(0, length ~/ 4),
    SlotLoadMethod.em410xId ||
    SlotLoadMethod.unsupported => emulator.getLfId(TagType.em410x),
  };

  static bool _sameBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// A progress step. Guarded like every other post-`await` assignment: the
  /// sheet can be dismissed between two commands.
  void _publish(double progress) {
    if (!ref.mounted) return;
    state = SlotLoadState(busy: true, progress: progress);
  }
}
```

- [ ] **Step 4: Generate and run**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && dart run build_runner build --delete-conflicting-outputs
cd app && flutter test test/features/cards/load_to_slot_test.dart
```

Expected: PASS, all six tests.

- [ ] **Step 5: Run the whole suite and the checks**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd .. && dart run melos run check:all
```

Expected: green, `check_codegen.sh` included.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/cards/state app/test/features/cards/load_to_slot_test.dart
git commit -m "feat(cards): load a dump into an emulation slot

Spec 7.7 step 5. The order is the device's — select, reset to the type,
write, anti-collision, name, enable — and the slot is read back afterwards,
because a slot that quietly will not emulate is worth one extra round trip
to catch.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RsoXVLpXo5zoScmBLSMFw5"
```

---

### Task 6: The load-to-slot sheet (owns the ARB)

Layout only (spec 8.5): confirm, progress, done, error, unsupported — five states, one per `SlotLoadState` shape.

**Files:**
- Create: `app/lib/features/cards/ui/load_to_slot_sheet.dart`
- Modify: `app/lib/l10n/app_en.arb`
- Test: `app/test/features/cards/load_to_slot_test.dart` (append a `group`)

**Interfaces:**
- Consumes: `slotLoaderProvider`, `SlotLoadState`, `SlotLoader.load/reset` (Task 5); `SpectraBottomSheet.show<T>({required BuildContext context, required String title, required WidgetBuilder builder})`, `SpectraCard`, `SpectraButton({required String label, SpectraButtonVariant? variant, VoidCallback? onPressed})`, `SpectraProgressIndicator({required String label, double? value, String? detail, VoidCallback? onCancel})` (`package:spectra_ui`); `ProblemView` (`core/errors/problem_view.dart`); `tagTypeLabel` (`core/format/tag_labels.dart`); `AppLocalizations.of(context)`.
- Produces, relied on by Tasks 7 and 10:
  - `Future<bool?> showLoadToSlotSheet(BuildContext context, {required int slotIndex, required TagType type, required Uint8List bytes, required String name})` — resolves to true when the slot was loaded and verified, and to null when the sheet was dismissed.
  - ARB keys: `cardsLoadToSlot`, `cardsLoadTitle`, `cardsLoadPrompt`, `cardsLoadConfirm`, `cardsLoadProgress`, `cardsLoadVerifying`, `cardsLoadDone`, `cardsLoadUnsupported`, `cardsLoadedToSlot`, `commonClose`.

- [ ] **Step 1: Write the failing test**

Append to `app/test/features/cards/load_to_slot_test.dart`:

```dart
  group('the sheet', () {
    testWidgetsApp('confirms, loads and reports done', (tester) async {
      await openLoader(tester);
      final BuildContext context = tester.element(find.byType(SpectraAppShell));

      final Future<bool?> pending = showLoadToSlotSheet(
        context,
        slotIndex: 2,
        type: TagType.mifare1k,
        bytes: classic1k(0x22),
        name: 'Office badge',
      );
      await pumpFrames(tester);
      expect(find.text('Load into slot 3'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(SpectraBottomSheet),
          matching: find.text('Load'),
        ),
      );
      await pumpFrames(tester, count: 30);
      expect(find.text('Loaded into slot 3.'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(SpectraBottomSheet),
          matching: find.text('Close'),
        ),
      );
      await pumpFrames(tester);
      expect(await pending, isTrue);
    });

    testWidgetsApp('says so for a type it cannot emulate', (tester) async {
      await openLoader(tester);
      final BuildContext context = tester.element(find.byType(SpectraAppShell));

      final Future<bool?> pending = showLoadToSlotSheet(
        context,
        slotIndex: 0,
        type: TagType.hidProx,
        bytes: Uint8List(13),
        name: 'Badge',
      );
      await pumpFrames(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(SpectraBottomSheet),
          matching: find.text('Load'),
        ),
      );
      await pumpFrames(tester);
      expect(
        find.text('Spectra cannot emulate this tag type yet.'),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(SpectraBottomSheet),
          matching: find.text('Close'),
        ),
      );
      await pumpFrames(tester);
      expect(await pending, isNull);
    });

    testWidgetsApp('shows a failure through the shared ProblemView', (
      tester,
    ) async {
      final SlotLoader loader = await openLoader(tester);
      final BuildContext context = tester.element(find.byType(SpectraAppShell));

      final Future<bool?> pending = showLoadToSlotSheet(
        context,
        slotIndex: 0,
        type: TagType.mifare1k,
        bytes: classic1k(0x33),
        name: 'Office badge',
      );
      await pumpFrames(tester);
      loader.debugFail(const SlotLoadVerificationFailed('the emulated blocks'));
      await pumpFrames(tester);

      expect(
        find.descendant(
          of: find.byType(SpectraBottomSheet),
          matching: find.byType(ProblemView),
        ),
        findsOneWidget,
      );

      // Try again puts the confirm button back. `find.text` matches the
      // whole string, so 'Load' finds the button and not the sheet's
      // 'Load into slot 1' title.
      await tester.tap(
        find.descendant(
          of: find.byType(SpectraBottomSheet),
          matching: find.text('Try again'),
        ),
      );
      await pumpFrames(tester);
      expect(
        find.descendant(
          of: find.byType(SpectraBottomSheet),
          matching: find.text('Load'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.close));
      await pumpFrames(tester);
      await pending;
    });
  });
```

and extend that file's imports:

```dart
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/core/errors/app_failures.dart';
import 'package:spectra/core/errors/problem_view.dart';
import 'package:spectra/features/cards/ui/load_to_slot_sheet.dart';
import 'package:spectra_ui/spectra_ui.dart';
```

- [ ] **Step 2: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/cards/load_to_slot_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: '.../load_to_slot_sheet.dart'`.

- [ ] **Step 3: Add the ARB strings and regenerate**

Append before the closing `commonCancel` entry in `app/lib/l10n/app_en.arb` (keep the file's one-line-per-key style):

```json
  "cardsLoadToSlot": "Load into a slot",
  "@cardsLoadToSlot": {"description": "Action on a saved card: put it into an emulation slot."},
  "cardsLoadTitle": "Load into slot {number}",
  "@cardsLoadTitle": {
    "description": "Title of the load-to-slot sheet; the one-based slot number.",
    "placeholders": {"number": {"type": "int"}}
  },
  "cardsLoadPrompt": "{name} will replace whatever slot {number} holds on the {type} side.",
  "@cardsLoadPrompt": {
    "description": "What loading will do, before it is confirmed.",
    "placeholders": {"name": {"type": "String"}, "number": {"type": "int"}, "type": {"type": "String"}}
  },
  "cardsLoadConfirm": "Load",
  "@cardsLoadConfirm": {"description": "Starts the load."},
  "cardsLoadProgress": "Writing the card into the slot…",
  "@cardsLoadProgress": {"description": "Progress label while a slot is being loaded."},
  "cardsLoadVerifying": "Checking what the device stored…",
  "@cardsLoadVerifying": {"description": "Progress label for the read-back at the end of a load."},
  "cardsLoadDone": "Loaded into slot {number}.",
  "@cardsLoadDone": {
    "description": "Shown when a load finished and the read-back matched.",
    "placeholders": {"number": {"type": "int"}}
  },
  "cardsLoadUnsupported": "Spectra cannot emulate this tag type yet.",
  "@cardsLoadUnsupported": {"description": "Shown for a tag type with no emulator write."},
  "cardsLoadedToSlot": "Loaded into slot {number}.",
  "@cardsLoadedToSlot": {
    "description": "Confirmation shown on the screen behind the sheet after a load.",
    "placeholders": {"number": {"type": "int"}}
  },
  "commonClose": "Close",
  "@commonClose": {"description": "Dismisses a sheet that has finished."},
```

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter gen-l10n
```

`cardsLoadDone` and `cardsLoadedToSlot` deliberately carry the same sentence in two keys: one is inside the sheet and one is the snackbar behind it, they are never on screen together, and collapsing them would tie the sheet's wording to the snackbar's (Phase 6 ruling 14 is about two keys that *are* on screen together — this is the opposite case, and the note here is why).

- [ ] **Step 4: Write the sheet**

```dart
// app/lib/features/cards/ui/load_to_slot_sheet.dart
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/problem_view.dart';
import '../../../core/format/tag_labels.dart';
import '../../../l10n/app_localizations.dart';
import '../state/load_to_slot_controller.dart';

/// Spec 7.7 step 5: put [bytes] into slot [slotIndex] and say how it went.
///
/// [slotIndex] is a **wire index**, 0..7 — what `showSlotPicker`
/// (`features/slots/slots.dart`) resolves to and what `SlotsFacade` takes.
/// One is added only when a number is shown to a person.
///
/// Resolves to true when the slot was loaded and the read-back agreed, and
/// to null when the sheet was dismissed — including a dismissal after an
/// unsupported type or a failure, both of which are "nothing was loaded".
Future<bool?> showLoadToSlotSheet(
  BuildContext context, {
  required int slotIndex,
  required TagType type,
  required Uint8List bytes,
  required String name,
}) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return SpectraBottomSheet.show<bool>(
    context: context,
    title: l10n.cardsLoadTitle(slotIndex + 1),
    builder: (BuildContext context) => _LoadToSlotBody(
      slotIndex: slotIndex,
      type: type,
      bytes: bytes,
      name: name,
    ),
  );
}

class _LoadToSlotBody extends ConsumerWidget {
  const _LoadToSlotBody({
    required this.slotIndex,
    required this.type,
    required this.bytes,
    required this.name,
  });

  final int slotIndex;
  final TagType type;
  final Uint8List bytes;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SlotLoadState state = ref.watch(slotLoaderProvider);
    final SlotLoader loader = ref.read(slotLoaderProvider.notifier);

    if (state.error case final Object error) {
      return ProblemView(
        error: error,
        onAction: loader.reset,
        variant: SpectraButtonVariant.secondary,
      );
    }
    if (state.busy) {
      return SpectraProgressIndicator(
        label: (state.progress ?? 0) >= 0.9
            ? l10n.cardsLoadVerifying
            : l10n.cardsLoadProgress,
        value: state.progress,
      );
    }
    if (state.done) {
      return _Finished(
        message: l10n.cardsLoadDone(slotIndex + 1),
        onClose: () => Navigator.of(context).pop(true),
      );
    }
    if (state.unsupported) {
      return _Finished(
        message: l10n.cardsLoadUnsupported,
        onClose: () => Navigator.of(context).pop(),
      );
    }
    return SpectraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.cardsLoadPrompt(
              name,
              slotIndex + 1,
              senseLabel(type.sense, l10n),
            ),
          ),
          const SizedBox(height: SpectraSpacing.sm),
          Text(tagTypeLabel(type, l10n)),
          const SizedBox(height: SpectraSpacing.lg),
          SpectraButton(
            label: l10n.cardsLoadConfirm,
            onPressed: () => loader.load(
              slotIndex: slotIndex,
              type: type,
              bytes: bytes,
              name: name,
            ),
          ),
        ],
      ),
    );
  }
}

/// The terminal states: one sentence and a way out. The sheet does not pop
/// itself — a load is worth reading the outcome of, and popping from a
/// provider listener while a modal route is settling is a flake this screen
/// does not need.
class _Finished extends StatelessWidget {
  const _Finished({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SpectraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(message),
          const SizedBox(height: SpectraSpacing.lg),
          SpectraButton(
            label: l10n.commonClose,
            variant: SpectraButtonVariant.secondary,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
```

The `load(...)` call in `onPressed` returns a `Future` that is deliberately not awaited: the notifier owns every outcome, and the button is gone from the tree the moment `state.busy` turns true. If `analyze` flags the unawaited future, wrap it as `onPressed: () => unawaited(loader.load(...))` with `import 'dart:async';`.

- [ ] **Step 5: Run the tests and watch them pass**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/cards
cd .. && dart run melos run check:all
```

Expected: PASS, and `lint:strings` green — every sentence in the sheet comes from the ARB.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/cards app/lib/l10n app/test/features/cards
git commit -m "feat(cards): the load-to-slot sheet

Five states, one per shape SlotLoadState can take, so an unsupported tag
type reads as a sentence rather than a dead button and a verification
failure lands in the same spec 9 card as everything else.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RsoXVLpXo5zoScmBLSMFw5"
```

---

### Task 7: "Load into a slot" on the card detail page

The first entry point. Pick a slot with the Slots feature's published picker, then run the sheet.

This is also spec 7.7 step 5's "quick emulate from the library": the library's row opens the detail page, and the detail page's Load into a slot is the one step from there to an emulating device. Task 10 adds the other quick path, from the read screen.

**Files:**
- Modify: `app/lib/features/cards/ui/card_detail_page.dart`
- Test: `app/test/features/cards/card_detail_page_test.dart` (append; the landed file name may differ — `ls app/test/features/cards` first and append to the detail page's own test file)

The appended test needs these imports; add whichever the landed file does not already have: `dart:typed_data`, `package:chameleon/chameleon.dart`, `package:material_ui/material_ui.dart' hide ConnectionState`, `package:spectra/features/cards/state/saved_cards_provider.dart` (for `cardLibraryProvider` and `CardLibrary`), `package:spectra/features/slots/slots.dart` (for `slotViewsProvider` and `SlotView`), `package:spectra_ui/spectra_ui.dart`, and `../../support/app_harness.dart`.

**Interfaces:**
- Consumes: `showSlotPicker(BuildContext context, {bool Function(SlotView slot)? isSelectable}) → Future<int?>` from `package:spectra/features/slots/slots.dart` — a **wire index 0..7, or null on dismissal**, and it changes nothing on the device; `showLoadToSlotSheet` (Task 6); `CardEditState` with `.card` (a `SavedCard`), `.tagType` (a `TagType`) and `.bytes` (`Uint8List`) from `../state/card_editor_controller.dart`; `AppRoutes` and `ScaffoldMessenger`.
- Produces: no new public names. `_Detail` gains one more callback parameter.

- [ ] **Step 1: Read the file as it stands**

```bash
sed -n '1,80p' app/lib/features/cards/ui/card_detail_page.dart
grep -n "_Detail(" app/lib/features/cards/ui/card_detail_page.dart
```

Phase 6 Tasks 8 and 10 also edit this file (editing, the unsaved-changes guard, import/export). `_Detail`'s constructor already has parameters this plan does not list — for example a `loading` flag. **Add `onLoadToSlot` to whatever list is there; do not replace the constructor.**

- [ ] **Step 2: Write the failing test**

```dart
  testWidgetsApp('loads a saved card into a slot from the detail page', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await connectToEmulator(tester);
    keepAlive(tester, cardLibraryProvider);
    keepAlive(tester, slotViewsProvider);
    await tester.tap(find.text('Cards').last);
    await pumpFrames(tester);

    final CardLibrary library = readProvider(
      tester,
      cardLibraryProvider.notifier,
    );
    final Future<String?> saving = library.add(
      name: 'Office badge',
      type: TagType.mifare1k,
      bytes: classic1k(0x44),
    );
    await tester.pump(const Duration(milliseconds: 20));
    await saving;
    await pumpFrames(tester);

    await tester.tap(find.text('Office badge'));
    await pumpFrames(tester);
    await tester.tap(find.text('Load into a slot'));
    await pumpFrames(tester);

    // The slot picker: slot 4 is the fourth tile.
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(SpectraSlotTile),
      ).at(3),
    );
    await pumpFrames(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Load'),
      ),
    );
    await pumpFrames(tester, count: 30);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Close'),
      ),
    );
    await pumpFrames(tester);

    expect(find.text('Loaded into slot 4.'), findsOneWidget);
    final List<SlotView> views = readProvider(tester, slotViewsProvider);
    expect(views[3].slot.hfNick, 'Office badge');
    expect(views[3].slot.hfType, TagType.mifare1k);
  });
```

Reuse the `classic1k` helper by copying it into this file if it is not already there (a four-line fixture builder; the alternative — a shared fixtures file — is Task 11's business, when three files want it).

- [ ] **Step 3: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/cards/card_detail_page_test.dart
```

Expected: FAIL — `Nothing found` for `find.text('Load into a slot')`.

- [ ] **Step 4: Wire the entry point**

Add the imports to `app/lib/features/cards/ui/card_detail_page.dart`:

```dart
import '../../slots/slots.dart' show showSlotPicker;
import 'load_to_slot_sheet.dart';
```

Add the handler method to `CardDetailPage`, beside `_confirmDelete`:

```dart
  /// Spec 7.7 step 5: which slot, then load it.
  ///
  /// `showSlotPicker` is the Slots feature's published API
  /// (`features/slots/slots.dart`); it resolves to a **wire index** 0..7, or
  /// null when the sheet was dismissed, and it changes nothing on the device
  /// — choosing a slot is a choice, the write is this screen's. No
  /// `isSelectable` filter is passed: the load resets the slot to the card's
  /// own type first, so every slot is a legal target.
  Future<void> _loadToSlot(BuildContext context, CardEditState state) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final int? slotIndex = await showSlotPicker(context);
    if (slotIndex == null || !context.mounted) return;
    final bool? loaded = await showLoadToSlotSheet(
      context,
      slotIndex: slotIndex,
      type: state.tagType,
      bytes: state.bytes,
      name: state.card.name,
    );
    if (loaded != true) return;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.cardsLoadedToSlot(slotIndex + 1))),
    );
  }
```

In `build`, pass it into `_Detail` alongside the callbacks already there:

```dart
        onLoadToSlot: () => _loadToSlot(context, value),
```

In `_Detail`, add the field and parameter to the existing list:

```dart
  final VoidCallback onLoadToSlot;
```

and the button, directly above the landed delete button:

```dart
        SpectraButton(
          label: l10n.cardsLoadToSlot,
          variant: SpectraButtonVariant.secondary,
          onPressed: onLoadToSlot,
        ),
        const SizedBox(height: SpectraSpacing.md),
```

- [ ] **Step 5: Run the tests and watch them pass**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/cards
cd .. && dart run melos run check:all
```

Expected: PASS, and `lint:deps` green — the cards feature imports `features/slots/slots.dart`, the barrel, and nothing under `features/slots/ui/` or `state/`.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/cards app/test/features/cards
git commit -m "feat(cards): load a saved card into a slot from its detail page

The first half of spec 7.7 step 5, reached from where the user already is.
Which slot is the Slots feature's own question, so it is asked through the
picker that feature published rather than by a second slot list here.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RsoXVLpXo5zoScmBLSMFw5"
```

---

### Task 8: The `CardWriter` notifier

Spec 7.7 step 5, second half: write a saved card back onto a physical card. MIFARE Classic through `mf1WriteDump` (Task 1), EM410x onto a T55xx through `em410xWriteToT55xx` (Task 2), everything else a typed unsupported state.

**Files:**
- Create: `app/lib/features/cards/state/write_card_controller.dart`
- Modify: `app/lib/features/cards/state/default_keys.dart`
- Test: `app/test/features/cards/write_card_test.dart`

**Interfaces:**
- Consumes: `activeSessionProvider`, `ActiveSession.session`; `ReaderFacade.mf1WriteDump(...) → Future<Mf1DumpWriteResult>` and `.em410xWriteToT55xx(...)` (Tasks 1, 2); `Mf1DumpWriteResult.writtenBlockCount/attemptedBlockCount/isComplete`; `CancelToken()` and `CommandCancelled` from the SDK; `CardWriteMethod`, `writeMethodFor`, `expectedDumpLength` (Task 3); `defaultMifareKeys()` (`state/default_keys.dart`).
- Produces, relied on by Task 9:
  - `final class CardWriteState` with `const CardWriteState({bool busy = false, double? progress, Object? error, bool unsupported = false, int? written, int? attempted})`.
  - `@riverpod class CardWriter extends _$CardWriter` — provider `cardWriterProvider`:
    - `CardWriteState build()`
    - `Future<void> write({required TagType type, required Uint8List bytes})`
    - `void cancel()`
    - `void reset()`
    - `@visibleForTesting void debugFail(Object error)`
  - In `default_keys.dart`: `Uint8List defaultT55xxKey()` and `List<Uint8List> defaultT55xxOldKeys()`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/cards/write_card_test.dart
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/emulator/demo_cards.dart';
import 'package:spectra/features/cards/state/write_card_controller.dart';

import '../../support/app_harness.dart';

Uint8List classic1k(int fill) {
  final Uint8List blocks = Uint8List(64 * 16);
  blocks.setRange(0, 4, <int>[0xDE, 0xAD, 0xBE, 0xEF]);
  blocks[4] = 0xDE ^ 0xAD ^ 0xBE ^ 0xEF;
  blocks[5] = 0x08;
  blocks[6] = 0x04;
  blocks[7] = 0x00;
  for (int block = 1; block < 64; block++) {
    if (block % 4 == 3) continue;
    blocks.fillRange(block * 16, block * 16 + 16, fill);
  }
  return blocks;
}

/// The app with the emulated device's scripted cards in the reader's field
/// (`core/emulator/demo_cards.dart`), which is what the production transport
/// factory hands the fake device anyway.
Future<CardWriter> openWriter(WidgetTester tester) async {
  useDesktopSurface(tester);
  await pumpTestApp(tester, transport: (_) => buildEmulatedDevice());
  await connectToEmulator(tester);
  keepAlive(tester, cardWriterProvider);
  await pumpFrames(tester);
  return readProvider(tester, cardWriterProvider.notifier);
}

void main() {
  testWidgetsApp('writes a MIFARE Classic dump onto the card in the field', (
    tester,
  ) async {
    final CardWriter writer = await openWriter(tester);

    final Future<void> pending = writer.write(
      type: TagType.mifare1k,
      bytes: classic1k(0x7E),
    );
    await pumpFrames(tester, count: 40);
    await pending;
    await pumpFrames(tester);

    final CardWriteState state = readProvider(tester, cardWriterProvider);
    expect(state.error, isNull);
    expect(state.busy, isFalse);
    expect(state.attempted, 47); // 64 blocks less block 0 and 16 trailers
    expect(state.written, 47);
  });

  testWidgetsApp('writes an EM410x id to the T55xx in the field', (
    tester,
  ) async {
    final CardWriter writer = await openWriter(tester);

    final Future<void> pending = writer.write(
      type: TagType.em410x,
      bytes: Uint8List.fromList(<int>[0xAA, 0xBB, 0xCC, 0xDD, 0xEE]),
    );
    await pumpFrames(tester, count: 20);
    await pending;
    await pumpFrames(tester);

    final CardWriteState state = readProvider(tester, cardWriterProvider);
    expect(state.error, isNull);
    expect(state.written, 1);
    expect(state.attempted, 1);
  });

  testWidgetsApp('an Ultralight dump is a typed unsupported state', (
    tester,
  ) async {
    final CardWriter writer = await openWriter(tester);

    final Future<void> pending = writer.write(
      type: TagType.ntag215,
      bytes: Uint8List(135 * 4),
    );
    await pumpFrames(tester);
    await pending;

    final CardWriteState state = readProvider(tester, cardWriterProvider);
    expect(state.unsupported, isTrue);
    expect(state.error, isNull);
  });

  testWidgetsApp('no card in the field is the typed LfTagNotFound', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await connectToEmulator(tester);
    keepAlive(tester, cardWriterProvider);
    await pumpFrames(tester);
    final CardWriter writer = readProvider(tester, cardWriterProvider.notifier);

    final Future<void> pending = writer.write(
      type: TagType.em410x,
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4, 5]),
    );
    await pumpFrames(tester, count: 20);
    await pending;
    await pumpFrames(tester);

    expect(
      readProvider(tester, cardWriterProvider).error,
      isA<LfTagNotFound>(),
    );
  });

  testWidgetsApp('reset clears a failure', (tester) async {
    final CardWriter writer = await openWriter(tester);
    writer.debugFail(const LfTagNotFound());
    await pumpFrames(tester, count: 2);
    expect(readProvider(tester, cardWriterProvider).error, isNotNull);

    writer.reset();
    await pumpFrames(tester, count: 2);
    expect(readProvider(tester, cardWriterProvider).error, isNull);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/cards/write_card_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: '.../write_card_controller.dart'`.

- [ ] **Step 3: Add the T55xx passwords**

Append to `app/lib/features/cards/state/default_keys.dart`:

```dart
/// The T55xx passwords an EM410x write uses.
///
/// `ReaderFacade.em410xWriteToT55xx` takes its keys as parameters, like
/// every other reader operation (spec 8.1), so the list lives in the app
/// beside the MIFARE dictionary and Phase 9's `DictionariesRepository` can
/// replace both without touching the SDK.
///
/// These are the widely published defaults for T5577 blanks, not values read
/// out of any GPL source. **`hardware-validate` (checklist H3):** whether a
/// given blank answers to them is only provable with a card in hand — a
/// blank with no password set ignores `oldKeys` entirely, and one with a
/// password Spectra does not know simply refuses the write.
const String defaultT55xxKeyHex = '20206666';
const List<String> defaultT55xxOldKeyHex = <String>[
  '51243648',
  '19920427',
];

Uint8List _hex(String hex) => Uint8List.fromList(<int>[
  for (int i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);

/// A fresh copy each call, so a caller mutating a key cannot poison the next
/// write.
Uint8List defaultT55xxKey() => _hex(defaultT55xxKeyHex);

List<Uint8List> defaultT55xxOldKeys() => <Uint8List>[
  for (final String hex in defaultT55xxOldKeyHex) _hex(hex),
];
```

If the landed `defaultMifareKeys()` already contains an inline hex-decoding loop, refactor it to call `_hex` in the same commit — one hex decoder per file.

- [ ] **Step 4: Write the controller**

```dart
// app/lib/features/cards/state/write_card_controller.dart
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/session/active_device.dart';
import '../../../core/session/active_session.dart';
import 'default_keys.dart';
import 'write_target.dart';

part 'write_card_controller.g.dart';

/// The write's whole state; no `copyWith`, for the reason `ReadState` gives.
final class CardWriteState {
  const CardWriteState({
    this.busy = false,
    this.progress,
    this.error,
    this.unsupported = false,
    this.written,
    this.attempted,
  });

  final bool busy;

  /// A fraction of the **sectors** done, not the blocks:
  /// `ReaderFacade.mf1WriteDump`'s `onProgress(done, total)` counts sectors
  /// (16 for a 1K), while [written] and [attempted] count blocks (47 of the
  /// 64 on the same card). Both are correct, they just count different units
  /// — the same pairing `ReadState.progress` documents for reads (Phase 6
  /// ruling 23). Null for a write with no per-chunk notion (an LF id).
  final double? progress;

  final Object? error;

  /// This tag type has no reader write in the SDK
  /// (`CardWriteMethod.unsupported`). A state, not an error.
  final bool unsupported;

  /// Blocks written and blocks attempted, once the write has finished. One
  /// and one for an LF id: it is a single command, and reporting it as
  /// "1 of 1" keeps the summary one sentence instead of two.
  final int? written;
  final int? attempted;

  bool get isDone => written != null;

  /// Some of what was attempted did not go on. A normal outcome for a card
  /// with locked sectors, not an error.
  bool get isPartial => written != null && attempted != null && written! < attempted!;
}

/// Spec 7.7 step 5: write a dump back onto a physical card.
///
/// Only the two families the SDK's `ReaderFacade` can write are offered —
/// MIFARE Classic block by block, and an EM410x id onto a T55xx blank.
/// Everything else is [CardWriteState.unsupported]: a typed state the sheet
/// renders as a sentence, never a silent no-op and never a guess at some
/// other encoding.
///
/// **`hardware-validate` (checklist H3): nothing here is proven on a real
/// card.** `FakeDevice` accepts every write and hands the bytes straight
/// back, which proves the app's sequencing and nothing about a card whose
/// access bits refuse a key or a blank that will not take a password. The
/// sheet says so on screen for as long as that stays true.
///
/// No wakelock code: `mf1WriteDump` runs the whole write inside one reader
/// lease and one `DeviceSession.busy`, which is exactly what
/// `sessionNeedsWakelock` polls.
///
/// Drop, do not queue (`_inFlight`); the sheet disables its button while
/// `state.busy`. Every post-`await` assignment is guarded with `ref.mounted`
/// (R25).
@riverpod
class CardWriter extends _$CardWriter {
  @override
  CardWriteState build() {
    ref.onDispose(() {
      // Not `state` — the element is gone by now (Global Constraints).
      _cancel?.cancel();
      _inFlight = false;
    });
    return const CardWriteState();
  }

  CancelToken? _cancel;
  bool _inFlight = false;

  Future<void> write({
    required TagType type,
    required Uint8List bytes,
  }) async {
    if (_inFlight) return;
    final CardWriteMethod method = writeMethodFor(type);
    if (method == CardWriteMethod.unsupported) {
      state = const CardWriteState(unsupported: true);
      return;
    }
    final ActiveSession? active = ref.read(activeSessionProvider);
    if (active == null) {
      state = const CardWriteState(error: SessionNotReady('no active session'));
      return;
    }
    final int expected = expectedDumpLength(type);
    if (bytes.length != expected) {
      state = CardWriteState(
        error: ArgumentError.value(
          bytes.length,
          'bytes',
          'a $type dump is $expected bytes',
        ),
      );
      return;
    }

    _inFlight = true;
    final CancelToken cancel = CancelToken();
    _cancel = cancel;
    state = const CardWriteState(busy: true);
    try {
      final (int written, int attempted) = switch (method) {
        CardWriteMethod.mifareClassicBlocks => await _writeClassic(
          active.session.reader,
          type,
          bytes,
          cancel,
        ),
        CardWriteMethod.em410xT55xx => await _writeEm410x(
          active.session.reader,
          bytes,
        ),
        CardWriteMethod.unsupported => (0, 0), // Unreachable.
      };
      if (ref.mounted) {
        state = CardWriteState(written: written, attempted: attempted);
      }
    } on Object catch (error) {
      if (ref.mounted) state = CardWriteState(error: error);
    } finally {
      _inFlight = false;
      _cancel = null;
    }
  }

  /// Asks the running write to stop. The SDK has no wire-level cancel, so
  /// the command in flight still runs to completion or timeout before the
  /// future resolves with `CommandCancelled` (spec 4.3's honest contract).
  /// An EM410x write is one round trip with nothing to check cancellation
  /// between, so calling this during one does nothing.
  void cancel() => _cancel?.cancel();

  /// Back to the empty state, so the sheet offers the write again.
  void reset() => state = const CardWriteState();

  @visibleForTesting
  void debugFail(Object error) => state = CardWriteState(error: error);

  Future<(int, int)> _writeClassic(
    ReaderFacade reader,
    TagType type,
    Uint8List bytes,
    CancelToken cancel,
  ) async {
    final Mf1DumpWriteResult result = await reader.mf1WriteDump(
      type: type,
      blocks: bytes,
      candidateKeys: defaultMifareKeys(),
      onProgress: (int done, int total) {
        if (!ref.mounted) return;
        state = CardWriteState(
          busy: true,
          progress: total == 0 ? null : done / total,
        );
      },
      cancel: cancel,
    );
    return (result.writtenBlockCount, result.attemptedBlockCount);
  }

  Future<(int, int)> _writeEm410x(ReaderFacade reader, Uint8List id) async {
    await reader.em410xWriteToT55xx(
      id: id,
      newKey: defaultT55xxKey(),
      oldKeys: defaultT55xxOldKeys(),
    );
    return (1, 1);
  }
}
```

- [ ] **Step 5: Generate, run the tests and watch them pass**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && dart run build_runner build --delete-conflicting-outputs
cd app && flutter test test/features/cards/write_card_test.dart
cd .. && dart run melos run check:all
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/cards/state app/test/features/cards/write_card_test.dart
git commit -m "feat(cards): write a saved dump back onto a physical card

Two families, because two is what the SDK's reader facade can write; every
other type is a typed unsupported state rather than a dead button. Nothing
here is proven on a real card, and the controller says so where the next
reader will look.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RsoXVLpXo5zoScmBLSMFw5"
```

---

### Task 9: The write-to-card sheet and its entry point (owns the ARB)

**Files:**
- Create: `app/lib/features/cards/ui/write_card_sheet.dart`
- Modify: `app/lib/features/cards/ui/card_detail_page.dart`, `app/lib/l10n/app_en.arb`
- Test: `app/test/features/cards/write_card_test.dart` (append a `group`)

**Interfaces:**
- Consumes: `cardWriterProvider`, `CardWriteState`, `CardWriter.write/cancel/reset` (Task 8); `SpectraBottomSheet.show`, `SpectraCard`, `SpectraButton`, `SpectraProgressIndicator` (with its `onCancel`); `ProblemView`; `tagTypeLabel`; `showSlotPicker` is **not** used here.
- Produces:
  - `Future<bool?> showWriteToCardSheet(BuildContext context, {required TagType type, required Uint8List bytes, required String name})` — true when a write finished (complete or partial), null on dismissal.
  - ARB keys: `cardsWriteToCard`, `cardsWriteTitle`, `cardsWritePrompt`, `cardsWriteNotice`, `cardsWriteConfirm`, `cardsWriteProgress`, `cardsWriteDone`, `cardsWritePartial`, `cardsWriteUnsupported`.
  - A second button on the card detail page.

- [ ] **Step 1: Write the failing test**

Append to `app/test/features/cards/write_card_test.dart`:

```dart
  group('the sheet', () {
    testWidgetsApp('warns, writes and summarises', (tester) async {
      await openWriter(tester);
      final BuildContext context = tester.element(find.byType(SpectraAppShell));

      final Future<bool?> pending = showWriteToCardSheet(
        context,
        type: TagType.mifare1k,
        bytes: classic1k(0x66),
        name: 'Office badge',
      );
      await pumpFrames(tester);
      expect(
        find.text(
          'Writing to a physical card has not been checked on real hardware '
          'yet. Use a card you can afford to lose.',
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(SpectraBottomSheet),
          matching: find.text('Write'),
        ),
      );
      await pumpFrames(tester, count: 40);
      expect(find.text('47 of 47 blocks written.'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(SpectraBottomSheet),
          matching: find.text('Close'),
        ),
      );
      await pumpFrames(tester);
      expect(await pending, isTrue);
    });

    testWidgetsApp('says so for a type it cannot write', (tester) async {
      await openWriter(tester);
      final BuildContext context = tester.element(find.byType(SpectraAppShell));

      final Future<bool?> pending = showWriteToCardSheet(
        context,
        type: TagType.ntag215,
        bytes: Uint8List(135 * 4),
        name: 'Tag',
      );
      await pumpFrames(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(SpectraBottomSheet),
          matching: find.text('Write'),
        ),
      );
      await pumpFrames(tester);
      expect(
        find.text('Spectra cannot write this tag type onto a card yet.'),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(SpectraBottomSheet),
          matching: find.text('Close'),
        ),
      );
      await pumpFrames(tester);
      expect(await pending, isNull);
    });

    testWidgetsApp('a failure lands in the shared ProblemView', (tester) async {
      final CardWriter writer = await openWriter(tester);
      final BuildContext context = tester.element(find.byType(SpectraAppShell));

      final Future<bool?> pending = showWriteToCardSheet(
        context,
        type: TagType.mifare1k,
        bytes: classic1k(0x66),
        name: 'Office badge',
      );
      await pumpFrames(tester);
      writer.debugFail(const HfTagNotFound());
      await pumpFrames(tester);
      expect(
        find.descendant(
          of: find.byType(SpectraBottomSheet),
          matching: find.byType(ProblemView),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.close));
      await pumpFrames(tester);
      await pending;
    });
  });
```

with the imports this group needs added at the top of the file:

```dart
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/core/errors/problem_view.dart';
import 'package:spectra/features/cards/ui/write_card_sheet.dart';
import 'package:spectra_ui/spectra_ui.dart';
```

- [ ] **Step 2: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/cards/write_card_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: '.../write_card_sheet.dart'`.

- [ ] **Step 3: Add the ARB strings and regenerate**

```json
  "cardsWriteToCard": "Write to a card",
  "@cardsWriteToCard": {"description": "Action on a saved card: put it onto a physical blank."},
  "cardsWriteTitle": "Write to a card",
  "@cardsWriteTitle": {"description": "Title of the write-to-card sheet."},
  "cardsWritePrompt": "Hold a writable blank against the back of the Chameleon, then write {name} onto it.",
  "@cardsWritePrompt": {
    "description": "What writing will do, before it is confirmed.",
    "placeholders": {"name": {"type": "String"}}
  },
  "cardsWriteNotice": "Writing to a physical card has not been checked on real hardware yet. Use a card you can afford to lose.",
  "@cardsWriteNotice": {"description": "Standing hardware-validation notice on the write sheet."},
  "cardsWriteConfirm": "Write",
  "@cardsWriteConfirm": {"description": "Starts the write."},
  "cardsWriteProgress": "Writing to the card…",
  "@cardsWriteProgress": {"description": "Progress label while a card is being written."},
  "cardsWriteDone": "{written} of {attempted} blocks written.",
  "@cardsWriteDone": {
    "description": "Summary after a write.",
    "placeholders": {"written": {"type": "int"}, "attempted": {"type": "int"}}
  },
  "cardsWritePartial": "Blocks that did not take the write are unchanged on the card.",
  "@cardsWritePartial": {"description": "Extra line shown when some blocks were refused."},
  "cardsWriteUnsupported": "Spectra cannot write this tag type onto a card yet.",
  "@cardsWriteUnsupported": {"description": "Shown for a tag type with no reader write."},
```

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter gen-l10n
```

- [ ] **Step 4: Write the sheet**

```dart
// app/lib/features/cards/ui/write_card_sheet.dart
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/problem_view.dart';
import '../../../core/format/tag_labels.dart';
import '../../../l10n/app_localizations.dart';
import '../state/write_card_controller.dart';

/// Spec 7.7 step 5: write [bytes] onto the card in the reader's field.
///
/// Resolves to true when a write finished — complete or partial, both are
/// outcomes the user acted on — and to null when the sheet was dismissed,
/// including a dismissal after an unsupported type or a failure.
///
/// `hardware-validate`: the sheet carries a standing notice, because
/// everything under it is proven against `FakeDevice` only. Remove the
/// notice when the H3 checklist item for a physical write is reported
/// passing, not before.
Future<bool?> showWriteToCardSheet(
  BuildContext context, {
  required TagType type,
  required Uint8List bytes,
  required String name,
}) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return SpectraBottomSheet.show<bool>(
    context: context,
    title: l10n.cardsWriteTitle,
    builder: (BuildContext context) =>
        _WriteCardBody(type: type, bytes: bytes, name: name),
  );
}

class _WriteCardBody extends ConsumerWidget {
  const _WriteCardBody({
    required this.type,
    required this.bytes,
    required this.name,
  });

  final TagType type;
  final Uint8List bytes;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CardWriteState state = ref.watch(cardWriterProvider);
    final CardWriter writer = ref.read(cardWriterProvider.notifier);

    if (state.error case final Object error) {
      return ProblemView(
        error: error,
        onAction: writer.reset,
        variant: SpectraButtonVariant.secondary,
      );
    }
    if (state.busy) {
      return SpectraProgressIndicator(
        label: l10n.cardsWriteProgress,
        value: state.progress,
        onCancel: writer.cancel,
      );
    }
    if (state.isDone) {
      return SpectraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.cardsWriteDone(state.written!, state.attempted!)),
            if (state.isPartial) ...<Widget>[
              const SizedBox(height: SpectraSpacing.sm),
              Text(l10n.cardsWritePartial),
            ],
            const SizedBox(height: SpectraSpacing.lg),
            SpectraButton(
              label: l10n.commonClose,
              variant: SpectraButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );
    }
    if (state.unsupported) {
      return SpectraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.cardsWriteUnsupported),
            const SizedBox(height: SpectraSpacing.lg),
            SpectraButton(
              label: l10n.commonClose,
              variant: SpectraButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
    return SpectraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.cardsWritePrompt(name)),
          const SizedBox(height: SpectraSpacing.sm),
          Text(tagTypeLabel(type, l10n)),
          const SizedBox(height: SpectraSpacing.md),
          Text(l10n.cardsWriteNotice),
          const SizedBox(height: SpectraSpacing.lg),
          SpectraButton(
            label: l10n.cardsWriteConfirm,
            onPressed: () => writer.write(type: type, bytes: bytes),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Wire the entry point**

In `app/lib/features/cards/ui/card_detail_page.dart` add the import:

```dart
import 'write_card_sheet.dart';
```

the handler beside `_loadToSlot`:

```dart
  /// Spec 7.7 step 5: put this card back onto a physical blank. The sheet
  /// owns every outcome, so nothing is reported here beyond it.
  Future<void> _writeToCard(BuildContext context, CardEditState state) =>
      showWriteToCardSheet(
        context,
        type: state.tagType,
        bytes: state.bytes,
        name: state.card.name,
      );
```

the callback into `_Detail`:

```dart
        onWriteToCard: () => _writeToCard(context, value),
```

the field on `_Detail`:

```dart
  final VoidCallback onWriteToCard;
```

and the button, directly below the "Load into a slot" button Task 7 added:

```dart
        SpectraButton(
          label: l10n.cardsWriteToCard,
          variant: SpectraButtonVariant.secondary,
          onPressed: onWriteToCard,
        ),
        const SizedBox(height: SpectraSpacing.md),
```

`_writeToCard` returns a `Future<bool?>` that the `VoidCallback` discards; if `analyze` objects, write `onWriteToCard: () => unawaited(_writeToCard(context, value))` — `dart:async` is already imported by this file.

- [ ] **Step 6: Run the tests and watch them pass**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/cards
cd .. && dart run melos run check:all
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/cards app/lib/l10n app/test/features/cards
git commit -m "feat(cards): the write-to-card sheet, with its hardware notice

The one screen in the app that can damage something the user owns, so it
says out loud that it has never been run against a real card, and reports a
partial write as a count rather than as success.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RsoXVLpXo5zoScmBLSMFw5"
```

---

### Task 10: Quick emulate from the read screen (owns the ARB)

Spec 7.7 step 5's third clause: emulate a card that was just read, without saving it first. Read → pick a slot → loaded, in one step.

**Files:**
- Modify: `app/lib/features/cards/ui/read_page.dart`, `app/lib/l10n/app_en.arb`
- Test: `app/test/features/cards/read_page_test.dart` (append; confirm the landed file name with `ls app/test/features/cards`)

**Interfaces:**
- Consumes: `CardReadResult.tagType`, `.bytes`, `.canSave` (`../state/read_state.dart`); `slotLoadMethodFor`, `SlotLoadMethod` (Task 3); `showSlotPicker` (Slots barrel); `showLoadToSlotSheet` (Task 6); `tagTypeLabel`.
- Produces: ARB key `cardsEmulateThis`. No new public Dart names — `_Result` gains one button.

- [ ] **Step 1: Write the failing test**

```dart
  testWidgetsApp('emulates a just-read card in one step', (tester) async {
    useDesktopSurface(tester);
    // No transport override: the production factory gives the emulated
    // device its scripted cards (`core/emulator/demo_cards.dart`).
    await pumpTestApp(tester);
    await connectToEmulator(tester);
    keepAlive(tester, slotViewsProvider);
    await tester.tap(find.text('Cards').last);
    await pumpFrames(tester);
    await tester.tap(find.text('Read a card'));
    await pumpFrames(tester);
    await tester.tap(find.text('Scan high frequency'));
    await pumpFrames(tester, count: 40);

    await tester.tap(find.text('Emulate this card'));
    await pumpFrames(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(SpectraSlotTile),
      ).at(1),
    );
    await pumpFrames(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Load'),
      ),
    );
    await pumpFrames(tester, count: 30);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Close'),
      ),
    );
    await pumpFrames(tester);

    final List<SlotView> views = readProvider(tester, slotViewsProvider);
    expect(views[1].slot.hfType, TagType.mifare1k);
    expect(views[1].slot.hfEnabled, isTrue);
    expect(views[1].isActive, isTrue);
  });
```

- [ ] **Step 2: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/cards/read_page_test.dart
```

Expected: FAIL — `Nothing found` for `find.text('Emulate this card')`.

- [ ] **Step 3: Add the ARB string and regenerate**

```json
  "cardsEmulateThis": "Emulate this card",
  "@cardsEmulateThis": {"description": "Loads the card that was just read straight into a slot."},
```

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter gen-l10n
```

- [ ] **Step 4: Add the button**

In `app/lib/features/cards/ui/read_page.dart` add the imports:

```dart
import '../../slots/slots.dart' show showSlotPicker;
import '../state/write_target.dart';
import 'load_to_slot_sheet.dart';
```

and, in `_Result.build`, between the "Save to library" and "Read again" buttons:

```dart
        if (slotLoadMethodFor(result.tagType) != SlotLoadMethod.unsupported &&
            result.bytes.isNotEmpty) ...<Widget>[
          const SizedBox(height: SpectraSpacing.md),
          SpectraButton(
            label: l10n.cardsEmulateThis,
            variant: SpectraButtonVariant.secondary,
            onPressed: () => _emulate(context, l10n),
          ),
        ],
```

and the method on `_Result`:

```dart
  /// Spec 7.7 step 5, quick emulate: the card that was just read goes into a
  /// slot without being saved first. It has no name of its own yet, so the
  /// slot is named after its tag type — a name the user can change in the
  /// slot editor, and one that is never empty.
  Future<void> _emulate(BuildContext context, AppLocalizations l10n) async {
    final int? slotIndex = await showSlotPicker(context);
    if (slotIndex == null || !context.mounted) return;
    await showLoadToSlotSheet(
      context,
      slotIndex: slotIndex,
      type: result.tagType,
      bytes: result.bytes,
      name: tagTypeLabel(result.tagType, l10n),
    );
  }
```

- [ ] **Step 5: Run the tests and watch them pass**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/cards
cd .. && dart run melos run check:all
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/cards app/lib/l10n app/test/features/cards
git commit -m "feat(cards): emulate a card straight off the read screen

Spec 7.7 step 5's quick path: read, choose a slot, done, with no trip
through the library for a card the user may not want to keep.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RsoXVLpXo5zoScmBLSMFw5"
```

---

### Task 11: The flow widget test

One test that walks the whole feature the way a person does: read a card on the emulator, save it, open it, load it into a slot, and see the slot grid change. The widget-test twin of the gate, and much faster to run.

**Files:**
- Create: `app/test/flows/write_emulate_flow_test.dart`

**Interfaces:**
- Consumes: the harness's `testWidgetsApp`, `pumpTestApp`, `connectToEmulator`, `pumpFrames`, `useDesktopSurface`, `keepAlive`, `readProvider`, `openSlots`; `slotViewsProvider`, `SlotView` (Slots barrel); `SpectraBottomSheet`, `SpectraSlotTile`, `SpectraTextField` (`package:spectra_ui`); the landed flow tests `app/test/flows/connect_flow_test.dart` and `slot_edit_flow_test.dart` as the shape to copy.
- Produces: nothing importable.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/flows/write_emulate_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/features/slots/slots.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/app_harness.dart';

/// Spec 7.7 steps 3-5 end to end, in emulator mode: read the card the fake
/// presents, save it, load it into a slot, and see the slot grid agree.
/// No transport override — the production factory
/// (`core/emulator/demo_cards.dart`) is what gives the emulated device a
/// card to read, and this flow is worth running through it.
void main() {
  testWidgetsApp('read, save, then load the saved card into a slot', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await pumpTestApp(tester);
    await connectToEmulator(tester);
    keepAlive(tester, slotViewsProvider);

    // Read.
    await tester.tap(find.text('Cards').last);
    await pumpFrames(tester);
    await tester.tap(find.text('Read a card'));
    await pumpFrames(tester);
    await tester.tap(find.text('Scan high frequency'));
    await pumpFrames(tester, count: 40);
    expect(find.text('MIFARE Classic 1K'), findsWidgets);

    // Save.
    await tester.tap(find.text('Save to library'));
    await pumpFrames(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(SpectraTextField),
      ).first,
      'Office badge',
    );
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Save'),
      ),
    );
    await pumpFrames(tester, count: 20);

    // Open it from the library.
    await tester.tap(find.text('Cards').last);
    await pumpFrames(tester);
    await tester.tap(find.text('Office badge'));
    await pumpFrames(tester);

    // Load it into slot 5.
    await tester.tap(find.text('Load into a slot'));
    await pumpFrames(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(SpectraSlotTile),
      ).at(4),
    );
    await pumpFrames(tester);
    expect(find.text('Load into slot 5'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Load'),
      ),
    );
    await pumpFrames(tester, count: 40);
    expect(find.text('Loaded into slot 5.'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Close'),
      ),
    );
    await pumpFrames(tester);

    // The slot grid, and the device behind it, agree.
    await openSlots(tester);
    final SpectraSlotTile fifth = tester.widget<SpectraSlotTile>(
      find.byType(SpectraSlotTile).at(4),
    );
    expect(fifth.nickname, 'Office badge');
    expect(fifth.active, isTrue);

    final List<SlotView> views = readProvider(tester, slotViewsProvider);
    expect(views[4].slot.hfNick, 'Office badge');
    expect(views[4].slot.hfEnabled, isTrue);
  });
}
```

- [ ] **Step 2: Run it**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/flows/write_emulate_flow_test.dart
```

Expected: PASS with Tasks 1-10 landed. If it fails on a finder, widen a `pumpFrames(tester, count: …)` before touching production code — `FakeDevice` answers on a real timer (ruling 22) and a MIFARE Classic dump is 16 sector round trips followed by 64 block reads.

- [ ] **Step 3: Run the whole suite**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd .. && dart run melos run check:all
```

Expected: green.

- [ ] **Step 4: Commit**

```bash
git add app/test/flows/write_emulate_flow_test.dart
git commit -m "test(cards): walk read, save and load-to-slot as one flow

The pieces each have their own test; this is the one that would catch a
seam between them — a picker that hands back a display number, a sheet that
never pops, a slot grid that does not refresh.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RsoXVLpXo5zoScmBLSMFw5"
```

---

### Task 12: The phase gate — the integration test on the emulator

Roadmap, Phase 7: "integration test on emulator". Same app, same overrides, a real engine.

**Files:**
- Create: `app/integration_test/load_to_slot_flow_test.dart`

**Interfaces:**
- Consumes: `app/integration_test/support.dart`, which re-exports `appOverrides`, `pumpFrames` and `testApp` from the harness (Phase 6 ruling 9 — never a fourth inline override block). If `support.dart`'s `show` clause does not yet list something this test needs, **widen that clause**; do not build a second override list.
- Produces: nothing importable.

- [ ] **Step 1: Write the test**

```dart
// app/integration_test/load_to_slot_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import 'support.dart';

/// The Phase 7 gate on a real engine: read a card in emulator mode, save it,
/// load it into a slot, and see it in the slot grid. No hardware is touched,
/// and none is needed.
///
/// No `transport:` argument: the production factory
/// (`core/emulator/demo_cards.dart`) is what puts a card in the emulated
/// device's field, and the gate is worth running through the real one.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('load a saved card into a slot on the emulator', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pump();

    Future<void> settle([int frames = 20]) => pumpFrames(tester, count: frames);

    await tester.tap(find.text(FakeScanner.emulatedUltra.name));
    await settle(30);
    expect(find.byType(SpectraAppShell), findsOneWidget);

    await tester.tap(find.text('Cards').last);
    await settle();
    await tester.tap(find.text('Read a card'));
    await settle();
    await tester.tap(find.text('Scan high frequency'));
    await settle(40);

    await tester.tap(find.text('Save to library'));
    await settle();
    await tester.enterText(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(SpectraTextField),
      ).first,
      'Office badge',
    );
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Save'),
      ),
    );
    await settle();

    await tester.tap(find.text('Cards').last);
    await settle();
    await tester.tap(find.text('Office badge'));
    await settle();

    await tester.tap(find.text('Load into a slot'));
    await settle();
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(SpectraSlotTile),
      ).at(2),
    );
    await settle();
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Load'),
      ),
    );
    await settle(40);
    expect(find.text('Loaded into slot 3.'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Close'),
      ),
    );
    await settle();

    await tester.tap(find.text('Slots').last);
    await settle();
    final SpectraSlotTile third = tester.widget<SpectraSlotTile>(
      find.byType(SpectraSlotTile).at(2),
    );
    expect(third.nickname, 'Office badge');
    expect(third.active, isTrue);
  });
}
```

`FakeScanner` comes from `package:chameleon/chameleon.dart`; add that import, and widen `app/integration_test/support.dart`'s export clause if `testApp` is not already exported without a `transport` argument (it takes an optional one — no change needed).

- [ ] **Step 2: Run it the way CI does**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test integration_test/load_to_slot_flow_test.dart
```

Expected: PASS. (The landed `slot_edit_flow_test.dart` runs the same way; match how `.github/workflows` invokes the integration tests — check it, and add this file to any explicit list there.)

- [ ] **Step 3: Run everything**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd .. && dart run melos run check:all
cd app && flutter test integration_test
```

Expected: green.

- [ ] **Step 4: Commit**

```bash
git add app/integration_test .github
git commit -m "test(cards): the Phase 7 gate on the emulator

The roadmap's gate for this phase: a card read, saved and loaded into a
slot on a real engine, with the production transport factory in place so
the emulator path the user actually takes is the one under test.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RsoXVLpXo5zoScmBLSMFw5"
```

---

### Task 13: Close-out

The roadmap's per-phase obligation: mark the phase, update the project's context files, record what only hardware can prove, and record the decisions a reviewer would otherwise raise as new.

**Files:**
- Modify: `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md`, `AGENTS.md`, `tasks/lessons.md`, `docs/research/DECISIONS.md`, `docs/hardware-checklist.md`

**Interfaces:**
- Consumes: everything landed in Tasks 1-12.
- Produces: no code.

- [ ] **Step 1: Verify the phase is actually done before writing that it is**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd .. && dart run melos run check:all
cd app && flutter test integration_test
```

Both green, in the foreground, with the output read. If either is red, this task stops here — the close-out is a record of a verified state, not a claim about one.

- [ ] **Step 2: Mark the phase in the roadmap**

In `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md`:
- In the phase table, Phase 7's Plan cell becomes `` `2026-09-03-phase-7-write-emulate.md` (done) ``.
- In "Phase status", `- [ ] Phase 7` becomes `- [x] Phase 7`.

- [ ] **Step 3: Update `AGENTS.md`**

Replace the "Next:" paragraph of the "Current status" section with:

```markdown
Phase 7 (write and emulate) is complete (2026-09-03): `ReaderFacade` gained
`mf1WriteDump` and `em410xWriteToT55xx` (with the fake answering
EM410X_WRITE_TO_T55XX), and the Cards feature gained load-a-card-into-a-slot
(select, reset to type, write emulator data, anti-collision, name, enable,
read back and verify), write-a-card-onto-a-blank for MIFARE Classic and
EM410x with every other type a typed unsupported state, and quick emulate
from the read screen. Entry points are on the card detail page and the read
screen; "which slot?" goes through the Slots feature's published
`showSlotPicker`, so the feature dependency runs one way, `cards -> slots`.
Writing a physical card is `hardware-validate` and the write sheet says so
on screen until H3 reports otherwise.

Next: Phase 8 (firmware update) — write the plan from spec 4.5, 5.3, 5.5,
5.6 and 7.7 step 6 with the writing-plans skill.
```

and add to the plan list:

```markdown
- `2026-09-03-phase-7-write-emulate.md`: load to slot, write to card, quick
  emulate (complete).
```

- [ ] **Step 4: Record the lessons**

Append to `tasks/lessons.md`:

```markdown
## Phase 7 (write and emulate)

- **Two feature barrels that import each other is a design smell, not a lint
  failure.** `tool/dep_lint.dart` allows any feature to import any other
  feature's barrel, so `cards -> slots` and `slots -> cards` would both pass
  while making the two features one. Phase 7 kept the edge one-way by putting
  every entry point on the cards side; `showCardPicker` stays published for
  a consumer that does not create a cycle.
- **A write with no read-back is a claim, not a result.** The load-to-slot
  flow costs one extra round trip to compare what the device stored with what
  was sent, and that is the difference between "loaded" and "probably
  loaded".
- **`EmulatorFacade` always acts on the *active* slot.** Selecting the slot
  is step one of loading it, not an afterthought — a load that skips
  `slots.setActive` silently writes into whichever slot was already active.
- **Skipped is not failed.** `Mf1DumpWriteResult` carries two masks because
  block 0 and the sector trailers are deliberately not written; measuring
  completeness against the whole card would report every successful write as
  a partial one.
```

- [ ] **Step 5: Record the decisions**

Append a "Phase 7" section to `docs/research/DECISIONS.md`:

```markdown
## Phase 7 (write and emulate)

- **No `features/emulate/` module.** All three flows start from a card the
  user is already looking at, so they live in `features/cards/` and reach
  Slots through `showSlotPicker`. A separate feature would have had to import
  both barrels and would still have needed entry points inside `cards`,
  which is the mutual import spec 8.3's barrel rule exists to avoid.
- **`mf1WriteDump` lives in the SDK, not in the app.** Spec 8.1: multi-command
  workflows are one facade method, and app code never builds a `Command`. It
  is the exact mirror of `mf1ReadDump`, down to the lease, the `busy`, the
  per-sector progress and the cancellation points.
- **Block 0 and the sector trailers are skipped by default.** Block 0 needs a
  "magic" card; a trailer written with access bits the card cannot satisfy
  locks that sector permanently. `writeTrailers: true` exists for a caller
  that means it; nothing in v1 passes it.
- **Ultralight cannot be written to a card.** `ReaderFacade` has no
  Ultralight write operation — `EmulatorFacade.writeNtagPages` writes the
  device's own emulation memory — so the app reports a typed unsupported
  state rather than reaching for `Hf14aRaw`. Adding it is spec 8.2's
  extension point: one command plus one facade method.
- **Spec 8.5's one-public-type rule is knowingly relaxed** for
  `state/write_target.dart` (two enums and four functions): they are one
  cohesive concern — what may be written where — and splitting them would add
  files without adding clarity. Recorded here so a reviewer does not raise it
  as new.
- **The T55xx passwords (`20206666`, `51243648`, `19920427`) are the widely
  published defaults for T5577 blanks**, declared in the app because spec 8.1
  makes keys a caller's parameter. Whether a given blank answers to them is
  an H3 item.
```

- [ ] **Step 6: Add the hardware checklist items**

Append under the existing `## H3 (before release): full checklist (spec section 10)` heading in `docs/hardware-checklist.md` (Phase 6 ruling 19: do not open a fourth section with a name a heading already uses):

```markdown
### Phase 7: write and emulate

- [ ] pending: **load a saved card into a slot, then read it back with
      another reader.** In Spectra, save a MIFARE Classic read from a real
      card, then Load into a slot. Report whether a phone or a second reader
      sees the emulated card as the original — UID, SAK and ATQA included.
      The app already compares its own read-back; this checks that the
      device *emulates* what it stored.
- [ ] pending: **`antiCollForClassic`'s block-0 layout on a 7-byte-UID card.**
      `app/lib/features/cards/state/write_target.dart` reads bytes 0-3 as the
      UID, 5 as SAK and 6-7 as ATQA, which is the 4-byte-UID layout
      `MifareClassicDump.uid` already flags. Load a 7-byte-UID card into a
      slot and report what the emulated card answers.
- [ ] pending: **write a MIFARE Classic onto a blank.** Use a card you can
      afford to lose. Report how many blocks the summary says were written,
      and whether reading the blank back afterwards gives the original dump.
- [ ] pending: **which key a data block takes for a write.**
      `ReaderFacade._writeOneBlock` tries key A and then key B. On a card
      whose access bits make key A read-only, report whether the key B retry
      succeeds — against `FakeDevice` both keys are the transport key and the
      order never shows.
- [ ] pending: **write an EM410x id onto a T55xx blank.** Report whether the
      write succeeds with the default password `20206666` and the old keys
      `51243648` / `19920427`
      (`app/lib/features/cards/state/default_keys.dart`), and whether an
      EM410x scan afterwards reads the new id back.
- [ ] pending: **remove the write sheet's hardware notice.** `cardsWriteNotice`
      in `app/lib/l10n/app_en.arb` stays on screen until the two write items
      above are reported passing. Deleting it is the last step of this
      section, not the first.
```

- [ ] **Step 7: Commit**

```bash
git add docs AGENTS.md tasks/lessons.md
git commit -m "docs: close out Phase 7

Marks the phase in the roadmap, points the next session at Phase 8, and
records the two things only a card in hand can prove: what a written blank
reads back as, and which key a data block takes for a write.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RsoXVLpXo5zoScmBLSMFw5"
```

---

## Task order and parallelism

```
T1 ∥ T2 ∥ T3   |   T4   |   T5   |   T6   |   T7   |   T8   |   T9   |   T10   |   T11   |   T12   |   T13
```

- **T1, T2 and T3 are file-disjoint** and may run together: T1 and T2 touch `packages/chameleon` only (T2 appends to the test file T1 creates, so run T2 after T1 if the two are dispatched to separate workers), T3 touches `app/lib/features/cards/state/` and the Slots barrel.
- **T4, T6, T9 and T10 each own `app_en.arb`.** They are serialised by the order above and must never run concurrently with each other.
- **T7, T9 and T10 modify files Phase 6 also touched** (`card_detail_page.dart`, `read_page.dart`). Each of those tasks starts by reading the file as it stands.
- T8 depends on T1 and T2 (the facade methods) and T3 (`writeMethodFor`); T9 depends on T8 and T7 (the button it sits under); T11 and T12 depend on everything.
