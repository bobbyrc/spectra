# Phase 9: Dictionaries and settings — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the last two v1 features: key dictionaries (list, create, edit, import, export, and the built-in default list every read and write already uses), and settings (device settings through `SettingsFacade`, plus app theme, emulator mode, feature flags and licences).

**Architecture:** Two feature modules. `app/lib/features/dictionaries/` is laid out like `features/cards/`: pure `state/` (codec, providers, notifiers) under a layout-only `ui/`, with `dictionaries.dart` as the only import surface, publishing `showDictionaryPicker` and the candidate-key providers the Cards feature reads. Storage goes through the `DictionariesRepository` interface Phase 4 declared, over the `KeyDictionaries` table that already exists at schema version 1 — no migration. The built-in MIFARE key list moves out of `features/cards/state/default_keys.dart` (whose own doc comment predicts this move) into the dictionaries feature and is exposed as a synthesized, read-only dictionary rather than a seeded database row, so "read-only" is true by construction. `features/settings/` replaces its Phase 4 placeholder with four sections: device settings driven by `SettingsFacade` (write-through, explicit save, re-read), app settings persisted through `PreferencesRepository`, a developer section that finally gives `FeatureFlagsController.setDfuOverBleEnabled` a caller, and an About section over `showLicensePage`.

**Tech Stack:** Flutter 3.47.2 / Dart 3.13, riverpod 3.4.2 + riverpod_generator 4.0.8, go_router 18, Drift 2.34, `material_ui` 1.1.1, `package:spectra_ui`, `package:chameleon` (`SettingsFacade`, `DeviceSettings`, `AnimationMode`, `ButtonFunction`, `DeviceButton`, `FakeDevice`).

**Spec:** `docs/superpowers/specs/2026-09-02-spectra-design.md` (sections 4 (`SettingsFacade`), 5.1 (pairing copy), 6.2, 7.3, 7.5, 7.6, 7.7 step 7, 8.1, 8.3–8.6, 9). Roadmap row: `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md`, Phase 9.

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
- Generated code (riverpod_generator, drift, freezed) is committed. After adding or changing an `@riverpod` provider or a Drift table use, run `cd app && dart run build_runner build --delete-conflicting-outputs` and commit the `.g.dart` files. `tool/check_codegen.sh` must pass.
- Package boundaries are enforced by `tool/dep_lint.dart` (`dart run melos run lint:deps`): `app/lib/features/*` may import another feature only through its barrel (`features/<x>/<x>.dart`), may not import `package:flutter/material.dart`, and may not import Drift outside `lib/data/`. Nothing outside `chameleon` may import `package:chameleon/src/...`.
- **`material_ui` only** under `app/lib/features/**` — `import 'package:material_ui/material_ui.dart';`, with `hide ConnectionState` on any features file that also imports `package:chameleon/chameleon.dart` (both libraries declare that name), and **no unused chameleon import** (Phase 6 ruling 3: `melos run analyze` fails on warnings). `package:flutter/services.dart` (for `Clipboard`) and `package:flutter/foundation.dart` are fine.
- All user-facing copy goes through `app/lib/l10n/app_en.arb` and `flutter gen-l10n`. The string-literal lint (`tool/src/string_rules.dart`) scans `lib/features/*/ui/` at any depth; `state/` is out of scope. Technical field names are exempt the way tag-type product names are in `app/lib/core/format/tag_labels.dart` (R28) — but every word in this phase's settings and dictionary screens is ordinary English and goes through the ARB.
- **The ARB is a single-writer resource** (Phase 5 ruling 14). Tasks that append to `app_en.arb` are serialised: never run two of them concurrently. Each such task runs `cd app && flutter gen-l10n` and commits the regenerated `app/lib/l10n/app_localizations*.dart` alongside its ARB edit.
- Riverpod 3.4.2 API notes:
  - `Override` and `ProviderListenable` come from `package:flutter_riverpod/misc.dart`, not the main library.
  - There is no `valueOrNull`. Use `.value` on an `AsyncValue` (null while loading).
  - Do not read `state` inside `ref.onDispose` — the element is already torn down. Mirror what you need in a field.
  - `Notifier.state` is `@visibleForTesting @protected`; assigning it from a test is an analyzer warning and `melos run analyze` fails on warnings. A notifier that needs a test to force a failure ships `@visibleForTesting void debugFail(Object error)` (Phase 5 ruling 3).
  - `@riverpod` is autoDispose; `@Riverpod(keepAlive: true)` is not. **Ruling 20 (Phase 4):** an autoDispose stream/async provider read or awaited outside a mounted app needs a listener held first — call the harness's `keepAlive(tester, provider)`, pump a few frames, then `readProvider(tester, provider)` or `readProvider(tester, provider.notifier)`.
  - **Ruling 22 (Phase 5):** `FakeDevice` replies via a real `Timer`, so a test must *start* the operation, *pump*, then *await* it: `final Future<void> f = controller.saveToDevice(); await tester.pump(const Duration(milliseconds: 50)); await f;` — never `await` before pumping.
- **R25 / Phase 6 ruling 2: guard every post-`await` `state =` with `ref.mounted`.** Every notifier in this phase writes to the database or the device after an `await` on an autoDispose element, and every one of their screens can be popped mid-write.
- **Drop, do not queue** (the `SlotEditor` pattern, `app/lib/features/slots/state/slot_editor_controller.dart`): a controller that mutates the device or the database guards re-entry with a plain `bool _inFlight` field, distinct from `state.isLoading`, and the screen disables its controls while busy so a dropped call is never the only thing between a tap and the change it was meant to make.
- **R27: one shared `app/lib/core/errors/problem_view.dart`.** No per-feature problem view. `ProblemView({required Object error, required VoidCallback onAction, String? instructions, SpectraButtonVariant? variant})`.
- **R28: `app/lib/core/format/tag_labels.dart` names tag types and senses.** Anything two features must call by the same name lives in `core/`, not in whichever feature needed it first. Task 1 applies the same rule to hex formatting.
- Every feature's barrel is its only import surface. Phase 9 publishes `features/dictionaries/dictionaries.dart` and consumes nothing from `features/cards/…` except through `features/cards/cards.dart`; the Cards feature consumes the dictionaries barrel (Task 5, Task 9).
- Tests: use the harness (`app/test/support/app_harness.dart`) — `testWidgetsApp`, `pumpTestApp`, `connectToEmulator`, `pumpFrames(tester, count:)`, `useDesktopSurface(tester)`, `keepAlive`, `readProvider`, `settleApp`. **The harness is edited by exactly one task this phase (Task 6, which adds `openDictionaries`)**; no other task touches it. Never write a local `pumpFrames`, and never set `tester.view` by hand (Phase 6 rulings 7 and 8).
- **Phase 6 ruling 10 / Phase 5 ruling 17: finders inside an open sheet are `find.descendant`-scoped.** No `.first`/`.at(n)` index arithmetic against a widget type that also appears on the screen underneath.
- A new `DeviceSession` is constructed per connect attempt; sessions are single-use. Tests pass `transport: (_) => FakeDevice()` — a fresh fake per attempt.
- **Phase 6 ruling 17: spec 8.5's one-public-type-per-file rule is knowingly relaxed** for `state/dictionary_codec.dart` (three types plus three functions, one cohesive concern: the dictionary text formats) and `ui/dictionary_detail_page.dart` (the page plus its private key-row widgets). Each file says so in its doc comment, so a reviewer sees the exception is deliberate.
- Never claim hardware behaviour works. Every device setting here is proven against `FakeDevice` only; BLE pairing behaviour on a real device (spec 5.1: enabling pairing hides the device from other hosts until bonds are cleared) is `hardware-validate` and goes to `docs/hardware-checklist.md`.
- **Cite landed source for every name you use.** If a symbol in this plan does not match the landed code, the landed code wins — report it rather than inventing an adapter. This plan was written while Phases 7 and 8 were in flight, so `app/lib/features/cards/**` and `app/lib/features/tools/**` may have moved on; Tasks 5, 9 and 12 say what to look for.

## Decisions this plan makes

- **No `file_selector`.** Spec 7.3 wants import and export "for cards and dictionaries"; spec section 2's dependency table does not list a file-dialog package, and Phase 6 already shipped card import as paste-in and card export as copy-to-clipboard (`app/lib/features/cards/ui/card_import_sheet.dart`, `card_detail_page.dart::_export`), recording the reasoning in `docs/research/DECISIONS.md`. Adding a file dialog now means a new dependency, per-platform setup on five targets and a spec section 2 amendment, to make dictionaries inconsistent with cards. Dictionaries therefore use the same paste-in / copy-out shape. **No spec amendment is made by this phase.**
- **The built-in key list is synthesized, not seeded.** `dictionariesProvider` puts a virtual `KeyDictionary` (id `builtin-mifare`) in front of the stored rows. Nothing can edit it because it is never a row; its name is localized at render time, which a stored row's name could not be.
- **The `dfuOverBleEnabled` flag gets a developer toggle**, not a read-only row: `FeatureFlagsController.setDfuOverBleEnabled` (`app/lib/core/flags/feature_flags.dart`) landed in Phase 4 with no caller, and spec 5.6's rule is that the flag flips on once the user reports H2 passed — the user needs a switch to flip. The row's subtitle says it stays off until the hardware checklist H2 passes.

## File structure

New, under `app/lib/features/dictionaries/`:

| File | Responsibility |
|---|---|
| `state/built_in_keys.dart` | `defaultMifareKeyHex`, `defaultMifareKeys()`, `builtInDictionaryId`, `builtInDictionary()` |
| `state/dictionary_codec.dart` | `.dic` and JSON parse/export — pure |
| `state/dictionaries_provider.dart` | `dictionariesProvider` stream + `DictionaryLibrary` notifier |
| `state/selected_dictionary.dart` | `SelectedDictionaryId` (persisted), `selectedDictionaryProvider`, `candidateMifareKeysProvider` |
| `ui/dictionaries_page.dart` | `/tools/dictionaries`: the list, create, select |
| `ui/dictionary_detail_page.dart` | `/tools/dictionaries/:id`: rename, keys, delete, duplicate |
| `ui/dictionary_import_sheet.dart` | Paste-in import |
| `ui/dictionary_picker.dart` | **Public API:** `showDictionaryPicker` / `DictionaryPicker` |
| `dictionaries.dart` | The barrel: the feature's whole public surface |

New, under `app/lib/features/settings/`:

| File | Responsibility |
|---|---|
| `state/device_settings_controller.dart` | `DeviceSettingsController` + `DeviceSettingsEditState` |
| `state/settings_labels.dart` | `animationLabel`, `buttonFunctionLabel`, `themeModeLabel` |
| `ui/device_settings_section.dart` | The device half of the screen |
| `ui/app_settings_section.dart` | Theme, emulator mode, developer flags, about |
| `ui/option_sheet.dart` | `showOptionSheet<T>` — one radio-style sheet for every enum choice |

New elsewhere:

| File | Responsibility |
|---|---|
| `app/lib/core/format/hex.dart` | `toHex`, `parseHex`, `parseMifareKey` — moved out of the Cards feature |
| `app/lib/core/theme/theme_mode.dart` | `ThemeModeController` (persisted) + `themeModeProvider` |
| `app/lib/data/database/drift_dictionaries_repository.dart` | `DictionariesRepository` over the `KeyDictionaries` table |
| `app/test/fixtures/reference_dictionary.json` | The reference-app dictionary export fixture |

Modified: `app/lib/data/memory/in_memory_repositories.dart`, `app/lib/data/repository_providers.dart`, `app/lib/core/routing/routes.dart`, `app/lib/core/routing/app_sections.dart`, `app/lib/core/discovery/scanners.dart`, `app/lib/app.dart`, `app/lib/features/tools/ui/tools_page.dart`, `app/lib/features/cards/state/default_keys.dart`, `app/lib/features/cards/state/read_controller.dart`, `app/lib/features/cards/ui/read_page.dart`, `app/lib/features/settings/settings.dart`, `app/lib/features/settings/ui/settings_page.dart`, `app/lib/l10n/app_en.arb`, `app/test/support/app_harness.dart` (Task 6 only).

---

### Task 1: Hex formatting moves to `core/format/`

A dictionary is a list of six-byte keys; parsing and printing them is exactly what `app/lib/features/cards/state/hex.dart` already does. A feature may not import another feature's internals (spec 8.4), so the choice is a second copy or a move. R28 already settled that question for tag labels: shared formatting lives in `core/format/`. This task moves it and adds the one key-shaped helper dictionaries need.

**Files:**
- Create: `app/lib/core/format/hex.dart` (moved from `app/lib/features/cards/state/hex.dart`)
- Delete: `app/lib/features/cards/state/hex.dart`
- Modify: every file that imports it (found by grep in Step 3)
- Test: `app/test/core/format/hex_test.dart` (moved from `app/test/features/cards/hex_test.dart` if that path exists)

**Interfaces:**
- Consumes: nothing but `dart:typed_data`.
- Produces:
  - `String toHex(List<int> bytes, {String separator = ''})` — upper-case, no `0x`.
  - `Uint8List? parseHex(String text)` — tolerates whitespace, `:`, `_`, `-`; null when the text is not an even-length run of hex digits.
  - `const int mifareKeyLength = 6`.
  - `Uint8List? parseMifareKey(String text)` — `parseHex` plus a length check; null unless exactly [mifareKeyLength] bytes.

- [ ] **Step 1: Write the failing test**

Create `app/test/core/format/hex_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/format/hex.dart';

void main() {
  group('toHex', () {
    test('is upper case with no separator by default', () {
      expect(toHex(<int>[0x0a, 0xff, 0x00]), '0AFF00');
    });

    test('honours a separator', () {
      expect(toHex(<int>[1, 2], separator: ' '), '01 02');
    });
  });

  group('parseHex', () {
    test('tolerates separators', () {
      expect(parseHex('AA:BB CC-DD_EE'), <int>[0xAA, 0xBB, 0xCC, 0xDD, 0xEE]);
    });

    test('rejects odd length and non-hex', () {
      expect(parseHex('ABC'), isNull);
      expect(parseHex('zz'), isNull);
    });
  });

  group('parseMifareKey', () {
    test('accepts twelve hex characters', () {
      final Uint8List? key = parseMifareKey('ffffffffffff');
      expect(key, isNotNull);
      expect(key!.length, mifareKeyLength);
      expect(toHex(key), 'FFFFFFFFFFFF');
    });

    test('accepts a spaced key, because a paste often carries spaces', () {
      expect(parseMifareKey('A0 A1 A2 A3 A4 A5'), isNotNull);
    });

    test('rejects any other length', () {
      expect(parseMifareKey('FFFFFFFFFF'), isNull);
      expect(parseMifareKey('FFFFFFFFFFFFFF'), isNull);
      expect(parseMifareKey(''), isNull);
    });

    test('rejects text that is not hex at all', () {
      expect(parseMifareKey('not a key!!!'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/core/format/hex_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: 'package:spectra/core/format/hex.dart'`.

- [ ] **Step 3: Move the file and add the key helper**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd /Users/bcraig/orca/workspaces/spectra/chinook
mkdir -p app/lib/core/format
git mv app/lib/features/cards/state/hex.dart app/lib/core/format/hex.dart
grep -rln "state/hex.dart\|features/cards/state/hex" app/lib app/test
```

Every path that grep prints gets its import rewritten to `package:spectra/core/format/hex.dart` (or the matching relative path — `../../../core/format/hex.dart` from `features/cards/ui/`, `../../../core/format/hex.dart` from `features/cards/state/`). Then append to `app/lib/core/format/hex.dart`:

```dart
/// The length of a MIFARE Classic key, in bytes. Twelve hex characters.
const int mifareKeyLength = 6;

/// A MIFARE Classic key, or null when [text] is not one.
///
/// Callers validate by checking for null rather than catching, the same
/// contract [parseHex] has. Separators are tolerated because a key pasted
/// out of another tool often arrives spaced or colon-grouped.
Uint8List? parseMifareKey(String text) {
  final Uint8List? bytes = parseHex(text);
  return bytes == null || bytes.length != mifareKeyLength ? null : bytes;
}
```

Update the moved file's own doc comment: it currently says "the app's copy rather than a reach into `src/`" — keep that, and add "It lives in `core/format/` beside `tag_labels.dart` (R28) because a card, a dump and a key dictionary all print bytes and must print them the same way."

- [ ] **Step 4: Run the moved test and the whole suite**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/core/format/hex_test.dart && flutter test
```

Expected: PASS. If an old `app/test/features/cards/hex_test.dart` exists, `git rm` it — its cases are all above.

- [ ] **Step 5: Check and commit**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd /Users/bcraig/orca/workspaces/spectra/chinook
dart run melos run check:all
git add -A app/lib app/test
git commit -m "$(cat <<'MSG'
move hex formatting to core/format

A key dictionary and a card dump both print bytes, and a feature may not
import another feature's internals, so the formatter belongs beside
tag_labels.dart rather than in a second copy.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 2: The dictionaries repository

Spec 7.3 gives storage one Drift database behind repository interfaces. `DictionariesRepository` and the `KeyDictionaries` table both landed in Phase 4 with no implementation ("Declared now so the seam exists; implemented in Phase 9"). This task fills that in, so every later task has a real place to put a key list.

**Files:**
- Create: `app/lib/data/database/drift_dictionaries_repository.dart`
- Modify: `app/lib/data/memory/in_memory_repositories.dart`, `app/lib/data/repository_providers.dart`
- Test: `app/test/data/dictionaries_repository_test.dart`

**Interfaces:**
- Consumes: `DictionariesRepository` with `all()`, `save(KeyDictionary)`, `delete(String)`, `watchAll()` (`app/lib/data/repositories.dart`); `KeyDictionary({required String id, required String name, required List<Uint8List> keys, required DateTime updatedAt})` (`app/lib/data/models/key_dictionary.dart`); `SpectraDatabase`, its generated `keyDictionaries` table and `KeyDictionaryRow` data class (`app/lib/data/database/spectra_database.dart`, `tables.dart`); `SpectraDatabase.memory()`; `toHex` / `parseMifareKey` (Task 1).
- Produces:
  - `final class DriftDictionariesRepository implements DictionariesRepository` with `DriftDictionariesRepository(SpectraDatabase db)`.
  - `final class InMemoryDictionariesRepository implements DictionariesRepository`.
  - `@Riverpod(keepAlive: true) DictionariesRepository dictionariesRepository(Ref ref)` in `repository_providers.dart`.
  - Ordering contract, shared by both: newest-updated first.

- [ ] **Step 1: Write the failing test**

Create `app/test/data/dictionaries_repository_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/data/database/drift_dictionaries_repository.dart';
import 'package:spectra/data/database/spectra_database.dart';
import 'package:spectra/data/memory/in_memory_repositories.dart';

Uint8List _key(int fill) => Uint8List.fromList(List<int>.filled(6, fill));

KeyDictionary _dict(String id, {String name = 'Keys', int fill = 0xFF}) =>
    KeyDictionary(
      id: id,
      name: name,
      keys: <Uint8List>[_key(fill)],
      updatedAt: DateTime.utc(2026, 9, 3),
    );

void main() {
  // Both implementations answer the same questions the same way; a test that
  // only exercised the in-memory one would prove nothing about what ships.
  for (final MapEntry<String, DictionariesRepository Function()> entry
      in <String, DictionariesRepository Function()>{
        'drift': () {
          final SpectraDatabase db = SpectraDatabase.memory();
          addTearDown(db.close);
          return DriftDictionariesRepository(db);
        },
        'in memory': InMemoryDictionariesRepository.new,
      }.entries) {
    group(entry.key, () {
      test('saves and reads back a dictionary, keys intact', () async {
        final DictionariesRepository repo = entry.value();
        await repo.save(_dict('a', name: 'Transport', fill: 0xA0));

        final List<KeyDictionary> all = await repo.all();
        expect(all, hasLength(1));
        expect(all.single.name, 'Transport');
        expect(all.single.keys.single, _key(0xA0));
        expect(all.single.updatedAt, DateTime.utc(2026, 9, 3));
      });

      test('save replaces an existing row', () async {
        final DictionariesRepository repo = entry.value();
        await repo.save(_dict('a', name: 'One'));
        await repo.save(_dict('a', name: 'Two'));

        final List<KeyDictionary> all = await repo.all();
        expect(all, hasLength(1));
        expect(all.single.name, 'Two');
      });

      test('orders newest-updated first', () async {
        final DictionariesRepository repo = entry.value();
        await repo.save(
          KeyDictionary(
            id: 'old',
            name: 'Old',
            keys: <Uint8List>[_key(1)],
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
        await repo.save(
          KeyDictionary(
            id: 'new',
            name: 'New',
            keys: <Uint8List>[_key(2)],
            updatedAt: DateTime.utc(2026, 6, 1),
          ),
        );

        expect(
          (await repo.all()).map((KeyDictionary d) => d.id),
          <String>['new', 'old'],
        );
      });

      test('delete removes exactly one row', () async {
        final DictionariesRepository repo = entry.value();
        await repo.save(_dict('a'));
        await repo.save(_dict('b'));
        await repo.delete('a');

        expect((await repo.all()).map((KeyDictionary d) => d.id), <String>['b']);
      });

      test('watchAll emits the current rows, then every change', () async {
        final DictionariesRepository repo = entry.value();
        await repo.save(_dict('a'));

        final Stream<List<KeyDictionary>> stream = repo.watchAll();
        final Future<List<List<KeyDictionary>>> first2 = stream.take(2).toList();
        await repo.save(_dict('b'));

        final List<List<KeyDictionary>> emitted = await first2;
        expect(emitted.first.map((KeyDictionary d) => d.id), <String>['a']);
        expect(emitted.last.map((KeyDictionary d) => d.id), hasLength(2));
      });

      test('an empty key list round-trips as empty, not as one blank key',
          () async {
        final DictionariesRepository repo = entry.value();
        await repo.save(
          KeyDictionary(
            id: 'empty',
            name: 'Empty',
            keys: const <Uint8List>[],
            updatedAt: DateTime.utc(2026, 9, 3),
          ),
        );
        expect((await repo.all()).single.keys, isEmpty);
      });
    });
  }
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/data/dictionaries_repository_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: '.../drift_dictionaries_repository.dart'`.

- [ ] **Step 3: Write the Drift implementation**

Create `app/lib/data/database/drift_dictionaries_repository.dart`:

```dart
import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../../core/format/hex.dart';
import '../models/key_dictionary.dart';
import '../repositories.dart';
import 'spectra_database.dart';

/// Key dictionaries over the `KeyDictionaries` table (spec 7.3). The table
/// landed at schema version 1 in Phase 4, so this needs no migration.
///
/// Keys are one newline-separated hex blob, as `tables.dart` says: a
/// dictionary is read and written whole, and a join table would buy nothing
/// but a migration. A row whose blob holds a line that is not a key (a
/// hand-edited database, a future format) drops that line rather than
/// failing the whole read — a dictionary is a hint list, and losing one bad
/// line is better than losing the list.
final class DriftDictionariesRepository implements DictionariesRepository {
  DriftDictionariesRepository(this._db);
  final SpectraDatabase _db;

  @override
  Future<List<KeyDictionary>> all() async =>
      (await _newestFirst().get()).map(_toModel).toList();

  @override
  Future<void> save(KeyDictionary dictionary) => _db
      .into(_db.keyDictionaries)
      .insertOnConflictUpdate(
        KeyDictionaryRow(
          id: dictionary.id,
          name: dictionary.name,
          keys: encodeKeyLines(dictionary.keys),
          updatedAt: dictionary.updatedAt,
        ),
      );

  @override
  Future<void> delete(String id) =>
      (_db.delete(_db.keyDictionaries)..where((t) => t.id.equals(id))).go();

  @override
  Stream<List<KeyDictionary>> watchAll() => _newestFirst().watch().map(
    (rows) => rows.map(_toModel).toList(growable: false),
  );

  SimpleSelectStatement<$KeyDictionariesTable, KeyDictionaryRow>
  _newestFirst() => _db.select(_db.keyDictionaries)
    ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);

  // Drift's unix-epoch DateTime storage round-trips the same instant but
  // reads it back in the local zone; normalise to UTC so callers get back
  // exactly what they wrote (the `DriftSavedCardsRepository` note).
  KeyDictionary _toModel(KeyDictionaryRow row) => KeyDictionary(
    id: row.id,
    name: row.name,
    keys: decodeKeyLines(row.keys),
    updatedAt: row.updatedAt.toUtc(),
  );
}

/// One key per line, upper-case hex. Public so the in-memory repository and
/// the tests share exactly one encoding.
String encodeKeyLines(List<Uint8List> keys) =>
    keys.map<String>(toHex).join('\n');

List<Uint8List> decodeKeyLines(String blob) => <Uint8List>[
  for (final String line in blob.split('\n'))
    if (parseMifareKey(line) case final Uint8List key) key,
];
```

- [ ] **Step 4: Write the in-memory implementation and the provider**

Append to `app/lib/data/memory/in_memory_repositories.dart` (and add `import '../models/key_dictionary.dart';` to its import block):

```dart
/// A [DictionariesRepository] with no database behind it, for unit tests
/// that are about something else (spec 8.6). Same ordering contract as the
/// Drift one: newest-updated first.
final class InMemoryDictionariesRepository implements DictionariesRepository {
  final Map<String, KeyDictionary> _rows = <String, KeyDictionary>{};
  final StreamController<List<KeyDictionary>> _changes =
      StreamController<List<KeyDictionary>>.broadcast();

  @override
  Future<List<KeyDictionary>> all() async => _sorted();

  @override
  Future<void> save(KeyDictionary dictionary) async {
    _rows[dictionary.id] = dictionary;
    _emit();
  }

  @override
  Future<void> delete(String id) async {
    _rows.remove(id);
    _emit();
  }

  @override
  Stream<List<KeyDictionary>> watchAll() {
    // The `InMemorySavedCardsRepository.watchAll` note applies verbatim: a
    // broadcast controller only receives what is added after a listener
    // attaches, and `async*` attaches one asynchronously, so a save between
    // the call and the subscription would be dropped. A single-subscription
    // controller's `onListen` runs inside `listen()`, so the snapshot and
    // the live subscription are both in place before the caller continues.
    late StreamController<List<KeyDictionary>> controller;
    StreamSubscription<List<KeyDictionary>>? subscription;
    controller = StreamController<List<KeyDictionary>>(
      onListen: () {
        controller.add(_sorted());
        subscription = _changes.stream.listen(
          controller.add,
          onDone: controller.close,
        );
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  List<KeyDictionary> _sorted() =>
      _rows.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  void _emit() {
    if (!_changes.isClosed) _changes.add(_sorted());
  }
}
```

Append to `app/lib/data/repository_providers.dart` (with `import 'database/drift_dictionaries_repository.dart';` in its import block):

```dart
@Riverpod(keepAlive: true)
DictionariesRepository dictionariesRepository(Ref ref) =>
    DriftDictionariesRepository(ref.watch(databaseProvider));
```

- [ ] **Step 5: Regenerate, run the test, check and commit**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && dart run build_runner build --delete-conflicting-outputs
flutter test test/data/dictionaries_repository_test.dart
cd .. && dart run melos run check:all
git add app/lib/data app/test/data
git commit -m "$(cat <<'MSG'
implement the key dictionaries repository

Phase 4 declared the interface and the table and left both empty; every
dictionary screen in this phase needs somewhere real to write.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 3: The dictionary import and export formats

Spec 7.3: "Import from the reference app's JSON export is a v1 requirement for cards and dictionaries, with fixtures built from the documented format." `docs/research/reference-gui.md` records that the reference app has a "dict download" tool and "import/export JSON+QR" in settings, but not the field-level shape — so, exactly as `card_import.dart` did for cards, this reader is deliberately permissive and its assumptions are an H3 checklist item (Task 14).

Two text formats are accepted: the plain `.dic` list every RFID tool speaks (one key per line, `#` comments), and JSON in either the reference app's shape or Spectra's own.

**Files:**
- Create: `app/lib/features/dictionaries/state/dictionary_codec.dart`
- Create: `app/test/fixtures/reference_dictionary.json`
- Test: `app/test/features/dictionaries/dictionary_codec_test.dart`

**Interfaces:**
- Consumes: `toHex`, `parseMifareKey`, `mifareKeyLength` (`app/lib/core/format/hex.dart`, Task 1); `KeyDictionary` (`app/lib/data/data.dart`).
- Produces:
  - `const int spectraDictionarySchemaVersion = 1`.
  - `enum DictionaryImportProblem { notReadable, noKeys, badKey }`.
  - `final class DictionaryImportException implements Exception` with `DictionaryImportProblem problem` and `String detail`.
  - `final class ImportedDictionary { String? name; List<Uint8List> keys; }` (const constructor `ImportedDictionary({this.name, required this.keys})`).
  - `List<ImportedDictionary> parseDictionaries(String text)` — throws `DictionaryImportException` and nothing else.
  - `String exportDictionariesJson(List<KeyDictionary> dictionaries)`.
  - `String exportDictionaryDic(KeyDictionary dictionary)`.

- [ ] **Step 1: Write the fixture**

Create `app/test/fixtures/reference_dictionary.json`:

```json
{
  "dictionaries": [
    {
      "id": "3f2b",
      "name": "Transport",
      "color": 4283215104,
      "keys": ["FFFFFFFFFFFF", "a0a1a2a3a4a5", "D3F7D3F7D3F7"]
    },
    {
      "id": "9c11",
      "name": "Hotel",
      "keys": ["714C5C886E97"]
    }
  ]
}
```

- [ ] **Step 2: Write the failing test**

Create `app/test/features/dictionaries/dictionary_codec_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/format/hex.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/features/dictionaries/state/dictionary_codec.dart';

void main() {
  group('parseDictionaries', () {
    test('reads a plain .dic list, one key per line', () {
      final List<ImportedDictionary> out = parseDictionaries(
        '# mfoc-style comment\n'
        'FFFFFFFFFFFF\n'
        'a0a1a2a3a4a5\n'
        '\n',
      );
      expect(out, hasLength(1));
      expect(out.single.name, isNull);
      expect(out.single.keys.map(toHex), <String>[
        'FFFFFFFFFFFF',
        'A0A1A2A3A4A5',
      ]);
    });

    test('reads the reference app export fixture', () {
      final String text = File(
        'test/fixtures/reference_dictionary.json',
      ).readAsStringSync();

      final List<ImportedDictionary> out = parseDictionaries(text);
      expect(out.map((ImportedDictionary d) => d.name), <String>[
        'Transport',
        'Hotel',
      ]);
      expect(out.first.keys, hasLength(3));
      expect(toHex(out.first.keys[1]), 'A0A1A2A3A4A5');
    });

    test('reads a bare object with a keys list', () {
      final List<ImportedDictionary> out = parseDictionaries(
        '{"name":"One","keys":["FFFFFFFFFFFF"]}',
      );
      expect(out.single.name, 'One');
      expect(out.single.keys, hasLength(1));
    });

    test('reads a JSON list of dictionaries', () {
      final List<ImportedDictionary> out = parseDictionaries(
        '[{"name":"A","keys":["FFFFFFFFFFFF"]},'
        '{"name":"B","keys":["000000000000"]}]',
      );
      expect(out, hasLength(2));
    });

    test('round-trips Spectra own export', () {
      final KeyDictionary dictionary = KeyDictionary(
        id: 'x',
        name: 'Mine',
        keys: <Uint8List>[parseMifareKey('B0B1B2B3B4B5')!],
        updatedAt: DateTime.utc(2026, 9, 3),
      );

      final List<ImportedDictionary> back = parseDictionaries(
        exportDictionariesJson(<KeyDictionary>[dictionary]),
      );
      expect(back.single.name, 'Mine');
      expect(toHex(back.single.keys.single), 'B0B1B2B3B4B5');
    });

    test('a .dic export round-trips through the line reader', () {
      final KeyDictionary dictionary = KeyDictionary(
        id: 'x',
        name: 'Mine',
        keys: <Uint8List>[parseMifareKey('B0B1B2B3B4B5')!],
        updatedAt: DateTime.utc(2026, 9, 3),
      );
      expect(
        parseDictionaries(exportDictionaryDic(dictionary)).single.keys.single,
        dictionary.keys.single,
      );
    });

    test('rejects a line that is not a key', () {
      expect(
        () => parseDictionaries('FFFFFFFFFFFF\nnot-a-key\n'),
        throwsA(
          isA<DictionaryImportException>().having(
            (DictionaryImportException e) => e.problem,
            'problem',
            DictionaryImportProblem.badKey,
          ),
        ),
      );
    });

    test('rejects a key of the wrong length', () {
      expect(
        () => parseDictionaries('{"keys":["FFFFFFFF"]}'),
        throwsA(
          isA<DictionaryImportException>().having(
            (DictionaryImportException e) => e.problem,
            'problem',
            DictionaryImportProblem.badKey,
          ),
        ),
      );
    });

    test('rejects JSON that holds no keys at all', () {
      expect(
        () => parseDictionaries('{"dictionaries":[]}'),
        throwsA(
          isA<DictionaryImportException>().having(
            (DictionaryImportException e) => e.problem,
            'problem',
            DictionaryImportProblem.noKeys,
          ),
        ),
      );
    });

    test('rejects empty text', () {
      expect(
        () => parseDictionaries('   \n\n'),
        throwsA(
          isA<DictionaryImportException>().having(
            (DictionaryImportException e) => e.problem,
            'problem',
            DictionaryImportProblem.noKeys,
          ),
        ),
      );
    });

    test('rejects JSON of a shape it does not understand', () {
      expect(
        () => parseDictionaries('{"dictionaries":{"a":1}}'),
        throwsA(
          isA<DictionaryImportException>().having(
            (DictionaryImportException e) => e.problem,
            'problem',
            DictionaryImportProblem.notReadable,
          ),
        ),
      );
    });
  });

  group('exportDictionariesJson', () {
    test('is versioned and lists keys as upper-case hex', () {
      final Map<String, Object?> decoded =
          jsonDecode(
                exportDictionariesJson(<KeyDictionary>[
                  KeyDictionary(
                    id: 'x',
                    name: 'Mine',
                    keys: <Uint8List>[parseMifareKey('aabbccddeeff')!],
                    updatedAt: DateTime.utc(2026, 9, 3),
                  ),
                ]),
              )
              as Map<String, Object?>;
      expect(decoded['schemaVersion'], spectraDictionarySchemaVersion);
      final List<Object?> list = decoded['dictionaries']! as List<Object?>;
      final Map<String, Object?> first = list.single! as Map<String, Object?>;
      expect(first['keys'], <String>['AABBCCDDEEFF']);
    });
  });
}
```

- [ ] **Step 3: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/dictionaries/dictionary_codec_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: '.../dictionary_codec.dart'`.

- [ ] **Step 4: Write the codec**

Create `app/lib/features/dictionaries/state/dictionary_codec.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import '../../../core/format/hex.dart';
import '../../../data/data.dart';

/// Spec 7.3: import a key list from the reference app's export, from the
/// plain `.dic` file every other RFID tool reads and writes, or from
/// Spectra's own versioned JSON — and export the last two.
///
/// The reference app (GameTec-live/ChameleonUltraGUI) is GPL-3.0. Only its
/// *format* is matched here — the field names its export writes — never its
/// code (`AGENTS.md`). `docs/research/reference-gui.md` records that it
/// downloads dictionaries and exports "JSON+QR" from Settings, but not the
/// field-level shape, so this reader is deliberately permissive: a
/// dictionary may arrive as a bare object, a list of objects, or an object
/// with a `dictionaries` list; keys may be spaced or colon-grouped and any
/// case. Verifying it against a real export is an H3 checklist item.
///
/// Spec 8.5's one-public-type-per-file rule is knowingly relaxed here (the
/// Phase 6 ruling 17 precedent): [ImportedDictionary],
/// [DictionaryImportProblem], [DictionaryImportException] and the three
/// top-level functions are one cohesive concern — reading and writing the
/// dictionary text formats — and splitting them would add files without
/// adding clarity.
library;

/// What Spectra writes. Bumped only when the shape changes incompatibly.
const int spectraDictionarySchemaVersion = 1;

/// Why an import could not be read.
enum DictionaryImportProblem {
  /// The text is neither a key list nor a JSON shape this reader knows.
  notReadable,

  /// Readable, but with no keys in it.
  noKeys,

  /// A line or list entry is not a twelve-character hex key.
  badKey,
}

/// Thrown by [parseDictionaries]; nothing else escapes it.
final class DictionaryImportException implements Exception {
  const DictionaryImportException(this.problem, this.detail);

  final DictionaryImportProblem problem;

  /// The raw detail a problem view can put one tap away.
  final String detail;

  @override
  String toString() => 'DictionaryImportException(${problem.name}: $detail)';
}

/// One key list from an import, before it is given an id and saved. [name]
/// is null for a bare `.dic` paste, which carries no name — the caller
/// supplies one.
final class ImportedDictionary {
  const ImportedDictionary({required this.keys, this.name});

  final String? name;
  final List<Uint8List> keys;
}

/// Reads any of the three formats. Throws [DictionaryImportException] and
/// nothing else.
List<ImportedDictionary> parseDictionaries(String text) {
  final String trimmed = text.trim();
  if (trimmed.isEmpty) {
    throw const DictionaryImportException(
      DictionaryImportProblem.noKeys,
      'the text is empty',
    );
  }
  // A `.dic` file is not JSON, and a JSON file never starts with a hex key,
  // so the first character is enough to choose the reader — and choosing on
  // shape rather than on a thrown FormatException keeps a malformed JSON
  // paste from being silently read as a key list and reported as "bad key".
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    return _readJson(trimmed);
  }
  return <ImportedDictionary>[
    ImportedDictionary(keys: _readKeyLines(trimmed)),
  ];
}

List<ImportedDictionary> _readJson(String text) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (e) {
    throw DictionaryImportException(
      DictionaryImportProblem.notReadable,
      e.message,
    );
  }

  final List<Object?> raw = switch (decoded) {
    final List<Object?> list => list,
    final Map<String, Object?> map when map['dictionaries'] is List<Object?> =>
      map['dictionaries']! as List<Object?>,
    final Map<String, Object?> map when map['keys'] is List<Object?> =>
      <Object?>[map],
    _ => throw const DictionaryImportException(
      DictionaryImportProblem.notReadable,
      'expected a list of dictionaries, or an object with a "keys" list',
    ),
  };
  if (raw.isEmpty) {
    throw const DictionaryImportException(
      DictionaryImportProblem.noKeys,
      'the file holds no dictionaries',
    );
  }
  return <ImportedDictionary>[for (final Object? e in raw) _readDictionary(e)];
}

ImportedDictionary _readDictionary(Object? entry) {
  if (entry is! Map<String, Object?>) {
    throw const DictionaryImportException(
      DictionaryImportProblem.notReadable,
      'a dictionary entry is not an object',
    );
  }
  final Object? keys = entry['keys'];
  if (keys is! List<Object?>) {
    throw const DictionaryImportException(
      DictionaryImportProblem.notReadable,
      'a dictionary entry has no "keys" list',
    );
  }
  final String name = entry['name']?.toString().trim() ?? '';
  return ImportedDictionary(
    name: name.isEmpty ? null : name,
    keys: <Uint8List>[
      for (final Object? key in keys) _readKey(key.toString()),
    ],
  );
}

List<Uint8List> _readKeyLines(String text) {
  final List<Uint8List> out = <Uint8List>[];
  for (final String line in text.split('\n')) {
    // `#` starts a comment in every .dic file in circulation; a blank line
    // is a separator, not a key.
    final String cleaned = line.split('#').first.trim();
    if (cleaned.isEmpty) continue;
    out.add(_readKey(cleaned));
  }
  if (out.isEmpty) {
    throw const DictionaryImportException(
      DictionaryImportProblem.noKeys,
      'the text holds no keys',
    );
  }
  return out;
}

Uint8List _readKey(String text) {
  final Uint8List? key = parseMifareKey(text);
  if (key == null) {
    throw DictionaryImportException(
      DictionaryImportProblem.badKey,
      '"$text" is not a $mifareKeyLength-byte key',
    );
  }
  return key;
}

/// Spectra's own export: versioned, keys as upper-case hex, so the file
/// stays diffable and hand-editable.
String exportDictionariesJson(List<KeyDictionary> dictionaries) =>
    jsonEncode(<String, Object?>{
      'schemaVersion': spectraDictionarySchemaVersion,
      'dictionaries': <Object?>[
        for (final KeyDictionary d in dictionaries)
          <String, Object?>{
            'name': d.name,
            'updatedAt': d.updatedAt.toIso8601String(),
            'keys': d.keys.map<String>(toHex).toList(),
          },
      ],
    });

/// One key per line, with the name as a leading comment: the format every
/// other tool on the bench already reads.
String exportDictionaryDic(KeyDictionary dictionary) =>
    <String>['# ${dictionary.name}', ...dictionary.keys.map<String>(toHex)]
        .join('\n');
```

- [ ] **Step 5: Run it and watch it pass, then check and commit**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/dictionaries/dictionary_codec_test.dart
cd .. && dart run melos run check:all
git add app/lib/features/dictionaries app/test/features/dictionaries app/test/fixtures
git commit -m "$(cat <<'MSG'
read and write the key dictionary formats

Spec 7.3 requires importing the reference app's export; accepting a plain
.dic list as well costs one branch and is what every other tool emits.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 4: The built-in list, the dictionaries provider and the library notifier

`app/lib/features/cards/state/default_keys.dart` says in its own doc comment that Phase 9 replaces it with `DictionariesRepository`. This task moves the MIFARE list into the dictionaries feature — a feature may not import another feature's internals, so the list has to live where the dictionaries do — and puts it in front of the stored rows as a synthesized, read-only dictionary. Nothing can edit it because it is never a row.

**Files:**
- Create: `app/lib/features/dictionaries/state/built_in_keys.dart`, `app/lib/features/dictionaries/state/dictionaries_provider.dart`, `app/lib/features/dictionaries/dictionaries.dart`
- Modify: `app/lib/features/cards/state/default_keys.dart` (remove the MIFARE list), `app/lib/features/cards/state/read_controller.dart` (import the barrel)
- Test: `app/test/features/dictionaries/dictionaries_provider_test.dart`

**Interfaces:**
- Consumes: `DictionariesRepository`, `dictionariesRepositoryProvider`, `KeyDictionary` (`app/lib/data/data.dart`, Task 2); `parseMifareKey` (`app/lib/core/format/hex.dart`, Task 1); `ImportedDictionary`, `parseDictionaries`, `DictionaryImportException` (Task 3).
- Produces:
  - `const List<String> defaultMifareKeyHex` and `List<Uint8List> defaultMifareKeys()` — moved verbatim from `features/cards/state/default_keys.dart`, doc comment and all (including its "Source: public MIFARE Classic default-key dictionaries circulated by the mfoc/libnfc/Proxmark3 community — not the GPL-3.0 reference app" line).
  - `const String builtInDictionaryId = 'builtin-mifare'`.
  - `KeyDictionary builtInDictionary()` — id [builtInDictionaryId], name `''` (the UI localizes it; see `dictionaryDisplayName`), keys `defaultMifareKeys()`, `updatedAt` `DateTime.utc(0)`.
  - `bool isBuiltIn(KeyDictionary d)`.
  - `@riverpod Stream<List<KeyDictionary>> dictionaries(Ref ref)` — the built-in first, then the stored rows newest-updated first.
  - `@riverpod class DictionaryLibrary extends _$DictionaryLibrary` with `Future<void> build()`, `Future<String?> create(String name, {List<Uint8List> keys = const <Uint8List>[]})`, `Future<void> rename(KeyDictionary d, String name)`, `Future<void> setKeys(KeyDictionary d, List<Uint8List> keys)`, `Future<void> remove(String id)`, `Future<String?> duplicate(KeyDictionary d, String name)`, `Future<ImportOutcome> importText(String text, {String? fallbackName})`, `void reset()`, `@visibleForTesting void debugFail(Object error)`.
  - `final class ImportOutcome { const ImportOutcome({required this.written, this.error}); final int written; final Object? error; bool get ok; }` — the same shape `features/cards/state/saved_cards_provider.dart` uses, deliberately: a partial import must be able to say both how many landed and what stopped the rest. It is a separate declaration, not an import, because it is another feature's internal — and for the same reason it is **not** exported from the barrel, so no cards file ever sees two `ImportOutcome`s.
  - `String newDictionaryId()`.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/dictionaries/dictionaries_provider_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/format/hex.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/features/dictionaries/state/built_in_keys.dart';
import 'package:spectra/features/dictionaries/state/dictionaries_provider.dart';

import '../../support/app_harness.dart';

void main() {
  testWidgetsApp('the built-in list is first and is not a stored row', (
    tester,
  ) async {
    await pumpTestApp(tester);
    keepAlive(tester, dictionariesProvider);
    await pumpFrames(tester);

    final List<KeyDictionary> all =
        readProvider(tester, dictionariesProvider).value!;
    expect(all.first.id, builtInDictionaryId);
    expect(all.first.keys.map(toHex), defaultMifareKeyHex);
    expect(isBuiltIn(all.first), isTrue);

    // Nothing was written to make that true.
    final DictionariesRepository repo = readProvider(
      tester,
      dictionariesRepositoryProvider,
    );
    expect(await repo.all(), isEmpty);
  });

  testWidgetsApp('create adds a list and it appears after the built-in', (
    tester,
  ) async {
    await pumpTestApp(tester);
    keepAlive(tester, dictionariesProvider);
    await pumpFrames(tester);

    final DictionaryLibrary library = readProvider(
      tester,
      dictionaryLibraryProvider.notifier,
    );
    final Future<String?> pending = library.create('Hotel');
    await pumpFrames(tester, count: 3);
    expect(await pending, isNotNull);
    await pumpFrames(tester, count: 3);

    final List<KeyDictionary> all =
        readProvider(tester, dictionariesProvider).value!;
    expect(all.map((KeyDictionary d) => d.name), <String>['', 'Hotel']);
  });

  testWidgetsApp('rename, setKeys and remove write through', (tester) async {
    await pumpTestApp(tester);
    keepAlive(tester, dictionariesProvider);
    await pumpFrames(tester);

    final DictionaryLibrary library = readProvider(
      tester,
      dictionaryLibraryProvider.notifier,
    );
    final Future<String?> created = library.create('Hotel');
    await pumpFrames(tester, count: 3);
    final String id = (await created)!;
    await pumpFrames(tester, count: 3);

    KeyDictionary stored() => readProvider(
      tester,
      dictionariesProvider,
    ).value!.firstWhere((KeyDictionary d) => d.id == id);

    final Future<void> renamed = library.rename(stored(), 'Office');
    await pumpFrames(tester, count: 3);
    await renamed;
    await pumpFrames(tester, count: 3);
    expect(stored().name, 'Office');

    final Future<void> keyed = library.setKeys(stored(), <Uint8List>[
      parseMifareKey('A0A1A2A3A4A5')!,
    ]);
    await pumpFrames(tester, count: 3);
    await keyed;
    await pumpFrames(tester, count: 3);
    expect(stored().keys.map(toHex), <String>['A0A1A2A3A4A5']);

    final Future<void> removed = library.remove(id);
    await pumpFrames(tester, count: 3);
    await removed;
    await pumpFrames(tester, count: 3);
    expect(
      readProvider(tester, dictionariesProvider).value!.map(
        (KeyDictionary d) => d.id,
      ),
      <String>[builtInDictionaryId],
    );
  });

  testWidgetsApp('duplicate copies the built-in into an editable list', (
    tester,
  ) async {
    await pumpTestApp(tester);
    keepAlive(tester, dictionariesProvider);
    await pumpFrames(tester);

    final DictionaryLibrary library = readProvider(
      tester,
      dictionaryLibraryProvider.notifier,
    );
    final Future<String?> pending = library.duplicate(
      builtInDictionary(),
      'My defaults',
    );
    await pumpFrames(tester, count: 3);
    final String id = (await pending)!;
    await pumpFrames(tester, count: 3);

    final KeyDictionary copy = readProvider(
      tester,
      dictionariesProvider,
    ).value!.firstWhere((KeyDictionary d) => d.id == id);
    expect(copy.name, 'My defaults');
    expect(copy.keys.map(toHex), defaultMifareKeyHex);
    expect(isBuiltIn(copy), isFalse);
  });

  testWidgetsApp('importText writes what it parsed', (tester) async {
    await pumpTestApp(tester);
    keepAlive(tester, dictionariesProvider);
    await pumpFrames(tester);

    final DictionaryLibrary library = readProvider(
      tester,
      dictionaryLibraryProvider.notifier,
    );
    final Future<ImportOutcome> pending = library.importText(
      'FFFFFFFFFFFF\nA0A1A2A3A4A5\n',
      fallbackName: 'Pasted',
    );
    await pumpFrames(tester, count: 3);
    final ImportOutcome outcome = await pending;
    await pumpFrames(tester, count: 3);

    expect(outcome.ok, isTrue);
    expect(outcome.written, 1);
    final KeyDictionary imported = readProvider(
      tester,
      dictionariesProvider,
    ).value!.last;
    expect(imported.name, 'Pasted');
    expect(imported.keys, hasLength(2));
  });

  testWidgetsApp('importText reports an unreadable paste and writes nothing', (
    tester,
  ) async {
    await pumpTestApp(tester);
    keepAlive(tester, dictionariesProvider);
    await pumpFrames(tester);

    final DictionaryLibrary library = readProvider(
      tester,
      dictionaryLibraryProvider.notifier,
    );
    final Future<ImportOutcome> pending = library.importText('nope');
    await pumpFrames(tester, count: 3);
    final ImportOutcome outcome = await pending;
    await pumpFrames(tester, count: 3);

    expect(outcome.ok, isFalse);
    expect(outcome.written, 0);
    expect(outcome.error, isA<DictionaryImportException>());
    expect(readProvider(tester, dictionariesProvider).value, hasLength(1));
  });

  testWidgetsApp('a second call while one is in flight is dropped', (
    tester,
  ) async {
    await pumpTestApp(tester);
    keepAlive(tester, dictionariesProvider);
    await pumpFrames(tester);

    final DictionaryLibrary library = readProvider(
      tester,
      dictionaryLibraryProvider.notifier,
    );
    final Future<String?> first = library.create('One');
    final Future<String?> second = library.create('Two');
    await pumpFrames(tester, count: 3);
    expect(await first, isNotNull);
    expect(await second, isNull, reason: 'dropped, not queued');
  });
}
```

`DictionaryImportException` comes from `dictionary_codec.dart`; add
`import 'package:spectra/features/dictionaries/state/dictionary_codec.dart';`
to the test's imports.

- [ ] **Step 2: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/dictionaries/dictionaries_provider_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: '.../built_in_keys.dart'`.

- [ ] **Step 3: Move the built-in list**

Create `app/lib/features/dictionaries/state/built_in_keys.dart` by moving `defaultMifareKeyHex` and `defaultMifareKeys()` out of `app/lib/features/cards/state/default_keys.dart` **with their doc comments unchanged**, then adding:

```dart
/// The id of the built-in list. It is not a database row: [dictionaries]
/// synthesizes it in front of the stored ones, which is what makes it
/// read-only by construction rather than by a check somewhere. A user who
/// wants to change it duplicates it (`DictionaryLibrary.duplicate`).
const String builtInDictionaryId = 'builtin-mifare';

/// The built-in list as a [KeyDictionary].
///
/// [KeyDictionary.name] is empty on purpose: the name is copy, and copy is
/// localized at render time (`dictionaryDisplayName`, `ui/`), which a value
/// baked into a stored row could never be. [KeyDictionary.updatedAt] is the
/// epoch so any real list sorts above it if a caller ever sorts the merged
/// list by date.
KeyDictionary builtInDictionary() => KeyDictionary(
  id: builtInDictionaryId,
  name: '',
  keys: defaultMifareKeys(),
  updatedAt: DateTime.utc(0),
);

bool isBuiltIn(KeyDictionary dictionary) =>
    dictionary.id == builtInDictionaryId;
```

with `import 'dart:typed_data';` and `import '../../../data/data.dart';` at the top.

In `app/lib/features/cards/state/default_keys.dart`: delete the moved declarations. **If the file is then empty** (Phase 7's T55xx additions have not landed), `git rm` it and delete its imports; **if it still holds the T55xx passwords**, leave those, and replace the file's doc comment with one that says the MIFARE list moved to `features/dictionaries/state/built_in_keys.dart` in Phase 9 and that the T55xx passwords stay here because they are a write-path concern with no dictionary UI in v1.

Fix `app/lib/features/cards/state/read_controller.dart`: replace the `default_keys.dart` import with `import '../../dictionaries/dictionaries.dart';` (Step 5 creates that barrel). The call site still reads `candidateKeys: defaultMifareKeys(),` — Task 5 changes it.

Then run `grep -rn "defaultMifareKeys\|defaultMifareKeyHex" app/lib app/test` and repoint every remaining hit at the barrel.

- [ ] **Step 4: Write the provider and the notifier**

Create `app/lib/features/dictionaries/state/dictionaries_provider.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/data.dart';
import 'built_in_keys.dart';
import 'dictionary_codec.dart';

part 'dictionaries_provider.g.dart';

/// Every key list the app knows: the built-in one, then the stored ones
/// newest-updated first (the repository's ordering contract,
/// `data/database/drift_dictionaries_repository.dart`). Every screen
/// watches this; nothing calls the repository directly.
@riverpod
Stream<List<KeyDictionary>> dictionaries(Ref ref) => ref
    .watch(dictionariesRepositoryProvider)
    .watchAll()
    .map(
      (List<KeyDictionary> stored) => <KeyDictionary>[
        builtInDictionary(),
        ...stored,
      ],
    );

/// What [DictionaryLibrary.importText] actually did: how many lists were
/// written, and — when it did not fully succeed — the failure that stopped
/// it going further.
///
/// The same shape `features/cards/state/saved_cards_provider.dart` uses,
/// and for the same reason: an import that wrote one list and then failed
/// must be able to say both things. It is declared again rather than
/// imported because that one is another feature's internal (spec 8.4).
final class ImportOutcome {
  const ImportOutcome({required this.written, this.error});

  final int written;

  /// Null when every list in the paste was written. A
  /// [DictionaryImportException] (the text could not be parsed at all)
  /// always carries [written] `== 0`, since [parseDictionaries] reads the
  /// whole paste before anything is written; any other error can carry a
  /// positive [written].
  final Object? error;

  bool get ok => error == null;
}

int _seq = 0;

/// A unique id for a new list, without a uuid dependency: the microsecond
/// clock plus a per-session counter (the `newCardId` pattern).
String newDictionaryId() =>
    'dict-${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

/// Every write to the dictionaries, as an [AsyncValue] the screen renders.
///
/// Failures stay in the state rather than being thrown, so a screen shows
/// them through the spec 9 catalog (`ProblemView`) instead of catching. A
/// call made while another is in flight is dropped, not queued, and the
/// screen disables its controls while `state.isLoading`.
///
/// This notifier is autoDispose: a sheet can be dismissed (or the screen
/// under it torn down) while a write is still in flight, so every
/// assignment to [state] after an `await` is guarded with `ref.mounted`
/// (R25) — the write itself still completes, there is simply no longer
/// anywhere to report it.
@riverpod
class DictionaryLibrary extends _$DictionaryLibrary {
  @override
  Future<void> build() async {
    ref.onDispose(() {
      // Not `state` — the element is gone by now (Global Constraints).
      _inFlight = false;
    });
  }

  bool _inFlight = false;

  /// Writes a new list and returns its id, or null when the write failed or
  /// was dropped.
  Future<String?> create(
    String name, {
    List<Uint8List> keys = const <Uint8List>[],
  }) async {
    final String id = newDictionaryId();
    final bool ok = await _run(
      (DictionariesRepository repo) => repo.save(_row(id, name, keys)),
    );
    return ok ? id : null;
  }

  /// A copy of [dictionary] under a fresh id — how the built-in list
  /// becomes editable.
  Future<String?> duplicate(KeyDictionary dictionary, String name) =>
      create(name, keys: dictionary.keys);

  Future<void> rename(KeyDictionary dictionary, String name) async {
    await _run(
      (DictionariesRepository repo) =>
          repo.save(_row(dictionary.id, name, dictionary.keys)),
    );
  }

  Future<void> setKeys(KeyDictionary dictionary, List<Uint8List> keys) async {
    await _run(
      (DictionariesRepository repo) =>
          repo.save(_row(dictionary.id, dictionary.name, keys)),
    );
  }

  Future<void> remove(String id) async {
    await _run((DictionariesRepository repo) => repo.delete(id));
  }

  /// Parses [text] in any format [parseDictionaries] understands and writes
  /// every list it holds under a fresh id. A `.dic` paste carries no name,
  /// so [fallbackName] names it; a JSON entry's own name wins.
  ///
  /// Writes one list at a time rather than inside a single
  /// `AsyncValue.guard`, for the reason `CardLibrary.importJson` records:
  /// a guard would report zero written the moment any list failed, even
  /// after earlier ones had already landed.
  Future<ImportOutcome> importText(String text, {String? fallbackName}) async {
    if (_inFlight) return const ImportOutcome(written: 0);
    _inFlight = true;
    state = const AsyncLoading<void>();
    int written = 0;
    Object? error;
    StackTrace? stackTrace;
    try {
      final List<ImportedDictionary> parsed = parseDictionaries(text);
      final DictionariesRepository repo = ref.read(
        dictionariesRepositoryProvider,
      );
      for (final ImportedDictionary d in parsed) {
        await repo.save(
          _row(newDictionaryId(), d.name ?? fallbackName ?? '', d.keys),
        );
        written++;
      }
    } on Object catch (e, st) {
      error = e;
      stackTrace = st;
    }
    if (!ref.mounted) {
      _inFlight = false;
      return ImportOutcome(written: written, error: error);
    }
    state = error == null
        ? const AsyncData<void>(null)
        : AsyncError<void>(error, stackTrace!);
    _inFlight = false;
    return ImportOutcome(written: written, error: error);
  }

  /// Clears a failed write back to idle, so a screen's "Try again" reopens
  /// the form instead of leaving the `ProblemView` up forever.
  void reset() => state = const AsyncData<void>(null);

  /// Lets a test drive an `AsyncError` without a repository that throws.
  /// `Notifier.state` is `@protected`; this is the narrow door around that.
  @visibleForTesting
  void debugFail(Object error) =>
      state = AsyncError<void>(error, StackTrace.current);

  KeyDictionary _row(String id, String name, List<Uint8List> keys) =>
      KeyDictionary(
        id: id,
        name: name,
        keys: keys,
        updatedAt: DateTime.now().toUtc(),
      );

  /// Drop-not-queue, with `ref.mounted` on every post-await assignment and
  /// `_inFlight` reset on the disposed branch too (the `CardLibrary._run`
  /// pattern).
  Future<bool> _run(
    Future<void> Function(DictionariesRepository repo) body,
  ) async {
    if (_inFlight) return false;
    _inFlight = true;
    state = const AsyncLoading<void>();
    final AsyncValue<void> next = await AsyncValue.guard<void>(
      () => body(ref.read(dictionariesRepositoryProvider)),
    );
    if (!ref.mounted) {
      _inFlight = false;
      return false;
    }
    state = next;
    _inFlight = false;
    return !next.hasError;
  }
}
```

- [ ] **Step 5: Create the barrel**

Create `app/lib/features/dictionaries/dictionaries.dart`:

```dart
/// The Dictionaries feature's public API (spec 8.3): the key lists other
/// features read, and — from Task 9 — the picker they open to choose one.
///
/// Nothing else in the app may import `features/dictionaries/…` directly.
library;

export 'state/built_in_keys.dart'
    show builtInDictionary, builtInDictionaryId, defaultMifareKeys, isBuiltIn;
// `ImportOutcome` is deliberately *not* exported: `features/cards` declares
// its own type of that name, and a cards file that imports this barrel
// would then carry two `ImportOutcome`s.
export 'state/dictionaries_provider.dart' show dictionariesProvider;
```

- [ ] **Step 6: Regenerate, run, check and commit**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && dart run build_runner build --delete-conflicting-outputs
flutter test test/features/dictionaries/ test/features/cards/
cd .. && dart run melos run check:all
git add -A app/lib app/test
git commit -m "$(cat <<'MSG'
move the built-in key list into the dictionaries feature

A feature may not import another feature's internals, and default_keys.dart
already said this move was Phase 9's job. Synthesizing the built-in list in
front of the stored rows makes "read-only" true by construction.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 5: The selected dictionary, and the keys a read actually uses

Spec 8.1: reader operations "take keys as parameters, supplied by the app from its dictionary repository". Until now that supply was the hard-coded list. This task adds the persisted selection and the provider that turns it into keys, and rewires `CardReader`.

**Files:**
- Create: `app/lib/features/dictionaries/state/selected_dictionary.dart`
- Modify: `app/lib/features/dictionaries/dictionaries.dart`, `app/lib/features/cards/state/read_controller.dart`
- Test: `app/test/features/dictionaries/selected_dictionary_test.dart`

**Interfaces:**
- Consumes: `PreferencesRepository`, `preferencesRepositoryProvider` (`app/lib/data/data.dart`); `dictionariesProvider`, `builtInDictionary()`, `builtInDictionaryId` (Task 4); the `FeatureFlagsController` shape in `app/lib/core/flags/feature_flags.dart` as the model for a preference-backed keepAlive notifier.
- Produces:
  - `@Riverpod(keepAlive: true) class SelectedDictionaryId extends _$SelectedDictionaryId` with `Future<String> build()` (defaults to `builtInDictionaryId`), `Future<void> select(String id)`, and `static const String preferenceKey = 'dictionary.selectedId'`.
  - `@riverpod Future<KeyDictionary> selectedDictionary(Ref ref)` — the selected list, falling back to the built-in one when the stored id no longer exists (it was deleted).
  - `@riverpod Future<List<Uint8List>> candidateMifareKeys(Ref ref)` — the selected list's keys, or `defaultMifareKeys()` when that list is empty, so a read is never left with nothing to try.
- Consumed by: `CardReader._readHf` (this task), `ui/dictionaries_page.dart` (Task 6), `ui/read_page.dart` (Task 9).

- [ ] **Step 1: Write the failing test**

Create `app/test/features/dictionaries/selected_dictionary_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/format/hex.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/features/dictionaries/state/built_in_keys.dart';
import 'package:spectra/features/dictionaries/state/dictionaries_provider.dart';
import 'package:spectra/features/dictionaries/state/selected_dictionary.dart';

import '../../support/app_harness.dart';

void main() {
  testWidgetsApp('defaults to the built-in list', (tester) async {
    await pumpTestApp(tester);
    keepAlive(tester, selectedDictionaryProvider);
    await pumpFrames(tester);

    expect(
      readProvider(tester, selectedDictionaryProvider).value!.id,
      builtInDictionaryId,
    );
    expect(
      readProvider(tester, candidateMifareKeysProvider).value!.map(toHex),
      defaultMifareKeyHex,
    );
  });

  testWidgetsApp('selecting a list changes the candidate keys and persists', (
    tester,
  ) async {
    await pumpTestApp(tester);
    keepAlive(tester, selectedDictionaryProvider);
    keepAlive(tester, candidateMifareKeysProvider);
    await pumpFrames(tester);

    final DictionaryLibrary library = readProvider(
      tester,
      dictionaryLibraryProvider.notifier,
    );
    final Future<String?> created = library.create(
      'Hotel',
      keys: <Uint8List>[parseMifareKey('714C5C886E97')!],
    );
    await pumpFrames(tester, count: 3);
    final String id = (await created)!;
    await pumpFrames(tester, count: 3);

    final Future<void> selected = readProvider(
      tester,
      selectedDictionaryIdProvider.notifier,
    ).select(id);
    await pumpFrames(tester, count: 3);
    await selected;
    await pumpFrames(tester, count: 3);

    expect(readProvider(tester, selectedDictionaryProvider).value!.id, id);
    expect(
      readProvider(tester, candidateMifareKeysProvider).value!.map(toHex),
      <String>['714C5C886E97'],
    );
    expect(
      await readProvider(
        tester,
        preferencesRepositoryProvider,
      ).read(SelectedDictionaryId.preferenceKey),
      id,
    );
  });

  testWidgetsApp('falls back to the built-in list when the selection is gone', (
    tester,
  ) async {
    await pumpTestApp(tester);
    keepAlive(tester, selectedDictionaryProvider);
    await pumpFrames(tester);

    final Future<void> selected = readProvider(
      tester,
      selectedDictionaryIdProvider.notifier,
    ).select('deleted-list');
    await pumpFrames(tester, count: 3);
    await selected;
    await pumpFrames(tester, count: 3);

    expect(
      readProvider(tester, selectedDictionaryProvider).value!.id,
      builtInDictionaryId,
    );
  });

  testWidgetsApp('an empty list still gives a read something to try', (
    tester,
  ) async {
    await pumpTestApp(tester);
    keepAlive(tester, candidateMifareKeysProvider);
    await pumpFrames(tester);

    final DictionaryLibrary library = readProvider(
      tester,
      dictionaryLibraryProvider.notifier,
    );
    final Future<String?> created = library.create('Empty');
    await pumpFrames(tester, count: 3);
    final String id = (await created)!;
    await pumpFrames(tester, count: 3);

    final Future<void> selected = readProvider(
      tester,
      selectedDictionaryIdProvider.notifier,
    ).select(id);
    await pumpFrames(tester, count: 3);
    await selected;
    await pumpFrames(tester, count: 3);

    expect(
      readProvider(tester, candidateMifareKeysProvider).value,
      isNotEmpty,
    );
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/dictionaries/selected_dictionary_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: '.../selected_dictionary.dart'`.

- [ ] **Step 3: Write the selection**

Create `app/lib/features/dictionaries/state/selected_dictionary.dart`:

```dart
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/data.dart';
import 'built_in_keys.dart';
import 'dictionaries_provider.dart';

part 'selected_dictionary.g.dart';

/// Which key list a read or a write uses (spec 8.1: the app supplies the
/// keys). Persisted, because it is a preference and not a per-session
/// choice — the same `PreferencesRepository`-backed keepAlive shape
/// `core/flags/feature_flags.dart` uses.
@Riverpod(keepAlive: true)
class SelectedDictionaryId extends _$SelectedDictionaryId {
  static const String preferenceKey = 'dictionary.selectedId';

  @override
  Future<String> build() async =>
      await ref.watch(preferencesRepositoryProvider).read(preferenceKey) ??
      builtInDictionaryId;

  Future<void> select(String id) async {
    await ref.read(preferencesRepositoryProvider).write(preferenceKey, id);
    if (!ref.mounted) return;
    state = AsyncData<String>(id);
  }
}

/// The selected list itself. A selection whose list has since been deleted
/// falls back to the built-in one rather than leaving a read with no keys;
/// the preference is deliberately *not* rewritten on that path, because the
/// fallback is a display decision, not a user choice.
@riverpod
Future<KeyDictionary> selectedDictionary(Ref ref) async {
  final String id = await ref.watch(selectedDictionaryIdProvider.future);
  final List<KeyDictionary> all = await ref.watch(dictionariesProvider.future);
  return all.firstWhere(
    (KeyDictionary d) => d.id == id,
    orElse: builtInDictionary,
  );
}

/// The keys a MIFARE Classic read or write hands to the facade.
///
/// An empty list falls back to the built-in keys: a user who empties a list
/// and then reads a card should get the default attempt, not a silent
/// no-key read that reports every sector locked.
@riverpod
Future<List<Uint8List>> candidateMifareKeys(Ref ref) async {
  final KeyDictionary selected = await ref.watch(selectedDictionaryProvider.future);
  return selected.keys.isEmpty
      ? defaultMifareKeys()
      : <Uint8List>[
          for (final Uint8List key in selected.keys) Uint8List.fromList(key),
        ];
}
```

- [ ] **Step 4: Rewire the reader**

In `app/lib/features/cards/state/read_controller.dart`, inside `_readHf`, read the keys before the dump starts and pass them:

```dart
    // Spec 8.1: the app supplies the keys. `candidateMifareKeysProvider`
    // resolves the user's selected dictionary (Phase 9), falling back to
    // the built-in list.
    final List<Uint8List> keys = await ref.read(
      candidateMifareKeysProvider.future,
    );
    if (!_current(generation)) throw const CommandCancelled();

    if (_current(generation)) {
      state = const ReadState(busy: true, progress: 0);
    }
    final Mf1DumpReadResult dump = await reader.mf1ReadDump(
      type: type,
      candidateKeys: keys,
      ...
```

Notes for the implementer:

- The `if (!_current(generation)) throw const CommandCancelled();` line is there because `_run`'s `catch` is the only place that can discard an abandoned read's outcome, and the generation may have moved while the preference read was in flight. Check the landed name of the SDK's cancellation error before writing it (`packages/chameleon/lib/src/protocol/errors.dart`); if `CommandCancelled` takes arguments, match the call `read_controller.dart` already makes elsewhere.
- Keep the `import '../../dictionaries/dictionaries.dart';` Task 4 added — Step 5 exports `candidateMifareKeysProvider` from it.
- `read_controller.dart` may have been reshaped by Phase 7. The rule is unchanged: the keys come from the provider, `defaultMifareKeys()` is no longer called from `features/cards/**`, and `grep -rn "defaultMifareKeys" app/lib/features/cards` must come back empty (a Phase 7 write controller gets the same one-line swap).

- [ ] **Step 5: Extend the barrel**

In `app/lib/features/dictionaries/dictionaries.dart`, add:

```dart
export 'state/selected_dictionary.dart'
    show
        SelectedDictionaryId,
        candidateMifareKeysProvider,
        selectedDictionaryIdProvider,
        selectedDictionaryProvider;
```

- [ ] **Step 6: Regenerate, run, check and commit**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && dart run build_runner build --delete-conflicting-outputs
flutter test test/features/dictionaries/ test/features/cards/
cd .. && dart run melos run check:all
git add -A app/lib app/test
git commit -m "$(cat <<'MSG'
read MIFARE keys from the selected dictionary

Spec 8.1 has the app supply reader keys; until now that supply was a
constant. The selection is a preference, so it is persisted.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 6: The dictionaries screen

Spec 7.2 puts dictionaries in the Tools tab. This task adds the list screen, its route, the Tools entry that reaches it, and the ARB keys the whole feature uses for its list-level copy. **This task owns the ARB and the harness this phase** for its keys; no other task may run concurrently with it.

**Files:**
- Create: `app/lib/features/dictionaries/ui/dictionaries_page.dart`
- Modify: `app/lib/core/routing/routes.dart`, `app/lib/core/routing/app_sections.dart`, `app/lib/features/tools/ui/tools_page.dart`, `app/lib/features/dictionaries/dictionaries.dart`, `app/lib/l10n/app_en.arb`, `app/test/support/app_harness.dart`
- Test: `app/test/features/dictionaries/dictionaries_page_test.dart`

**Interfaces:**
- Consumes: `dictionariesProvider`, `DictionaryLibrary`/`dictionaryLibraryProvider` (Task 4); `selectedDictionaryIdProvider`, `selectedDictionaryProvider` (Task 5); `isBuiltIn` (Task 4); `ProblemView` (`app/lib/core/errors/problem_view.dart`); `SpectraSectionHeader({required String title, String? actionLabel, VoidCallback? onAction})`, `SpectraListTile({required String title, String? subtitle, Widget? leading, Widget? trailing, VoidCallback? onTap})`, `SpectraCard`, `SpectraButton`, `SpectraTextField`, `SpectraBottomSheet.show<T>({required BuildContext context, required String title, required WidgetBuilder builder})`, `SpectraSpacing` (`package:spectra_ui/spectra_ui.dart`); `SubPageScaffold({required String title, required Widget body})` (`app/lib/core/routing/sub_page_scaffold.dart`); `AppRoutes` (`app/lib/core/routing/routes.dart`); `GoRouter.of(context).go(...)`, `context.pop()`.
- Produces:
  - `class DictionariesPage extends ConsumerWidget` — the body of `/tools/dictionaries`.
  - `String dictionaryDisplayName(KeyDictionary d, AppLocalizations l10n)` — `l10n.dictBuiltInName` for the built-in list, the stored name otherwise, `l10n.dictUnnamed` for a stored list with a blank name.
  - `Future<String?> showDictionaryNameSheet(BuildContext context, {required String title, String initialValue = ''})` — the one name prompt, used for create, rename and duplicate.
  - `AppRoutes.dictionaries` (`'/tools/dictionaries'`) and `AppRoutes.dictionary(String id)`.
  - Harness helper `Future<void> openDictionaries(WidgetTester tester)`.

- [ ] **Step 1: Add the ARB keys**

Append to `app/lib/l10n/app_en.arb` (before the closing brace), then run `cd app && flutter gen-l10n`:

```json
  "toolsDictionaries": "Key dictionaries",
  "@toolsDictionaries": {"description": "Tools entry that opens the key lists."},
  "toolsDictionariesSubtitle": "Key lists used when reading and writing cards.",
  "@toolsDictionariesSubtitle": {"description": "Subtitle of the Tools entry for key lists."},
  "dictTitle": "Key dictionaries",
  "@dictTitle": {"description": "Title of the key lists screen."},
  "dictBuiltInName": "Default keys",
  "@dictBuiltInName": {"description": "Name of the built-in, read-only key list."},
  "dictUnnamed": "Untitled list",
  "@dictUnnamed": {"description": "Name shown for a saved key list with no name."},
  "dictEmpty": "No key lists of your own yet.",
  "@dictEmpty": {"description": "Shown when only the built-in list exists."},
  "dictKeyCount": "{count, plural, =0 {No keys} one {{count} key} other {{count} keys}}",
  "@dictKeyCount": {
    "description": "How many keys a list holds.",
    "placeholders": {"count": {"type": "int"}}
  },
  "dictInUse": "Used for reading and writing",
  "@dictInUse": {"description": "Marks the list a read or write takes its keys from."},
  "dictUse": "Use these keys",
  "@dictUse": {"description": "Selects a list as the one reads and writes use."},
  "dictNew": "New list",
  "@dictNew": {"description": "Creates an empty key list."},
  "dictNameTitle": "Name this list",
  "@dictNameTitle": {"description": "Title of the sheet that names a key list."},
  "dictNameLabel": "Name",
  "@dictNameLabel": {"description": "Label of the key list name field."},
  "dictNameConfirm": "Save",
  "@dictNameConfirm": {"description": "Confirms a key list's name."}
```

- [ ] **Step 2: Write the failing test**

Create `app/test/features/dictionaries/dictionaries_page_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/format/hex.dart';
import 'package:spectra/features/dictionaries/state/dictionaries_provider.dart';
import 'package:spectra/features/dictionaries/state/selected_dictionary.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

Future<void> _createList(WidgetTester tester, String name) async {
  await tester.tap(find.text('New list'));
  await pumpFrames(tester);
  await tester.enterText(
    find.descendant(
      of: find.byType(SpectraBottomSheet),
      matching: find.byType(SpectraTextField),
    ),
    name,
  );
  await tester.pump();
  await tester.tap(
    find.descendant(
      of: find.byType(SpectraBottomSheet),
      matching: find.text('Save'),
    ),
  );
  await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));
}

void main() {
  testWidgetsApp('lists the built-in dictionary and says it is in use', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await pumpTestApp(tester);
    await connectToEmulator(tester);
    await openDictionaries(tester);

    expect(find.text('Default keys'), findsOneWidget);
    expect(find.text('Used for reading and writing'), findsOneWidget);
    expect(find.text('No key lists of your own yet.'), findsOneWidget);
  });

  testWidgetsApp('creates a list from the sheet', (tester) async {
    useDesktopSurface(tester);
    await pumpTestApp(tester);
    await connectToEmulator(tester);
    await openDictionaries(tester);

    await _createList(tester, 'Hotel');

    expect(find.text('Hotel'), findsOneWidget);
    expect(find.text('No keys'), findsOneWidget);
    expect(find.text('No key lists of your own yet.'), findsNothing);
  });

  testWidgetsApp('choosing a list makes it the one reads use', (tester) async {
    useDesktopSurface(tester);
    await pumpTestApp(tester);
    await connectToEmulator(tester);
    await openDictionaries(tester);
    await _createList(tester, 'Hotel');

    await tester.tap(find.text('Use these keys').last);
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    expect(
      readProvider(tester, selectedDictionaryProvider).value!.name,
      'Hotel',
    );
  });

  testWidgetsApp('a failed write is shown through the shared problem view', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await pumpTestApp(tester);
    await connectToEmulator(tester);
    await openDictionaries(tester);

    readProvider(
      tester,
      dictionaryLibraryProvider.notifier,
    ).debugFail(StateError('disk full'));
    await pumpFrames(tester, count: 3);

    expect(find.text('Something went wrong in the background.'), findsOneWidget);
  });
}
```

The last test's expected sentence is `errorBackgroundTask` in `app_en.arb`; if `ErrorCatalog` (`app/lib/core/errors/error_catalog.dart`) words an unrecognised error differently by then, use whatever it returns for a `StateError` — read the catalog, do not guess.

- [ ] **Step 3: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/dictionaries/dictionaries_page_test.dart
```

Expected: FAIL — `openDictionaries` is undefined.

- [ ] **Step 4: Add the route and the Tools entry**

In `app/lib/core/routing/routes.dart`:

```dart
  /// The key lists (spec 7.2 puts dictionaries in the Tools tab).
  static const String dictionaries = '$tools/dictionaries';

  /// One key list's detail screen.
  static String dictionary(String id) =>
      '$dictionaries/${Uri.encodeComponent(id)}';
```

In `app/lib/core/routing/app_sections.dart`, inside the Tools section's `subRoutes` list, after the existing `frame-log` and `update` routes:

```dart
      GoRoute(
        path: 'dictionaries',
        builder: (context, state) => const DictionariesPage(),
        routes: <RouteBase>[
          GoRoute(
            path: ':id',
            builder: (context, state) =>
                DictionaryDetailPage(id: state.pathParameters['id'] ?? ''),
          ),
        ],
      ),
```

`DictionaryDetailPage` lands in Task 7. **Until then, land only the `dictionaries` route** (drop the nested `routes:` list) so this task compiles on its own — Task 7 adds the child route with its screen (the Phase 6 ruling 13 mistake, avoided). Add `import '../../features/dictionaries/dictionaries.dart';` to the file's imports.

In `app/lib/features/tools/ui/tools_page.dart`, add a tile between the frame log and the update entries:

```dart
        SpectraListTile(
          title: l10n.toolsDictionaries,
          subtitle: l10n.toolsDictionariesSubtitle,
          leading: const Icon(Icons.key_outlined),
          onTap: () => GoRouter.of(context).go(AppRoutes.dictionaries),
        ),
```

- [ ] **Step 5: Write the screen**

Create `app/lib/features/dictionaries/ui/dictionaries_page.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/problem_view.dart';
import '../../../core/routing/routes.dart';
import '../../../core/routing/sub_page_scaffold.dart';
import '../../../data/data.dart';
import '../../../l10n/app_localizations.dart';
import '../state/built_in_keys.dart';
import '../state/dictionaries_provider.dart';
import '../state/selected_dictionary.dart';

/// Spec 7.7 step 7: the key lists. Layout only — every mutation is
/// [DictionaryLibrary], and the selection is [SelectedDictionaryId].
class DictionariesPage extends ConsumerWidget {
  const DictionariesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<KeyDictionary> all =
        ref.watch(dictionariesProvider).value ?? const <KeyDictionary>[];
    final String? selectedId = ref.watch(selectedDictionaryProvider).value?.id;
    final AsyncValue<void> write = ref.watch(dictionaryLibraryProvider);
    final bool busy = write.isLoading;

    return SubPageScaffold(
      title: l10n.dictTitle,
      body: ListView(
        padding: const EdgeInsets.all(SpectraSpacing.lg),
        children: <Widget>[
          SpectraSectionHeader(
            title: l10n.dictTitle,
            actionLabel: l10n.dictNew,
            onAction: busy ? null : () => unawaited(_create(context, ref)),
          ),
          if (write.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: SpectraSpacing.md),
              child: ProblemView(
                error: write.error!,
                variant: SpectraButtonVariant.secondary,
                onAction: ref.read(dictionaryLibraryProvider.notifier).reset,
              ),
            ),
          for (final KeyDictionary dictionary in all)
            Padding(
              padding: const EdgeInsets.only(bottom: SpectraSpacing.sm),
              child: SpectraListTile(
                title: dictionaryDisplayName(dictionary, l10n),
                subtitle: dictionary.id == selectedId
                    ? '${l10n.dictKeyCount(dictionary.keys.length)} · '
                          '${l10n.dictInUse}'
                    : l10n.dictKeyCount(dictionary.keys.length),
                leading: Icon(
                  isBuiltIn(dictionary) ? Icons.lock_outline : Icons.key,
                ),
                trailing: dictionary.id == selectedId
                    ? const Icon(Icons.check)
                    : TextButton(
                        onPressed: busy
                            ? null
                            : () => unawaited(
                                ref
                                    .read(selectedDictionaryIdProvider.notifier)
                                    .select(dictionary.id),
                              ),
                        child: Text(l10n.dictUse),
                      ),
                onTap: () =>
                    GoRouter.of(context).go(AppRoutes.dictionary(dictionary.id)),
              ),
            ),
          if (all.length == 1)
            SpectraCard(child: Text(l10n.dictEmpty)),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? name = await showDictionaryNameSheet(
      context,
      title: l10n.dictNameTitle,
    );
    if (name == null) return;
    await ref.read(dictionaryLibraryProvider.notifier).create(name);
  }
}

/// The name a list is shown under. The built-in list has no stored name —
/// it is synthesized, and its name is copy (`built_in_keys.dart`).
String dictionaryDisplayName(KeyDictionary d, AppLocalizations l10n) =>
    isBuiltIn(d)
    ? l10n.dictBuiltInName
    : (d.name.trim().isEmpty ? l10n.dictUnnamed : d.name);

/// The one name prompt: create, rename and duplicate all use it. Resolves
/// to the trimmed name, or null when the sheet was dismissed.
Future<String?> showDictionaryNameSheet(
  BuildContext context, {
  required String title,
  String initialValue = '',
}) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return SpectraBottomSheet.show<String>(
    context: context,
    title: title,
    builder: (BuildContext context) =>
        _NameForm(l10n: l10n, initialValue: initialValue),
  );
}

class _NameForm extends StatefulWidget {
  const _NameForm({required this.l10n, required this.initialValue});

  final AppLocalizations l10n;
  final String initialValue;

  @override
  State<_NameForm> createState() => _NameFormState();
}

class _NameFormState extends State<_NameForm> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initialValue,
  )..addListener(_onChanged);

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _text.removeListener(_onChanged);
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool valid = _text.text.trim().isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SpectraTextField(
          label: widget.l10n.dictNameLabel,
          controller: _text,
          autofocus: true,
        ),
        const SizedBox(height: SpectraSpacing.lg),
        SpectraButton(
          label: widget.l10n.dictNameConfirm,
          onPressed: valid
              ? () => Navigator.of(context).pop(_text.text.trim())
              : null,
        ),
      ],
    );
  }
}
```

Export both from the barrel:

```dart
export 'ui/dictionaries_page.dart'
    show DictionariesPage, dictionaryDisplayName, showDictionaryNameSheet;
```

- [ ] **Step 6: Add the harness helper**

In `app/test/support/app_harness.dart`, beside `openFrameLog` / `openUpdate`:

```dart
Future<void> openDictionaries(WidgetTester tester) =>
    _openTool(tester, 'Key dictionaries');
```

- [ ] **Step 7: Run, check and commit**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/dictionaries/ test/features/tools/ test/core/routing/
cd .. && dart run melos run check:all
git add -A app/lib app/test
git commit -m "$(cat <<'MSG'
add the key dictionaries screen

Spec 7.2 puts dictionaries in the Tools tab; the list screen is the entry
point for creating a list and choosing which one reads use.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 7: The dictionary detail screen

One list: rename it, add, edit and remove keys with 12-hex-character validation, delete it, and — for the built-in list — read it and duplicate it. **This task owns the ARB.**

**Files:**
- Create: `app/lib/features/dictionaries/ui/dictionary_detail_page.dart`
- Modify: `app/lib/core/routing/app_sections.dart` (add the `:id` child route), `app/lib/features/dictionaries/dictionaries.dart`, `app/lib/l10n/app_en.arb`
- Test: `app/test/features/dictionaries/dictionary_detail_page_test.dart`

**Interfaces:**
- Consumes: `dictionariesProvider`, `DictionaryLibrary` (`rename`, `setKeys`, `remove`, `duplicate`, `reset`) (Task 4); `isBuiltIn`, `builtInDictionary` (Task 4); `dictionaryDisplayName`, `showDictionaryNameSheet` (Task 6); `parseMifareKey`, `toHex`, `mifareKeyLength` (Task 1); `SpectraDialog.show<T>({required BuildContext context, required String title, required Widget content, required List<Widget> Function(BuildContext) actions})`; `ProblemView`; `SubPageScaffold`.
- Produces: `class DictionaryDetailPage extends ConsumerWidget` with `DictionaryDetailPage({required String id, super.key})`.
- Spec 8.5 is relaxed here (Global Constraints): the page plus its private `_KeyRow` and `_KeyForm` widgets are one screen.

- [ ] **Step 1: Add the ARB keys**

Append to `app/lib/l10n/app_en.arb`, then `cd app && flutter gen-l10n`:

```json
  "dictNotFound": "That key list no longer exists.",
  "@dictNotFound": {"description": "Shown when a key list route names a deleted list."},
  "dictKeysTitle": "Keys",
  "@dictKeysTitle": {"description": "Section header above a list's keys."},
  "dictNoKeys": "This list has no keys yet.",
  "@dictNoKeys": {"description": "Shown when a key list is empty."},
  "dictAddKey": "Add key",
  "@dictAddKey": {"description": "Adds a key to the list."},
  "dictKeyLabel": "Key",
  "@dictKeyLabel": {"description": "Label of the key entry field."},
  "dictKeyHint": "12 hexadecimal characters",
  "@dictKeyHint": {"description": "Hint under the key entry field."},
  "dictKeyInvalid": "A key is 12 hexadecimal characters.",
  "@dictKeyInvalid": {"description": "The typed key is not a 6-byte key."},
  "dictKeyDuplicate": "That key is already in this list.",
  "@dictKeyDuplicate": {"description": "The typed key is already stored."},
  "dictRemoveKey": "Remove key",
  "@dictRemoveKey": {"description": "Removes one key from the list."},
  "dictRename": "Rename",
  "@dictRename": {"description": "Renames a key list."},
  "dictRenameTitle": "Rename this list",
  "@dictRenameTitle": {"description": "Title of the rename sheet."},
  "dictDuplicate": "Duplicate",
  "@dictDuplicate": {"description": "Copies a key list into an editable one."},
  "dictDuplicateTitle": "Name the copy",
  "@dictDuplicateTitle": {"description": "Title of the sheet that names a duplicated list."},
  "dictDuplicateSuffix": "{name} copy",
  "@dictDuplicateSuffix": {
    "description": "Default name offered for a duplicated list.",
    "placeholders": {"name": {"type": "String"}}
  },
  "dictBuiltInNote": "Built in and read-only. Duplicate it to make a list you can edit.",
  "@dictBuiltInNote": {"description": "Explains why the built-in list cannot be edited."},
  "dictDelete": "Delete list",
  "@dictDelete": {"description": "Deletes a key list."},
  "dictDeleteTitle": "Delete this list?",
  "@dictDeleteTitle": {"description": "Title of the delete confirmation."},
  "dictDeleteBody": "The keys in it are removed from Spectra. Cards and slots are untouched.",
  "@dictDeleteBody": {"description": "Body of the delete confirmation."},
  "commonCancel": "Cancel",
  "@commonCancel": {"description": "Dismisses a dialog without acting."}
```

`commonCancel` may already exist — check `app_en.arb` first and reuse it rather than adding a second key.

- [ ] **Step 2: Write the failing test**

Create `app/test/features/dictionaries/dictionary_detail_page_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/features/dictionaries/state/dictionaries_provider.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

/// Creates a list called Hotel and opens it. Returns nothing: every test
/// below asserts on what is on screen.
Future<void> _openHotel(WidgetTester tester) async {
  useDesktopSurface(tester);
  await pumpTestApp(tester);
  await connectToEmulator(tester);
  await openDictionaries(tester);

  await tester.tap(find.text('New list'));
  await pumpFrames(tester);
  await tester.enterText(
    find.descendant(
      of: find.byType(SpectraBottomSheet),
      matching: find.byType(SpectraTextField),
    ),
    'Hotel',
  );
  await tester.pump();
  await tester.tap(
    find.descendant(
      of: find.byType(SpectraBottomSheet),
      matching: find.text('Save'),
    ),
  );
  await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));
  await tester.tap(find.text('Hotel'));
  await pumpFrames(tester);
}

Future<void> _addKey(WidgetTester tester, String key) async {
  await tester.enterText(find.byType(SpectraTextField).last, key);
  await tester.pump();
  await tester.tap(find.text('Add key'));
  await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));
}

void main() {
  testWidgetsApp('adds a key and shows it', (tester) async {
    await _openHotel(tester);
    expect(find.text('This list has no keys yet.'), findsOneWidget);

    await _addKey(tester, 'A0A1A2A3A4A5');

    expect(find.text('A0A1A2A3A4A5'), findsOneWidget);
    expect(find.text('This list has no keys yet.'), findsNothing);
  });

  testWidgetsApp('rejects a key of the wrong length', (tester) async {
    await _openHotel(tester);
    await _addKey(tester, 'A0A1A2');

    expect(find.text('A key is 12 hexadecimal characters.'), findsOneWidget);
  });

  testWidgetsApp('rejects a key the list already holds', (tester) async {
    await _openHotel(tester);
    await _addKey(tester, 'A0A1A2A3A4A5');
    await _addKey(tester, 'a0a1a2a3a4a5');

    expect(find.text('That key is already in this list.'), findsOneWidget);
    expect(find.text('A0A1A2A3A4A5'), findsOneWidget);
  });

  testWidgetsApp('removes a key', (tester) async {
    await _openHotel(tester);
    await _addKey(tester, 'A0A1A2A3A4A5');

    await tester.tap(find.byTooltip('Remove key'));
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    expect(find.text('A0A1A2A3A4A5'), findsNothing);
  });

  testWidgetsApp('renames the list', (tester) async {
    await _openHotel(tester);

    await tester.tap(find.text('Rename'));
    await pumpFrames(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(SpectraTextField),
      ),
      'Office',
    );
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Save'),
      ),
    );
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    expect(find.text('Office'), findsWidgets);
  });

  testWidgetsApp('deletes the list and returns to the list screen', (
    tester,
  ) async {
    await _openHotel(tester);

    await tester.tap(find.text('Delete list'));
    await pumpFrames(tester);
    await tester.tap(find.text('Delete list').last);
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    expect(find.text('No key lists of your own yet.'), findsOneWidget);
  });

  testWidgetsApp('the built-in list is read-only and can be duplicated', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await pumpTestApp(tester);
    await connectToEmulator(tester);
    await openDictionaries(tester);

    await tester.tap(find.text('Default keys'));
    await pumpFrames(tester);

    expect(
      find.text(
        'Built in and read-only. Duplicate it to make a list you can edit.',
      ),
      findsOneWidget,
    );
    expect(find.text('Add key'), findsNothing);
    expect(find.text('Delete list'), findsNothing);

    await tester.tap(find.text('Duplicate'));
    await pumpFrames(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Save'),
      ),
    );
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    expect(find.text('Default keys copy'), findsWidgets);
  });

  testWidgetsApp('a failed write shows the shared problem view', (
    tester,
  ) async {
    await _openHotel(tester);

    readProvider(
      tester,
      dictionaryLibraryProvider.notifier,
    ).debugFail(StateError('disk full'));
    await pumpFrames(tester, count: 3);

    expect(find.text('Something went wrong in the background.'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/dictionaries/dictionary_detail_page_test.dart
```

Expected: FAIL — the `Hotel` tile has nothing to open (`DictionaryDetailPage` does not exist).

- [ ] **Step 4: Write the screen**

Create `app/lib/features/dictionaries/ui/dictionary_detail_page.dart`:

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/problem_view.dart';
import '../../../core/format/hex.dart';
import '../../../core/routing/sub_page_scaffold.dart';
import '../../../data/data.dart';
import '../../../l10n/app_localizations.dart';
import '../state/built_in_keys.dart';
import '../state/dictionaries_provider.dart';
import 'dictionaries_page.dart';

/// One key list (spec 7.7 step 7). Layout only: every mutation goes through
/// [DictionaryLibrary], which writes the whole list back — a dictionary is
/// read and written whole (`tables.dart`).
///
/// Spec 8.5's one-public-type rule is relaxed here (Global Constraints):
/// the private key row and key form below are this screen and nothing else.
class DictionaryDetailPage extends ConsumerWidget {
  const DictionaryDetailPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<KeyDictionary> all =
        ref.watch(dictionariesProvider).value ?? const <KeyDictionary>[];
    final KeyDictionary? dictionary = all
        .where((KeyDictionary d) => d.id == id)
        .firstOrNull;
    if (dictionary == null) {
      // A route to a list that has since been deleted — including the
      // moment right after this screen's own Delete button lands.
      return SubPageScaffold(
        title: l10n.dictTitle,
        body: Padding(
          padding: const EdgeInsets.all(SpectraSpacing.lg),
          child: SpectraCard(child: Text(l10n.dictNotFound)),
        ),
      );
    }

    final AsyncValue<void> write = ref.watch(dictionaryLibraryProvider);
    final bool busy = write.isLoading;
    final bool readOnly = isBuiltIn(dictionary);
    final DictionaryLibrary library = ref.read(
      dictionaryLibraryProvider.notifier,
    );

    return SubPageScaffold(
      title: dictionaryDisplayName(dictionary, l10n),
      body: ListView(
        padding: const EdgeInsets.all(SpectraSpacing.lg),
        children: <Widget>[
          if (write.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: SpectraSpacing.md),
              child: ProblemView(
                error: write.error!,
                variant: SpectraButtonVariant.secondary,
                onAction: library.reset,
              ),
            ),
          SpectraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(dictionaryDisplayName(dictionary, l10n)),
                if (readOnly) ...<Widget>[
                  const SizedBox(height: SpectraSpacing.sm),
                  Text(l10n.dictBuiltInNote),
                ],
                const SizedBox(height: SpectraSpacing.md),
                Wrap(
                  spacing: SpectraSpacing.sm,
                  children: <Widget>[
                    if (!readOnly)
                      SpectraButton(
                        label: l10n.dictRename,
                        variant: SpectraButtonVariant.secondary,
                        onPressed: busy
                            ? null
                            : () => unawaited(
                                _rename(context, library, dictionary, l10n),
                              ),
                      ),
                    SpectraButton(
                      label: l10n.dictDuplicate,
                      variant: SpectraButtonVariant.secondary,
                      onPressed: busy
                          ? null
                          : () => unawaited(
                              _duplicate(context, library, dictionary, l10n),
                            ),
                    ),
                    if (!readOnly)
                      SpectraButton(
                        label: l10n.dictDelete,
                        variant: SpectraButtonVariant.secondary,
                        onPressed: busy
                            ? null
                            : () => unawaited(
                                _delete(context, library, dictionary, l10n),
                              ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: SpectraSpacing.lg),
          SpectraSectionHeader(title: l10n.dictKeysTitle),
          if (dictionary.keys.isEmpty)
            SpectraCard(child: Text(l10n.dictNoKeys)),
          for (int i = 0; i < dictionary.keys.length; i++)
            SpectraListTile(
              title: toHex(dictionary.keys[i]),
              trailing: readOnly
                  ? null
                  : IconButton(
                      tooltip: l10n.dictRemoveKey,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: busy
                          ? null
                          : () => unawaited(
                              library.setKeys(dictionary, <Uint8List>[
                                ...dictionary.keys,
                              ]..removeAt(i)),
                            ),
                    ),
            ),
          if (!readOnly) ...<Widget>[
            const SizedBox(height: SpectraSpacing.lg),
            _KeyForm(dictionary: dictionary, busy: busy),
          ],
        ],
      ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    DictionaryLibrary library,
    KeyDictionary dictionary,
    AppLocalizations l10n,
  ) async {
    final String? name = await showDictionaryNameSheet(
      context,
      title: l10n.dictRenameTitle,
      initialValue: dictionary.name,
    );
    if (name == null) return;
    await library.rename(dictionary, name);
  }

  Future<void> _duplicate(
    BuildContext context,
    DictionaryLibrary library,
    KeyDictionary dictionary,
    AppLocalizations l10n,
  ) async {
    final String? name = await showDictionaryNameSheet(
      context,
      title: l10n.dictDuplicateTitle,
      initialValue: l10n.dictDuplicateSuffix(
        dictionaryDisplayName(dictionary, l10n),
      ),
    );
    if (name == null) return;
    await library.duplicate(dictionary, name);
  }

  Future<void> _delete(
    BuildContext context,
    DictionaryLibrary library,
    KeyDictionary dictionary,
    AppLocalizations l10n,
  ) async {
    final GoRouter router = GoRouter.of(context);
    final bool? confirmed = await SpectraDialog.show<bool>(
      context: context,
      title: l10n.dictDeleteTitle,
      content: Text(l10n.dictDeleteBody),
      actions: (BuildContext context) => <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.dictDelete),
        ),
      ],
    );
    if (confirmed != true) return;
    await library.remove(dictionary.id);
    router.go(AppRoutes.dictionaries);
  }
}
```

`AppRoutes` needs `import '../../../core/routing/routes.dart';`.

Then the key form, in the same file:

```dart
/// Adds one key. Validation is [parseMifareKey] plus a duplicate check —
/// a dictionary with the same key twice costs a wasted authentication
/// attempt on every sector.
class _KeyForm extends ConsumerStatefulWidget {
  const _KeyForm({required this.dictionary, required this.busy});

  final KeyDictionary dictionary;
  final bool busy;

  @override
  ConsumerState<_KeyForm> createState() => _KeyFormState();
}

class _KeyFormState extends ConsumerState<_KeyForm> {
  final TextEditingController _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Uint8List? key = parseMifareKey(_text.text);
    if (key == null) {
      setState(() => _error = l10n.dictKeyInvalid);
      return;
    }
    final String hex = toHex(key);
    if (widget.dictionary.keys.map<String>(toHex).contains(hex)) {
      setState(() => _error = l10n.dictKeyDuplicate);
      return;
    }
    setState(() => _error = null);
    await ref
        .read(dictionaryLibraryProvider.notifier)
        .setKeys(widget.dictionary, <Uint8List>[
          ...widget.dictionary.keys,
          key,
        ]);
    if (!mounted) return;
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SpectraTextField(
          label: l10n.dictKeyLabel,
          hint: l10n.dictKeyHint,
          controller: _text,
          errorText: _error,
        ),
        const SizedBox(height: SpectraSpacing.md),
        SpectraButton(
          label: l10n.dictAddKey,
          onPressed: widget.busy ? null : () => unawaited(_add()),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Land the child route**

In `app/lib/core/routing/app_sections.dart`, add the nested `:id` route under `dictionaries` exactly as Task 6's step 4 showed, now that `DictionaryDetailPage` exists. Export it from the barrel:

```dart
export 'ui/dictionary_detail_page.dart' show DictionaryDetailPage;
```

- [ ] **Step 6: Run, check and commit**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/dictionaries/ test/core/routing/
cd .. && dart run melos run check:all
git add -A app/lib app/test
git commit -m "$(cat <<'MSG'
add the key list detail screen

Editing keys is the point of a dictionary; validating them at entry keeps a
malformed key out of the list a read depends on.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 8: Import and export

Spec 7.3 requires import from the reference app's export for dictionaries as well as cards, and Spectra's own versioned format both ways. Import is a paste, export is a copy to the clipboard — the shape Phase 6 shipped for cards (`ui/card_import_sheet.dart`, `card_detail_page.dart::_export`) and the reason is in this plan's "Decisions this plan makes". **This task owns the ARB.**

**Files:**
- Create: `app/lib/features/dictionaries/ui/dictionary_import_sheet.dart`
- Modify: `app/lib/features/dictionaries/ui/dictionaries_page.dart` (an Import action), `app/lib/features/dictionaries/ui/dictionary_detail_page.dart` (an Export action), `app/lib/features/dictionaries/dictionaries.dart`, `app/lib/l10n/app_en.arb`
- Test: `app/test/features/dictionaries/dictionary_import_sheet_test.dart`

**Interfaces:**
- Consumes: `parseDictionaries`, `DictionaryImportException`, `DictionaryImportProblem`, `exportDictionariesJson`, `exportDictionaryDic` (Task 3); `DictionaryLibrary.importText`, `ImportOutcome` (Task 4); `ProblemView`; `Clipboard.setData(ClipboardData(text: …))` from `package:flutter/services.dart`; `ScaffoldMessenger.of(context).showSnackBar`.
- Produces:
  - `Future<int?> showDictionaryImportSheet(BuildContext context)` — resolves to the number of lists written, or null when dismissed without a fully successful import (the `showCardImportSheet` contract, verbatim).
  - `String importProblemMessage(DictionaryImportProblem problem, AppLocalizations l10n)`.

- [ ] **Step 1: Add the ARB keys**

Append to `app/lib/l10n/app_en.arb`, then `cd app && flutter gen-l10n`:

```json
  "dictImport": "Import",
  "@dictImport": {"description": "Opens the key list import sheet."},
  "dictImportTitle": "Import key lists",
  "@dictImportTitle": {"description": "Title of the import sheet."},
  "dictImportHint": "Paste a key list: one key per line, or a JSON export from Spectra or the reference app.",
  "@dictImportHint": {"description": "Explains what may be pasted."},
  "dictImportLabel": "Pasted text",
  "@dictImportLabel": {"description": "Label of the import text field."},
  "dictImportConfirm": "Import",
  "@dictImportConfirm": {"description": "Runs the import."},
  "dictImportNotReadable": "That is not a key list Spectra can read.",
  "@dictImportNotReadable": {"description": "The pasted text is neither keys nor a known JSON shape."},
  "dictImportNoKeys": "There are no keys in that text.",
  "@dictImportNoKeys": {"description": "The paste parsed but held no keys."},
  "dictImportBadKey": "One of those keys is not 12 hexadecimal characters.",
  "@dictImportBadKey": {"description": "A key in the paste is malformed."},
  "dictImported": "{count, plural, one {Imported {count} list.} other {Imported {count} lists.}}",
  "@dictImported": {
    "description": "Confirms how many key lists were imported.",
    "placeholders": {"count": {"type": "int"}}
  },
  "dictExport": "Copy list",
  "@dictExport": {"description": "Copies a key list to the clipboard."},
  "dictExported": "List copied to the clipboard.",
  "@dictExported": {"description": "Confirms the copy."}
```

- [ ] **Step 2: Write the failing test**

Create `app/test/features/dictionaries/dictionary_import_sheet_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/features/dictionaries/state/dictionaries_provider.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

Future<void> _openImport(WidgetTester tester) async {
  useDesktopSurface(tester);
  await pumpTestApp(tester);
  await connectToEmulator(tester);
  await openDictionaries(tester);
  await tester.tap(find.text('Import'));
  await pumpFrames(tester);
}

Future<void> _paste(WidgetTester tester, String text) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(SpectraBottomSheet),
      matching: find.byType(SpectraTextField),
    ),
    text,
  );
  await tester.pump();
  await tester.tap(
    find.descendant(
      of: find.byType(SpectraBottomSheet),
      matching: find.text('Import'),
    ),
  );
  await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));
}

void main() {
  testWidgetsApp('imports a pasted key list', (tester) async {
    await _openImport(tester);
    await _paste(tester, 'FFFFFFFFFFFF\nA0A1A2A3A4A5\n');

    expect(find.byType(SpectraBottomSheet), findsNothing);
    expect(readProvider(tester, dictionariesProvider).value, hasLength(2));
  });

  testWidgetsApp('imports the reference app JSON shape', (tester) async {
    await _openImport(tester);
    await _paste(
      tester,
      '{"dictionaries":[{"name":"Transport","keys":["FFFFFFFFFFFF"]}]}',
    );

    expect(find.text('Transport'), findsOneWidget);
  });

  testWidgetsApp('words a malformed paste without writing anything', (
    tester,
  ) async {
    await _openImport(tester);
    await _paste(tester, 'FFFFFFFFFFFF\nnot-a-key');

    expect(
      find.text('One of those keys is not 12 hexadecimal characters.'),
      findsOneWidget,
    );
    expect(readProvider(tester, dictionariesProvider).value, hasLength(1));
  });

  testWidgetsApp('a repository failure is shown through ProblemView, not as a '
      'parse failure', (tester) async {
    await _openImport(tester);
    readProvider(
      tester,
      dictionaryLibraryProvider.notifier,
    ).debugFail(StateError('disk full'));
    await pumpFrames(tester, count: 3);

    expect(find.text('That is not a key list Spectra can read.'), findsNothing);
  });
}
```

- [ ] **Step 3: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/dictionaries/dictionary_import_sheet_test.dart
```

Expected: FAIL — there is no `Import` action on the dictionaries screen.

- [ ] **Step 4: Write the sheet**

Create `app/lib/features/dictionaries/ui/dictionary_import_sheet.dart`, modelled on `app/lib/features/cards/ui/card_import_sheet.dart` — read that file first and keep the same structure, including its `_failure` handling:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/problem_view.dart';
import '../../../l10n/app_localizations.dart';
import '../state/dictionaries_provider.dart';
import '../state/dictionary_codec.dart';

/// The words for an import failure [parseDictionaries] itself raised. Spec 9
/// keeps errors typed to the UI, so this switches on the problem rather than
/// showing the exception's text. Anything that is *not* a
/// [DictionaryImportException] — a repository failure partway through —
/// goes through [ProblemView] and the shared catalog instead, so a storage
/// failure is never worded as a parse failure (Phase 6 ruling 21).
String importProblemMessage(
  DictionaryImportProblem problem,
  AppLocalizations l10n,
) => switch (problem) {
  DictionaryImportProblem.notReadable => l10n.dictImportNotReadable,
  DictionaryImportProblem.noKeys => l10n.dictImportNoKeys,
  DictionaryImportProblem.badKey => l10n.dictImportBadKey,
};

/// Spec 7.3: import from the reference app's export, a plain `.dic` list, or
/// Spectra's own. Pasting works on all five platforms and needs no new
/// dependency; see this phase's plan for why there is no file dialog.
///
/// Resolves to the number of lists written, or null when the sheet was
/// dismissed without a fully successful import.
Future<int?> showDictionaryImportSheet(BuildContext context) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return SpectraBottomSheet.show<int>(
    context: context,
    title: l10n.dictImportTitle,
    builder: (BuildContext context) => const _ImportForm(),
  );
}
```

`_ImportForm` is `card_import_sheet.dart`'s `_ImportFormState` with three substitutions: `cardLibraryProvider` → `dictionaryLibraryProvider`, `importJson(_text.text)` → `importText(_text.text)`, and the `cardsImport*` ARB keys → the `dictImport*` ones. Keep its `initState`/`dispose` listener pair (the confirm button tracks the field), its `ImportOutcome? _failure` field, and its `ProblemView` branch for a non-`DictionaryImportException` error.

- [ ] **Step 5: Wire the two actions**

In `dictionaries_page.dart`, add an Import button under the section header (disabled while `busy`):

```dart
          SpectraButton(
            label: l10n.dictImport,
            variant: SpectraButtonVariant.secondary,
            onPressed: busy
                ? null
                : () => unawaited(showDictionaryImportSheet(context)),
          ),
```

In `dictionary_detail_page.dart`, add an export action beside Rename/Duplicate/Delete (available for the built-in list too — copying it out is exactly how a user seeds another tool):

```dart
  Future<void> _export(
    BuildContext context,
    KeyDictionary dictionary,
    AppLocalizations l10n,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    // The `.dic` form, not the JSON one: a single list copied out is
    // overwhelmingly going into another tool, and every one of them reads
    // one key per line. `exportDictionariesJson` is what a whole-library
    // export would use.
    await Clipboard.setData(
      ClipboardData(text: exportDictionaryDic(dictionary)),
    );
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.dictExported)));
  }
```

with `import 'package:flutter/services.dart';` and the codec import, plus a `SpectraButton(label: l10n.dictExport, …)` in the same `Wrap`.

Export from the barrel:

```dart
export 'ui/dictionary_import_sheet.dart'
    show importProblemMessage, showDictionaryImportSheet;
```

- [ ] **Step 6: Run, check and commit**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/dictionaries/
cd .. && dart run melos run check:all
git add -A app/lib app/test
git commit -m "$(cat <<'MSG'
import and export key lists

Spec 7.3 requires reference-app import for dictionaries as well as cards;
export as .dic is what every other tool on the bench reads.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 9: The dictionary picker, and the read screen's key source

The feature's public API, and the one place outside it that has to change: the read screen should say which keys it is about to try, and let the user change them without leaving. **This task owns the ARB, the barrel and `read_page.dart`.**

**Files:**
- Create: `app/lib/features/dictionaries/ui/dictionary_picker.dart`
- Modify: `app/lib/features/dictionaries/dictionaries.dart`, `app/lib/features/cards/ui/read_page.dart`, `app/lib/l10n/app_en.arb`
- Test: `app/test/features/dictionaries/dictionary_picker_test.dart`

**Interfaces:**
- Consumes: `dictionariesProvider`, `selectedDictionaryProvider`, `selectedDictionaryIdProvider` (Tasks 4, 5); `dictionaryDisplayName` (Task 6); `SpectraBottomSheet.show`, `SpectraListTile`, `SpectraCard`.
- Produces:
  - `Future<KeyDictionary?> showDictionaryPicker(BuildContext context, {bool Function(KeyDictionary dictionary)? isSelectable})` — the feature's public API.
  - `class DictionaryPicker extends ConsumerWidget` — the body, for an inline caller.
- Consumed by: `app/lib/features/cards/ui/read_page.dart` (this task) and any Phase 7 write screen (unchanged by this task).

- [ ] **Step 1: Add the ARB keys**

```json
  "dictPickerTitle": "Choose a key list",
  "@dictPickerTitle": {"description": "Title of the key list picker sheet."},
  "cardsReadKeys": "Keys: {name}",
  "@cardsReadKeys": {
    "description": "Names the key list a read will try.",
    "placeholders": {"name": {"type": "String"}}
  },
  "cardsReadKeysChange": "Change",
  "@cardsReadKeysChange": {"description": "Opens the key list picker from the read screen."}
```

Then `cd app && flutter gen-l10n`.

- [ ] **Step 2: Write the failing test**

Create `app/test/features/dictionaries/dictionary_picker_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/features/dictionaries/state/selected_dictionary.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

Future<void> _openRead(WidgetTester tester) async {
  useDesktopSurface(tester);
  await pumpTestApp(tester);
  await connectToEmulator(tester);
  await tester.tap(find.text('Cards').last);
  await pumpFrames(tester);
  await tester.tap(find.text('Read a card'));
  await pumpFrames(tester);
}

void main() {
  testWidgetsApp('the read screen names the key list it will try', (
    tester,
  ) async {
    await _openRead(tester);
    expect(find.text('Keys: Default keys'), findsOneWidget);
  });

  testWidgetsApp('the picker changes the selection', (tester) async {
    await _openRead(tester);

    // Only the built-in list exists, so choosing it is the whole round
    // trip: sheet opens, tap resolves, selection is unchanged and valid.
    await tester.tap(find.text('Change'));
    await pumpFrames(tester);
    expect(find.byType(SpectraBottomSheet), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Default keys'),
      ),
    );
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    expect(find.byType(SpectraBottomSheet), findsNothing);
    expect(
      readProvider(tester, selectedDictionaryProvider).value!.name,
      '',
      reason: 'the built-in list stores no name; its label is localized',
    );
  });

  testWidgetsApp('an unselectable list is listed but not tappable', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await pumpTestApp(tester);
    await connectToEmulator(tester);

    // Drive the picker directly: the read screen never filters, but the
    // contract other features rely on is that it can.
    final BuildContext context = tester.element(find.byType(SpectraAppShell));
    final Future<Object?> pending = showDictionaryPicker(
      context,
      isSelectable: (_) => false,
    );
    await pumpFrames(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Default keys'),
      ),
    );
    await pumpFrames(tester);

    expect(find.byType(SpectraBottomSheet), findsOneWidget);
    Navigator.of(context).pop();
    await pumpFrames(tester);
    expect(await pending, isNull);
  });
}
```

Add `import 'package:spectra/features/dictionaries/dictionaries.dart';` for `showDictionaryPicker`, and `import 'package:material_ui/material_ui.dart';` for `Navigator`/`BuildContext`.

- [ ] **Step 3: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/dictionaries/dictionary_picker_test.dart
```

Expected: FAIL — `showDictionaryPicker` is undefined and the read screen names no key list.

- [ ] **Step 4: Write the picker**

Create `app/lib/features/dictionaries/ui/dictionary_picker.dart`, modelled on `app/lib/features/cards/ui/card_picker.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../data/data.dart';
import '../../../l10n/app_localizations.dart';
import '../state/dictionaries_provider.dart';
import 'dictionaries_page.dart';

/// **The Dictionaries feature's public API** (spec 8.3). Asks the user which
/// key list to use, and resolves to it — keys and all — or null if the sheet
/// was dismissed.
///
/// Contract for the features that call it:
///
/// - Import it as `package:spectra/features/dictionaries/dictionaries.dart`.
///   Never reach into `features/dictionaries/ui/…` or `state/…` (spec 8.4).
/// - The whole list comes back, so a caller needs no second lookup: the
///   returned `keys` are the six-byte MIFARE Classic keys a reader facade
///   takes as `candidateKeys` (spec 8.1).
/// - It resolves to null on dismissal, and callers must handle that: it is
///   the normal way out of the sheet, not an error.
/// - [isSelectable] filters what may be chosen — an unselectable list is
///   still listed and untappable, so the user can see why it is not on
///   offer.
/// - It changes nothing. Choosing is a choice; a caller that wants the
///   choice to stick calls `selectedDictionaryIdProvider.notifier.select`.
/// - The built-in list is always in it, so the sheet is never empty.
Future<KeyDictionary?> showDictionaryPicker(
  BuildContext context, {
  bool Function(KeyDictionary dictionary)? isSelectable,
}) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return SpectraBottomSheet.show<KeyDictionary>(
    context: context,
    title: l10n.dictPickerTitle,
    builder: (BuildContext context) =>
        DictionaryPicker(isSelectable: isSelectable),
  );
}

/// The picker's body, for a caller that wants it inline rather than modal.
/// Pops the enclosing route with the chosen list.
class DictionaryPicker extends ConsumerWidget {
  const DictionaryPicker({this.isSelectable, super.key});

  final bool Function(KeyDictionary dictionary)? isSelectable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<KeyDictionary> all =
        ref.watch(dictionariesProvider).value ?? const <KeyDictionary>[];
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: all.length,
        separatorBuilder: (BuildContext context, int i) =>
            const SizedBox(height: SpectraSpacing.sm),
        itemBuilder: (BuildContext context, int i) {
          final KeyDictionary dictionary = all[i];
          final bool selectable = isSelectable?.call(dictionary) ?? true;
          return SpectraListTile(
            title: dictionaryDisplayName(dictionary, l10n),
            subtitle: l10n.dictKeyCount(dictionary.keys.length),
            leading: const Icon(Icons.key),
            onTap: selectable
                ? () => Navigator.of(context).pop(dictionary)
                : null,
          );
        },
      ),
    );
  }
}
```

Export it:

```dart
export 'ui/dictionary_picker.dart' show DictionaryPicker, showDictionaryPicker;
```

- [ ] **Step 5: Name the key source on the read screen**

In `app/lib/features/cards/ui/read_page.dart`, above the scan buttons, add a row that names the selected list and opens the picker. Read the landed file first — Phases 6 and 7 both shaped it — and place this where the screen's other pre-scan controls are:

```dart
        SpectraListTile(
          title: l10n.cardsReadKeys(
            dictionaryDisplayName(
              ref.watch(selectedDictionaryProvider).value ??
                  builtInDictionary(),
              l10n,
            ),
          ),
          leading: const Icon(Icons.key),
          trailing: TextButton(
            onPressed: busy ? null : () => unawaited(_chooseKeys(context, ref)),
            child: Text(l10n.cardsReadKeysChange),
          ),
        ),
```

```dart
  Future<void> _chooseKeys(BuildContext context, WidgetRef ref) async {
    final KeyDictionary? chosen = await showDictionaryPicker(context);
    if (chosen == null) return;
    await ref.read(selectedDictionaryIdProvider.notifier).select(chosen.id);
  }
```

The file imports `package:spectra/features/dictionaries/dictionaries.dart` (the barrel, never the internals) and `../../../data/data.dart` for `KeyDictionary`. `busy` is whatever the screen already calls its in-flight flag; match the landed name.

- [ ] **Step 6: Run, check and commit**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/dictionaries/ test/features/cards/
cd .. && dart run melos run check:all
git add -A app/lib app/test
git commit -m "$(cat <<'MSG'
publish the dictionary picker and name the read screen's keys

A read that silently uses one key list is a read the user cannot explain
when it fails; the picker is also the public API other features need.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 10: The device settings controller

Spec 8.1 and 4: `session.settings` is the only way app code touches device settings, and `SettingsFacade` (`packages/chameleon/lib/src/session/facades/settings.dart`) deliberately does not auto-save — "a BLE pairing change needs an explicit `save` and a reboot, and batching the rest behind one save keeps the settings screen's save button honest". This task is that button's state.

**Files:**
- Create: `app/lib/features/settings/state/device_settings_controller.dart`, `app/lib/features/settings/state/settings_labels.dart`
- Test: `app/test/features/settings/device_settings_controller_test.dart`

**Interfaces:**
- Consumes (all landed, all in `packages/chameleon`): `SettingsFacade.setAnimation(AnimationMode)`, `.setButton(DeviceButton button, ButtonFunction fn, {bool long = false})`, `.setSleepTimeout(int seconds)`, `.setBlePairingEnabled(bool)`, `.setBlePairingKey(String)`, `.save()`, `.reset()`, `.refresh()`, `.deleteAllBleBonds()`, `.current`; `DeviceSettings({required int version, required AnimationMode animation, required ButtonFunction buttonA, required ButtonFunction buttonB, required ButtonFunction longButtonA, required ButtonFunction longButtonB, required bool blePairingEnabled, required String blePairingKey, int? sleepTimeoutSeconds})`; `AnimationMode.{full,minimal,none,symmetric}`; `ButtonFunction.{none,nextSlot,prevSlot,cloneUid,battery,nfcFieldGenerator}`; `DeviceButton.{a,b}`; `SessionNotReady`. From the app: `activeSessionProvider`, `ActiveSession.session` (`app/lib/core/session/active_device.dart`, `active_session.dart`); `settingsProvider` (`app/lib/core/session/session_streams.dart`) is what the *screen* watches for values — the controller does not duplicate them.
- Produces:
  - `final class DeviceSettingsEditState { const DeviceSettingsEditState({this.busy = false, this.dirty = false, this.error}); final bool busy; final bool dirty; final Object? error; }`
  - `@riverpod class DeviceSettingsController extends _$DeviceSettingsController` with `DeviceSettingsEditState build()`, `Future<void> setAnimation(AnimationMode)`, `Future<void> setButton(DeviceButton, ButtonFunction, {bool long = false})`, `Future<void> setSleepTimeout(int)`, `Future<void> setBlePairingEnabled(bool)`, `Future<void> setBlePairingKey(String)`, `Future<void> saveToDevice()`, `Future<void> resetToFactory()`, `Future<void> deleteBonds()`, `void clearError()`, `@visibleForTesting void debugFail(Object)`.
  - `String animationLabel(AnimationMode, AppLocalizations)`, `String buttonFunctionLabel(ButtonFunction, AppLocalizations)` — exhaustive switches, so an enum value added to the SDK is a compile error here rather than a blank row.
  - `bool isValidPairingKey(String)` — six ASCII digits (`docs/research/chameleon-protocol.md`: "1030/1031 SET/GET_BLE_PAIRING_KEY 6 ascii digits").

- [ ] **Step 1: Write the failing test**

Create `app/test/features/settings/device_settings_controller_test.dart`:

```dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/session/session_streams.dart';
import 'package:spectra/features/settings/state/device_settings_controller.dart';

import '../../support/app_harness.dart';

void main() {
  testWidgetsApp('a change writes through and marks the settings unsaved', (
    tester,
  ) async {
    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await connectToEmulator(tester);
    keepAlive(tester, settingsProvider);
    await pumpFrames(tester);

    final DeviceSettingsController controller = readProvider(
      tester,
      deviceSettingsControllerProvider.notifier,
    );
    final Future<void> pending = controller.setAnimation(AnimationMode.none);
    await pumpFrames(tester, count: 5, step: const Duration(milliseconds: 20));
    await pending;
    await pumpFrames(tester, count: 3);

    expect(
      readProvider(tester, settingsProvider).value!.animation,
      AnimationMode.none,
    );
    expect(
      readProvider(tester, deviceSettingsControllerProvider).dirty,
      isTrue,
    );
  });

  testWidgetsApp('saving clears the unsaved marker', (tester) async {
    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await connectToEmulator(tester);
    keepAlive(tester, settingsProvider);
    await pumpFrames(tester);

    final DeviceSettingsController controller = readProvider(
      tester,
      deviceSettingsControllerProvider.notifier,
    );
    final Future<void> changed = controller.setButton(
      DeviceButton.a,
      ButtonFunction.battery,
    );
    await pumpFrames(tester, count: 5, step: const Duration(milliseconds: 20));
    await changed;

    final Future<void> saved = controller.saveToDevice();
    await pumpFrames(tester, count: 5, step: const Duration(milliseconds: 20));
    await saved;
    await pumpFrames(tester, count: 3);

    final DeviceSettingsEditState state = readProvider(
      tester,
      deviceSettingsControllerProvider,
    );
    expect(state.dirty, isFalse);
    expect(state.error, isNull);
    expect(
      readProvider(tester, settingsProvider).value!.buttonA,
      ButtonFunction.battery,
    );
  });

  testWidgetsApp('reset restores the firmware defaults and re-reads them', (
    tester,
  ) async {
    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await connectToEmulator(tester);
    keepAlive(tester, settingsProvider);
    await pumpFrames(tester);

    final DeviceSettingsController controller = readProvider(
      tester,
      deviceSettingsControllerProvider.notifier,
    );
    final Future<void> changed = controller.setAnimation(AnimationMode.none);
    await pumpFrames(tester, count: 5, step: const Duration(milliseconds: 20));
    await changed;

    final Future<void> reset = controller.resetToFactory();
    await pumpFrames(tester, count: 5, step: const Duration(milliseconds: 20));
    await reset;
    await pumpFrames(tester, count: 3);

    expect(
      readProvider(tester, settingsProvider).value!.animation,
      AnimationMode.full,
    );
    expect(readProvider(tester, deviceSettingsControllerProvider).dirty, isFalse);
  });

  testWidgetsApp('with no session the failure is typed, not thrown', (
    tester,
  ) async {
    await pumpTestApp(tester);
    await pumpFrames(tester);

    final DeviceSettingsController controller = readProvider(
      tester,
      deviceSettingsControllerProvider.notifier,
    );
    await controller.setAnimation(AnimationMode.none);
    await pumpFrames(tester, count: 3);

    expect(
      readProvider(tester, deviceSettingsControllerProvider).error,
      isA<SessionNotReady>(),
    );
  });

  testWidgetsApp('a second call while one is in flight is dropped', (
    tester,
  ) async {
    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await connectToEmulator(tester);
    await pumpFrames(tester);

    final DeviceSettingsController controller = readProvider(
      tester,
      deviceSettingsControllerProvider.notifier,
    );
    final Future<void> first = controller.setAnimation(AnimationMode.none);
    final Future<void> second = controller.setAnimation(AnimationMode.minimal);
    await pumpFrames(tester, count: 5, step: const Duration(milliseconds: 20));
    await first;
    await second;
    await pumpFrames(tester, count: 3);

    // The second call never reached the device: the first one's value stands.
    expect(
      readProvider(tester, settingsProvider).value!.animation,
      AnimationMode.none,
    );
  });

  group('validation and labels', () {
    test('a pairing key is six digits', () {
      expect(isValidPairingKey('123456'), isTrue);
      expect(isValidPairingKey('12345'), isFalse);
      expect(isValidPairingKey('1234567'), isFalse);
      expect(isValidPairingKey('12345a'), isFalse);
    });
  });
}
```

`isValidPairingKey` lives in `settings_labels.dart`; import it in the test.

- [ ] **Step 2: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/settings/device_settings_controller_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: '.../device_settings_controller.dart'`.

- [ ] **Step 3: Write the controller**

Create `app/lib/features/settings/state/device_settings_controller.dart`:

```dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/session/active_device.dart';
import '../../../core/session/active_session.dart';

part 'device_settings_controller.g.dart';

/// What the settings screen needs beyond the values themselves.
///
/// The values are not here: `SettingsFacade` writes every change through to
/// `DeviceSession.settingsState` (spec 4.3's cache contract), which
/// `settingsProvider` (`core/session/session_streams.dart`) already streams.
/// Mirroring them into this state would give the screen two sources for one
/// fact.
final class DeviceSettingsEditState {
  const DeviceSettingsEditState({
    this.busy = false,
    this.dirty = false,
    this.error,
  });

  final bool busy;

  /// True when a change has reached the device's RAM but not its flash.
  /// The firmware needs an explicit SAVE_SETTINGS (1013); until then a
  /// reboot loses the change, so the screen says so.
  final bool dirty;

  final Object? error;
}

/// Every device-settings change, as state the screen renders (spec 7.7 step
/// 7, spec 8.1).
///
/// Failures stay in [DeviceSettingsEditState.error] rather than being
/// thrown, so the screen shows them through the spec 9 catalog. A call made
/// while another is in flight is dropped, not queued, and the screen
/// disables its controls while `busy`. Every post-`await` assignment is
/// guarded with `ref.mounted` (R25): the Settings tab can be left while a
/// write is on the wire.
@riverpod
class DeviceSettingsController extends _$DeviceSettingsController {
  @override
  DeviceSettingsEditState build() {
    ref.onDispose(() {
      // Not `state` — the element is gone by now (Global Constraints).
      _inFlight = false;
    });
    return const DeviceSettingsEditState();
  }

  bool _inFlight = false;

  Future<void> setAnimation(AnimationMode mode) =>
      _run((SettingsFacade s) => s.setAnimation(mode));

  Future<void> setButton(
    DeviceButton button,
    ButtonFunction fn, {
    bool long = false,
  }) => _run((SettingsFacade s) => s.setButton(button, fn, long: long));

  /// The firmware accepts 5..60 seconds (`docs/research/chameleon-protocol.md`,
  /// 1039/1040); the screen only offers values in that range.
  Future<void> setSleepTimeout(int seconds) =>
      _run((SettingsFacade s) => s.setSleepTimeout(seconds));

  Future<void> setBlePairingEnabled(bool enabled) =>
      _run((SettingsFacade s) => s.setBlePairingEnabled(enabled));

  /// The caller validates with `isValidPairingKey` first: the firmware wants
  /// exactly six ASCII digits, and a shorter string would be a wire-format
  /// error rather than a message the catalog has words for.
  Future<void> setBlePairingKey(String key) =>
      _run((SettingsFacade s) => s.setBlePairingKey(key));

  /// SAVE_SETTINGS, then a re-read: the settings struct is the one payload
  /// the wiki's length is uncertain about (spec 11), so reading back what
  /// the device actually kept is cheaper than trusting the write.
  Future<void> saveToDevice() => _run((SettingsFacade s) async {
    await s.save();
    await s.refresh();
  }, clearsDirty: true);

  /// RESET_SETTINGS. `SettingsFacade.reset` already re-reads.
  Future<void> resetToFactory() =>
      _run((SettingsFacade s) => s.reset(), clearsDirty: true);

  /// Clears the bonds a paired host holds (1032). Spec 5.1: with pairing
  /// enabled the device is invisible to hosts that are not bonded, so this
  /// is the way back.
  Future<void> deleteBonds() =>
      _run((SettingsFacade s) => s.deleteAllBleBonds(), marksDirty: false);

  void clearError() =>
      state = DeviceSettingsEditState(dirty: state.dirty);

  @visibleForTesting
  void debugFail(Object error) =>
      state = DeviceSettingsEditState(dirty: state.dirty, error: error);

  Future<void> _run(
    Future<void> Function(SettingsFacade settings) body, {
    bool marksDirty = true,
    bool clearsDirty = false,
  }) async {
    if (_inFlight) return;
    final ActiveSession? active = ref.read(activeSessionProvider);
    if (active == null) {
      state = DeviceSettingsEditState(
        dirty: state.dirty,
        error: const SessionNotReady('no active session'),
      );
      return;
    }
    _inFlight = true;
    state = DeviceSettingsEditState(busy: true, dirty: state.dirty);
    Object? error;
    try {
      await body(active.session.settings);
    } on Object catch (e) {
      error = e;
    }
    if (!ref.mounted) {
      _inFlight = false;
      return;
    }
    final bool dirty = switch ((error != null, clearsDirty, marksDirty)) {
      (true, _, _) => state.dirty, // a failed write changed nothing
      (false, true, _) => false,
      (false, false, true) => true,
      _ => state.dirty,
    };
    state = DeviceSettingsEditState(dirty: dirty, error: error);
    _inFlight = false;
  }
}
```

- [ ] **Step 4: Write the labels**

Create `app/lib/features/settings/state/settings_labels.dart`:

```dart
import 'package:chameleon/chameleon.dart';

import '../../../l10n/app_localizations.dart';

/// How the SDK's settings enums become words. Both switches are exhaustive,
/// so a value added to the SDK is a compile error here rather than a blank
/// row in the settings screen.
String animationLabel(AnimationMode mode, AppLocalizations l10n) =>
    switch (mode) {
      AnimationMode.full => l10n.settingsAnimationFull,
      AnimationMode.minimal => l10n.settingsAnimationMinimal,
      AnimationMode.none => l10n.settingsAnimationNone,
      AnimationMode.symmetric => l10n.settingsAnimationSymmetric,
    };

String buttonFunctionLabel(ButtonFunction fn, AppLocalizations l10n) =>
    switch (fn) {
      ButtonFunction.none => l10n.settingsButtonNone,
      ButtonFunction.nextSlot => l10n.settingsButtonNextSlot,
      ButtonFunction.prevSlot => l10n.settingsButtonPrevSlot,
      ButtonFunction.cloneUid => l10n.settingsButtonCloneUid,
      ButtonFunction.battery => l10n.settingsButtonBattery,
      ButtonFunction.nfcFieldGenerator => l10n.settingsButtonField,
    };

final RegExp _sixDigits = RegExp(r'^[0-9]{6}$');

/// The firmware's BLE pairing passkey is exactly six ASCII digits
/// (`docs/research/chameleon-protocol.md`, command 1030).
bool isValidPairingKey(String key) => _sixDigits.hasMatch(key);
```

The ARB keys it names land in Task 11, which owns the ARB. Land `settings_labels.dart` in **this** task only if Task 11 runs immediately after; otherwise land the controller here and the labels file with Task 11. Whichever order the executor picks, `flutter analyze` must be green at the commit — do not commit a file that names ARB getters that do not exist yet.

- [ ] **Step 5: Regenerate, run, check and commit**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && dart run build_runner build --delete-conflicting-outputs
flutter test test/features/settings/
cd .. && dart run melos run check:all
git add -A app/lib app/test
git commit -m "$(cat <<'MSG'
add the device settings controller

SettingsFacade deliberately does not auto-save, so the screen needs state
that knows a change is in the device's RAM but not yet in its flash.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 11: The device settings screen

Spec 7.7 step 7: "device settings (LEDs, buttons, sleep, pairing)". **This task owns the ARB.**

**Files:**
- Create: `app/lib/features/settings/ui/device_settings_section.dart`, `app/lib/features/settings/ui/option_sheet.dart`
- Modify: `app/lib/features/settings/ui/settings_page.dart`, `app/lib/l10n/app_en.arb`
- Test: `app/test/features/settings/device_settings_section_test.dart`

**Interfaces:**
- Consumes: `DeviceSettingsController`, `DeviceSettingsEditState` (Task 10); `animationLabel`, `buttonFunctionLabel`, `isValidPairingKey` (Task 10); `settingsProvider` (`app/lib/core/session/session_streams.dart`) — a `Stream<DeviceSettings?>`, null when nothing is connected; `ProblemView`; `SpectraCard`, `SpectraSectionHeader`, `SpectraListTile`, `SpectraButton`, `SpectraTextField`, `SpectraBottomSheet`, `SpectraDialog`, `SpectraSpacing`; `Switch` from `material_ui`.
- Produces:
  - `class DeviceSettingsSection extends ConsumerWidget`.
  - `Future<T?> showOptionSheet<T>({required BuildContext context, required String title, required List<T> options, required String Function(T) labelOf, T? selected})`.

- [ ] **Step 1: Add the ARB keys**

Append to `app/lib/l10n/app_en.arb` and run `cd app && flutter gen-l10n`:

```json
  "settingsDeviceTitle": "Device",
  "@settingsDeviceTitle": {"description": "Section header above the connected device's settings."},
  "settingsNoDevice": "Connect a device to change its settings.",
  "@settingsNoDevice": {"description": "Shown in place of device settings with nothing connected."},
  "settingsAnimation": "Start-up animation",
  "@settingsAnimation": {"description": "The LED animation the device plays when it wakes."},
  "settingsAnimationFull": "Full",
  "@settingsAnimationFull": {"description": "Animation mode: full."},
  "settingsAnimationMinimal": "Minimal",
  "@settingsAnimationMinimal": {"description": "Animation mode: minimal."},
  "settingsAnimationNone": "None",
  "@settingsAnimationNone": {"description": "Animation mode: none."},
  "settingsAnimationSymmetric": "Symmetric",
  "@settingsAnimationSymmetric": {"description": "Animation mode: symmetric."},
  "settingsButtonA": "Button A",
  "@settingsButtonA": {"description": "Short press of button A."},
  "settingsButtonB": "Button B",
  "@settingsButtonB": {"description": "Short press of button B."},
  "settingsLongButtonA": "Button A, held",
  "@settingsLongButtonA": {"description": "Long press of button A."},
  "settingsLongButtonB": "Button B, held",
  "@settingsLongButtonB": {"description": "Long press of button B."},
  "settingsButtonNone": "Nothing",
  "@settingsButtonNone": {"description": "Button function: none."},
  "settingsButtonNextSlot": "Next slot",
  "@settingsButtonNextSlot": {"description": "Button function: next slot."},
  "settingsButtonPrevSlot": "Previous slot",
  "@settingsButtonPrevSlot": {"description": "Button function: previous slot."},
  "settingsButtonCloneUid": "Clone UID",
  "@settingsButtonCloneUid": {"description": "Button function: clone the UID of a card in the field."},
  "settingsButtonBattery": "Show battery",
  "@settingsButtonBattery": {"description": "Button function: show the battery level."},
  "settingsButtonField": "NFC field detector",
  "@settingsButtonField": {"description": "Button function: NFC field generator/detector."},
  "settingsSleep": "Sleep after",
  "@settingsSleep": {"description": "How long the device waits before sleeping."},
  "settingsSleepSeconds": "{seconds} seconds",
  "@settingsSleepSeconds": {
    "description": "A sleep timeout in seconds.",
    "placeholders": {"seconds": {"type": "int"}}
  },
  "settingsBlePairing": "Require Bluetooth pairing",
  "@settingsBlePairing": {"description": "Whether the device demands pairing before it talks."},
  "settingsBlePairingWarning": "With pairing on, the device only advertises to hosts it has already bonded with. Forget the paired hosts to make it visible again.",
  "@settingsBlePairingWarning": {"description": "Spec 5.1 warning about enabling pairing."},
  "settingsBlePairingKey": "Pairing passkey",
  "@settingsBlePairingKey": {"description": "The six-digit passkey the device displays."},
  "settingsBlePairingKeyInvalid": "The passkey is six digits.",
  "@settingsBlePairingKeyInvalid": {"description": "Validation message for the passkey field."},
  "settingsDeleteBonds": "Forget paired hosts",
  "@settingsDeleteBonds": {"description": "Clears the device's BLE bonds."},
  "settingsBondsDeleted": "The device forgot its paired hosts.",
  "@settingsBondsDeleted": {"description": "Confirms the bonds were cleared."},
  "settingsSave": "Save to device",
  "@settingsSave": {"description": "Writes the settings to the device's flash."},
  "settingsUnsaved": "Unsaved. Save these settings to the device so they survive a reboot.",
  "@settingsUnsaved": {"description": "Shown while a change is in RAM but not in flash."},
  "settingsSaved": "Settings saved to the device.",
  "@settingsSaved": {"description": "Confirms SAVE_SETTINGS."},
  "settingsResetDevice": "Restore device defaults",
  "@settingsResetDevice": {"description": "Runs RESET_SETTINGS on the device."},
  "settingsResetTitle": "Restore the device's defaults?",
  "@settingsResetTitle": {"description": "Title of the reset confirmation."},
  "settingsResetBody": "Animation, buttons, sleep and pairing all go back to the firmware defaults. Slots and cards are untouched.",
  "@settingsResetBody": {"description": "Body of the reset confirmation."}
```

- [ ] **Step 2: Write the failing test**

Create `app/test/features/settings/device_settings_section_test.dart`:

```dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/session/session_streams.dart';
import 'package:spectra/features/settings/state/device_settings_controller.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

Future<void> _openSettings(WidgetTester tester) async {
  useDesktopSurface(tester);
  await pumpTestApp(tester, transport: (_) => FakeDevice());
  await connectToEmulator(tester);
  await tester.tap(find.text('Settings').last);
  await pumpFrames(tester);
}

void main() {
  testWidgetsApp('shows the device settings the fake reports', (tester) async {
    await _openSettings(tester);

    expect(find.text('Start-up animation'), findsOneWidget);
    expect(find.text('Full'), findsOneWidget);
    expect(find.text('Next slot'), findsOneWidget); // button A default
  });

  testWidgetsApp('changing the animation writes through and asks to be saved', (
    tester,
  ) async {
    await _openSettings(tester);

    await tester.tap(find.text('Start-up animation'));
    await pumpFrames(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('None'),
      ),
    );
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    expect(
      readProvider(tester, settingsProvider).value!.animation,
      AnimationMode.none,
    );
    expect(
      find.text(
        'Unsaved. Save these settings to the device so they survive a reboot.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Save to device'));
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));
    expect(
      readProvider(tester, deviceSettingsControllerProvider).dirty,
      isFalse,
    );
  });

  testWidgetsApp('the pairing switch carries the spec 5.1 warning', (
    tester,
  ) async {
    await _openSettings(tester);
    expect(
      find.textContaining('only advertises to hosts it has already bonded'),
      findsOneWidget,
    );
  });

  testWidgetsApp('a six-digit passkey is required', (tester) async {
    await _openSettings(tester);

    await tester.enterText(find.byType(SpectraTextField).first, '12345');
    await tester.pump();
    expect(find.text('The passkey is six digits.'), findsOneWidget);
  });

  testWidgetsApp('a failed write is shown through ProblemView', (tester) async {
    await _openSettings(tester);
    readProvider(
      tester,
      deviceSettingsControllerProvider.notifier,
    ).debugFail(const HfTagNotFound());
    await pumpFrames(tester, count: 3);

    expect(find.byType(ProblemView), findsOneWidget);
  });
}
```

Import `ProblemView` from `package:spectra/core/errors/problem_view.dart`.

- [ ] **Step 3: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/settings/device_settings_section_test.dart
```

Expected: FAIL — the Settings tab still shows the Phase 4 placeholder.

- [ ] **Step 4: Write the option sheet**

Create `app/lib/features/settings/ui/option_sheet.dart`:

```dart
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

/// One radio-style chooser for every enum on the settings screen: the
/// animation mode, four button functions and the sleep timeout all pick one
/// value out of a short list, and five bespoke sheets would be five places
/// for the same layout to drift.
///
/// Resolves to the chosen value, or null when dismissed.
Future<T?> showOptionSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> options,
  required String Function(T option) labelOf,
  T? selected,
}) => SpectraBottomSheet.show<T>(
  context: context,
  title: title,
  builder: (BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (final T option in options)
        SpectraListTile(
          title: labelOf(option),
          trailing: option == selected ? const Icon(Icons.check) : null,
          onTap: () => Navigator.of(context).pop(option),
        ),
    ],
  ),
);
```

- [ ] **Step 5: Write the section**

Create `app/lib/features/settings/ui/device_settings_section.dart`. Layout only; every mutation goes through `DeviceSettingsController`, every value comes from `settingsProvider`:

```dart
import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/problem_view.dart';
import '../../../core/session/session_streams.dart';
import '../../../l10n/app_localizations.dart';
import '../state/device_settings_controller.dart';
import '../state/settings_labels.dart';
import 'option_sheet.dart';

/// Spec 7.7 step 7: LEDs, buttons, sleep and pairing.
///
/// The values come from `settingsProvider` — the session's write-through
/// cache (spec 4.3) — not from this widget's own state, so a change made
/// with the device's buttons shows up here too.
class DeviceSettingsSection extends ConsumerWidget {
  const DeviceSettingsSection({super.key});

  /// The firmware accepts 5..60 seconds (1039/1040); these are the values
  /// worth offering.
  static const List<int> sleepOptions = <int>[5, 8, 15, 30, 60];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DeviceSettings? settings = ref.watch(settingsProvider).value;
    final DeviceSettingsEditState edit = ref.watch(
      deviceSettingsControllerProvider,
    );
    final DeviceSettingsController controller = ref.read(
      deviceSettingsControllerProvider.notifier,
    );

    if (settings == null) {
      return SpectraCard(child: Text(l10n.settingsNoDevice));
    }
    final bool busy = edit.busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SpectraSectionHeader(title: l10n.settingsDeviceTitle),
        if (edit.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: SpectraSpacing.md),
            child: ProblemView(
              error: edit.error!,
              variant: SpectraButtonVariant.secondary,
              onAction: controller.clearError,
            ),
          ),
        SpectraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SpectraListTile(
                title: l10n.settingsAnimation,
                subtitle: animationLabel(settings.animation, l10n),
                onTap: busy
                    ? null
                    : () => unawaited(
                        _pickAnimation(context, controller, settings, l10n),
                      ),
              ),
              for (final (String label, ButtonFunction current, DeviceButton
                  button, bool long) row in <(
                String,
                ButtonFunction,
                DeviceButton,
                bool,
              )>[
                (l10n.settingsButtonA, settings.buttonA, DeviceButton.a, false),
                (l10n.settingsButtonB, settings.buttonB, DeviceButton.b, false),
                (
                  l10n.settingsLongButtonA,
                  settings.longButtonA,
                  DeviceButton.a,
                  true,
                ),
                (
                  l10n.settingsLongButtonB,
                  settings.longButtonB,
                  DeviceButton.b,
                  true,
                ),
              ])
                SpectraListTile(
                  title: row.$1,
                  subtitle: buttonFunctionLabel(row.$2, l10n),
                  onTap: busy
                      ? null
                      : () => unawaited(
                          _pickButton(context, controller, row, l10n),
                        ),
                ),
              if (settings.sleepTimeoutSeconds case final int seconds)
                SpectraListTile(
                  title: l10n.settingsSleep,
                  subtitle: l10n.settingsSleepSeconds(seconds),
                  onTap: busy
                      ? null
                      : () => unawaited(
                          _pickSleep(context, controller, seconds, l10n),
                        ),
                ),
            ],
          ),
        ),
        const SizedBox(height: SpectraSpacing.md),
        SpectraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SpectraListTile(
                title: l10n.settingsBlePairing,
                subtitle: l10n.settingsBlePairingWarning,
                trailing: Switch(
                  value: settings.blePairingEnabled,
                  onChanged: busy
                      ? null
                      : (bool v) =>
                            unawaited(controller.setBlePairingEnabled(v)),
                ),
              ),
              const SizedBox(height: SpectraSpacing.md),
              _PairingKeyField(
                initialValue: settings.blePairingKey,
                enabled: !busy,
              ),
              const SizedBox(height: SpectraSpacing.md),
              SpectraButton(
                label: l10n.settingsDeleteBonds,
                variant: SpectraButtonVariant.secondary,
                onPressed: busy
                    ? null
                    : () => unawaited(_deleteBonds(context, controller, l10n)),
              ),
            ],
          ),
        ),
        const SizedBox(height: SpectraSpacing.md),
        if (edit.dirty) ...<Widget>[
          SpectraCard(child: Text(l10n.settingsUnsaved)),
          const SizedBox(height: SpectraSpacing.sm),
        ],
        SpectraButton(
          label: l10n.settingsSave,
          busy: busy,
          onPressed: busy ? null : () => unawaited(controller.saveToDevice()),
        ),
        const SizedBox(height: SpectraSpacing.sm),
        SpectraButton(
          label: l10n.settingsResetDevice,
          variant: SpectraButtonVariant.secondary,
          onPressed: busy
              ? null
              : () => unawaited(_reset(context, controller, l10n)),
        ),
      ],
    );
  }
}
```

The five handlers, in the same file:

```dart
Future<void> _pickAnimation(
  BuildContext context,
  DeviceSettingsController controller,
  DeviceSettings settings,
  AppLocalizations l10n,
) async {
  final AnimationMode? mode = await showOptionSheet<AnimationMode>(
    context: context,
    title: l10n.settingsAnimation,
    options: AnimationMode.values,
    labelOf: (AnimationMode m) => animationLabel(m, l10n),
    selected: settings.animation,
  );
  if (mode == null) return;
  await controller.setAnimation(mode);
}

Future<void> _pickButton(
  BuildContext context,
  DeviceSettingsController controller,
  (String, ButtonFunction, DeviceButton, bool) row,
  AppLocalizations l10n,
) async {
  final ButtonFunction? fn = await showOptionSheet<ButtonFunction>(
    context: context,
    title: row.$1,
    options: ButtonFunction.values,
    labelOf: (ButtonFunction f) => buttonFunctionLabel(f, l10n),
    selected: row.$2,
  );
  if (fn == null) return;
  await controller.setButton(row.$3, fn, long: row.$4);
}

Future<void> _pickSleep(
  BuildContext context,
  DeviceSettingsController controller,
  int current,
  AppLocalizations l10n,
) async {
  final int? seconds = await showOptionSheet<int>(
    context: context,
    title: l10n.settingsSleep,
    options: DeviceSettingsSection.sleepOptions,
    labelOf: l10n.settingsSleepSeconds,
    selected: current,
  );
  if (seconds == null) return;
  await controller.setSleepTimeout(seconds);
}

Future<void> _deleteBonds(
  BuildContext context,
  DeviceSettingsController controller,
  AppLocalizations l10n,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  await controller.deleteBonds();
  if (!context.mounted) return;
  messenger.showSnackBar(SnackBar(content: Text(l10n.settingsBondsDeleted)));
}

Future<void> _reset(
  BuildContext context,
  DeviceSettingsController controller,
  AppLocalizations l10n,
) async {
  final bool? confirmed = await SpectraDialog.show<bool>(
    context: context,
    title: l10n.settingsResetTitle,
    content: Text(l10n.settingsResetBody),
    actions: (BuildContext context) => <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: Text(l10n.commonCancel),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: Text(l10n.settingsResetDevice),
      ),
    ],
  );
  if (confirmed != true) return;
  await controller.resetToFactory();
}
```

And the passkey field, which validates as the user types and only writes a valid key:

```dart
class _PairingKeyField extends ConsumerStatefulWidget {
  const _PairingKeyField({required this.initialValue, required this.enabled});

  final String initialValue;
  final bool enabled;

  @override
  ConsumerState<_PairingKeyField> createState() => _PairingKeyFieldState();
}

class _PairingKeyFieldState extends ConsumerState<_PairingKeyField> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initialValue,
  );
  bool _invalid = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _onChanged(String value) async {
    final bool ok = isValidPairingKey(value);
    setState(() => _invalid = !ok);
    if (!ok) return;
    await ref
        .read(deviceSettingsControllerProvider.notifier)
        .setBlePairingKey(value);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SpectraTextField(
      label: l10n.settingsBlePairingKey,
      controller: _text,
      enabled: widget.enabled,
      errorText: _invalid ? l10n.settingsBlePairingKeyInvalid : null,
      onChanged: (String v) => unawaited(_onChanged(v)),
    );
  }
}
```

- [ ] **Step 6: Put it on the screen**

Replace the placeholder body of `app/lib/features/settings/ui/settings_page.dart` with a `ListView` whose only child (for now) is `const DeviceSettingsSection()` under the existing `SpectraSectionHeader(title: l10n.navSettings)`. Task 12 adds the rest. Delete `comingSoonSettings` from the ARB once nothing references it (`grep -rn comingSoonSettings app`).

- [ ] **Step 7: Run, check and commit**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/settings/
cd .. && dart run melos run check:all
git add -A app/lib app/test
git commit -m "$(cat <<'MSG'
add the device settings screen

Spec 7.7 step 7 wants LEDs, buttons, sleep and pairing; the pairing warning
is spec 5.1's, because turning it on hides the device from other hosts.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 12: App settings — theme, emulator mode, flags, about

Spec 7.7 step 7 ends with "app theme"; spec 7.5 makes emulator mode a user-visible choice; spec 5.6 needs somewhere to flip `dfuOverBleEnabled` once the user reports H2 passed. **This task owns the ARB.**

**Files:**
- Create: `app/lib/core/theme/theme_mode.dart`, `app/lib/features/settings/ui/app_settings_section.dart`
- Modify: `app/lib/app.dart`, `app/lib/core/discovery/scanners.dart`, `app/lib/features/settings/ui/settings_page.dart`, `app/lib/features/settings/state/settings_labels.dart`, `app/lib/l10n/app_en.arb`, `app/test/core/discovery/discovery_provider_test.dart`
- Test: `app/test/core/theme/theme_mode_test.dart`, `app/test/features/settings/app_settings_section_test.dart`

**Interfaces:**
- Consumes: `PreferencesRepository`, `preferencesRepositoryProvider`; `FeatureFlags`, `featureFlagsProvider`, `FeatureFlagsController.setDfuOverBleEnabled(bool)`, `FeatureFlags.dfuOverBleKey` (`app/lib/core/flags/feature_flags.dart`); `EmulatorMode.setEnabled` and `emulatorModeProvider` (`app/lib/core/discovery/scanners.dart`); `SpectraApp({required RouterConfig<Object> routerConfig, String title, String Function(BuildContext)? onGenerateTitle, ThemeMode themeMode, List<LocalizationsDelegate<Object?>> extraDelegates, Iterable<Locale>? supportedLocales, …})` (`packages/spectra_ui/lib/src/theme/spectra_app.dart`); `showLicensePage` from `material_ui`.
- Produces:
  - `@Riverpod(keepAlive: true) class ThemeModeController extends _$ThemeModeController` with `Future<ThemeMode> build()`, `Future<void> select(ThemeMode)`, `static const String preferenceKey = 'app.themeMode'`.
  - `@Riverpod(keepAlive: true) ThemeMode themeMode(Ref ref)` — the sync mirror `SpectraRoot` reads (`ref.watch(themeModeControllerProvider).value ?? ThemeMode.system`), the `featureFlagsProvider` shape.
  - `String themeModeLabel(ThemeMode, AppLocalizations)` in `settings_labels.dart`.
  - `class AppSettingsSection extends ConsumerWidget`.
  - `EmulatorMode.setEnabled` becomes `Future<void>` and persists (`EmulatorMode.preferenceKey = 'app.emulatorMode'`).

- [ ] **Step 1: Add the ARB keys**

```json
  "settingsAppTitle": "App",
  "@settingsAppTitle": {"description": "Section header above the app's own settings."},
  "settingsTheme": "Theme",
  "@settingsTheme": {"description": "Light, dark or follow the system."},
  "settingsThemeSystem": "Match the system",
  "@settingsThemeSystem": {"description": "Theme mode: system."},
  "settingsThemeLight": "Light",
  "@settingsThemeLight": {"description": "Theme mode: light."},
  "settingsThemeDark": "Dark",
  "@settingsThemeDark": {"description": "Theme mode: dark."},
  "settingsEmulator": "Emulated device",
  "@settingsEmulator": {"description": "Whether the connect screen offers an emulated Chameleon."},
  "settingsEmulatorSubtitle": "Show an emulated Chameleon Ultra on the connect screen, so Spectra works with no hardware attached.",
  "@settingsEmulatorSubtitle": {"description": "Explains emulator mode (spec 7.5)."},
  "settingsDeveloperTitle": "Developer",
  "@settingsDeveloperTitle": {"description": "Section header above the feature flags."},
  "settingsFlagDfuBle": "Firmware update over Bluetooth",
  "@settingsFlagDfuBle": {"description": "The dfuOverBleEnabled feature flag."},
  "settingsFlagDfuBleSubtitle": "Off until a USB update has recovered a device from an interrupted Bluetooth update on real hardware.",
  "@settingsFlagDfuBleSubtitle": {"description": "Spec 5.6's rule for enabling BLE DFU."},
  "settingsAboutTitle": "About",
  "@settingsAboutTitle": {"description": "Section header above the about rows."},
  "settingsLicences": "Open-source licences",
  "@settingsLicences": {"description": "Opens the licences of the packages Spectra uses."}
```

Then `cd app && flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests**

Create `app/test/core/theme/theme_mode_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra/core/theme/theme_mode.dart';
import 'package:spectra/data/data.dart';

import '../../support/app_harness.dart';

void main() {
  testWidgetsApp('defaults to following the system', (tester) async {
    await pumpTestApp(tester);
    await pumpFrames(tester);
    expect(readProvider(tester, themeModeProvider), ThemeMode.system);
  });

  testWidgetsApp('a chosen theme is applied and persisted', (tester) async {
    await pumpTestApp(tester);
    await pumpFrames(tester);

    final Future<void> pending = readProvider(
      tester,
      themeModeControllerProvider.notifier,
    ).select(ThemeMode.dark);
    await pumpFrames(tester, count: 3);
    await pending;
    await pumpFrames(tester, count: 3);

    expect(readProvider(tester, themeModeProvider), ThemeMode.dark);
    expect(
      await readProvider(
        tester,
        preferencesRepositoryProvider,
      ).read(ThemeModeController.preferenceKey),
      'dark',
    );
  });
}
```

Create `app/test/features/settings/app_settings_section_test.dart`:

```dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/core/discovery/scanners.dart';
import 'package:spectra/core/flags/feature_flags.dart';
import 'package:spectra/core/theme/theme_mode.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

Future<void> _openSettings(WidgetTester tester) async {
  useDesktopSurface(tester);
  await pumpTestApp(tester, transport: (_) => FakeDevice());
  await connectToEmulator(tester);
  await tester.tap(find.text('Settings').last);
  await pumpFrames(tester);
}

void main() {
  testWidgetsApp('picks a theme', (tester) async {
    await _openSettings(tester);

    await tester.tap(find.text('Theme'));
    await pumpFrames(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Dark'),
      ),
    );
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    expect(readProvider(tester, themeModeProvider), ThemeMode.dark);
  });

  testWidgetsApp('turns emulator mode off', (tester) async {
    await _openSettings(tester);

    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Emulated device'),
          matching: find.byType(SpectraListTile),
        ),
        matching: find.byType(Switch),
      ),
    );
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    expect(readProvider(tester, emulatorModeProvider), isFalse);
  });

  testWidgetsApp('flips the BLE DFU flag and says why it is off', (
    tester,
  ) async {
    await _openSettings(tester);
    expect(
      find.textContaining('recovered a device from an interrupted'),
      findsOneWidget,
    );
    expect(readProvider(tester, featureFlagsProvider).dfuOverBleEnabled, isFalse);

    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Firmware update over Bluetooth'),
          matching: find.byType(SpectraListTile),
        ),
        matching: find.byType(Switch),
      ),
    );
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    expect(readProvider(tester, featureFlagsProvider).dfuOverBleEnabled, isTrue);
  });

  testWidgetsApp('offers the licences', (tester) async {
    await _openSettings(tester);
    expect(find.text('Open-source licences'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run them and watch them fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/core/theme test/features/settings/app_settings_section_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: 'package:spectra/core/theme/theme_mode.dart'`.

- [ ] **Step 4: Write the theme preference**

Create `app/lib/core/theme/theme_mode.dart`:

```dart
import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/data.dart';

part 'theme_mode.g.dart';

/// The app's theme choice (spec 7.7 step 7), persisted like every other app
/// preference. The same `PreferencesRepository`-backed keepAlive shape
/// `core/flags/feature_flags.dart` uses: an async controller, plus a plain
/// value provider so a widget above `Localizations` — `SpectraRoot` — can
/// read it synchronously.
@Riverpod(keepAlive: true)
class ThemeModeController extends _$ThemeModeController {
  static const String preferenceKey = 'app.themeMode';

  @override
  Future<ThemeMode> build() async {
    final String? stored = await ref
        .watch(preferencesRepositoryProvider)
        .read(preferenceKey);
    return ThemeMode.values
            .where((ThemeMode m) => m.name == stored)
            .firstOrNull ??
        ThemeMode.system;
  }

  Future<void> select(ThemeMode mode) async {
    await ref
        .read(preferencesRepositoryProvider)
        .write(preferenceKey, mode.name);
    if (!ref.mounted) return;
    state = AsyncData<ThemeMode>(mode);
  }
}

/// The theme as a plain value: the system theme until the stored one loads,
/// which is the safe direction (it is what the platform already shows).
@Riverpod(keepAlive: true)
ThemeMode themeMode(Ref ref) =>
    ref.watch(themeModeControllerProvider).value ?? ThemeMode.system;
```

In `app/lib/app.dart`, pass it: `themeMode: ref.watch(themeModeProvider),` on `SpectraApp`, with `import 'core/theme/theme_mode.dart';`.

- [ ] **Step 5: Persist emulator mode**

In `app/lib/core/discovery/scanners.dart`, replace the body of `EmulatorMode`:

```dart
@Riverpod(keepAlive: true)
class EmulatorMode extends _$EmulatorMode {
  static const String preferenceKey = 'app.emulatorMode';

  @override
  bool build() {
    // The stored value arrives asynchronously and a scanner list cannot
    // wait for it, so the default holds until it lands. On by default,
    // because it is also how screenshots and manual QA happen with no
    // hardware attached (spec 7.5) — and the stored value can only ever
    // turn it off, which is the harmless direction to be late about.
    final PreferencesRepository prefs = ref.watch(preferencesRepositoryProvider);
    unawaited(
      prefs.read(preferenceKey).then((String? stored) {
        if (stored != null && ref.mounted) state = stored == 'true';
      }),
    );
    return true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await ref
        .read(preferencesRepositoryProvider)
        .write(preferenceKey, '$enabled');
  }
}
```

with `import 'dart:async';` and `import '../../data/data.dart';`. `setEnabled` now returns a `Future`, and `unawaited_futures` is on: update the one landed call site, `app/test/core/discovery/discovery_provider_test.dart:185`, to `await container.read(emulatorModeProvider.notifier).setEnabled(false);`.

- [ ] **Step 6: Write the section and assemble the screen**

Create `app/lib/features/settings/ui/app_settings_section.dart` with three cards — App (theme, emulator switch), Developer (the BLE DFU switch), About (a licences row calling `showLicensePage(context: context, applicationName: l10n.appTitle)`):

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/discovery/scanners.dart';
import '../../../core/flags/feature_flags.dart';
import '../../../core/theme/theme_mode.dart';
import '../../../l10n/app_localizations.dart';
import '../state/settings_labels.dart';
import 'option_sheet.dart';

/// Spec 7.7 step 7 (app theme), spec 7.5 (emulator mode) and spec 5.6 (the
/// BLE DFU flag, which stays off until the user reports hardware handoff H2
/// passed — this switch is how they turn it on afterwards).
///
/// The About card lists the licences of the packages Spectra ships.
/// Spectra's own LICENSE files are still the template TODO (`AGENTS.md`), so
/// no licence is claimed for the app itself here; add that row when a
/// licence is chosen.
class AppSettingsSection extends ConsumerWidget {
  const AppSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeMode theme = ref.watch(themeModeProvider);
    final bool emulator = ref.watch(emulatorModeProvider);
    final FeatureFlags flags = ref.watch(featureFlagsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SpectraSectionHeader(title: l10n.settingsAppTitle),
        SpectraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SpectraListTile(
                title: l10n.settingsTheme,
                subtitle: themeModeLabel(theme, l10n),
                onTap: () => unawaited(_pickTheme(context, ref, theme, l10n)),
              ),
              SpectraListTile(
                title: l10n.settingsEmulator,
                subtitle: l10n.settingsEmulatorSubtitle,
                trailing: Switch(
                  value: emulator,
                  onChanged: (bool v) => unawaited(
                    ref.read(emulatorModeProvider.notifier).setEnabled(v),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SpectraSpacing.lg),
        SpectraSectionHeader(title: l10n.settingsDeveloperTitle),
        SpectraCard(
          child: SpectraListTile(
            title: l10n.settingsFlagDfuBle,
            subtitle: l10n.settingsFlagDfuBleSubtitle,
            trailing: Switch(
              value: flags.dfuOverBleEnabled,
              onChanged: (bool v) => unawaited(
                ref
                    .read(featureFlagsControllerProvider.notifier)
                    .setDfuOverBleEnabled(v),
              ),
            ),
          ),
        ),
        const SizedBox(height: SpectraSpacing.lg),
        SpectraSectionHeader(title: l10n.settingsAboutTitle),
        SpectraCard(
          child: SpectraListTile(
            title: l10n.settingsLicences,
            leading: const Icon(Icons.article_outlined),
            onTap: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickTheme(
    BuildContext context,
    WidgetRef ref,
    ThemeMode current,
    AppLocalizations l10n,
  ) async {
    final ThemeMode? mode = await showOptionSheet<ThemeMode>(
      context: context,
      title: l10n.settingsTheme,
      options: ThemeMode.values,
      labelOf: (ThemeMode m) => themeModeLabel(m, l10n),
      selected: current,
    );
    if (mode == null) return;
    await ref.read(themeModeControllerProvider.notifier).select(mode);
  }
}
```

Add to `settings_labels.dart` (with `import 'package:material_ui/material_ui.dart' show ThemeMode;`):

```dart
String themeModeLabel(ThemeMode mode, AppLocalizations l10n) => switch (mode) {
  ThemeMode.system => l10n.settingsThemeSystem,
  ThemeMode.light => l10n.settingsThemeLight,
  ThemeMode.dark => l10n.settingsThemeDark,
};
```

`settings_labels.dart` is under `state/`, which the string lint does not scan, and it imports `material_ui` — not `package:flutter/material.dart` — so the features lint stays green.

Finally, `settings_page.dart` becomes the two sections in one `ListView`:

```dart
      children: <Widget>[
        const DeviceSettingsSection(),
        const SizedBox(height: SpectraSpacing.xl),
        const AppSettingsSection(),
      ],
```

- [ ] **Step 7: Regenerate, run, check and commit**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && dart run build_runner build --delete-conflicting-outputs
flutter test
cd .. && dart run melos run check:all
git add -A app/lib app/test
git commit -m "$(cat <<'MSG'
add app settings: theme, emulator mode, flags and licences

Theme and emulator mode are preferences and now persist; the BLE DFU flag
finally has the switch spec 5.6 assumes the user flips after H2.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 13: The phase gate

The roadmap's Phase 9 gate is "integration test on emulator". One flow widget test and one integration test, both driving the same app: edit a dictionary, then change a device setting.

**Files:**
- Create: `app/test/flows/dictionary_and_settings_flow_test.dart`, `app/integration_test/settings_flow_test.dart`
- Modify: `app/integration_test/support.dart` (export what the new test needs)
- Test: the two files above are the test.

**Interfaces:**
- Consumes: the harness (`testWidgetsApp`, `pumpTestApp`, `connectToEmulator`, `openDictionaries`, `pumpFrames`, `useDesktopSurface`, `readProvider`) and, in the integration test, `appOverrides` / `testApp` / `pumpFrames` re-exported from `app/integration_test/support.dart`; `FakeDevice`, `FakeScanner.emulatedUltra`, `AnimationMode` (`package:chameleon`); `SpectraAppShell`, `SpectraBottomSheet`, `SpectraTextField` (`package:spectra_ui`).

- [ ] **Step 1: Write the flow widget test**

Create `app/test/flows/dictionary_and_settings_flow_test.dart`:

```dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/session/session_streams.dart';
import 'package:spectra/features/dictionaries/state/selected_dictionary.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/app_harness.dart';

/// The roadmap's Phase 9 gate: edit a key list and change a device setting,
/// in emulator mode, through the real `DeviceSession`.
void main() {
  testWidgetsApp('create a key list, add a key, use it, then set the '
      'animation mode', (tester) async {
    useDesktopSurface(tester);
    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await tester.pump();
    await connectToEmulator(tester);

    // A key list of our own.
    await openDictionaries(tester);
    await tester.tap(find.text('New list'));
    await pumpFrames(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(SpectraTextField),
      ),
      'Hotel',
    );
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Save'),
      ),
    );
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    // A key in it.
    await tester.tap(find.text('Hotel'));
    await pumpFrames(tester);
    await tester.enterText(find.byType(SpectraTextField).last, '714C5C886E97');
    await tester.pump();
    await tester.tap(find.text('Add key'));
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));
    expect(find.text('714C5C886E97'), findsOneWidget);

    // And it is the list a read will use.
    await tester.tap(find.byType(BackButton));
    await pumpFrames(tester);
    await tester.tap(find.text('Use these keys').last);
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));
    expect(
      readProvider(tester, candidateMifareKeysProvider).value,
      hasLength(1),
    );

    // A device setting, on the emulated device.
    await tester.tap(find.text('Settings').last);
    await pumpFrames(tester);
    await tester.tap(find.text('Start-up animation'));
    await pumpFrames(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('None'),
      ),
    );
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));
    await tester.tap(find.text('Save to device'));
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    expect(
      readProvider(tester, settingsProvider).value!.animation,
      AnimationMode.none,
    );
  });
}
```

`BackButton` comes from `package:material_ui/material_ui.dart` — import it with `hide ConnectionState`, as `app/test/flows/slot_edit_flow_test.dart` does.

- [ ] **Step 2: Run it**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/flows/dictionary_and_settings_flow_test.dart
```

Expected: PASS. If it fails on a finder, fix the finder — not the app — unless the failure is a real defect, in which case fix the defect and say so in the commit body.

- [ ] **Step 3: Write the integration test**

Create `app/integration_test/settings_flow_test.dart`:

```dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import 'support.dart';

/// The Phase 9 gate on a real engine: edit a key list and change a device
/// setting in emulator mode. No hardware is touched, and none is needed.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('edit a dictionary and a device setting on the emulator', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await tester.pump();

    Future<void> settle([int frames = 20]) => pumpFrames(tester, count: frames);

    await tester.tap(find.text(FakeScanner.emulatedUltra.name));
    await settle(30);
    expect(find.byType(SpectraAppShell), findsOneWidget);

    await tester.tap(find.text('Tools').last);
    await settle();
    await tester.tap(find.text('Key dictionaries'));
    await settle();

    await tester.tap(find.text('New list'));
    await settle();
    await tester.enterText(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(SpectraTextField),
      ),
      'Hotel',
    );
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Save'),
      ),
    );
    await settle(30);
    expect(find.text('Hotel'), findsOneWidget);

    await tester.tap(find.text('Settings').last);
    await settle();
    await tester.tap(find.text('Start-up animation'));
    await settle();
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('None'),
      ),
    );
    await settle(30);
    await tester.tap(find.text('Save to device'));
    await settle(30);

    expect(find.text('None'), findsOneWidget);
  });
}
```

If `support.dart`'s export list does not carry a name this test needs, widen that list — do not build a second override list (Phase 6 ruling 9).

- [ ] **Step 4: Run the integration test**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test integration_test/settings_flow_test.dart -d macos
```

Expected: PASS. (`-d macos` is how the landed integration tests are run on this machine; if the runner is configured differently in CI, match what `.github/workflows` already does for `slot_edit_flow_test.dart`.)

- [ ] **Step 5: Check and commit**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd /Users/bcraig/orca/workspaces/spectra/chinook
dart run melos run check:all
git add app/test/flows app/integration_test
git commit -m "$(cat <<'MSG'
add the Phase 9 gate flows

The roadmap gate is an integration test on the emulator: a key list edited
and a device setting changed, through the real session.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 14: Close-out

The roadmap's per-phase obligation: leave the repo describing itself accurately.

**Files:**
- Modify: `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md`, `AGENTS.md`, `tasks/lessons.md`, `docs/research/DECISIONS.md`, `docs/hardware-checklist.md`
- Test: the whole suite (`dart run melos run check:all`).

- [ ] **Step 1: Run everything, in the foreground**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd /Users/bcraig/orca/workspaces/spectra/chinook
dart run melos run check:all
cd app && flutter test
```

Both must be green before anything below is written. Nothing in this task may claim a result the commands did not produce.

- [ ] **Step 2: Tick the roadmap**

In `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md`, change `- [ ] Phase 9` to `- [x] Phase 9`, and in the phase table replace the Phase 9 row's `write from spec 7.7 step 7` with `2026-09-03-phase-9-dictionaries-settings.md (done)`.

- [ ] **Step 3: Update `AGENTS.md`**

In "Current status", add a paragraph for Phase 9 in the style of the Phase 5/6 ones: the dictionaries feature (repository, built-in synthesized list, codec for `.dic` and both JSON shapes, list and detail screens, import/export, `showDictionaryPicker`, the selected-list preference feeding `ReaderFacade.mf1ReadDump`), the settings feature (device settings through `SettingsFacade` with explicit save and re-read, theme, emulator mode, the `dfuOverBleEnabled` switch, licences), and the test count the run in Step 1 actually reported. Point "Next" at Phase 10 and its plan-to-be-written.

- [ ] **Step 4: Record the decisions**

In `docs/research/DECISIONS.md`, under a Phase 9 heading, record:

1. **No `file_selector`.** Spec 7.3's import/export is paste-in and copy-out for dictionaries as it already is for cards; adding a file dialog would mean a new dependency, per-platform setup on five targets and a spec section 2 amendment. Revisit in Phase 10 if the release checklist wants file round-trips.
2. **The built-in key list is synthesized, not seeded** — `dictionariesProvider` puts it in front of the stored rows, so read-only is structural and its name can be localized.
3. **`hex.dart` moved to `core/format/`** (R28's rule applied a second time).
4. **The `dfuOverBleEnabled` flag has a developer switch** in Settings, because spec 5.6 has the user flip it after reporting H2 and `FeatureFlagsController.setDfuOverBleEnabled` had no caller until now.
5. **Spec 8.5 relaxed for two files** (`dictionary_codec.dart`, `dictionary_detail_page.dart`) — the Phase 6 ruling 17 precedent.
6. **The dictionary format assumptions are unverified against a real reference-app export** — the reader is permissive by design; see the checklist item below.

- [ ] **Step 5: Add the hardware-checklist items**

In `docs/hardware-checklist.md`, append to an existing H3 section (do **not** add a second section with a name already in the file — Phase 6 ruling 19; `grep -n '^## ' docs/hardware-checklist.md` first):

- [ ] Import a dictionary exported from the real reference app and confirm every key lands (the JSON field names are inferred, not documented).
- [ ] With a real device: change the animation mode, save, power-cycle, and confirm the change survived (SAVE_SETTINGS is the only thing that makes a setting durable).
- [ ] Set a button function and confirm the physical button does it.
- [ ] Set the sleep timeout to 5 s and confirm the device sleeps on that schedule.
- [ ] Enable BLE pairing, save, reboot, and confirm: the device demands the passkey, is invisible to a host that has not bonded (spec 5.1), and "Forget paired hosts" makes it visible again.
- [ ] Read a MIFARE Classic card with a custom key list selected and confirm the sectors that list opens are the ones reported (the dictionary reaches `mf1ReadDump` unchanged).

- [ ] **Step 6: Add lessons**

Append to `tasks/lessons.md` whatever this phase actually taught — not a summary of the plan. Candidates only if they happened: a landed name this plan got wrong (and what the executor did about it), a finder that needed scoping, a preference-backed provider whose async load raced a widget test.

- [ ] **Step 7: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git add AGENTS.md docs tasks
git commit -m "$(cat <<'MSG'
close out Phase 9

Record what dictionaries and settings shipped, the decisions taken along
the way, and the device-settings checks only real hardware can prove.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

## Parallelisation

`T1 | T2 ∥ T3 | T4 | T5 ∥ T10 | T6 | T7 | T8 | T9 | T11 | T12 | T13 | T14`

T2 and T3 are file-disjoint once T1 has landed. T10 (the settings controller) touches nothing the dictionaries UI touches and can run beside T5–T9, with one caveat in its own Step 4 about the ARB. Everything from T6 on that appends to `app_en.arb` is serialised by the single-writer rule.
