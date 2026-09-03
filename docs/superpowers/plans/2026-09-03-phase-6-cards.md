# Phase 6: Read, library, editor, import — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Cards feature: read a card off the reader, save it to a searchable library with folders and colours, view and edit its dump through the hex viewer, import the reference app's JSON export, and publish a card picker other features call.

**Architecture:** One feature module, `app/lib/features/cards/`, laid out the way `features/slots/` already is: pure `state/` (models, pure functions, riverpod notifiers) under a layout-only `ui/`, with `cards.dart` as the only import surface. Reading goes through `session.reader` (`ReaderFacade`), which takes its own reader lease per call, so the wakelock rule already landed in `core/lifecycle/wakelock.dart` holds the screen awake with no new code. Storage goes through the `SavedCardsRepository` interface that Phase 4 declared; this phase writes its Drift and in-memory implementations against the `SavedCards` table that already exists at schema version 1, so there is no migration. Import and export are pure functions over JSON strings, tested against a fixture, with the UI a thin sheet on top.

**Tech Stack:** Flutter 3.47.2 / Dart 3.13, riverpod 3.4.2 + riverpod_generator 4.0.8, go_router 18, Drift 2.34, `material_ui` 1.1.1, `package:spectra_ui`, `package:chameleon` (the SDK's `ReaderFacade`, `DumpFormats`, `MifareGeometry`, `FakeDevice`).

**Spec:** `docs/superpowers/specs/2026-09-02-spectra-design.md` (sections 3.5, 6.2, 7.3, 7.7 steps 3-4, 8.3-8.6, 9). Roadmap row: `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md`, Phase 6.

## Global Constraints

Every task's requirements implicitly include this section.

- Toolchain: Flutter 3.47.2 / Dart 3.13, pinned by `mise.toml`. On this Mac `mise x --` is not enough, because fvm's Dart precedes it on PATH. Prefix every shell command that runs `dart`, `flutter` or `melos` with:
  `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"`
- TDD for every task: failing test, run it and watch it fail, minimal code, run it and watch it pass, commit. Commit messages: imperative subject, short body explaining why, trailer:
  ```
  Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
  ```
- `dart run melos run check:all` must be green at every commit. Foreground test runs only — never background a test command.
- This is a git worktree. Never use bare `git stash`.
- Generated code (riverpod_generator, drift, freezed) is committed. After adding or changing an `@riverpod` provider or a Drift table use, run `cd app && dart run build_runner build --delete-conflicting-outputs` and commit the `.g.dart` files. `tool/check_codegen.sh` must pass.
- Package boundaries are enforced by `tool/dep_lint.dart` (`dart run melos run lint:deps`): `app/lib/features/*` may not import another feature's internals (only `features/<x>/<x>.dart`), may not import `package:flutter/material.dart`, and may not import Drift outside `lib/data/`. Nothing outside `chameleon` may import `package:chameleon/src/...`.
- **`material_ui` only** under `app/lib/features/**` — `import 'package:material_ui/material_ui.dart';`, and write `hide ConnectionState` on any features file that also imports `package:chameleon/chameleon.dart` (both libraries declare that name). `package:flutter/services.dart` (for `Clipboard`) and `package:flutter/foundation.dart` are fine.
- All user-facing copy goes through `app/lib/l10n/app_en.arb` and `flutter gen-l10n`. The string-literal lint (`tool/src/string_rules.dart`) scans `lib/features/*/ui/` at any depth; `state/` is out of scope. **Technical field names are exempt** the way tag-type product names already are in `features/slots/state/slot_labels.dart`: `DumpField` labels come from the SDK's own `describe()` ('UID', 'SAK', 'ATQA', 'Sectors'), are the names printed in every RFID tool, and are not copy a translator would change.
- **The ARB is a single-writer resource** (Phase 5 ruling 14). Tasks that append to `app_en.arb` are serialised: never run two of them concurrently. Each such task runs `cd app && flutter gen-l10n` and commits the regenerated `app/lib/l10n/app_localizations*.dart` alongside its ARB edit.
- Riverpod 3.4.2 API notes:
  - `Override` and `ProviderListenable` come from `package:flutter_riverpod/misc.dart`, not the main library.
  - There is no `valueOrNull`. Use `.value` on an `AsyncValue` (null while loading).
  - Do not read `state` inside `ref.onDispose` — the element is already torn down. Mirror what you need in a field.
  - `Notifier.state` is `@visibleForTesting @protected`; assigning it from a test is an analyzer warning and `melos run analyze` fails on warnings. A notifier that needs a test to force a failure ships `@visibleForTesting void debugFail(Object error)` (Phase 5 ruling 3).
  - `@riverpod` is autoDispose. **Ruling 20 (Phase 4):** an autoDispose stream/async provider read or awaited outside a mounted app needs a listener held first — call the harness's `keepAlive(tester, provider)`, pump a few frames, then `readProvider(tester, provider)` or `readProvider(tester, provider.notifier)`.
  - **Ruling 22 (Phase 5):** `FakeDevice` replies via a real `Timer`, so a test must *start* the operation, *pump*, then *await* it: `final Future<void> f = controller.readHf(); await tester.pump(const Duration(milliseconds: 50)); await f;` — never `await` before pumping.
- **Drop, do not queue** (the `SlotEditor` pattern): a controller that mutates the device or the database guards re-entry with a plain `bool _inFlight` field, distinct from `state.isLoading`, and the screen disables its controls while busy so a dropped call is never the only thing between a tap and the change it was meant to make.
- A new `DeviceSession` is constructed per connect attempt; sessions are single-use and spent after a terminal close. Tests pass `transport: (_) => FakeDevice()` — a fresh fake per attempt.
- Every feature's barrel (`features/<x>/<x>.dart`) is its only import surface. Phase 6 consumes `features/slots/slots.dart` (`showSlotPicker`) and publishes `features/cards/cards.dart` (`showCardPicker`).
- Never claim hardware behaviour works. Reading a **real** card is `hardware-validate`: it is proven only against `FakeDevice` here, and the corresponding checks go into `docs/hardware-checklist.md` H1 and H3.
- Cite landed source for every name you use. If a symbol in this plan does not match the landed code, the landed code wins — report it rather than inventing an adapter.

## File structure

New, under `app/lib/features/cards/`:

| File | Responsibility |
|---|---|
| `state/hex.dart` | `toHex` / `parseHex`, the only hex string conversion in the app |
| `state/card_codec.dart` | `SavedCard.tagType` (a `String`) ↔ `TagType`; parse/describe/validate a saved card through `DumpFormats` |
| `state/default_keys.dart` | The built-in MIFARE Classic key list Phase 9's dictionaries will replace |
| `state/read_state.dart` | `ReadState`, `CardReadResult`, `classicTypeForSak` — pure |
| `state/read_controller.dart` | `CardReader` notifier: scan HF/LF, dump, progress, cancel |
| `state/saved_cards_provider.dart` | `savedCardsProvider` stream + `CardLibrary` notifier (add/update/remove/import) |
| `state/cards_filter.dart` | `CardsFilter`, `CardsSort`, `filterCards` (pure) + `cardsFilterProvider` |
| `state/card_editor_controller.dart` | `CardEditor` family notifier: load, edit a chunk, dirty flag, save, delete |
| `state/card_import.dart` | Reference-app and Spectra JSON parse/export — pure |
| `ui/read_page.dart` | `/cards/read`: idle, scanning, progress+cancel, result, error |
| `ui/save_card_sheet.dart` | Name / folder / colour, writes through `CardLibrary.add` |
| `ui/cards_page.dart` | The library list: search, folder filter, sort |
| `ui/card_detail_page.dart` | `/cards/:id`: fields, hex viewer, editor, delete, export |
| `ui/card_hex_editor.dart` | The chunk editor (block/page/id) with validation |
| `ui/card_import_sheet.dart` | Paste-JSON import |
| `ui/card_picker.dart` | **Public API:** `showCardPicker` / `CardPicker` |
| `ui/cards_problem_view.dart` | Spec 9 error rendering for this feature |
| `cards.dart` | The barrel: the feature's whole public surface |

New elsewhere:

| File | Responsibility |
|---|---|
| `app/lib/data/database/drift_saved_cards_repository.dart` | `SavedCardsRepository` over the `SavedCards` table |
| `app/lib/core/emulator/demo_cards.dart` | The cards the emulated device's reader "sees" (spec 7.5) |
| `app/test/fixtures/reference_card_mifare_mini.json` | The reference-app export fixture the gate imports |

Modified: `app/lib/data/memory/in_memory_repositories.dart`, `app/lib/data/repository_providers.dart`, `app/lib/core/routing/routes.dart`, `app/lib/core/routing/app_sections.dart`, `app/lib/core/session/sessions.dart`, `app/lib/l10n/app_en.arb`.

---

### Task 1: The saved-cards repository

Spec 7.3 gives storage one Drift database behind repository interfaces. `SavedCardsRepository` and the `SavedCards` table both landed in Phase 4 with no implementation; this task fills that in, so every later task has a real place to put a card.

**Files:**
- Create: `app/lib/data/database/drift_saved_cards_repository.dart`
- Modify: `app/lib/data/memory/in_memory_repositories.dart`, `app/lib/data/repository_providers.dart`
- Test: `app/test/data/saved_cards_repository_test.dart`

**Interfaces:**
- Consumes: `SavedCardsRepository` (`app/lib/data/repositories.dart`) with `all()`, `byId(String)`, `save(SavedCard)`, `delete(String)`, `watchAll()`; `SavedCard({required String id, required String name, required String tagType, required Uint8List bytes, required DateTime updatedAt, String? folder, int? color})` (`app/lib/data/models/saved_card.dart`); `SpectraDatabase` and its generated `savedCards` table / `SavedCardRow` data class (`app/lib/data/database/spectra_database.dart`, `tables.dart`); `SpectraDatabase.memory()`.
- Produces, frozen for Tasks 5-13:
  - `final class DriftSavedCardsRepository implements SavedCardsRepository` with `DriftSavedCardsRepository(SpectraDatabase db)`.
  - `final class InMemorySavedCardsRepository implements SavedCardsRepository` with a zero-argument constructor.
  - `@Riverpod(keepAlive: true) SavedCardsRepository savedCardsRepository(Ref ref)` → generated `savedCardsRepositoryProvider`, exported from `app/lib/data/data.dart` via the existing `export 'repository_providers.dart';`.
  - Ordering contract: `all()` and `watchAll()` return newest-updated first.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/data/saved_cards_repository_test.dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/data/database/drift_saved_cards_repository.dart';
import 'package:spectra/data/database/spectra_database.dart';
import 'package:spectra/data/memory/in_memory_repositories.dart';

SavedCard card(String id, {String name = 'Card', int day = 1}) => SavedCard(
  id: id,
  name: name,
  tagType: 'mifare1k',
  bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
  updatedAt: DateTime.utc(2026, 9, day),
  folder: 'Work',
  color: 0xFF4488FF,
);

void main() {
  for (final (String label, SavedCardsRepository Function() make) in <
    (String, SavedCardsRepository Function())
  >[
    ('drift', () {
      final SpectraDatabase db = SpectraDatabase.memory();
      addTearDown(db.close);
      return DriftSavedCardsRepository(db);
    }),
    ('in memory', InMemorySavedCardsRepository.new),
  ]) {
    group(label, () {
      test('saves, reads back and deletes a card', () async {
        final SavedCardsRepository repo = make();
        await repo.save(card('a', name: 'Office badge'));

        final SavedCard? read = await repo.byId('a');
        expect(read, isNotNull);
        expect(read!.name, 'Office badge');
        expect(read.tagType, 'mifare1k');
        expect(read.bytes, <int>[1, 2, 3, 4]);
        expect(read.folder, 'Work');
        expect(read.color, 0xFF4488FF);

        await repo.delete('a');
        expect(await repo.byId('a'), isNull);
        expect(await repo.all(), isEmpty);
      });

      test('saving the same id twice replaces the row', () async {
        final SavedCardsRepository repo = make();
        await repo.save(card('a', name: 'First'));
        await repo.save(card('a', name: 'Second'));
        expect(await repo.all(), hasLength(1));
        expect((await repo.byId('a'))!.name, 'Second');
      });

      test('all() is newest-updated first', () async {
        final SavedCardsRepository repo = make();
        await repo.save(card('old', name: 'Old', day: 1));
        await repo.save(card('new', name: 'New', day: 9));
        expect(
          (await repo.all()).map((SavedCard c) => c.id),
          <String>['new', 'old'],
        );
      });

      test('watchAll() emits the current rows and then every change', () async {
        final SavedCardsRepository repo = make();
        await repo.save(card('a'));
        final Stream<List<SavedCard>> stream = repo.watchAll();
        final Future<List<List<SavedCard>>> collected = stream.take(2).toList();
        await repo.save(card('b'));
        final List<List<SavedCard>> emissions = await collected;
        expect(emissions.first.map((SavedCard c) => c.id), <String>['a']);
        expect(
          emissions.last.map((SavedCard c) => c.id).toSet(),
          <String>{'a', 'b'},
        );
      });
    });
  }
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/data/saved_cards_repository_test.dart
```

Expected: FAIL — `DriftSavedCardsRepository` and `InMemorySavedCardsRepository` do not exist.

- [ ] **Step 3: Write the Drift implementation**

```dart
// app/lib/data/database/drift_saved_cards_repository.dart
import 'package:drift/drift.dart';

import '../models/saved_card.dart';
import '../repositories.dart';
import 'spectra_database.dart';

/// Saved card dumps over the `SavedCards` table (spec 7.3). The table landed
/// at schema version 1 in Phase 4, so this needs no migration.
///
/// Rows come back newest-updated first: the library's default sort, and the
/// order a picker wants when it opens.
final class DriftSavedCardsRepository implements SavedCardsRepository {
  DriftSavedCardsRepository(this._db);
  final SpectraDatabase _db;

  @override
  Future<List<SavedCard>> all() async =>
      (await _newestFirst().get()).map(_toModel).toList();

  @override
  Future<SavedCard?> byId(String id) async {
    final SavedCardRow? row = await (_db.select(
      _db.savedCards,
    )..where(($SavedCardsTable t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toModel(row);
  }

  @override
  Future<void> save(SavedCard card) => _db
      .into(_db.savedCards)
      .insertOnConflictUpdate(
        SavedCardRow(
          id: card.id,
          name: card.name,
          tagType: card.tagType,
          bytes: card.bytes,
          folder: card.folder,
          color: card.color,
          updatedAt: card.updatedAt,
        ),
      );

  @override
  Future<void> delete(String id) => (_db.delete(
    _db.savedCards,
  )..where(($SavedCardsTable t) => t.id.equals(id))).go();

  @override
  Stream<List<SavedCard>> watchAll() =>
      _newestFirst().watch().map((List<SavedCardRow> rows) => rows.map(_toModel).toList());

  SimpleSelectStatement<$SavedCardsTable, SavedCardRow> _newestFirst() =>
      _db.select(_db.savedCards)
        ..orderBy(<OrderClauseGenerator<$SavedCardsTable>>[
          ($SavedCardsTable t) => OrderingTerm.desc(t.updatedAt),
        ]);

  SavedCard _toModel(SavedCardRow row) => SavedCard(
    id: row.id,
    name: row.name,
    tagType: row.tagType,
    bytes: row.bytes,
    updatedAt: row.updatedAt,
    folder: row.folder,
    color: row.color,
  );
}
```

Note: the generated table class is `$SavedCardsTable` (drift prefixes table classes with `$`). If the generated name in `spectra_database.g.dart` differs, use whatever is generated — check with `grep -n 'class \$' app/lib/data/database/spectra_database.g.dart`. The simplest way to stay honest is to let the closures infer: `..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])` and `..where((t) => t.id.equals(id))` both type-infer, so the explicit annotations above may be dropped if `analyze` prefers it.

- [ ] **Step 4: Write the in-memory implementation**

Append to `app/lib/data/memory/in_memory_repositories.dart` (it already imports `dart:async` and `../repositories.dart`; add `import '../models/saved_card.dart';` to the existing import block):

```dart
/// A [SavedCardsRepository] with no database behind it, for unit tests that
/// are about something else (spec 8.6). Same ordering contract as the Drift
/// one: newest-updated first.
final class InMemorySavedCardsRepository implements SavedCardsRepository {
  final Map<String, SavedCard> _rows = <String, SavedCard>{};
  final StreamController<List<SavedCard>> _changes =
      StreamController<List<SavedCard>>.broadcast();

  @override
  Future<List<SavedCard>> all() async => _sorted();

  @override
  Future<SavedCard?> byId(String id) async => _rows[id];

  @override
  Future<void> save(SavedCard card) async {
    _rows[card.id] = card;
    _emit();
  }

  @override
  Future<void> delete(String id) async {
    _rows.remove(id);
    _emit();
  }

  @override
  Stream<List<SavedCard>> watchAll() async* {
    yield _sorted();
    yield* _changes.stream;
  }

  List<SavedCard> _sorted() => _rows.values.toList()
    ..sort((SavedCard a, SavedCard b) => b.updatedAt.compareTo(a.updatedAt));

  void _emit() {
    if (!_changes.isClosed) _changes.add(_sorted());
  }
}
```

- [ ] **Step 5: Add the provider**

Append to `app/lib/data/repository_providers.dart`, and add
`import 'database/drift_saved_cards_repository.dart';` to its import block:

```dart
@Riverpod(keepAlive: true)
SavedCardsRepository savedCardsRepository(Ref ref) =>
    DriftSavedCardsRepository(ref.watch(databaseProvider));
```

- [ ] **Step 6: Regenerate, run the tests and watch them pass**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && dart run build_runner build --delete-conflicting-outputs
flutter test test/data
cd .. && dart run melos run check:all
```

Expected: PASS, `check:all` green.

- [ ] **Step 7: Commit**

```bash
git add app/lib/data app/test/data/saved_cards_repository_test.dart
git commit -m "feat(data): implement the saved-cards repository

Spec 7.3's card library needs a place to put a dump; the interface and the
table landed in Phase 4 with nothing behind them. Both implementations share
one ordering contract so the library list and the picker agree.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: Hex, the tag-type codec, and the default key list

Pure helpers the rest of the phase leans on. `SavedCard.tagType` is a `String` on the wire to Drift; everything above it wants a `TagType`. `DumpFormats` (spec 3.5) already knows how to parse, describe and validate; this is the adapter from a stored row to that.

**Files:**
- Create: `app/lib/features/cards/state/hex.dart`, `app/lib/features/cards/state/card_codec.dart`, `app/lib/features/cards/state/default_keys.dart`
- Test: `app/test/features/cards/card_codec_test.dart`

**Interfaces:**
- Consumes: `TagType`, `TagFamily`, `DumpFormats.forType(TagType)` → `DumpFormat<CardDump>?`, `DumpFormats.parse(Uint8List, TagType)`, `DumpFormats.ultralightPageCount(TagType)`, `DumpField(String label, String value)`, `MifareGeometry.blockCount/sectorCount/trailerOf/firstBlockOf/blocksInSector`, `CardDump` — all from `package:chameleon/chameleon.dart`. `SavedCard` from `package:spectra/data/data.dart`.
- Produces, frozen for Tasks 3-13:
  - `String toHex(List<int> bytes, {String separator = ''})` — upper case.
  - `Uint8List? parseHex(String text)` — null when the text is not an even-length run of hex digits (whitespace and `:` separators are stripped first).
  - `TagType tagTypeFromName(String name)` — `TagType.undefined` when unknown.
  - `String tagTypeName(TagType type)` — `type.name`, the string stored in `SavedCard.tagType`.
  - `CardDump? parseSavedCard(SavedCard card)` — null when the type has no `DumpFormat` or parsing throws.
  - `List<DumpField> describeSavedCard(SavedCard card)` — empty when there is no format.
  - `List<String> validateSavedCard(SavedCard card)` — problems; empty means valid; `['unsupported tag type']` when the type has no format.
  - `int chunkSizeFor(TagType type)` — 16 for MIFARE Classic, 4 for Ultralight, 5 for EM410x, 0 for anything else (meaning "not editable").
  - `int chunkCountFor(TagType type, int byteLength)` — `byteLength ~/ chunkSizeFor(type)`, 0 when the size is 0.
  - `List<Uint8List> defaultMifareKeys()` — fresh copies, so a caller mutating one cannot poison the list.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/cards/card_codec_test.dart
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/features/cards/state/card_codec.dart';
import 'package:spectra/features/cards/state/default_keys.dart';
import 'package:spectra/features/cards/state/hex.dart';

SavedCard mini({Uint8List? bytes}) {
  final Uint8List blocks = bytes ?? Uint8List(20 * 16);
  if (bytes == null) {
    blocks.setRange(0, 4, <int>[0xDE, 0xAD, 0xBE, 0xEF]);
    blocks[4] = 0x22; // BCC of DE AD BE EF
  }
  return SavedCard(
    id: 'a',
    name: 'Mini',
    tagType: 'mifareMini',
    bytes: blocks,
    updatedAt: DateTime.utc(2026, 9, 3),
  );
}

void main() {
  group('hex', () {
    test('round-trips bytes', () {
      expect(toHex(<int>[0x0A, 0xFF]), '0AFF');
      expect(toHex(<int>[0x0A, 0xFF], separator: ' '), '0A FF');
      expect(parseHex('0aff'), <int>[0x0A, 0xFF]);
      expect(parseHex('0A FF'), <int>[0x0A, 0xFF]);
      expect(parseHex('0A:FF'), <int>[0x0A, 0xFF]);
    });

    test('rejects odd length and non-hex', () {
      expect(parseHex('0AF'), isNull);
      expect(parseHex('zz'), isNull);
      expect(parseHex(''), isEmpty);
    });
  });

  group('tag type names', () {
    test('round-trip through the stored string', () {
      expect(tagTypeName(TagType.mifare1k), 'mifare1k');
      expect(tagTypeFromName('mifare1k'), TagType.mifare1k);
      expect(tagTypeFromName('em410x'), TagType.em410x);
      expect(tagTypeFromName('nonsense'), TagType.undefined);
    });
  });

  group('saved card through the dump formats', () {
    test('describes a MIFARE Classic Mini', () {
      final List<DumpField> fields = describeSavedCard(mini());
      expect(
        fields.map((DumpField f) => f.label),
        containsAll(<String>['UID', 'Sectors']),
      );
      expect(
        fields.firstWhere((DumpField f) => f.label == 'UID').value,
        'DEADBEEF',
      );
    });

    test('validates length and BCC', () {
      expect(validateSavedCard(mini()), isEmpty);
      final Uint8List broken = Uint8List(20 * 16);
      broken.setRange(0, 4, <int>[0xDE, 0xAD, 0xBE, 0xEF]);
      broken[4] = 0x00;
      expect(validateSavedCard(mini(bytes: broken)), isNotEmpty);
    });

    test('an unsupported type is a problem, not a crash', () {
      final SavedCard seos = SavedCard(
        id: 'b',
        name: 'SEOS',
        tagType: 'seos',
        bytes: Uint8List(4),
        updatedAt: DateTime.utc(2026, 9, 3),
      );
      expect(parseSavedCard(seos), isNull);
      expect(describeSavedCard(seos), isEmpty);
      expect(validateSavedCard(seos), <String>['unsupported tag type']);
    });
  });

  group('chunking', () {
    test('one chunk is a block, a page or the whole LF id', () {
      expect(chunkSizeFor(TagType.mifare1k), 16);
      expect(chunkSizeFor(TagType.ntag215), 4);
      expect(chunkSizeFor(TagType.em410x), 5);
      expect(chunkSizeFor(TagType.seos), 0);
      expect(chunkCountFor(TagType.mifare1k, 64 * 16), 64);
      expect(chunkCountFor(TagType.seos, 16), 0);
    });
  });

  test('the default key list starts with the transport key', () {
    final List<Uint8List> keys = defaultMifareKeys();
    expect(keys.first, <int>[0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
    expect(keys.every((Uint8List k) => k.length == 6), isTrue);
    // Fresh copies: mutating one must not change the next call's list.
    keys.first[0] = 0;
    expect(defaultMifareKeys().first[0], 0xFF);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/cards/card_codec_test.dart
```

Expected: FAIL — none of the three files exist.

- [ ] **Step 3: Write `hex.dart`**

```dart
// app/lib/features/cards/state/hex.dart
import 'dart:typed_data';

/// Bytes as upper-case hex. The one hex formatter in the app: the SDK keeps
/// its own `hexOf` internal (see `package:chameleon`'s library directive),
/// so this is the app's copy rather than a reach into `src/`.
String toHex(List<int> bytes, {String separator = ''}) => bytes
    .map((int b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
    .join(separator);

final RegExp _notHexSeparator = RegExp(r'[\s:_-]');
final RegExp _hexOnly = RegExp(r'^[0-9a-fA-F]*$');

/// Parses a hex string, tolerating spaces, colons, underscores and dashes.
/// Returns null when the text is not an even-length run of hex digits, so a
/// caller validates by checking for null rather than catching.
Uint8List? parseHex(String text) {
  final String cleaned = text.replaceAll(_notHexSeparator, '');
  if (cleaned.length.isOdd) return null;
  if (!_hexOnly.hasMatch(cleaned)) return null;
  final Uint8List out = Uint8List(cleaned.length ~/ 2);
  for (int i = 0; i < out.length; i++) {
    out[i] = int.parse(cleaned.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}
```

- [ ] **Step 4: Write `card_codec.dart`**

```dart
// app/lib/features/cards/state/card_codec.dart
import 'package:chameleon/chameleon.dart';

import '../../../data/data.dart';

/// A stored [SavedCard] seen through the SDK's dump formats (spec 3.5).
///
/// `SavedCard.tagType` is a plain `String` because the data layer stores a
/// column, not an enum. This file is the only place that string becomes a
/// [TagType] again, so a rename of the enum is one edit, not a search.

/// The string stored in `SavedCard.tagType`.
String tagTypeName(TagType type) => type.name;

/// The inverse of [tagTypeName]. An unknown string is [TagType.undefined]
/// rather than a throw: a row written by a future version of Spectra must
/// not make the library unopenable.
TagType tagTypeFromName(String name) {
  for (final TagType t in TagType.values) {
    if (t.name == name) return t;
  }
  return TagType.undefined;
}

/// The parsed dump, or null when this type has no [DumpFormat] (spec 3.5
/// covers MIFARE Classic, Ultralight and EM410x) or the bytes do not parse.
CardDump? parseSavedCard(SavedCard card) {
  final TagType type = tagTypeFromName(card.tagType);
  if (DumpFormats.forType(type) == null) return null;
  try {
    return DumpFormats.parse(card.bytes, type);
  } on Object {
    return null;
  }
}

/// The dump's headline fields, for the detail screen. Empty when the type
/// has no format.
///
/// The labels come from the SDK's own `describe()` ('UID', 'SAK', 'ATQA',
/// 'Sectors'): technical field names printed by every RFID tool, exempt from
/// localization the same way tag-type product names are in
/// `features/slots/state/slot_labels.dart`.
List<DumpField> describeSavedCard(SavedCard card) {
  final TagType type = tagTypeFromName(card.tagType);
  final DumpFormat<CardDump>? format = DumpFormats.forType(type);
  final CardDump? dump = parseSavedCard(card);
  if (format == null || dump == null) return const <DumpField>[];
  return format.describe(dump);
}

/// Problems with the stored bytes, empty when the card is valid.
List<String> validateSavedCard(SavedCard card) {
  final TagType type = tagTypeFromName(card.tagType);
  final DumpFormat<CardDump>? format = DumpFormats.forType(type);
  if (format == null) return const <String>['unsupported tag type'];
  final CardDump? dump = parseSavedCard(card);
  if (dump == null) return const <String>['the bytes could not be parsed'];
  return format.validate(dump);
}

/// The unit the editor edits: a MIFARE Classic block, an Ultralight page, or
/// the whole EM410x id. Zero means "this type is not editable".
int chunkSizeFor(TagType type) => switch (type.family) {
  TagFamily.mifareClassic => 16,
  TagFamily.ultralight => 4,
  TagFamily.lf => type == TagType.em410x ? 5 : 0,
  _ => 0,
};

/// How many chunks [byteLength] bytes of [type] hold.
int chunkCountFor(TagType type, int byteLength) {
  final int size = chunkSizeFor(type);
  return size == 0 ? 0 : byteLength ~/ size;
}
```

- [ ] **Step 5: Write `default_keys.dart`**

```dart
// app/lib/features/cards/state/default_keys.dart
import 'dart:typed_data';

/// The MIFARE Classic keys a read tries before giving up.
///
/// Phase 9 replaces this with `DictionariesRepository` (spec 7.3): the
/// reader facade already takes its keys as a parameter
/// (`ReaderFacade.mf1ReadDump(candidateKeys: …)`, spec 8.1), so swapping the
/// source is a one-line change at the call site in `read_controller.dart`
/// and nothing else moves.
///
/// The transport key every blank card ships with comes first, because it
/// opens the majority of cards in one chunk of
/// MF1_CHECK_KEYS_OF_SECTORS and the facade stops as soon as every sector is
/// solved.
const List<String> defaultMifareKeyHex = <String>[
  'FFFFFFFFFFFF',
  'A0A1A2A3A4A5',
  'D3F7D3F7D3F7',
  '000000000000',
  'B0B1B2B3B4B5',
  '4D3A99C351DD',
  '1A982C7E459A',
  'AABBCCDDEEFF',
  '714C5C886E97',
  '587EE5F9350F',
  'A0478CC39091',
  '533CB6C723F6',
  '8FD0A4F256E9',
];

/// Fresh copies each call, so a caller mutating a key cannot poison the
/// next read's dictionary.
List<Uint8List> defaultMifareKeys() => <Uint8List>[
  for (final String hex in defaultMifareKeyHex)
    Uint8List.fromList(<int>[
      for (int i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ]),
];
```

- [ ] **Step 6: Run the tests and watch them pass**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/cards/card_codec_test.dart
cd .. && dart run melos run check:all
```

Expected: PASS, `check:all` green.

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/cards/state app/test/features/cards
git commit -m "feat(cards): add hex, tag-type and dump-format helpers

Everything above the data layer wants a TagType, but a stored card carries a
string; this is the one place that conversion happens, and the one place the
SDK's DumpFormats are reached from the app.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: The read controller

Spec 7.7 step 3: "scan HF and LF, show identity and detail, read full dump where supported". The device work all happens through `session.reader`, which takes its own reader lease per call (spec 4.3, 8.1) — so the wakelock rule in `core/lifecycle/wakelock.dart` (`sessionNeedsWakelock` → `session.readerLeaseCount > 0 || session.isBusy`) already holds the screen awake for the whole dump with no code here.

**Files:**
- Create: `app/lib/features/cards/state/read_state.dart`, `app/lib/features/cards/state/read_controller.dart`
- Test: `app/test/features/cards/read_controller_test.dart`

**Interfaces:**
- Consumes: `ReaderFacade` (`session.reader`) with `Future<List<Hf14aTag>> scan14a()`, `Future<bool> detectMf1Support()`, `Future<Mf1DumpReadResult> mf1ReadDump({required TagType type, required List<Uint8List> candidateKeys, void Function(int done, int total)? onProgress, CancelToken? cancel})`, `Future<Uint8List?> scanEm410x()`; `Mf1DumpReadResult` with `blocks`, `readMask`, `keys`, `blockCount`, `readBlockCount`, `isComplete`; `Hf14aTag(uid, atqa, sak, ats)`; `SectorKeys(sector, keyA, keyB)`; `CancelToken` with `cancel()`/`isCancelled`; errors `HfTagNotFound()`, `LfTagNotFound()`, `CommandCancelled()`, `SessionNotReady(String)`; `DumpFormats`, `DumpField`, `MifareGeometry`. `activeSessionProvider` → `ActiveSession?` with `.session` (`app/lib/core/session/active_device.dart`, `active_session.dart`). Task 2's `toHex`, `describeSavedCard`-style use of `DumpFormats`, `defaultMifareKeys()`.
- Produces, frozen for Tasks 4, 5 and 13:
  - `final class CardReadResult` — `const CardReadResult({required TagType tagType, required Uint8List bytes, required List<DumpField> fields, this.readChunks, this.totalChunks, this.keysFound})`, plus `factory CardReadResult.identity(Hf14aTag tag)`, `bool get canSave`, `bool get isPartial`.
  - `final class ReadState` — `const ReadState({this.busy = false, this.progress, this.result, this.error})`; no `copyWith` (every transition constructs a whole new state, so there is no sentinel to get wrong).
  - `TagType classicTypeForSak(int sak)`.
  - `@riverpod class CardReader extends _$CardReader` with `ReadState build()`, `Future<void> readHf()`, `Future<void> readLf()`, `void cancel()`, `void reset()` → generated `cardReaderProvider`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/cards/read_controller_test.dart
import 'dart:typed_data';
import 'dart:ui';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/features/cards/state/read_controller.dart';
import 'package:spectra/features/cards/state/read_state.dart';

import '../../support/app_harness.dart';

FakeDevice deviceWith({bool hf = true, bool lf = false}) {
  final FakeFirmware firmware = FakeFirmware();
  if (hf) {
    firmware.present(
      FakeMf1Card.classic1k(uid: Uint8List.fromList(<int>[0xDE, 0xAD, 0xBE, 0xEF])),
    );
  }
  if (lf) {
    firmware.present(
      FakeLfCard(3000, Uint8List.fromList(<int>[0x12, 0x34, 0x56, 0x78, 0x9A])),
    );
  }
  return FakeDevice(firmware: firmware);
}

void main() {
  Future<CardReader> connected(WidgetTester tester, FakeDevice device) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpTestApp(tester, transport: (_) => device);
    await connectToEmulator(tester);
    keepAlive(tester, cardReaderProvider);
    return readProvider(tester, cardReaderProvider.notifier);
  }

  testWidgetsApp('a MIFARE Classic read comes back complete', (tester) async {
    final CardReader reader = await connected(tester, deviceWith());

    // Ruling 22: start, pump, then await — the fake replies on a real timer.
    final Future<void> run = reader.readHf();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await run;

    final ReadState state = readProvider(tester, cardReaderProvider);
    expect(state.busy, isFalse);
    expect(state.error, isNull);
    final CardReadResult result = state.result!;
    expect(result.tagType, TagType.mifare1k);
    expect(result.bytes, hasLength(64 * 16));
    expect(result.canSave, isTrue);
    expect(result.isPartial, isFalse);
    expect(result.totalChunks, 64);
    expect(result.readChunks, 64);
    expect(result.keysFound, 16);
    expect(
      result.fields.firstWhere((DumpField f) => f.label == 'UID').value,
      'DEADBEEF',
    );
  });

  testWidgetsApp('no card in the field is a typed error, not a crash', (
    tester,
  ) async {
    final CardReader reader = await connected(tester, deviceWith(hf: false));

    final Future<void> run = reader.readHf();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await run;

    final ReadState state = readProvider(tester, cardReaderProvider);
    expect(state.busy, isFalse);
    expect(state.result, isNull);
    expect(state.error, isA<HfTagNotFound>());
  });

  testWidgetsApp('an EM410x read returns the five id bytes', (tester) async {
    final CardReader reader = await connected(
      tester,
      deviceWith(hf: false, lf: true),
    );

    final Future<void> run = reader.readLf();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await run;

    final CardReadResult result =
        readProvider(tester, cardReaderProvider).result!;
    expect(result.tagType, TagType.em410x);
    expect(result.bytes, <int>[0x12, 0x34, 0x56, 0x78, 0x9A]);
    expect(result.canSave, isTrue);
    expect(
      result.fields.single.value,
      '123456789A',
      reason: "Em410xFormat.describe emits one 'ID' field",
    );
  });

  testWidgetsApp('no LF card is a typed error', (tester) async {
    final CardReader reader = await connected(tester, deviceWith(hf: false));

    final Future<void> run = reader.readLf();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await run;

    expect(
      readProvider(tester, cardReaderProvider).error,
      isA<LfTagNotFound>(),
    );
  });

  testWidgetsApp('cancelling a dump ends in CommandCancelled', (tester) async {
    final FakeDevice device = deviceWith();
    device.latency = const Duration(milliseconds: 5);
    final CardReader reader = await connected(tester, device);

    final Future<void> run = reader.readHf();
    await tester.pump(const Duration(milliseconds: 20));
    reader.cancel();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await run;

    final ReadState state = readProvider(tester, cardReaderProvider);
    expect(state.busy, isFalse);
    expect(state.error, isA<CommandCancelled>());
  });

  testWidgetsApp('a second read while one is running is dropped', (
    tester,
  ) async {
    final FakeDevice device = deviceWith();
    device.latency = const Duration(milliseconds: 2);
    final CardReader reader = await connected(tester, device);

    final Future<void> first = reader.readHf();
    await tester.pump(const Duration(milliseconds: 10));
    final Future<void> second = reader.readHf();
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await first;
    await second;

    expect(
      device.received.where((Frame f) => f.command == 2000).length,
      1,
      reason: 'HF14A_SCAN is 2000; the dropped call sent nothing',
    );
  });

  testWidgetsApp('reset clears the last result', (tester) async {
    final CardReader reader = await connected(tester, deviceWith());
    final Future<void> run = reader.readHf();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await run;
    expect(readProvider(tester, cardReaderProvider).result, isNotNull);

    reader.reset();
    await tester.pump();
    expect(readProvider(tester, cardReaderProvider).result, isNull);
  });

  test('classicTypeForSak maps the four SAK values', () {
    expect(classicTypeForSak(0x09), TagType.mifareMini);
    expect(classicTypeForSak(0x08), TagType.mifare1k);
    expect(classicTypeForSak(0x18), TagType.mifare4k);
    expect(classicTypeForSak(0x88), TagType.mifare1k);
    expect(classicTypeForSak(0x00), TagType.undefined);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/cards/read_controller_test.dart
```

Expected: FAIL — `read_controller.dart` and `read_state.dart` do not exist.

- [ ] **Step 3: Write `read_state.dart`**

```dart
// app/lib/features/cards/state/read_state.dart
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';

import 'hex.dart';

/// What one read got off the card.
///
/// [bytes] is the dump in the layout the matching `DumpFormat` expects
/// (16 bytes per MIFARE Classic block, 4 per Ultralight page, the 5 id bytes
/// for EM410x), so saving is `SavedCard(bytes: result.bytes, …)` with no
/// re-encoding.
final class CardReadResult {
  const CardReadResult({
    required this.tagType,
    required this.bytes,
    required this.fields,
    this.readChunks,
    this.totalChunks,
    this.keysFound,
  });

  /// A tag that answered the anti-collision but whose memory this SDK cannot
  /// read: the identity is worth showing, but there is nothing to save.
  ///
  /// Ultralight is here today. `ReaderFacade` (spec 8.1) has no Ultralight
  /// read operation — `EmulatorFacade.readNtagPages` reads the *device's*
  /// emulation memory, not a card in the field — so a physical NTAG shows its
  /// UID and nothing more until that reader operation is added (spec 8.2's
  /// extension point: one command plus one facade method).
  factory CardReadResult.identity(Hf14aTag tag) => CardReadResult(
    tagType: TagType.hf14a4,
    bytes: Uint8List(0),
    fields: <DumpField>[
      DumpField('UID', toHex(tag.uid)),
      DumpField('ATQA', toHex(tag.atqa)),
      DumpField('SAK', toHex(<int>[tag.sak])),
      if (tag.ats.isNotEmpty) DumpField('ATS', toHex(tag.ats)),
    ],
  );

  final TagType tagType;
  final Uint8List bytes;

  /// Headline fields, from the SDK's `DumpFormat.describe` where there is a
  /// format and from the anti-collision answer otherwise. Labels are the
  /// SDK's technical field names, exempt from localization (see the
  /// plan's Global Constraints).
  final List<DumpField> fields;

  /// Blocks or pages actually read, and how many the card has. Null for a
  /// read with no per-chunk notion (an LF id, an identity-only result).
  final int? readChunks;
  final int? totalChunks;

  /// Sectors a working key was found for, for the MIFARE Classic summary.
  final int? keysFound;

  /// Whether this result can go into the library: there is a dump, and the
  /// type has a `DumpFormat` to read it back with.
  bool get canSave =>
      bytes.isNotEmpty && DumpFormats.forType(tagType) != null;

  /// True when some of the card could not be read — a sector whose key is
  /// not in the dictionary. A normal outcome, not an error (spec 3.5's
  /// `Mf1DumpReadResult` contract).
  bool get isPartial {
    final int? read = readChunks;
    final int? total = totalChunks;
    return read != null && total != null && read < total;
  }
}

/// The read screen's whole state. Deliberately without a `copyWith`: every
/// transition builds a complete new value, so there is no "unchanged versus
/// explicitly null" sentinel to get wrong.
final class ReadState {
  const ReadState({this.busy = false, this.progress, this.result, this.error});

  /// True from the first command until the operation ends, however it ends.
  final bool busy;

  /// 0..1 while a dump is running, null while scanning (the scan has no
  /// meaningful fraction).
  final double? progress;

  final CardReadResult? result;

  /// The typed error the last read ended with, rendered through the spec 9
  /// catalog. Never a string.
  final Object? error;
}

/// The MIFARE Classic type a SAK byte names.
///
/// Bit 3 (0x08) is the "MIFARE Classic compliant" bit and bit 6 (0x40) plus
/// the cascade bit 0x04 carry UID-length and ISO14443-4 information that says
/// nothing about capacity, so the low nibble decides. Anything that is not
/// one of the four known values is [TagType.undefined]; the caller then falls
/// back on `detectMf1Support()` (see `read_controller.dart`).
TagType classicTypeForSak(int sak) => switch (sak & 0x1F) {
  0x09 => TagType.mifareMini,
  0x08 => TagType.mifare1k,
  0x19 => TagType.mifare2k,
  0x18 => TagType.mifare4k,
  _ => TagType.undefined,
};
```

- [ ] **Step 4: Write `read_controller.dart`**

```dart
// app/lib/features/cards/state/read_controller.dart
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/session/active_device.dart';
import '../../../core/session/active_session.dart';
import 'default_keys.dart';
import 'read_state.dart';

part 'read_controller.g.dart';

/// Spec 7.7 step 3: read a card through `session.reader`.
///
/// Every `ReaderFacade` method takes its own reader lease, so the device is
/// in reader mode for exactly as long as the operation runs and back in
/// emulator mode afterwards, including when it throws (spec 4.3). That lease
/// is also what holds the wakelock: `sessionNeedsWakelock`
/// (`core/lifecycle/wakelock.dart`) polls `readerLeaseCount > 0 || isBusy`,
/// and `mf1ReadDump` wraps the whole dump in one lease and one `busy`. There
/// is therefore no wakelock code here, and there must not be.
///
/// Failures stay in [ReadState.error] rather than being thrown, so the screen
/// renders them through the spec 9 catalog instead of catching. "No tag in
/// the field" is the facade's empty result, which this turns into the typed
/// [HfTagNotFound]/[LfTagNotFound] the catalog already has words for.
///
/// A call made while another is in flight is dropped, not queued (`_inFlight`);
/// the screen disables its buttons while `state.busy`.
@riverpod
class CardReader extends _$CardReader {
  @override
  ReadState build() {
    ref.onDispose(() {
      // Not `state` — the element is gone by now (Global Constraints).
      _cancel?.cancel();
      _inFlight = false;
    });
    return const ReadState();
  }

  CancelToken? _cancel;
  bool _inFlight = false;

  /// Scan the 13.56 MHz field, and read the whole card when it is a MIFARE
  /// Classic the firmware can authenticate.
  Future<void> readHf() =>
      _run((ReaderFacade reader, CancelToken cancel) => _readHf(reader, cancel));

  /// Scan the 125 kHz field for an EM410x, the one LF family with a
  /// `DumpFormat` (spec 3.5).
  Future<void> readLf() =>
      _run((ReaderFacade reader, CancelToken cancel) => _readLf(reader));

  /// Asks the running read to stop. The SDK has no wire-level cancel, so the
  /// command in flight still runs to completion or timeout before the future
  /// resolves with [CommandCancelled] (spec 4.3's honest contract).
  void cancel() => _cancel?.cancel();

  /// Back to the empty screen, so "Read again" starts clean.
  void reset() => state = const ReadState();

  Future<CardReadResult> _readHf(ReaderFacade reader, CancelToken cancel) async {
    final List<Hf14aTag> tags = await reader.scan14a();
    if (tags.isEmpty) throw const HfTagNotFound();
    final Hf14aTag tag = tags.first;

    if (!await reader.detectMf1Support()) {
      return CardReadResult.identity(tag);
    }
    // A SAK the table does not know, on a card that authenticates: 1K is the
    // safe guess — it is the most common card by a wide margin, and a wrong
    // guess costs a partial dump, not a failure.
    final TagType guessed = classicTypeForSak(tag.sak);
    final TagType type = guessed == TagType.undefined
        ? TagType.mifare1k
        : guessed;

    state = const ReadState(busy: true, progress: 0);
    final Mf1DumpReadResult dump = await reader.mf1ReadDump(
      type: type,
      candidateKeys: defaultMifareKeys(),
      onProgress: (int done, int total) {
        if (!_inFlight) return;
        state = ReadState(busy: true, progress: total == 0 ? null : done / total);
      },
      cancel: cancel,
    );

    final MifareClassicDump parsed =
        DumpFormats.parse(dump.blocks, type) as MifareClassicDump;
    return CardReadResult(
      tagType: type,
      bytes: dump.blocks,
      fields: const MifareClassicFormat().describe(parsed),
      readChunks: dump.readBlockCount,
      totalChunks: dump.blockCount,
      keysFound: dump.keys
          .where((SectorKeys k) => k.keyA != null || k.keyB != null)
          .length,
    );
  }

  Future<CardReadResult> _readLf(ReaderFacade reader) async {
    final Uint8List? id = await reader.scanEm410x();
    if (id == null) throw const LfTagNotFound();
    final Em410xDump parsed =
        DumpFormats.parse(id, TagType.em410x) as Em410xDump;
    return CardReadResult(
      tagType: TagType.em410x,
      bytes: id,
      fields: const Em410xFormat().describe(parsed),
    );
  }

  Future<void> _run(
    Future<CardReadResult> Function(ReaderFacade reader, CancelToken cancel)
    body,
  ) async {
    if (_inFlight) return;
    final ActiveSession? active = ref.read(activeSessionProvider);
    if (active == null) {
      state = const ReadState(error: SessionNotReady('no active session'));
      return;
    }
    _inFlight = true;
    final CancelToken cancel = CancelToken();
    _cancel = cancel;
    state = const ReadState(busy: true);
    try {
      final CardReadResult result = await body(active.session.reader, cancel);
      state = ReadState(result: result);
    } on Object catch (error) {
      state = ReadState(error: error);
    } finally {
      _inFlight = false;
      _cancel = null;
    }
  }
}
```

- [ ] **Step 5: Regenerate, run the tests and watch them pass**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && dart run build_runner build --delete-conflicting-outputs
flutter test test/features/cards/read_controller_test.dart
cd .. && dart run melos run check:all
```

Expected: PASS, `check:all` green.

Note: if `state =` after the notifier is disposed throws in the cancel test (the phase-5 log records that exposure for `SlotEditor` and `ConnectController`), the fix is the `_inFlight` guard already in `onProgress`, not a `try`/`catch` around the assignment — the `_run` body only assigns while `_inFlight` is true and the test holds the provider alive with `keepAlive`.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/cards app/test/features/cards
git commit -m "feat(cards): read a card through the reader facade

Spec 7.7 step 3. The facade owns the lease, so the wakelock rule from
Phase 4 covers the whole dump with no new code; failures stay typed in the
state so the screen can use the spec 9 catalog.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: The read screen and its route

Spec 7.7 step 3's screen: two scan buttons, a progress indicator with a cancel while a dump runs, the identity and detail of what came back, and the spec 9 error card. Spec 7.2 puts it on a deep route pushed on top of the Cards tab, the way `/slots/:index` and `/tools/frame-log` already are.

**Files:**
- Create: `app/lib/features/cards/ui/read_page.dart`, `app/lib/features/cards/ui/cards_problem_view.dart`
- Modify: `app/lib/core/routing/routes.dart`, `app/lib/core/routing/app_sections.dart`, `app/lib/features/cards/ui/cards_page.dart`, `app/lib/features/cards/cards.dart`, `app/lib/l10n/app_en.arb` (**owns the ARB for this task**)
- Test: `app/test/features/cards/read_page_test.dart`

**Interfaces:**
- Consumes: `cardReaderProvider`, `ReadState`, `CardReadResult` (Task 3); `SubPageScaffold({required String title, required Widget body})` (`app/lib/core/routing/sub_page_scaffold.dart`); `AppRoutes.cards`; `ErrorCatalog(l10n).describe(Object)` → `ErrorPresentation(message, recovery, detail)` and `ErrorRecovery` (`app/lib/core/errors/`); `SpectraCard({required Widget child})`, `SpectraButton({required String label, required VoidCallback? onPressed, SpectraButtonVariant variant, IconData? icon, bool busy})`, `SpectraProgressIndicator({required String label, double? value, String? detail, VoidCallback? onCancel})`, `SpectraListTile({required String title, String? subtitle})`, `SpectraSectionHeader({required String title, String? actionLabel, VoidCallback? onAction})`, `SpectraDisclosure({required Widget summary, required Widget detail})`, `SpectraSpacing` (`package:spectra_ui/spectra_ui.dart`); `DumpField(label, value)`.
- Produces, frozen for Tasks 5, 6 and 13:
  - `static const String AppRoutes.cardRead = '$cards/read'` and `static String AppRoutes.card(String id)`.
  - `class ReadPage extends ConsumerWidget` with `const ReadPage({super.key})`, exported from `features/cards/cards.dart`.
  - `class CardsProblemView extends StatelessWidget` with `const CardsProblemView({required Object error, required VoidCallback onDismiss, super.key})`.
  - ARB keys: `cardsReadTitle`, `cardsReadAction`, `cardsReadHint`, `cardsReadHf`, `cardsReadLf`, `cardsReadScanning`, `cardsReadDumping`, `cardsReadAgain`, `cardsReadPartial`, `cardsReadIdentityOnly`, `cardsReadKeysFound`.

- [ ] **Step 1: Rebase onto HEAD first**

Another implementer may be holding `app_en.arb`. Start from the tip:

```bash
git fetch --all && git status --short && git log --oneline -3
```

- [ ] **Step 2: Write the failing test**

```dart
// app/test/features/cards/read_page_test.dart
import 'dart:typed_data';
import 'dart:ui';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/features/cards/cards.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

FakeDevice deviceWithCard({bool present = true}) {
  final FakeFirmware firmware = FakeFirmware();
  if (present) {
    firmware.present(
      FakeMf1Card.classic1k(uid: Uint8List.fromList(<int>[0xDE, 0xAD, 0xBE, 0xEF])),
    );
  }
  return FakeDevice(firmware: firmware);
}

Future<void> pumpFrames(WidgetTester tester, [int frames = 20]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> openRead(WidgetTester tester, FakeDevice device) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpTestApp(tester, transport: (_) => device);
  await connectToEmulator(tester);
  await tester.tap(find.text('Cards').last);
  await pumpFrames(tester, 10);
  await tester.tap(find.text('Read a card'));
  await pumpFrames(tester, 10);
}

void main() {
  testWidgetsApp('the idle screen offers an HF and an LF scan', (tester) async {
    await openRead(tester, deviceWithCard());
    expect(find.byType(ReadPage), findsOneWidget);
    expect(find.text('Scan high frequency'), findsOneWidget);
    expect(find.text('Scan low frequency'), findsOneWidget);
    expect(find.byType(SpectraProgressIndicator), findsNothing);
  });

  testWidgetsApp('a successful read shows the card and offers a save', (
    tester,
  ) async {
    await openRead(tester, deviceWithCard());
    await tester.tap(find.text('Scan high frequency'));
    await pumpFrames(tester, 40);

    expect(find.text('DEADBEEF'), findsOneWidget);
    expect(find.text('Save to library'), findsOneWidget);
    expect(find.text('Read again'), findsOneWidget);
    expect(
      find.byType(SpectraProgressIndicator),
      findsNothing,
      reason: 'the read is over',
    );
  });

  testWidgetsApp('an empty field shows the catalog message', (tester) async {
    await openRead(tester, deviceWithCard(present: false));
    await tester.tap(find.text('Scan high frequency'));
    await pumpFrames(tester, 30);

    expect(find.byType(CardsProblemView), findsOneWidget);
    expect(
      find.textContaining('No high-frequency card was found'),
      findsOneWidget,
    );

    await tester.tap(find.text('Try again'));
    await pumpFrames(tester, 5);
    expect(find.byType(CardsProblemView), findsNothing);
  });

  testWidgetsApp('a running dump shows progress and a cancel', (tester) async {
    final FakeDevice device = deviceWithCard();
    device.latency = const Duration(milliseconds: 5);
    await openRead(tester, device);

    await tester.tap(find.text('Scan high frequency'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SpectraProgressIndicator), findsOneWidget);

    await pumpFrames(tester, 60);
    expect(find.byType(SpectraProgressIndicator), findsNothing);
  });
}
```

- [ ] **Step 3: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/cards/read_page_test.dart
```

Expected: FAIL — there is no `Read a card` entry and no `ReadPage`.

- [ ] **Step 4: Add the ARB strings and regenerate**

Append inside the top-level object of `app/lib/l10n/app_en.arb` (before the closing `}`; remember the comma on the previous entry):

```json
  "cardsReadTitle": "Read a card",
  "@cardsReadTitle": {"description": "Title of the read-a-card screen."},
  "cardsReadAction": "Read a card",
  "@cardsReadAction": {"description": "Opens the read screen from the card library."},
  "cardsReadHint": "Hold the card flat against the back of the Chameleon, then choose a frequency.",
  "@cardsReadHint": {"description": "Instruction shown before a scan starts."},
  "cardsReadHf": "Scan high frequency",
  "@cardsReadHf": {"description": "Starts a 13.56 MHz scan."},
  "cardsReadLf": "Scan low frequency",
  "@cardsReadLf": {"description": "Starts a 125 kHz scan."},
  "cardsReadScanning": "Looking for a card…",
  "@cardsReadScanning": {"description": "Progress label while the field is being scanned."},
  "cardsReadDumping": "Reading the card…",
  "@cardsReadDumping": {"description": "Progress label while a full dump is being read."},
  "cardsReadAgain": "Read again",
  "@cardsReadAgain": {"description": "Clears the result and returns to the idle screen."},
  "cardsReadPartial": "{read} of {total} blocks could be read. Sectors with no known key are blank.",
  "@cardsReadPartial": {
    "description": "Explains a partial dump.",
    "placeholders": {"read": {"type": "int"}, "total": {"type": "int"}}
  },
  "cardsReadIdentityOnly": "Spectra can show this card's identity but cannot read its memory yet.",
  "@cardsReadIdentityOnly": {"description": "Shown for a tag with no readable dump format."},
  "cardsReadKeysFound": "Keys found for {count} sectors.",
  "@cardsReadKeysFound": {
    "description": "How many sectors a working key was found for.",
    "placeholders": {"count": {"type": "int"}}
  },
  "cardsSaveToLibrary": "Save to library",
  "@cardsSaveToLibrary": {"description": "Saves the card that was just read."},
```

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter gen-l10n
```

- [ ] **Step 5: Add the routes**

`app/lib/core/routing/routes.dart` — append inside `AppRoutes`:

```dart
  /// The read screen (spec 7.7 step 3), pushed on top of the Cards tab.
  static const String cardRead = '$cards/read';

  /// One saved card's detail and editor (spec 7.7 step 4).
  static String card(String id) => '$cards/${Uri.encodeComponent(id)}';
```

`app/lib/core/routing/app_sections.dart` — give the cards section its sub-routes. **`read` must come before `:id`**: go_router matches in list order, and `:id` would otherwise swallow `/cards/read`.

```dart
  AppSection(
    path: AppRoutes.cards,
    label: (l10n) => l10n.navCards,
    icon: Icons.style_outlined,
    selectedIcon: Icons.style,
    builder: (context, state) => const CardsPage(),
    subRoutes: <RouteBase>[
      // Before ':id': a literal segment and a parameter both match
      // '/cards/read', and go_router takes the first one listed.
      GoRoute(path: 'read', builder: (context, state) => const ReadPage()),
      GoRoute(
        path: ':id',
        builder: (context, state) =>
            CardDetailPage(id: state.pathParameters['id'] ?? ''),
      ),
    ],
  ),
```

`CardDetailPage` arrives in Task 7. Until then, keep the `:id` route out of the list and add it in Task 7 — this task lands only the `read` sub-route, and Task 7 adds the second entry plus the comment above it.

- [ ] **Step 6: Write the problem view**

```dart
// app/lib/features/cards/ui/cards_problem_view.dart
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/error_catalog.dart';
import '../../../core/errors/error_presentation.dart';
import '../../../l10n/app_localizations.dart';

/// A card read or a library write that failed, in the shape spec 9 asks for:
/// one plain sentence, the recovery action's words, and the raw line one tap
/// away. The only action is "dismiss and try again" — the controls that
/// produced the failure are still on screen, exactly as in
/// `features/slots/ui/slot_problem_view.dart`.
class CardsProblemView extends StatelessWidget {
  const CardsProblemView({
    required this.error,
    required this.onDismiss,
    super.key,
  });

  final Object error;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ErrorPresentation p = ErrorCatalog(l10n).describe(error);
    return SpectraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(p.message),
          const SizedBox(height: SpectraSpacing.md),
          SpectraDisclosure(
            summary: Text(l10n.commonDetails),
            detail: Text(p.detail),
          ),
          const SizedBox(height: SpectraSpacing.md),
          SpectraButton(
            label: switch (p.recovery) {
              ErrorRecovery.openSettings => l10n.commonOpenSettings,
              ErrorRecovery.update => l10n.commonUpdateFirmware,
              ErrorRecovery.retry ||
              ErrorRecovery.platformInstructions ||
              ErrorRecovery.reconnect ||
              ErrorRecovery.none => l10n.commonRetry,
            },
            variant: SpectraButtonVariant.secondary,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Write the read page**

```dart
// app/lib/features/cards/ui/read_page.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/routing/sub_page_scaffold.dart';
import '../../../l10n/app_localizations.dart';
import '../state/read_controller.dart';
import '../state/read_state.dart';
import 'cards_problem_view.dart';

/// Spec 7.7 step 3. Layout only: every decision is in [CardReader].
///
/// Task 5 replaces the disabled "Save to library" button's `onPressed` with
/// the save sheet; it is present here so the finished screen is one widget
/// tree rather than two.
class ReadPage extends ConsumerWidget {
  const ReadPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ReadState state = ref.watch(cardReaderProvider);
    final CardReader reader = ref.read(cardReaderProvider.notifier);

    return SubPageScaffold(
      title: l10n.cardsReadTitle,
      body: ListView(
        padding: const EdgeInsets.all(SpectraSpacing.lg),
        children: <Widget>[
          if (state.error != null) ...<Widget>[
            CardsProblemView(error: state.error!, onDismiss: reader.reset),
            const SizedBox(height: SpectraSpacing.lg),
          ],
          if (state.busy)
            SpectraProgressIndicator(
              label: state.progress == null
                  ? l10n.cardsReadScanning
                  : l10n.cardsReadDumping,
              value: state.progress,
              onCancel: reader.cancel,
            )
          else if (state.result != null)
            _Result(result: state.result!, onReadAgain: reader.reset)
          else
            _Idle(
              onHf: reader.readHf,
              onLf: reader.readLf,
            ),
        ],
      ),
    );
  }
}

class _Idle extends StatelessWidget {
  const _Idle({required this.onHf, required this.onLf});

  final VoidCallback onHf;
  final VoidCallback onLf;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SpectraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.cardsReadHint),
          const SizedBox(height: SpectraSpacing.lg),
          SpectraButton(label: l10n.cardsReadHf, onPressed: onHf),
          const SizedBox(height: SpectraSpacing.md),
          SpectraButton(
            label: l10n.cardsReadLf,
            variant: SpectraButtonVariant.secondary,
            onPressed: onLf,
          ),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.result, required this.onReadAgain});

  final CardReadResult result;
  final VoidCallback onReadAgain;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SpectraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final DumpField field in result.fields)
                SpectraListTile(title: field.label, subtitle: field.value),
              if (result.keysFound != null) ...<Widget>[
                const SizedBox(height: SpectraSpacing.sm),
                Text(l10n.cardsReadKeysFound(result.keysFound!)),
              ],
              if (result.isPartial) ...<Widget>[
                const SizedBox(height: SpectraSpacing.sm),
                Text(
                  l10n.cardsReadPartial(result.readChunks!, result.totalChunks!),
                ),
              ],
              if (!result.canSave) ...<Widget>[
                const SizedBox(height: SpectraSpacing.sm),
                Text(l10n.cardsReadIdentityOnly),
              ],
            ],
          ),
        ),
        const SizedBox(height: SpectraSpacing.lg),
        // Task 5 wires this to the save sheet.
        SpectraButton(
          label: l10n.cardsSaveToLibrary,
          onPressed: result.canSave ? () {} : null,
        ),
        const SizedBox(height: SpectraSpacing.md),
        SpectraButton(
          label: l10n.cardsReadAgain,
          variant: SpectraButtonVariant.secondary,
          onPressed: onReadAgain,
        ),
      ],
    );
  }
}
```

- [ ] **Step 8: Put the entry point on the Cards tab and export the page**

Replace the body of `app/lib/features/cards/ui/cards_page.dart`'s `build` (Task 6 rewrites this screen properly; this is the smallest thing that makes the route reachable):

```dart
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/routing/routes.dart';
import '../../../l10n/app_localizations.dart';

/// The card library. Task 6 fills in the list; this is the read entry point.
class CardsPage extends StatelessWidget {
  const CardsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(SpectraSpacing.lg),
      children: <Widget>[
        SpectraButton(
          label: l10n.cardsReadAction,
          icon: Icons.nfc,
          onPressed: () => GoRouter.of(context).go(AppRoutes.cardRead),
        ),
      ],
    );
  }
}
```

`app/lib/features/cards/cards.dart`:

```dart
/// The Cards feature's public API (spec 8.3): its screens, and — from Task
/// 11 — the card picker other features call. Nothing else in the app may
/// import `features/cards/…` directly.
library;

export 'ui/cards_page.dart';
export 'ui/cards_problem_view.dart';
export 'ui/read_page.dart';
```

Delete the now-unused `comingSoonCards` ARB entry and its `@comingSoonCards` description in the same commit.

- [ ] **Step 9: Run the tests and watch them pass**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/cards
cd .. && dart run melos run check:all
```

Expected: PASS, `check:all` green (`lint:deps` included — `read_page.dart` imports `material_ui` with `hide ConnectionState` because it also imports `package:chameleon/chameleon.dart` for `DumpField`).

- [ ] **Step 10: Commit**

```bash
git add app/lib/core/routing app/lib/features/cards app/lib/l10n app/test/features/cards
git commit -m "feat(cards): add the read screen and its route

Spec 7.7 step 3 needs a place for the scan buttons, the dump progress with
its cancel, and the spec 9 error card; the route sits under the Cards tab
like every other deep route.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: Saving a read card to the library

Spec 7.7 step 3 ends at "save to library", and spec 7.3's data model carries name, folder and colour. This task adds the library writer and the sheet that collects those three things.

**Files:**
- Create: `app/lib/features/cards/state/saved_cards_provider.dart`, `app/lib/features/cards/ui/save_card_sheet.dart`
- Modify: `app/lib/features/cards/ui/read_page.dart`, `app/lib/features/cards/cards.dart`, `app/lib/l10n/app_en.arb` (**owns the ARB**)
- Test: `app/test/features/cards/save_card_test.dart`

**Interfaces:**
- Consumes: `savedCardsRepositoryProvider`, `SavedCardsRepository`, `SavedCard` (Task 1); `tagTypeName` (Task 2); `CardReadResult`, `cardReaderProvider` (Tasks 3-4); `SpectraBottomSheet.show<T>({required BuildContext context, required String title, required WidgetBuilder builder})`, `SpectraTextField({required String label, TextEditingController? controller, String? hint, String? errorText, ValueChanged<String>? onChanged})`, `SpectraButton`, `SpectraCard`, `SpectraSpacing` (`package:spectra_ui`).
- Produces, frozen for Tasks 6-13:
  - `@riverpod Stream<List<SavedCard>> savedCards(Ref ref)` → `savedCardsProvider`, newest-updated first (Task 1's contract).
  - `@riverpod class CardLibrary extends _$CardLibrary` with `Future<void> build()`, and:
    - `Future<String?> add({required String name, required TagType type, required Uint8List bytes, String? folder, int? color})` → the new card's id, or null when the write failed (the failure is in `state`).
    - `Future<void> update(SavedCard card)`
    - `Future<void> remove(String id)`
    - `@visibleForTesting void debugFail(Object error)`
    → generated `cardLibraryProvider`.
  - `String newCardId()` — `'card-${DateTime.now().microsecondsSinceEpoch}-${_seq++}'`, unique within a session without a uuid dependency.
  - `Future<bool?> showSaveCardSheet(BuildContext context, {required TagType type, required Uint8List bytes, String? suggestedName})` — true when a card was saved, null when the sheet was dismissed.
  - `const List<int> cardColors` — the seven-swatch palette a card may be tinted with.
  - ARB keys: `cardsSaveTitle`, `cardsSaveName`, `cardsSaveFolder`, `cardsSaveFolderHint`, `cardsSaveColour`, `cardsSaveConfirm`, `cardsSaveNameRequired`, `cardsSaved`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/cards/save_card_test.dart
import 'dart:typed_data';
import 'dart:ui';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/data/data.dart';
import 'package:spectra/features/cards/state/saved_cards_provider.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

FakeDevice deviceWithCard() {
  final FakeFirmware firmware = FakeFirmware()
    ..present(
      FakeMf1Card.classic1k(uid: Uint8List.fromList(<int>[0xDE, 0xAD, 0xBE, 0xEF])),
    );
  return FakeDevice(firmware: firmware);
}

Future<void> pumpFrames(WidgetTester tester, [int frames = 20]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgetsApp('the library notifier writes a card through the repository', (
    tester,
  ) async {
    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await connectToEmulator(tester);
    keepAlive(tester, cardLibraryProvider);
    final CardLibrary library = readProvider(
      tester,
      cardLibraryProvider.notifier,
    );

    final Future<String?> pending = library.add(
      name: 'Office badge',
      type: TagType.mifare1k,
      bytes: Uint8List(64 * 16),
      folder: 'Work',
      color: cardColors.first,
    );
    await tester.pump(const Duration(milliseconds: 50));
    final String? id = await pending;
    expect(id, isNotNull);

    final SavedCardsRepository repo = readProvider(
      tester,
      savedCardsRepositoryProvider,
    );
    final SavedCard? saved = await repo.byId(id!);
    expect(saved!.name, 'Office badge');
    expect(saved.tagType, 'mifare1k');
    expect(saved.folder, 'Work');
    expect(saved.bytes, hasLength(64 * 16));
  });

  testWidgetsApp('reading a card and saving it puts it in the library', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpTestApp(tester, transport: (_) => deviceWithCard());
    await connectToEmulator(tester);
    await tester.tap(find.text('Cards').last);
    await pumpFrames(tester, 10);
    await tester.tap(find.text('Read a card'));
    await pumpFrames(tester, 10);
    await tester.tap(find.text('Scan high frequency'));
    await pumpFrames(tester, 40);

    await tester.tap(find.text('Save to library'));
    await pumpFrames(tester, 10);
    expect(find.text('Save this card'), findsOneWidget);

    await tester.enterText(
      find.byType(SpectraTextField).first,
      'Office badge',
    );
    await pumpFrames(tester, 5);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Save'),
      ),
    );
    await pumpFrames(tester, 20);

    keepAlive(tester, savedCardsProvider);
    await pumpFrames(tester, 5);
    final List<SavedCard> cards =
        readProvider(tester, savedCardsProvider).value ?? const <SavedCard>[];
    expect(cards, hasLength(1));
    expect(cards.single.name, 'Office badge');
    expect(cards.single.tagType, 'mifare1k');
  });

  testWidgetsApp('an empty name is refused before anything is written', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpTestApp(tester, transport: (_) => deviceWithCard());
    await connectToEmulator(tester);
    await tester.tap(find.text('Cards').last);
    await pumpFrames(tester, 10);
    await tester.tap(find.text('Read a card'));
    await pumpFrames(tester, 10);
    await tester.tap(find.text('Scan high frequency'));
    await pumpFrames(tester, 40);
    await tester.tap(find.text('Save to library'));
    await pumpFrames(tester, 10);

    await tester.enterText(find.byType(SpectraTextField).first, '   ');
    await pumpFrames(tester, 5);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Save'),
      ),
    );
    await pumpFrames(tester, 10);

    expect(find.text('Give the card a name.'), findsOneWidget);
    expect(find.text('Save this card'), findsOneWidget, reason: 'still open');
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/cards/save_card_test.dart
```

Expected: FAIL — `saved_cards_provider.dart` does not exist.

- [ ] **Step 3: Add the ARB strings and regenerate**

```json
  "cardsSaveTitle": "Save this card",
  "@cardsSaveTitle": {"description": "Title of the save-to-library sheet."},
  "cardsSaveName": "Name",
  "@cardsSaveName": {"description": "Label of the card name field."},
  "cardsSaveFolder": "Folder",
  "@cardsSaveFolder": {"description": "Label of the optional folder field."},
  "cardsSaveFolderHint": "Work",
  "@cardsSaveFolderHint": {"description": "Example folder name."},
  "cardsSaveColour": "Colour",
  "@cardsSaveColour": {"description": "Label above the colour swatches."},
  "cardsSaveConfirm": "Save",
  "@cardsSaveConfirm": {"description": "Confirms the save."},
  "cardsSaveNameRequired": "Give the card a name.",
  "@cardsSaveNameRequired": {"description": "Validation message under an empty name field."},
  "cardsSaved": "Saved to the library.",
  "@cardsSaved": {"description": "Confirms a card reached the library."},
```

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter gen-l10n
```

- [ ] **Step 4: Write the library provider and notifier**

```dart
// app/lib/features/cards/state/saved_cards_provider.dart
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/data.dart';
import 'card_codec.dart';

part 'saved_cards_provider.g.dart';

/// The library, newest-updated first (the repository's ordering contract,
/// `data/database/drift_saved_cards_repository.dart`). Every screen watches
/// this; nothing calls the repository directly.
@riverpod
Stream<List<SavedCard>> savedCards(Ref ref) =>
    ref.watch(savedCardsRepositoryProvider).watchAll();

/// The colours a card may be tinted with (spec 7.3's `color` column). A
/// fixed palette rather than a full picker: seven distinguishable hues is
/// what a library needs, and it keeps the value a plain ARGB int.
const List<int> cardColors = <int>[
  0xFF4C8DFF,
  0xFF35C08A,
  0xFFF5A524,
  0xFFE5484D,
  0xFF9B6BFF,
  0xFF19B3C4,
  0xFF8C8C99,
];

int _seq = 0;

/// A unique id for a new card, without adding a uuid dependency: the
/// microsecond clock plus a per-session counter, so two cards saved in the
/// same microsecond still differ.
String newCardId() =>
    'card-${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

/// Every write to the library, as an [AsyncValue] the screen renders.
///
/// Failures stay in the state rather than being thrown, so a screen shows
/// them through the spec 9 catalog (`CardsProblemView`) instead of catching.
/// A call made while another is in flight is dropped, not queued; the sheet
/// disables its confirm button while `state.isLoading`.
@riverpod
class CardLibrary extends _$CardLibrary {
  @override
  Future<void> build() async {}

  bool _inFlight = false;

  /// Writes a new card and returns its id, or null when the write failed.
  Future<String?> add({
    required String name,
    required TagType type,
    required Uint8List bytes,
    String? folder,
    int? color,
  }) async {
    final String id = newCardId();
    final bool ok = await _run(
      (SavedCardsRepository repo) => repo.save(
        SavedCard(
          id: id,
          name: name,
          tagType: tagTypeName(type),
          bytes: bytes,
          updatedAt: DateTime.now(),
          folder: folder,
          color: color,
        ),
      ),
    );
    return ok ? id : null;
  }

  /// Replaces an existing card, stamping it as changed now.
  Future<void> update(SavedCard card) async {
    await _run(
      (SavedCardsRepository repo) => repo.save(
        SavedCard(
          id: card.id,
          name: card.name,
          tagType: card.tagType,
          bytes: card.bytes,
          updatedAt: DateTime.now(),
          folder: card.folder,
          color: card.color,
        ),
      ),
    );
  }

  Future<void> remove(String id) async {
    await _run((SavedCardsRepository repo) => repo.delete(id));
  }

  /// Lets a test drive an `AsyncError` without a repository that throws.
  /// `Notifier.state` is `@protected`; this is the narrow door around that.
  @visibleForTesting
  void debugFail(Object error) =>
      state = AsyncError<void>(error, StackTrace.current);

  Future<bool> _run(Future<void> Function(SavedCardsRepository repo) body) async {
    if (_inFlight) return false;
    _inFlight = true;
    state = const AsyncLoading<void>();
    final AsyncValue<void> next = await AsyncValue.guard<void>(
      () => body(ref.read(savedCardsRepositoryProvider)),
    );
    state = next;
    _inFlight = false;
    return !next.hasError;
  }
}
```

- [ ] **Step 5: Write the save sheet**

```dart
// app/lib/features/cards/ui/save_card_sheet.dart
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../state/saved_cards_provider.dart';

/// Collects the three things spec 7.3 stores beside the dump — name, folder,
/// colour — and writes the card. Resolves to true when a card was saved and
/// to null when the sheet was dismissed.
Future<bool?> showSaveCardSheet(
  BuildContext context, {
  required TagType type,
  required Uint8List bytes,
  String? suggestedName,
}) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return SpectraBottomSheet.show<bool>(
    context: context,
    title: l10n.cardsSaveTitle,
    builder: (BuildContext context) => _SaveCardForm(
      type: type,
      bytes: bytes,
      suggestedName: suggestedName,
    ),
  );
}

class _SaveCardForm extends ConsumerStatefulWidget {
  const _SaveCardForm({
    required this.type,
    required this.bytes,
    this.suggestedName,
  });

  final TagType type;
  final Uint8List bytes;
  final String? suggestedName;

  @override
  ConsumerState<_SaveCardForm> createState() => _SaveCardFormState();
}

class _SaveCardFormState extends ConsumerState<_SaveCardForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.suggestedName ?? '',
  );
  final TextEditingController _folder = TextEditingController();
  int _color = cardColors.first;
  bool _nameMissing = false;

  @override
  void dispose() {
    _name.dispose();
    _folder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameMissing = true);
      return;
    }
    final String? folder = _folder.text.trim().isEmpty
        ? null
        : _folder.text.trim();
    final String? id = await ref
        .read(cardLibraryProvider.notifier)
        .add(
          name: name,
          type: widget.type,
          bytes: widget.bytes,
          folder: folder,
          color: _color,
        );
    if (!mounted || id == null) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool busy = ref.watch(cardLibraryProvider).isLoading;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SpectraTextField(
          label: l10n.cardsSaveName,
          controller: _name,
          errorText: _nameMissing ? l10n.cardsSaveNameRequired : null,
          onChanged: (String _) {
            if (_nameMissing) setState(() => _nameMissing = false);
          },
        ),
        const SizedBox(height: SpectraSpacing.md),
        SpectraTextField(
          label: l10n.cardsSaveFolder,
          controller: _folder,
          hint: l10n.cardsSaveFolderHint,
        ),
        const SizedBox(height: SpectraSpacing.md),
        Text(l10n.cardsSaveColour),
        const SizedBox(height: SpectraSpacing.sm),
        Row(
          children: <Widget>[
            for (final int value in cardColors)
              Padding(
                padding: const EdgeInsets.only(right: SpectraSpacing.sm),
                child: SpectraTappable(
                  onTap: () => setState(() => _color = value),
                  semanticsLabel: l10n.cardsSaveColour,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(value),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: SpectraTheme.of(context).colors.borderStrong,
                        width: _color == value ? 3 : 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: SpectraSpacing.lg),
        SpectraButton(
          label: l10n.cardsSaveConfirm,
          busy: busy,
          onPressed: busy ? null : _save,
        ),
      ],
    );
  }
}
```

`SpectraTappable({required VoidCallback? onTap, required Widget child, String? semanticsLabel, bool enabled = true, …})` is the design system's one tappable primitive (`packages/spectra_ui/lib/src/components/tappable.dart`) — it puts the tap on the semantics node and makes the swatch keyboard-reachable, which a bare `GestureDetector` would not. Do not change the design system in this phase.

- [ ] **Step 6: Wire the read page's save button**

In `app/lib/features/cards/ui/read_page.dart`, `_Result` stays a `StatelessWidget` — it needs no `ref`, only the `BuildContext` its `build` already has. Replace the placeholder `onPressed: result.canSave ? () {} : null` with:

```dart
        SpectraButton(
          label: l10n.cardsSaveToLibrary,
          onPressed: result.canSave
              ? () => showSaveCardSheet(
                  context,
                  type: result.tagType,
                  bytes: result.bytes,
                )
              : null,
        ),
```

adding `import 'save_card_sheet.dart';` to the file's imports.

- [ ] **Step 7: Regenerate, run the tests and watch them pass**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && dart run build_runner build --delete-conflicting-outputs
flutter test test/features/cards
cd .. && dart run melos run check:all
```

Expected: PASS, `check:all` green.

- [ ] **Step 8: Commit**

```bash
git add app/lib/features/cards app/lib/l10n app/test/features/cards
git commit -m "feat(cards): save a read card to the library

Spec 7.7 step 3 ends at the library and spec 7.3 stores a name, a folder and
a colour with the dump, so the read result goes through one sheet that
collects exactly those and one notifier that owns every write.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: The library list — search, folder filter, sort

Spec 7.7 step 4: "folders, colours". The list is the Cards tab itself. The filtering rule is a pure function so it is unit-tested without a widget, exactly as `buildSlotViews` is in `features/slots/state/slot_view.dart`.

**Files:**
- Create: `app/lib/features/cards/state/cards_filter.dart`
- Modify: `app/lib/features/cards/ui/cards_page.dart`, `app/lib/features/cards/cards.dart`, `app/lib/l10n/app_en.arb` (**owns the ARB**)
- Test: `app/test/features/cards/cards_filter_test.dart`, `app/test/features/cards/cards_page_test.dart`

**Interfaces:**
- Consumes: `savedCardsProvider`, `SavedCard` (Tasks 1, 5); `tagTypeFromName` (Task 2); `AppRoutes.card(String id)`, `AppRoutes.cardRead` (Task 4); `SpectraTextField`, `SpectraListTile`, `SpectraCard`, `SpectraSectionHeader`, `SpectraButton`, `SpectraSpacing`, `SpectraTheme.of(context).colors`.
- Produces, frozen for Tasks 7, 11 and 13:
  - `enum CardsSort { recent, name }`
  - `final class CardsFilter` — `const CardsFilter({this.query = '', this.folder, this.sort = CardsSort.recent})` with `CardsFilter copyWith({String? query, Object? folder = _unsetFolder, CardsSort? sort})` (an explicit `null` folder clears it; omitting it keeps the current one).
  - `List<SavedCard> filterCards(List<SavedCard> cards, CardsFilter filter)` — pure; case-insensitive substring match on name and folder, exact folder match, then the sort.
  - `List<String> foldersOf(List<SavedCard> cards)` — the distinct non-null folders, alphabetical.
  - `@riverpod class CardsFilterState extends _$CardsFilterState` with `CardsFilter build()`, `void setQuery(String)`, `void setFolder(String?)`, `void setSort(CardsSort)` → `cardsFilterStateProvider`.
  - ARB keys: `cardsTitle`, `cardsEmpty`, `cardsNoMatches`, `cardsSearch`, `cardsAllFolders`, `cardsSortRecent`, `cardsSortName`, `cardsSubtitle`.

- [ ] **Step 1: Write the failing pure test**

```dart
// app/test/features/cards/cards_filter_test.dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/features/cards/state/cards_filter.dart';

SavedCard card(String id, String name, {String? folder, int day = 1}) =>
    SavedCard(
      id: id,
      name: name,
      tagType: 'mifare1k',
      bytes: Uint8List(16),
      updatedAt: DateTime.utc(2026, 9, day),
      folder: folder,
    );

void main() {
  final List<SavedCard> cards = <SavedCard>[
    card('a', 'Office badge', folder: 'Work', day: 3),
    card('b', 'Gym', folder: 'Personal', day: 5),
    card('c', 'Hotel key', day: 1),
  ];

  test('no filter keeps everything, newest first', () {
    expect(
      filterCards(cards, const CardsFilter()).map((SavedCard c) => c.id),
      <String>['b', 'a', 'c'],
    );
  });

  test('the query matches name and folder, case-insensitively', () {
    expect(
      filterCards(cards, const CardsFilter(query: 'off')).map((c) => c.id),
      <String>['a'],
    );
    expect(
      filterCards(cards, const CardsFilter(query: 'PERSONAL')).map((c) => c.id),
      <String>['b'],
    );
    expect(filterCards(cards, const CardsFilter(query: 'zzz')), isEmpty);
  });

  test('the folder filter is exact', () {
    expect(
      filterCards(cards, const CardsFilter(folder: 'Work')).map((c) => c.id),
      <String>['a'],
    );
  });

  test('sorting by name is case-insensitive and alphabetical', () {
    expect(
      filterCards(
        cards,
        const CardsFilter(sort: CardsSort.name),
      ).map((SavedCard c) => c.id),
      <String>['b', 'c', 'a'],
    );
  });

  test('folders are the distinct non-null ones, alphabetical', () {
    expect(foldersOf(cards), <String>['Personal', 'Work']);
  });

  test('copyWith clears the folder only when null is passed explicitly', () {
    const CardsFilter filter = CardsFilter(folder: 'Work', query: 'x');
    expect(filter.copyWith(query: 'y').folder, 'Work');
    expect(filter.copyWith(folder: null).folder, isNull);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/cards/cards_filter_test.dart
```

Expected: FAIL — `cards_filter.dart` does not exist.

- [ ] **Step 3: Write the filter**

```dart
// app/lib/features/cards/state/cards_filter.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/data.dart';

part 'cards_filter.g.dart';

/// How the library list is ordered.
enum CardsSort {
  /// Newest change first — the repository's own order.
  recent,

  /// By name, case-insensitively.
  name,
}

/// Sentinel distinguishing "leave the folder alone" from "clear it" in
/// [CardsFilter.copyWith], since null is itself a valid folder.
const Object _unsetFolder = Object();

/// What the library list is showing (spec 7.7 step 4's minimum: search,
/// folders, sort).
final class CardsFilter {
  const CardsFilter({this.query = '', this.folder, this.sort = CardsSort.recent});

  /// Case-insensitive substring, matched against the name and the folder.
  final String query;

  /// An exact folder, or null for every folder.
  final String? folder;

  final CardsSort sort;

  CardsFilter copyWith({
    String? query,
    Object? folder = _unsetFolder,
    CardsSort? sort,
  }) => CardsFilter(
    query: query ?? this.query,
    folder: identical(folder, _unsetFolder) ? this.folder : folder as String?,
    sort: sort ?? this.sort,
  );
}

/// Pure, so the rule is tested without a widget or a database.
List<SavedCard> filterCards(List<SavedCard> cards, CardsFilter filter) {
  final String needle = filter.query.trim().toLowerCase();
  final List<SavedCard> matched = cards.where((SavedCard c) {
    if (filter.folder != null && c.folder != filter.folder) return false;
    if (needle.isEmpty) return true;
    return c.name.toLowerCase().contains(needle) ||
        (c.folder?.toLowerCase().contains(needle) ?? false);
  }).toList();
  matched.sort(switch (filter.sort) {
    CardsSort.recent => (SavedCard a, SavedCard b) =>
      b.updatedAt.compareTo(a.updatedAt),
    CardsSort.name => (SavedCard a, SavedCard b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  });
  return matched;
}

/// The folders in use, alphabetical, for the filter control.
List<String> foldersOf(List<SavedCard> cards) =>
    cards
        .map((SavedCard c) => c.folder)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();

@riverpod
class CardsFilterState extends _$CardsFilterState {
  @override
  CardsFilter build() => const CardsFilter();

  void setQuery(String query) => state = state.copyWith(query: query);

  /// Null means "every folder"; the sentinel in [CardsFilter.copyWith] is
  /// what makes that expressible.
  void setFolder(String? folder) => state = state.copyWith(folder: folder);

  void setSort(CardsSort sort) => state = state.copyWith(sort: sort);
}
```

- [ ] **Step 4: Add the ARB strings and regenerate**

```json
  "cardsTitle": "Cards",
  "@cardsTitle": {"description": "Heading of the card library."},
  "cardsEmpty": "No cards yet. Read one, or import from another app.",
  "@cardsEmpty": {"description": "Shown when the library has no cards at all."},
  "cardsNoMatches": "No cards match that search.",
  "@cardsNoMatches": {"description": "Shown when the filter hides every card."},
  "cardsSearch": "Search",
  "@cardsSearch": {"description": "Label of the library search field."},
  "cardsAllFolders": "All folders",
  "@cardsAllFolders": {"description": "Folder filter entry that clears the filter."},
  "cardsSortRecent": "Recent",
  "@cardsSortRecent": {"description": "Sorts the library by last change."},
  "cardsSortName": "Name",
  "@cardsSortName": {"description": "Sorts the library alphabetically."},
  "cardsSubtitle": "{tagType} · {folder}",
  "@cardsSubtitle": {
    "description": "Second line of a library row: the tag type and folder.",
    "placeholders": {"tagType": {"type": "String"}, "folder": {"type": "String"}}
  },
```

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter gen-l10n
```

- [ ] **Step 5: Write the widget test**

```dart
// app/test/features/cards/cards_page_test.dart
import 'dart:typed_data';
import 'dart:ui';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/features/cards/state/saved_cards_provider.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

Future<void> pumpFrames(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<CardLibrary> openLibrary(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpTestApp(tester, transport: (_) => FakeDevice());
  await connectToEmulator(tester);
  keepAlive(tester, cardLibraryProvider);
  await tester.tap(find.text('Cards').last);
  await pumpFrames(tester);
  return readProvider(tester, cardLibraryProvider.notifier);
}

Future<void> seed(WidgetTester tester, CardLibrary library) async {
  for (final (String name, String? folder) in <(String, String?)>[
    ('Office badge', 'Work'),
    ('Gym', 'Personal'),
  ]) {
    final Future<String?> pending = library.add(
      name: name,
      type: TagType.mifare1k,
      bytes: Uint8List(64 * 16),
      folder: folder,
    );
    await tester.pump(const Duration(milliseconds: 20));
    await pending;
  }
  await pumpFrames(tester);
}

void main() {
  testWidgetsApp('an empty library says so', (tester) async {
    await openLibrary(tester);
    expect(
      find.text('No cards yet. Read one, or import from another app.'),
      findsOneWidget,
    );
  });

  testWidgetsApp('saved cards are listed and searchable', (tester) async {
    final CardLibrary library = await openLibrary(tester);
    await seed(tester, library);

    expect(find.text('Office badge'), findsOneWidget);
    expect(find.text('Gym'), findsOneWidget);

    await tester.enterText(find.byType(SpectraTextField).first, 'gym');
    await pumpFrames(tester);
    expect(find.text('Office badge'), findsNothing);
    expect(find.text('Gym'), findsOneWidget);

    await tester.enterText(find.byType(SpectraTextField).first, 'zzz');
    await pumpFrames(tester);
    expect(find.text('No cards match that search.'), findsOneWidget);
  });

  testWidgetsApp('the read entry is still on the library screen', (
    tester,
  ) async {
    await openLibrary(tester);
    expect(find.text('Read a card'), findsOneWidget);
  });
}
```

- [ ] **Step 6: Write the library screen**

```dart
// app/lib/features/cards/ui/cards_page.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/routing/routes.dart';
import '../../../data/data.dart';
import '../../../l10n/app_localizations.dart';
import '../state/card_codec.dart';
import '../state/cards_filter.dart';
import '../state/saved_cards_provider.dart';

/// Spec 7.7 step 4: the library. Layout only — the rule is [filterCards].
class CardsPage extends ConsumerWidget {
  const CardsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<SavedCard> all =
        ref.watch(savedCardsProvider).value ?? const <SavedCard>[];
    final CardsFilter filter = ref.watch(cardsFilterStateProvider);
    final CardsFilterState filterState = ref.read(
      cardsFilterStateProvider.notifier,
    );
    final List<SavedCard> shown = filterCards(all, filter);
    final List<String> folders = foldersOf(all);

    return ListView(
      padding: const EdgeInsets.all(SpectraSpacing.lg),
      children: <Widget>[
        SpectraButton(
          label: l10n.cardsReadAction,
          icon: Icons.nfc,
          onPressed: () => GoRouter.of(context).go(AppRoutes.cardRead),
        ),
        const SizedBox(height: SpectraSpacing.lg),
        SpectraTextField(
          label: l10n.cardsSearch,
          onChanged: filterState.setQuery,
        ),
        const SizedBox(height: SpectraSpacing.md),
        Wrap(
          spacing: SpectraSpacing.sm,
          children: <Widget>[
            _Chip(
              label: l10n.cardsAllFolders,
              selected: filter.folder == null,
              onTap: () => filterState.setFolder(null),
            ),
            for (final String folder in folders)
              _Chip(
                label: folder,
                selected: filter.folder == folder,
                onTap: () => filterState.setFolder(folder),
              ),
            _Chip(
              label: l10n.cardsSortRecent,
              selected: filter.sort == CardsSort.recent,
              onTap: () => filterState.setSort(CardsSort.recent),
            ),
            _Chip(
              label: l10n.cardsSortName,
              selected: filter.sort == CardsSort.name,
              onTap: () => filterState.setSort(CardsSort.name),
            ),
          ],
        ),
        const SizedBox(height: SpectraSpacing.lg),
        if (all.isEmpty)
          SpectraCard(child: Text(l10n.cardsEmpty))
        else if (shown.isEmpty)
          SpectraCard(child: Text(l10n.cardsNoMatches))
        else
          for (final SavedCard card in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: SpectraSpacing.sm),
              child: SpectraListTile(
                title: card.name,
                subtitle: l10n.cardsSubtitle(
                  tagTypeFromName(card.tagType).name,
                  card.folder ?? '',
                ),
                leading: Icon(
                  Icons.circle,
                  color: card.color == null
                      ? SpectraTheme.of(context).colors.border
                      : Color(card.color!),
                ),
                onTap: () => GoRouter.of(context).go(AppRoutes.card(card.id)),
              ),
            ),
      ],
    );
  }
}

/// A filter chip on the design system's own tappable, so it is focusable and
/// announces itself; `material_ui`'s `FilterChip` is not part of the kit.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final SpectraColorScheme colors = SpectraTheme.of(context).colors;
    return SpectraTappable(
      onTap: onTap,
      semanticsLabel: label,
      borderRadius: BorderRadius.circular(SpectraSpacing.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SpectraSpacing.md,
          vertical: SpectraSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.accent : colors.surface,
          borderRadius: BorderRadius.circular(SpectraSpacing.md),
          border: Border.all(color: colors.border),
        ),
        child: Text(
          label,
          style: SpectraTypography.label.copyWith(
            color: selected ? colors.onAccent : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
```

The `AppRoutes.card(card.id)` tap target only becomes a live route in Task 7; until then it navigates to a path with no builder, which go_router renders as its error page. That is why Task 7 follows immediately and why this task's tests do not tap a row.

- [ ] **Step 7: Regenerate, run the tests and watch them pass**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && dart run build_runner build --delete-conflicting-outputs
flutter test test/features/cards
cd .. && dart run melos run check:all
```

Expected: PASS, `check:all` green.

- [ ] **Step 8: Commit**

```bash
git add app/lib/features/cards app/lib/l10n app/test/features/cards
git commit -m "feat(cards): list the library with search, folders and sort

Spec 7.7 step 4's library. The filtering rule is a pure function so it is
tested without a widget, the way the slots feature tests its view model.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: The card detail screen and its hex viewer

Spec 7.7 step 4: "view and edit dumps through the hex viewer". This task lands the read-only half — fields, the hex viewer with the sector trailers highlighted, validation problems, and delete. Task 8 adds editing on top.

**Files:**
- Create: `app/lib/features/cards/state/card_editor_controller.dart`, `app/lib/features/cards/ui/card_detail_page.dart`
- Modify: `app/lib/core/routing/app_sections.dart`, `app/lib/features/cards/cards.dart`, `app/lib/l10n/app_en.arb` (**owns the ARB**)
- Test: `app/test/features/cards/card_detail_page_test.dart`

**Interfaces:**
- Consumes: `savedCardsRepositoryProvider`, `SavedCard` (Task 1); `tagTypeFromName`, `describeSavedCard`, `validateSavedCard`, `chunkSizeFor`, `chunkCountFor`, `toHex` (Task 2); `cardLibraryProvider`/`CardLibrary.update`/`.remove` (Task 5); `SubPageScaffold`; `SpectraHexViewer({required Uint8List bytes, int bytesPerRow = 16, int groupSize = 4, List<SpectraHexHighlight> highlights = const [], bool showAscii = true})`, `SpectraHexHighlight({required int start, required int length, required Color color, String? label})`, `SpectraDialog.show<T>({required BuildContext context, required String title, required Widget content, required List<Widget> Function(BuildContext) actions})`, `SpectraListTile`, `SpectraCard`, `SpectraButton`, `SpectraSectionHeader`; `MifareGeometry.sectorCount/trailerOf`, `TagFamily`.
- Produces, frozen for Tasks 8, 10 and 13:
  - `final class CardEditState` — `const CardEditState({required SavedCard card, required Uint8List bytes, required bool dirty})`, with `TagType get tagType`, `int get chunkSize`, `int get chunkCount`, `Uint8List chunk(int index)`.
  - `@riverpod class CardEditor extends _$CardEditor` with `Future<CardEditState?> build(String id)` (null when the id is unknown), `void replaceChunk(int index, Uint8List bytes)` (Task 8), `Future<void> save()`, `Future<void> discard()`, `Future<void> deleteCard()`, `@visibleForTesting void debugFail(Object error)` → `cardEditorProvider(String id)`.
  - `List<SpectraHexHighlight> trailerHighlights(TagType type, Color color)` — the sector trailers of a MIFARE Classic, empty for every other family.
  - `class CardDetailPage extends ConsumerWidget` with `const CardDetailPage({required String id, super.key})`.
  - ARB keys: `cardsDetailNotFound`, `cardsDetailDelete`, `cardsDetailDeleteTitle`, `cardsDetailDeleteBody`, `cardsDetailProblems`, `cardsDetailBytes`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/cards/card_detail_page_test.dart
import 'dart:typed_data';
import 'dart:ui';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/features/cards/state/card_editor_controller.dart';
import 'package:spectra/features/cards/state/saved_cards_provider.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

Uint8List classic1kBytes() {
  final Uint8List blocks = Uint8List(64 * 16);
  blocks.setRange(0, 4, <int>[0xDE, 0xAD, 0xBE, 0xEF]);
  blocks[4] = 0x22;
  return blocks;
}

Future<void> pumpFrames(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<String> seedAndOpen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpTestApp(tester, transport: (_) => FakeDevice());
  await connectToEmulator(tester);
  keepAlive(tester, cardLibraryProvider);
  final CardLibrary library = readProvider(tester, cardLibraryProvider.notifier);
  final Future<String?> pending = library.add(
    name: 'Office badge',
    type: TagType.mifare1k,
    bytes: classic1kBytes(),
    folder: 'Work',
  );
  await tester.pump(const Duration(milliseconds: 20));
  final String id = (await pending)!;
  await tester.tap(find.text('Cards').last);
  await pumpFrames(tester);
  await tester.tap(find.text('Office badge'));
  await pumpFrames(tester);
  return id;
}

void main() {
  testWidgetsApp('the detail screen shows the fields and the hex', (
    tester,
  ) async {
    await seedAndOpen(tester);
    expect(find.byType(CardDetailPage), findsOneWidget);
    expect(find.text('DEADBEEF'), findsWidgets);
    expect(find.byType(SpectraHexViewer), findsOneWidget);
  });

  testWidgetsApp('deleting a card confirms first, then removes it', (
    tester,
  ) async {
    await seedAndOpen(tester);

    await tester.tap(find.text('Delete'));
    await pumpFrames(tester);
    expect(find.byType(SpectraDialog), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(SpectraDialog),
        matching: find.text('Delete'),
      ),
    );
    await pumpFrames(tester, 20);

    keepAlive(tester, savedCardsProvider);
    await pumpFrames(tester);
    expect(
      readProvider(tester, savedCardsProvider).value ?? const <Object>[],
      isEmpty,
    );
  });

  testWidgetsApp('an unknown id renders the not-found state', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await connectToEmulator(tester);
    await tester.tap(find.text('Cards').last);
    await pumpFrames(tester);

    final BuildContext context = tester.element(find.byType(CardsPage));
    GoRouter.of(context).go(AppRoutes.card('nope'));
    await pumpFrames(tester, 20);
    expect(find.text('That card is not in the library.'), findsOneWidget);
  });

  test('trailerHighlights covers every MIFARE Classic trailer', () {
    final List<SpectraHexHighlight> highlights = trailerHighlights(
      TagType.mifare1k,
      const Color(0xFF000000),
    );
    expect(highlights, hasLength(16));
    expect(highlights.first.start, 3 * 16);
    expect(highlights.first.length, 16);
    expect(trailerHighlights(TagType.em410x, const Color(0xFF000000)), isEmpty);
  });
}
```

Add the imports the last two tests need: `package:go_router/go_router.dart`, `package:spectra/core/routing/routes.dart`, `package:spectra/features/cards/cards.dart`.

- [ ] **Step 2: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/cards/card_detail_page_test.dart
```

Expected: FAIL — `card_editor_controller.dart` and `CardDetailPage` do not exist.

- [ ] **Step 3: Add the ARB strings and regenerate**

```json
  "cardsDetailNotFound": "That card is not in the library.",
  "@cardsDetailNotFound": {"description": "Shown when a card route names an id that is gone."},
  "cardsDetailDelete": "Delete",
  "@cardsDetailDelete": {"description": "Removes a card from the library."},
  "cardsDetailDeleteTitle": "Delete this card?",
  "@cardsDetailDeleteTitle": {"description": "Title of the delete confirmation."},
  "cardsDetailDeleteBody": "The saved dump is removed from Spectra. The physical card is not touched.",
  "@cardsDetailDeleteBody": {"description": "Body of the delete confirmation."},
  "cardsDetailProblems": "This dump has problems: {problems}",
  "@cardsDetailProblems": {
    "description": "Lists the validation problems of a stored dump.",
    "placeholders": {"problems": {"type": "String"}}
  },
  "cardsDetailBytes": "{count} bytes",
  "@cardsDetailBytes": {
    "description": "Size of the stored dump.",
    "placeholders": {"count": {"type": "int"}}
  },
```

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter gen-l10n
```

- [ ] **Step 4: Write the editor controller**

```dart
// app/lib/features/cards/state/card_editor_controller.dart
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/data.dart';
import 'card_codec.dart';
import 'saved_cards_provider.dart';

part 'card_editor_controller.g.dart';

/// One card being looked at, and possibly edited.
///
/// [bytes] is a working copy: edits change it without touching the stored
/// row, and [dirty] says whether the two have drifted apart.
final class CardEditState {
  const CardEditState({
    required this.card,
    required this.bytes,
    required this.dirty,
  });

  final SavedCard card;
  final Uint8List bytes;
  final bool dirty;

  TagType get tagType => tagTypeFromName(card.tagType);

  /// The edit unit: a MIFARE Classic block, an Ultralight page, or the whole
  /// EM410x id. Zero for a type with no editable layout.
  int get chunkSize => chunkSizeFor(tagType);

  int get chunkCount => chunkCountFor(tagType, bytes.length);

  /// A copy, so a caller mutating it cannot edit the card behind the
  /// notifier's back.
  Uint8List chunk(int index) => Uint8List.fromList(
    bytes.sublist(index * chunkSize, index * chunkSize + chunkSize),
  );
}

/// The detail screen's state, one notifier per card id, so a failure on one
/// card does not grey out another (the `SlotEditor` shape).
///
/// A call made while another write is in flight is dropped, not queued; the
/// screen disables its controls while `state.isLoading`.
@riverpod
class CardEditor extends _$CardEditor {
  @override
  Future<CardEditState?> build(String id) async {
    final SavedCard? card = await ref
        .read(savedCardsRepositoryProvider)
        .byId(id);
    if (card == null) return null;
    return CardEditState(
      card: card,
      bytes: Uint8List.fromList(card.bytes),
      dirty: false,
    );
  }

  bool _inFlight = false;

  /// Replaces one block, page or id in the working copy. In memory only:
  /// nothing reaches the database until [save].
  void replaceChunk(int index, Uint8List chunk) {
    final CardEditState? current = state.value;
    if (current == null) return;
    if (chunk.length != current.chunkSize) return;
    if (index < 0 || index >= current.chunkCount) return;
    final Uint8List next = Uint8List.fromList(current.bytes);
    next.setRange(index * current.chunkSize, (index + 1) * current.chunkSize, chunk);
    state = AsyncData<CardEditState?>(
      CardEditState(card: current.card, bytes: next, dirty: true),
    );
  }

  /// Writes the working copy back to the library.
  Future<void> save() async {
    final CardEditState? current = state.value;
    if (current == null || _inFlight) return;
    _inFlight = true;
    state = const AsyncLoading<CardEditState?>();
    final AsyncValue<void> written = await AsyncValue.guard<void>(
      () => ref
          .read(savedCardsRepositoryProvider)
          .save(
            SavedCard(
              id: current.card.id,
              name: current.card.name,
              tagType: current.card.tagType,
              bytes: current.bytes,
              updatedAt: DateTime.now(),
              folder: current.card.folder,
              color: current.card.color,
            ),
          ),
    );
    final Object? error = written.error;
    state = error != null
        ? AsyncError<CardEditState?>(error, written.stackTrace ?? StackTrace.current)
        : AsyncData<CardEditState?>(
            CardEditState(
              card: current.card,
              bytes: current.bytes,
              dirty: false,
            ),
          );
    _inFlight = false;
  }

  /// Throws the working copy away and reloads from the library.
  Future<void> discard() async {
    state = const AsyncLoading<CardEditState?>();
    state = await AsyncValue.guard<CardEditState?>(() => build(id));
  }

  Future<void> deleteCard() async {
    if (_inFlight) return;
    _inFlight = true;
    await ref.read(cardLibraryProvider.notifier).remove(id);
    state = const AsyncData<CardEditState?>(null);
    _inFlight = false;
  }

  /// Lets a test drive an `AsyncError` without a repository that throws.
  @visibleForTesting
  void debugFail(Object error) =>
      state = AsyncError<CardEditState?>(error, StackTrace.current);
}
```

- [ ] **Step 5: Write the detail page**

```dart
// app/lib/features/cards/ui/card_detail_page.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/routing/routes.dart';
import '../../../core/routing/sub_page_scaffold.dart';
import '../../../l10n/app_localizations.dart';
import '../state/card_codec.dart';
import '../state/card_editor_controller.dart';
import 'cards_problem_view.dart';

/// The sector trailers of a MIFARE Classic, so the keys and access bits are
/// visible at a glance in the hex viewer. Empty for every other family:
/// Ultralight and EM410x have no trailer.
List<SpectraHexHighlight> trailerHighlights(TagType type, Color color) {
  if (type.family != TagFamily.mifareClassic) {
    return const <SpectraHexHighlight>[];
  }
  return <SpectraHexHighlight>[
    for (int sector = 0; sector < MifareGeometry.sectorCount(type); sector++)
      SpectraHexHighlight(
        start: MifareGeometry.trailerOf(sector) * 16,
        length: 16,
        color: color,
      ),
  ];
}

/// Spec 7.7 step 4: one saved card, its fields, its dump and its editor.
/// Layout only — every decision is in [CardEditor].
class CardDetailPage extends ConsumerWidget {
  const CardDetailPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<CardEditState?> async = ref.watch(cardEditorProvider(id));
    final CardEditor editor = ref.read(cardEditorProvider(id).notifier);

    final Widget body = switch (async) {
      AsyncError<CardEditState?>(:final Object error) => CardsProblemView(
        error: error,
        onDismiss: editor.discard,
      ),
      AsyncData<CardEditState?>(value: null) => SpectraCard(
        child: Text(l10n.cardsDetailNotFound),
      ),
      AsyncData<CardEditState?>(:final CardEditState? value) => _Detail(
        state: value!,
        onDelete: () => _confirmDelete(context, ref, editor),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };

    return SubPageScaffold(
      title: async.value?.card.name ?? l10n.cardsTitle,
      body: ListView(
        padding: const EdgeInsets.all(SpectraSpacing.lg),
        children: <Widget>[body],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CardEditor editor,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final GoRouter router = GoRouter.of(context);
    final bool? confirmed = await SpectraDialog.show<bool>(
      context: context,
      title: l10n.cardsDetailDeleteTitle,
      content: Text(l10n.cardsDetailDeleteBody),
      actions: (BuildContext context) => <Widget>[
        SpectraButton(
          label: l10n.commonCancel,
          variant: SpectraButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        SpectraButton(
          label: l10n.cardsDetailDelete,
          variant: SpectraButtonVariant.danger,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true) return;
    await editor.deleteCard();
    router.go(AppRoutes.cards);
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.state, required this.onDelete});

  final CardEditState state;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<String> problems = validateSavedCard(state.card);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SpectraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final DumpField field in describeSavedCard(state.card))
                SpectraListTile(title: field.label, subtitle: field.value),
              SpectraListTile(
                title: l10n.cardsDetailBytes(state.bytes.length),
                subtitle: state.card.folder ?? '',
              ),
              if (problems.isNotEmpty)
                Text(l10n.cardsDetailProblems(problems.join(', '))),
            ],
          ),
        ),
        const SizedBox(height: SpectraSpacing.lg),
        SpectraCard(
          child: SpectraHexViewer(
            bytes: state.bytes,
            highlights: trailerHighlights(
              state.tagType,
              SpectraTheme.of(context).colors.warning,
            ),
          ),
        ),
        const SizedBox(height: SpectraSpacing.lg),
        SpectraButton(
          label: l10n.cardsDetailDelete,
          variant: SpectraButtonVariant.danger,
          onPressed: onDelete,
        ),
      ],
    );
  }
}
```

`SpectraHexViewer` builds every row eagerly (its own doc comment), so a 4K dump is 256 rows in one `Column`. That is fine inside the page's `ListView` for v1; if a 4K card ever feels slow, page the viewer rather than changing the component.

- [ ] **Step 6: Add the `:id` route and the export**

In `app/lib/core/routing/app_sections.dart`, add the second sub-route **after** `read` (a literal segment and a parameter both match `/cards/read`, and go_router takes the first listed):

```dart
      GoRoute(
        path: ':id',
        builder: (context, state) =>
            CardDetailPage(id: state.pathParameters['id'] ?? ''),
      ),
```

Add `export 'ui/card_detail_page.dart';` to `app/lib/features/cards/cards.dart`.

- [ ] **Step 7: Regenerate, run the tests and watch them pass**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && dart run build_runner build --delete-conflicting-outputs
flutter test test/features/cards
cd .. && dart run melos run check:all
```

Expected: PASS, `check:all` green.

- [ ] **Step 8: Commit**

```bash
git add app/lib/core/routing app/lib/features/cards app/lib/l10n app/test/features/cards
git commit -m "feat(cards): show a saved card's fields and dump

Spec 7.7 step 4 wants the dump visible through the hex viewer, with the
sector trailers marked so the keys and access bits are findable; delete
confirms first because a dump cannot be re-read without the card.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 8: Editing the dump

Spec 7.7 step 4's other half: "edit dumps through the hex viewer". One block, page or id at a time, validated before it is applied, held in memory until the user saves, with an unsaved-changes guard on the way out.

**Files:**
- Create: `app/lib/features/cards/ui/card_hex_editor.dart`
- Modify: `app/lib/features/cards/ui/card_detail_page.dart`, `app/lib/l10n/app_en.arb` (**owns the ARB**)
- Test: append to `app/test/features/cards/card_detail_page_test.dart`

**Interfaces:**
- Consumes: `CardEditState` (`chunkSize`, `chunkCount`, `chunk(int)`, `dirty`, `tagType`), `CardEditor.replaceChunk/save/discard`, `cardEditorProvider` (Task 7); `parseHex`, `toHex` (Task 2); `SpectraTextField`, `SpectraButton`, `SpectraCard`, `SpectraSectionHeader`, `SpectraHexHighlight`, `SpectraDialog`.
- Produces:
  - `class CardHexEditor extends ConsumerStatefulWidget` with `const CardHexEditor({required String id, required CardEditState state, super.key})`.
  - `String? chunkHexError(String text, int chunkSize, AppLocalizations l10n)` — the message for a bad chunk, null when the text is a valid chunk of exactly `chunkSize` bytes.
  - ARB keys: `cardsEditTitle`, `cardsEditChunkLabelBlock`, `cardsEditChunkLabelPage`, `cardsEditChunkLabelId`, `cardsEditValue`, `cardsEditApply`, `cardsEditBadHex`, `cardsEditBadLength`, `cardsEditBadIndex`, `cardsEditSave`, `cardsEditDiscard`, `cardsEditUnsavedTitle`, `cardsEditUnsavedBody`, `cardsEditNotEditable`.

- [ ] **Step 1: Write the failing test (appended to the Task 7 file)**

```dart
  testWidgetsApp('editing a block changes the dump and saves it', (
    tester,
  ) async {
    final String id = await seedAndOpen(tester);

    await tester.enterText(find.byKey(const Key('cardEditIndex')), '1');
    await tester.enterText(
      find.byKey(const Key('cardEditValue')),
      '000102030405060708090A0B0C0D0E0F',
    );
    await pumpFrames(tester);
    await tester.tap(find.text('Apply'));
    await pumpFrames(tester);

    // In memory only until Save.
    keepAlive(tester, cardEditorProvider(id));
    await pumpFrames(tester);
    final CardEditState edited =
        readProvider(tester, cardEditorProvider(id)).value!;
    expect(edited.dirty, isTrue);
    expect(edited.chunk(1), <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]);

    await tester.tap(find.text('Save changes'));
    await pumpFrames(tester, 20);

    final SavedCardsRepository repo =
        readProvider(tester, savedCardsRepositoryProvider);
    final SavedCard stored = (await repo.byId(id))!;
    expect(stored.bytes.sublist(16, 32), <int>[
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
    ]);
    expect(readProvider(tester, cardEditorProvider(id)).value!.dirty, isFalse);
  });

  testWidgetsApp('a bad hex value is refused before anything changes', (
    tester,
  ) async {
    final String id = await seedAndOpen(tester);

    await tester.enterText(find.byKey(const Key('cardEditIndex')), '1');
    await tester.enterText(find.byKey(const Key('cardEditValue')), 'zz');
    await pumpFrames(tester);
    await tester.tap(find.text('Apply'));
    await pumpFrames(tester);

    expect(find.text('That is not hex.'), findsOneWidget);
    keepAlive(tester, cardEditorProvider(id));
    await pumpFrames(tester);
    expect(readProvider(tester, cardEditorProvider(id)).value!.dirty, isFalse);
  });

  testWidgetsApp('a wrong-length value names the length it needs', (
    tester,
  ) async {
    await seedAndOpen(tester);
    await tester.enterText(find.byKey(const Key('cardEditIndex')), '1');
    await tester.enterText(find.byKey(const Key('cardEditValue')), 'AABB');
    await pumpFrames(tester);
    await tester.tap(find.text('Apply'));
    await pumpFrames(tester);
    expect(find.text('This card takes 16 bytes per block.'), findsOneWidget);
  });

  testWidgetsApp('discarding an edit puts the stored bytes back', (
    tester,
  ) async {
    final String id = await seedAndOpen(tester);
    await tester.enterText(find.byKey(const Key('cardEditIndex')), '1');
    await tester.enterText(
      find.byKey(const Key('cardEditValue')),
      '000102030405060708090A0B0C0D0E0F',
    );
    await pumpFrames(tester);
    await tester.tap(find.text('Apply'));
    await pumpFrames(tester);

    await tester.tap(find.text('Discard changes'));
    await pumpFrames(tester, 20);

    keepAlive(tester, cardEditorProvider(id));
    await pumpFrames(tester);
    final CardEditState reverted =
        readProvider(tester, cardEditorProvider(id)).value!;
    expect(reverted.dirty, isFalse);
    expect(reverted.chunk(1), everyElement(0));
  });
```

Add `import 'package:spectra/data/data.dart';` for `SavedCardsRepository`/`SavedCard` to that test file's imports.

- [ ] **Step 2: Run them and watch them fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/cards/card_detail_page_test.dart
```

Expected: FAIL — there is no editor on the screen.

- [ ] **Step 3: Add the ARB strings and regenerate**

```json
  "cardsEditTitle": "Edit",
  "@cardsEditTitle": {"description": "Heading of the dump editor."},
  "cardsEditChunkLabelBlock": "Block",
  "@cardsEditChunkLabelBlock": {"description": "Label of the block-number field."},
  "cardsEditChunkLabelPage": "Page",
  "@cardsEditChunkLabelPage": {"description": "Label of the page-number field."},
  "cardsEditChunkLabelId": "Id",
  "@cardsEditChunkLabelId": {"description": "Label of the LF id field."},
  "cardsEditValue": "Bytes (hex)",
  "@cardsEditValue": {"description": "Label of the hex value field."},
  "cardsEditApply": "Apply",
  "@cardsEditApply": {"description": "Applies the typed bytes to the working copy."},
  "cardsEditBadHex": "That is not hex.",
  "@cardsEditBadHex": {"description": "The typed value is not a hex string."},
  "cardsEditBadLength": "This card takes {size} bytes per block.",
  "@cardsEditBadLength": {
    "description": "The typed value is the wrong length.",
    "placeholders": {"size": {"type": "int"}}
  },
  "cardsEditBadIndex": "Choose a number between 0 and {last}.",
  "@cardsEditBadIndex": {
    "description": "The typed block or page number is out of range.",
    "placeholders": {"last": {"type": "int"}}
  },
  "cardsEditSave": "Save changes",
  "@cardsEditSave": {"description": "Writes the edited dump back to the library."},
  "cardsEditDiscard": "Discard changes",
  "@cardsEditDiscard": {"description": "Throws the edits away and reloads the stored dump."},
  "cardsEditUnsavedTitle": "Leave without saving?",
  "@cardsEditUnsavedTitle": {"description": "Title of the unsaved-changes guard."},
  "cardsEditUnsavedBody": "The edits to this dump have not been saved.",
  "@cardsEditUnsavedBody": {"description": "Body of the unsaved-changes guard."},
  "cardsEditNotEditable": "Spectra cannot edit this card's format yet.",
  "@cardsEditNotEditable": {"description": "Shown for a dump with no editable layout."},
```

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter gen-l10n
```

- [ ] **Step 4: Write the editor**

```dart
// app/lib/features/cards/ui/card_hex_editor.dart
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../state/card_editor_controller.dart';
import '../state/hex.dart';

/// The message for a chunk that cannot be applied, or null when [text] is a
/// valid hex run of exactly [chunkSize] bytes. Pure, so the rule is one
/// place and the widget only renders it.
String? chunkHexError(String text, int chunkSize, AppLocalizations l10n) {
  final Uint8List? bytes = parseHex(text);
  if (bytes == null) return l10n.cardsEditBadHex;
  if (bytes.length != chunkSize) return l10n.cardsEditBadLength(chunkSize);
  return null;
}

/// Edits one block, page or id at a time (spec 7.7 step 4).
///
/// Edits land in [CardEditor]'s working copy, not the database: "Apply"
/// changes the dump on screen, "Save changes" writes it. That split is what
/// makes an unsaved-changes guard meaningful, and it means a mistyped block
/// costs a Discard rather than a corrupted row.
class CardHexEditor extends ConsumerStatefulWidget {
  const CardHexEditor({required this.id, required this.state, super.key});

  final String id;
  final CardEditState state;

  @override
  ConsumerState<CardHexEditor> createState() => _CardHexEditorState();
}

class _CardHexEditorState extends ConsumerState<CardHexEditor> {
  final TextEditingController _index = TextEditingController(text: '0');
  final TextEditingController _value = TextEditingController();
  String? _indexError;
  String? _valueError;

  @override
  void dispose() {
    _index.dispose();
    _value.dispose();
    super.dispose();
  }

  String _chunkLabel(AppLocalizations l10n) => switch (widget.state.tagType.family) {
    TagFamily.ultralight => l10n.cardsEditChunkLabelPage,
    TagFamily.lf => l10n.cardsEditChunkLabelId,
    _ => l10n.cardsEditChunkLabelBlock,
  };

  void _apply(AppLocalizations l10n) {
    final int last = widget.state.chunkCount - 1;
    final int? index = int.tryParse(_index.text.trim());
    final String? indexError = index == null || index < 0 || index > last
        ? l10n.cardsEditBadIndex(last)
        : null;
    final String? valueError = chunkHexError(
      _value.text,
      widget.state.chunkSize,
      l10n,
    );
    setState(() {
      _indexError = indexError;
      _valueError = valueError;
    });
    if (indexError != null || valueError != null) return;
    ref
        .read(cardEditorProvider(widget.id).notifier)
        .replaceChunk(index!, parseHex(_value.text)!);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CardEditState state = widget.state;
    if (state.chunkSize == 0) {
      return SpectraCard(child: Text(l10n.cardsEditNotEditable));
    }
    return SpectraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SpectraSectionHeader(title: l10n.cardsEditTitle),
          SpectraTextField(
            key: const Key('cardEditIndex'),
            label: _chunkLabel(l10n),
            controller: _index,
            errorText: _indexError,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: SpectraSpacing.md),
          SpectraTextField(
            key: const Key('cardEditValue'),
            label: l10n.cardsEditValue,
            controller: _value,
            errorText: _valueError,
          ),
          const SizedBox(height: SpectraSpacing.md),
          SpectraButton(
            label: l10n.cardsEditApply,
            variant: SpectraButtonVariant.secondary,
            onPressed: () => _apply(l10n),
          ),
          if (state.dirty) ...<Widget>[
            const SizedBox(height: SpectraSpacing.lg),
            SpectraButton(
              label: l10n.cardsEditSave,
              onPressed: ref.read(cardEditorProvider(widget.id).notifier).save,
            ),
            const SizedBox(height: SpectraSpacing.md),
            SpectraButton(
              label: l10n.cardsEditDiscard,
              variant: SpectraButtonVariant.danger,
              onPressed:
                  ref.read(cardEditorProvider(widget.id).notifier).discard,
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Put it on the detail page, behind an unsaved-changes guard**

In `app/lib/features/cards/ui/card_detail_page.dart`:

1. `_Detail` gains `final String id;` (passed from `CardDetailPage.build` as `id: id`), and renders `CardHexEditor(id: id, state: state)` between the hex viewer and the delete button, with a `SizedBox(height: SpectraSpacing.lg)` above it.
2. Wrap the whole `SubPageScaffold` in a `PopScope` so leaving with unsaved edits asks first (`PopScope` comes from `package:flutter/widgets.dart`, re-exported by `material_ui`):

```dart
    final bool dirty = async.value?.dirty ?? false;
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop || !dirty) return;
        final bool? leave = await SpectraDialog.show<bool>(
          context: context,
          title: l10n.cardsEditUnsavedTitle,
          content: Text(l10n.cardsEditUnsavedBody),
          actions: (BuildContext context) => <Widget>[
            SpectraButton(
              label: l10n.commonCancel,
              variant: SpectraButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            SpectraButton(
              label: l10n.cardsEditDiscard,
              variant: SpectraButtonVariant.danger,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
        if (leave == true && context.mounted) GoRouter.of(context).go(AppRoutes.cards);
      },
      child: SubPageScaffold(/* … unchanged … */),
    );
```

`onPopInvokedWithResult` is the non-deprecated callback in Flutter 3.47; if the analyzer names a different signature, follow the analyzer — do not silence it.

- [ ] **Step 6: Run the tests and watch them pass**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/cards
cd .. && dart run melos run check:all
```

Expected: PASS, `check:all` green.

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/cards app/lib/l10n app/test/features/cards
git commit -m "feat(cards): edit a saved dump one chunk at a time

Spec 7.7 step 4 wants the dump editable. Edits land in a working copy so a
mistyped block costs a Discard rather than a corrupted row, and leaving with
unsaved edits asks first.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 9: Reading the reference app's JSON, and writing Spectra's own

Spec 3.5 and 7.3: "Import from the reference app's JSON export is a v1 requirement for cards … with fixtures built from the documented format", and "Spectra's own format is versioned JSON with a `schemaVersion`". This task is pure: parse in, serialise out, with a fixture.

Spec 7.3 asks for import "for cards and dictionaries"; dictionaries are Phase 9's deliverable (roadmap row 9), so this task covers cards only and leaves the dictionary reader to that phase.

**The reference app is GPL-3.0** (`AGENTS.md`, "Decisions already made"). Match the *format* — the field names its export writes — and never copy its code. `docs/research/reference-gui.md` line 10 records that the app exports cards as JSON with folders and colours but does not record the field-level shape, so the parser below is deliberately permissive and the exact spelling is a compatibility item on the H3 checklist (Task 14).

**Files:**
- Create: `app/lib/features/cards/state/card_import.dart`, `app/test/fixtures/reference_card_mifare_mini.json`
- Test: `app/test/features/cards/card_import_test.dart`

**Interfaces:**
- Consumes: `parseHex`, `toHex` (Task 2), `tagTypeFromName`, `tagTypeName`, `validateSavedCard`-style use of `DumpFormats`; `SavedCard`; `TagType`.
- Produces, frozen for Tasks 10-13:
  - `final class ImportedCard` — `const ImportedCard({required String name, required TagType tagType, required Uint8List bytes, String? folder, int? color})`.
  - `enum CardImportProblem { notJson, noCards, unsupportedTagType, badBytes }`
  - `final class CardImportException implements Exception` — `const CardImportException(CardImportProblem problem, String detail)`, with `toString()`.
  - `List<ImportedCard> parseCardsJson(String text)` — accepts Spectra's own export and the reference app's, throws `CardImportException` otherwise.
  - `String exportCardsJson(List<SavedCard> cards)` — Spectra's versioned format.
  - `const int spectraCardSchemaVersion = 1;`
  - `const Map<String, TagType> referenceTagNames`.

- [ ] **Step 1: Write the fixture**

`app/test/fixtures/reference_card_mifare_mini.json` — one MIFARE Classic Mini (5 sectors, 20 blocks of 16 bytes) in the reference app's shape: a list of card objects, each with `id`, `name`, `uid`, `sak`, `atqa`, `ats`, `tag`, `data` (one hex string per block) and `color`.

```json
[
  {
    "id": "3f7c1d20-0a1b-4c5d-8e9f-102030405060",
    "name": "Reference Mini",
    "uid": "DE:AD:BE:EF",
    "sak": "08",
    "atqa": "0400",
    "ats": "",
    "tag": "mifareMini",
    "color": 4284790262,
    "folder": "Imported",
    "data": [
      "DEADBEEF2208040001020304050607 08",
      "00000000000000000000000000000000",
      "00000000000000000000000000000000",
      "FFFFFFFFFFFFFF078069FFFFFFFFFFFF",
      "00000000000000000000000000000000",
      "00000000000000000000000000000000",
      "00000000000000000000000000000000",
      "FFFFFFFFFFFFFF078069FFFFFFFFFFFF",
      "00000000000000000000000000000000",
      "00000000000000000000000000000000",
      "00000000000000000000000000000000",
      "FFFFFFFFFFFFFF078069FFFFFFFFFFFF",
      "00000000000000000000000000000000",
      "00000000000000000000000000000000",
      "00000000000000000000000000000000",
      "FFFFFFFFFFFFFF078069FFFFFFFFFFFF",
      "00000000000000000000000000000000",
      "00000000000000000000000000000000",
      "00000000000000000000000000000000",
      "FFFFFFFFFFFFFF078069FFFFFFFFFFFF"
    ]
  }
]
```

Block 0 is `DEADBEEF` + BCC `22` (`0xDE^0xAD^0xBE^0xEF`) + SAK `08` + ATQA `0400` + eight manufacturer bytes; the embedded space is deliberate, and proves the parser tolerates the separators a hand-edited export carries. Every fourth block is a sector trailer with the transport key and the default access bits, so `MifareClassicFormat.validate` passes on the result.

- [ ] **Step 2: Write the failing test**

```dart
// app/test/features/cards/card_import_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/features/cards/state/card_codec.dart';
import 'package:spectra/features/cards/state/card_import.dart';

void main() {
  test('imports the reference app fixture', () {
    final String text = File(
      'test/fixtures/reference_card_mifare_mini.json',
    ).readAsStringSync();
    final List<ImportedCard> cards = parseCardsJson(text);

    expect(cards, hasLength(1));
    final ImportedCard card = cards.single;
    expect(card.name, 'Reference Mini');
    expect(card.tagType, TagType.mifareMini);
    expect(card.bytes, hasLength(20 * 16));
    expect(card.bytes.sublist(0, 5), <int>[0xDE, 0xAD, 0xBE, 0xEF, 0x22]);
    expect(card.folder, 'Imported');
    expect(card.color, 4284790262);

    // The imported bytes are a valid dump, not just the right length.
    expect(
      validateSavedCard(
        SavedCard(
          id: 'x',
          name: card.name,
          tagType: tagTypeName(card.tagType),
          bytes: card.bytes,
          updatedAt: DateTime.utc(2026, 9, 3),
        ),
      ),
      isEmpty,
    );
  });

  test('imports a single object as well as a list', () {
    const String single =
        '{"name":"One","tag":"em410X","uid":"1234567890","data":[]}';
    final ImportedCard card = parseCardsJson(single).single;
    expect(card.tagType, TagType.em410x);
    expect(card.bytes, <int>[0x12, 0x34, 0x56, 0x78, 0x90]);
  });

  test('round-trips Spectra\'s own export', () {
    final SavedCard saved = SavedCard(
      id: 'a',
      name: 'Office badge',
      tagType: 'mifare1k',
      bytes: Uint8List(64 * 16)..[0] = 0xAB,
      updatedAt: DateTime.utc(2026, 9, 3),
      folder: 'Work',
      color: 0xFF4C8DFF,
    );
    final String text = exportCardsJson(<SavedCard>[saved]);
    expect(text, contains('"schemaVersion":$spectraCardSchemaVersion'));

    final ImportedCard back = parseCardsJson(text).single;
    expect(back.name, 'Office badge');
    expect(back.tagType, TagType.mifare1k);
    expect(back.bytes.length, 64 * 16);
    expect(back.bytes[0], 0xAB);
    expect(back.folder, 'Work');
    expect(back.color, 0xFF4C8DFF);
  });

  test('a non-JSON string is a typed problem', () {
    expect(
      () => parseCardsJson('not json at all'),
      throwsA(
        isA<CardImportException>().having(
          (CardImportException e) => e.problem,
          'problem',
          CardImportProblem.notJson,
        ),
      ),
    );
  });

  test('an empty list is a typed problem', () {
    expect(
      () => parseCardsJson('[]'),
      throwsA(
        isA<CardImportException>().having(
          (CardImportException e) => e.problem,
          'problem',
          CardImportProblem.noCards,
        ),
      ),
    );
  });

  test('a tag type Spectra has no format for is refused by name', () {
    expect(
      () => parseCardsJson('{"name":"x","tag":"iso15693","data":[]}'),
      throwsA(
        isA<CardImportException>()
            .having(
              (CardImportException e) => e.problem,
              'problem',
              CardImportProblem.unsupportedTagType,
            )
            .having(
              (CardImportException e) => e.detail,
              'detail',
              contains('iso15693'),
            ),
      ),
    );
  });

  test('non-hex data is refused', () {
    expect(
      () => parseCardsJson('{"name":"x","tag":"mifare1K","data":["zzzz"]}'),
      throwsA(
        isA<CardImportException>().having(
          (CardImportException e) => e.problem,
          'problem',
          CardImportProblem.badBytes,
        ),
      ),
    );
  });
}
```

- [ ] **Step 3: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/cards/card_import_test.dart
```

Expected: FAIL — `card_import.dart` does not exist.

- [ ] **Step 4: Write the parser**

```dart
// app/lib/features/cards/state/card_import.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';

import '../../../data/data.dart';
import 'card_codec.dart';
import 'hex.dart';

/// Spec 7.3: import from the reference app's JSON export, and Spectra's own
/// versioned format.
///
/// The reference app (GameTec-live/ChameleonUltraGUI) is GPL-3.0. Only its
/// *format* is matched here — the field names its export writes — never its
/// code (`AGENTS.md`). `docs/research/reference-gui.md` records that it
/// exports cards as JSON with folders and colours but not the field-level
/// shape, so the reader below is deliberately permissive: a card may arrive
/// as a bare object, a list of objects, or an object with a `cards` list; hex
/// may carry spaces or colons; the tag name is matched case-insensitively
/// against both the reference spellings and Spectra's own `TagType.name`.
/// Verifying it against a real export is an H3 checklist item.

/// What Spectra writes. Bumped only when the shape changes incompatibly.
const int spectraCardSchemaVersion = 1;

/// The reference app's tag names, mapped to the SDK's enum. Case-insensitive
/// at the call site; only the families with a `DumpFormat` (spec 3.5) are
/// here, because there is nothing to store for the others.
const Map<String, TagType> referenceTagNames = <String, TagType>{
  'mifaremini': TagType.mifareMini,
  'mifare1k': TagType.mifare1k,
  'mifare2k': TagType.mifare2k,
  'mifare4k': TagType.mifare4k,
  'ntag210': TagType.ntag210,
  'ntag212': TagType.ntag212,
  'ntag213': TagType.ntag213,
  'ntag215': TagType.ntag215,
  'ntag216': TagType.ntag216,
  'ultralight': TagType.mf0icu1,
  'ultralightc': TagType.mf0icu2,
  'ultralight11': TagType.mf0ul11,
  'ultralight21': TagType.mf0ul21,
  'em410x': TagType.em410x,
};

/// Why an import could not be read.
enum CardImportProblem {
  /// The text is not JSON, or not a shape this reader understands.
  notJson,

  /// Valid JSON with no cards in it.
  noCards,

  /// A card names a tag type Spectra has no dump format for.
  unsupportedTagType,

  /// A card's data is not hex, or is empty.
  badBytes,
}

final class CardImportException implements Exception {
  const CardImportException(this.problem, this.detail);
  final CardImportProblem problem;

  /// The raw line spec 9 puts one tap away.
  final String detail;

  @override
  String toString() => 'CardImportException(${problem.name}: $detail)';
}

/// One card from an import, before it is given an id and saved.
final class ImportedCard {
  const ImportedCard({
    required this.name,
    required this.tagType,
    required this.bytes,
    this.folder,
    this.color,
  });

  final String name;
  final TagType tagType;
  final Uint8List bytes;
  final String? folder;
  final int? color;
}

/// Reads either format. Throws [CardImportException] and nothing else.
List<ImportedCard> parseCardsJson(String text) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (e) {
    throw CardImportException(CardImportProblem.notJson, e.message);
  }

  final List<Object?> raw = switch (decoded) {
    final List<Object?> list => list,
    final Map<String, Object?> map when map['cards'] is List<Object?> =>
      map['cards']! as List<Object?>,
    final Map<String, Object?> map => <Object?>[map],
    _ => throw const CardImportException(
      CardImportProblem.notJson,
      'expected an object or a list of objects',
    ),
  };
  if (raw.isEmpty) {
    throw const CardImportException(
      CardImportProblem.noCards,
      'the file holds no cards',
    );
  }
  return <ImportedCard>[
    for (final Object? entry in raw) _readCard(entry),
  ];
}

ImportedCard _readCard(Object? entry) {
  if (entry is! Map<String, Object?>) {
    throw const CardImportException(
      CardImportProblem.notJson,
      'a card entry is not an object',
    );
  }
  final String tagName = (entry['tag'] ?? entry['tagType'] ?? '').toString();
  final TagType type =
      referenceTagNames[tagName.toLowerCase()] ?? tagTypeFromName(tagName);
  if (type == TagType.undefined || DumpFormats.forType(type) == null) {
    throw CardImportException(
      CardImportProblem.unsupportedTagType,
      'no dump format for tag type "$tagName"',
    );
  }

  final Uint8List bytes = _readBytes(entry, type);
  return ImportedCard(
    name: (entry['name'] ?? '').toString().trim().isEmpty
        ? tagName
        : entry['name'].toString().trim(),
    tagType: type,
    bytes: bytes,
    folder: entry['folder']?.toString(),
    color: entry['color'] is int ? entry['color']! as int : null,
  );
}

/// The dump, from `data` (one hex string per block or page) or — for an LF
/// card, which the reference app stores as an id rather than a dump — from
/// `uid`.
Uint8List _readBytes(Map<String, Object?> entry, TagType type) {
  final Object? data = entry['data'];
  final List<Object?> rows = data is List<Object?> ? data : const <Object?>[];
  if (rows.isEmpty) {
    final Uint8List? id = parseHex((entry['uid'] ?? '').toString());
    if (id == null || id.isEmpty) {
      throw const CardImportException(
        CardImportProblem.badBytes,
        'the card has neither data rows nor a uid',
      );
    }
    return id;
  }
  final BytesBuilder out = BytesBuilder();
  for (final Object? row in rows) {
    final Uint8List? bytes = parseHex(row.toString());
    if (bytes == null) {
      throw CardImportException(
        CardImportProblem.badBytes,
        'row "$row" is not hex',
      );
    }
    out.add(bytes);
  }
  return out.toBytes();
}

/// Spectra's own export: versioned, with the dump as one hex string per card
/// so the file stays diffable and hand-editable.
String exportCardsJson(List<SavedCard> cards) => jsonEncode(<String, Object?>{
  'schemaVersion': spectraCardSchemaVersion,
  'cards': <Object?>[
    for (final SavedCard card in cards)
      <String, Object?>{
        'name': card.name,
        'tag': card.tagType,
        'folder': card.folder,
        'color': card.color,
        'updatedAt': card.updatedAt.toIso8601String(),
        'data': <String>[toHex(card.bytes)],
      },
  ],
});
```

- [ ] **Step 5: Run the tests and watch them pass**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/cards/card_import_test.dart
cd .. && dart run melos run check:all
```

Expected: PASS, `check:all` green.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/cards/state/card_import.dart app/test/fixtures app/test/features/cards/card_import_test.dart
git commit -m "feat(cards): read the reference app's JSON and write Spectra's

Spec 7.3 makes importing the reference app's export a v1 requirement. Only
the format is matched — the app is GPL and none of its code is used — and
the reader is permissive because the field-level shape is not documented in
this repo; verifying it against a real export is an H3 item.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 10: The import and export UI

Task 9's parser, on screen. Import is a paste sheet; export puts Spectra's JSON on the clipboard, the same affordance the frame log already uses (`features/tools/ui/frame_log_page.dart`).

**Decision recorded here, not assumed:** v1 has no native file-open dialog. Adding one means a new dependency (`file_selector` or `file_picker`) plus per-platform setup on all five targets, and spec section 2's dependency table would have to be amended for it — the same gate `crypto` went through. Pasting the exported text works on every platform today, needs nothing new, and is fully testable. Task 14 records this in `docs/research/DECISIONS.md` as a deliberate v1 limitation for Phase 9's export work to revisit.

**Files:**
- Create: `app/lib/features/cards/ui/card_import_sheet.dart`
- Modify: `app/lib/features/cards/ui/cards_page.dart`, `app/lib/features/cards/ui/card_detail_page.dart`, `app/lib/features/cards/state/saved_cards_provider.dart`, `app/lib/features/cards/cards.dart`, `app/lib/l10n/app_en.arb` (**owns the ARB**)
- Test: `app/test/features/cards/card_import_sheet_test.dart`

**Interfaces:**
- Consumes: `parseCardsJson`, `exportCardsJson`, `ImportedCard`, `CardImportException`, `CardImportProblem` (Task 9); `CardLibrary`, `cardLibraryProvider`, `newCardId` (Task 5); `SpectraBottomSheet.show`, `SpectraTextField`, `SpectraButton`; `Clipboard.setData(ClipboardData(text: …))` from `package:flutter/services.dart`.
- Produces:
  - `CardLibrary.importJson(String text)` → `Future<int>`: the number of cards written; 0 with the failure in `state` when the text could not be read.
  - `Future<int?> showCardImportSheet(BuildContext context)` — the count imported, or null when dismissed.
  - ARB keys: `cardsImport`, `cardsImportTitle`, `cardsImportHint`, `cardsImportLabel`, `cardsImportConfirm`, `cardsImported`, `cardsImportNotJson`, `cardsImportNoCards`, `cardsImportUnsupported`, `cardsImportBadBytes`, `cardsExport`, `cardsExported`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/cards/card_import_sheet_test.dart
import 'dart:io';
import 'dart:ui';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/data/data.dart';
import 'package:spectra/features/cards/state/saved_cards_provider.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

Future<void> pumpFrames(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> openImport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpTestApp(tester, transport: (_) => FakeDevice());
  await connectToEmulator(tester);
  await tester.tap(find.text('Cards').last);
  await pumpFrames(tester);
  await tester.tap(find.text('Import'));
  await pumpFrames(tester);
}

void main() {
  testWidgetsApp('pasting the fixture puts a card in the library', (
    tester,
  ) async {
    await openImport(tester);
    final String fixture = File(
      'test/fixtures/reference_card_mifare_mini.json',
    ).readAsStringSync();

    await tester.enterText(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(SpectraTextField),
      ),
      fixture,
    );
    await pumpFrames(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Import'),
      ),
    );
    await pumpFrames(tester, 20);

    keepAlive(tester, savedCardsProvider);
    await pumpFrames(tester);
    final List<SavedCard> cards =
        readProvider(tester, savedCardsProvider).value ?? const <SavedCard>[];
    expect(cards, hasLength(1));
    expect(cards.single.name, 'Reference Mini');
    expect(cards.single.tagType, 'mifareMini');
    expect(cards.single.bytes, hasLength(20 * 16));
    expect(cards.single.folder, 'Imported');
    expect(find.text('Reference Mini'), findsOneWidget);
  });

  testWidgetsApp('an unreadable paste explains itself and writes nothing', (
    tester,
  ) async {
    await openImport(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(SpectraTextField),
      ),
      'not json at all',
    );
    await pumpFrames(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Import'),
      ),
    );
    await pumpFrames(tester, 10);

    expect(
      find.text('That text is not a card export Spectra can read.'),
      findsOneWidget,
    );
    keepAlive(tester, savedCardsProvider);
    await pumpFrames(tester);
    expect(
      readProvider(tester, savedCardsProvider).value ?? const <Object>[],
      isEmpty,
    );
  });

  testWidgetsApp('an unsupported tag type says which one', (tester) async {
    await openImport(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(SpectraTextField),
      ),
      '{"name":"x","tag":"iso15693","data":[]}',
    );
    await pumpFrames(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Import'),
      ),
    );
    await pumpFrames(tester, 10);
    expect(
      find.textContaining('Spectra cannot read that tag type'),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/cards/card_import_sheet_test.dart
```

Expected: FAIL — there is no `Import` entry on the library screen.

- [ ] **Step 3: Add the ARB strings and regenerate**

```json
  "cardsImport": "Import",
  "@cardsImport": {"description": "Opens the import sheet, and confirms the import inside it."},
  "cardsImportTitle": "Import cards",
  "@cardsImportTitle": {"description": "Title of the import sheet."},
  "cardsImportHint": "Paste a card export from Spectra or from the Chameleon Ultra GUI.",
  "@cardsImportHint": {"description": "Explains what may be pasted."},
  "cardsImportLabel": "Exported JSON",
  "@cardsImportLabel": {"description": "Label of the paste field."},
  "cardsImported": "Imported {count} cards.",
  "@cardsImported": {
    "description": "Confirms how many cards were imported.",
    "placeholders": {"count": {"type": "int"}}
  },
  "cardsImportNotJson": "That text is not a card export Spectra can read.",
  "@cardsImportNotJson": {"description": "The pasted text is not JSON."},
  "cardsImportNoCards": "That export has no cards in it.",
  "@cardsImportNoCards": {"description": "The pasted export is empty."},
  "cardsImportUnsupported": "Spectra cannot read that tag type yet.",
  "@cardsImportUnsupported": {"description": "The export names a tag type with no dump format."},
  "cardsImportBadBytes": "That export's card data could not be read.",
  "@cardsImportBadBytes": {"description": "A card's data rows are not hex."},
  "cardsExport": "Copy as JSON",
  "@cardsExport": {"description": "Puts the card's export on the clipboard."},
  "cardsExported": "Copied to the clipboard.",
  "@cardsExported": {"description": "Confirms the export reached the clipboard."},
```

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter gen-l10n
```

- [ ] **Step 4: Add `importJson` to the library notifier**

In `app/lib/features/cards/state/saved_cards_provider.dart` (add `import 'card_import.dart';`):

```dart
  /// Parses [text] in either supported format and writes every card it holds.
  /// Returns how many were written; 0 with the [CardImportException] in
  /// `state` when the text could not be read, so the sheet renders the
  /// failure through the same catalog every other error uses.
  Future<int> importJson(String text) async {
    if (_inFlight) return 0;
    _inFlight = true;
    state = const AsyncLoading<void>();
    try {
      final List<ImportedCard> cards = parseCardsJson(text);
      final SavedCardsRepository repo = ref.read(savedCardsRepositoryProvider);
      for (final ImportedCard card in cards) {
        await repo.save(
          SavedCard(
            id: newCardId(),
            name: card.name,
            tagType: tagTypeName(card.tagType),
            bytes: card.bytes,
            updatedAt: DateTime.now(),
            folder: card.folder,
            color: card.color,
          ),
        );
      }
      state = const AsyncData<void>(null);
      return cards.length;
    } on Object catch (error, stack) {
      state = AsyncError<void>(error, stack);
      return 0;
    } finally {
      _inFlight = false;
    }
  }
```

- [ ] **Step 5: Write the import sheet**

```dart
// app/lib/features/cards/ui/card_import_sheet.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../state/card_import.dart';
import '../state/saved_cards_provider.dart';

/// The words for an import failure. Spec 9 keeps errors typed to the UI, so
/// this switches on the problem rather than showing the exception's text; the
/// raw line is still one tap away in [CardsProblemView].
String importProblemMessage(
  CardImportProblem problem,
  AppLocalizations l10n,
) => switch (problem) {
  CardImportProblem.notJson => l10n.cardsImportNotJson,
  CardImportProblem.noCards => l10n.cardsImportNoCards,
  CardImportProblem.unsupportedTagType => l10n.cardsImportUnsupported,
  CardImportProblem.badBytes => l10n.cardsImportBadBytes,
};

/// Spec 7.3: import from the reference app's export. Resolves to the number
/// of cards written, or null when the sheet was dismissed.
Future<int?> showCardImportSheet(BuildContext context) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return SpectraBottomSheet.show<int>(
    context: context,
    title: l10n.cardsImportTitle,
    builder: (BuildContext context) => const _ImportForm(),
  );
}

class _ImportForm extends ConsumerStatefulWidget {
  const _ImportForm();

  @override
  ConsumerState<_ImportForm> createState() => _ImportFormState();
}

class _ImportFormState extends ConsumerState<_ImportForm> {
  final TextEditingController _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final NavigatorState navigator = Navigator.of(context);
    setState(() => _error = null);
    final int count = await ref
        .read(cardLibraryProvider.notifier)
        .importJson(_text.text);
    if (!mounted) return;
    if (count == 0) {
      final Object? failure = ref.read(cardLibraryProvider).error;
      setState(() {
        _error = failure is CardImportException
            ? importProblemMessage(failure.problem, l10n)
            : l10n.cardsImportNotJson;
      });
      return;
    }
    navigator.pop(count);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool busy = ref.watch(cardLibraryProvider).isLoading;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.cardsImportHint),
        const SizedBox(height: SpectraSpacing.md),
        SpectraTextField(
          label: l10n.cardsImportLabel,
          controller: _text,
          errorText: _error,
        ),
        const SizedBox(height: SpectraSpacing.lg),
        SpectraButton(
          label: l10n.cardsImport,
          busy: busy,
          onPressed: busy ? null : _import,
        ),
      ],
    );
  }
}
```

`SpectraTextField` is single-line; a pasted export still goes in whole (the field scrolls) and the test proves it. If a multi-line field is ever wanted, it is a `maxLines` parameter on the design-system component — a Phase 9 change, not one to make here.

- [ ] **Step 6: Add the two entry points**

`cards_page.dart`: put an `Import` button next to the `Read a card` button:

```dart
        const SizedBox(height: SpectraSpacing.md),
        SpectraButton(
          label: l10n.cardsImport,
          icon: Icons.file_download_outlined,
          variant: SpectraButtonVariant.secondary,
          onPressed: () => showCardImportSheet(context),
        ),
```

`card_detail_page.dart`: in `_Detail`, above the delete button:

```dart
        SpectraButton(
          label: l10n.cardsExport,
          variant: SpectraButtonVariant.secondary,
          onPressed: () async {
            final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
            final String text = exportCardsJson(<SavedCard>[state.card]);
            await Clipboard.setData(ClipboardData(text: text));
            messenger.showSnackBar(
              SnackBar(content: Text(l10n.cardsExported)),
            );
          },
        ),
        const SizedBox(height: SpectraSpacing.md),
```

with `import 'package:flutter/services.dart';`, `import '../../../data/data.dart';` and `import '../state/card_import.dart';` added. Export the sheet from `cards.dart` (`export 'ui/card_import_sheet.dart';`).

- [ ] **Step 7: Regenerate, run the tests and watch them pass**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && dart run build_runner build --delete-conflicting-outputs
flutter test test/features/cards
cd .. && dart run melos run check:all
```

Expected: PASS, `check:all` green.

- [ ] **Step 8: Commit**

```bash
git add app/lib/features/cards app/lib/l10n app/test/features/cards
git commit -m "feat(cards): import pasted card exports and copy one out

Spec 7.3 makes importing the reference app's export a v1 requirement. Paste
rather than a file dialog: a native picker is a new dependency on five
platforms and a spec section 2 amendment, and pasting works everywhere today.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 11: The public card picker API

Spec 8.3: "`cards` exports the card picker and its providers". This is the contract Phase 7's "load a saved card into a slot" and "write to a physical card" call, so it is documented as a contract, exported from the barrel, and tested from outside the feature — the shape `showSlotPicker` already set in `features/slots/ui/slot_picker.dart`.

**Files:**
- Create: `app/lib/features/cards/ui/card_picker.dart`
- Modify: `app/lib/features/cards/cards.dart`, `app/lib/l10n/app_en.arb` (**owns the ARB**)
- Test: `app/test/features/cards/card_picker_test.dart`

**Interfaces:**
- Consumes: `savedCardsProvider`, `SavedCard`, `cardsFilterStateProvider`/`filterCards` are **not** used (the picker shows the whole library, newest first — a picker is not the library screen); `tagTypeFromName` (Task 2); `SpectraBottomSheet.show`, `SpectraListTile`, `SpectraCard`.
- Produces, **frozen for Phase 7**:
  - `Future<SavedCard?> showCardPicker(BuildContext context, {bool Function(SavedCard card)? isSelectable})` — presents the sheet and resolves to the chosen card, or null if dismissed.
  - `class CardPicker extends ConsumerWidget` with `const CardPicker({bool Function(SavedCard)? isSelectable, super.key})` — the sheet's body, for a caller that wants it inline.
  - Re-exported from `package:spectra/features/cards/cards.dart` together with `savedCardsProvider`, `tagTypeFromName`, `tagTypeName` and `SavedCard`-shaped helpers.
  - ARB key: `cardsPickerTitle`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/cards/card_picker_test.dart
import 'dart:typed_data';
import 'dart:ui';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/data/data.dart';
import 'package:spectra/features/cards/cards.dart';
import 'package:spectra/features/cards/state/saved_cards_provider.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

Future<void> pumpFrames(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<CardLibrary> openCards(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpTestApp(tester, transport: (_) => FakeDevice());
  await connectToEmulator(tester);
  keepAlive(tester, cardLibraryProvider);
  await tester.tap(find.text('Cards').last);
  await pumpFrames(tester);
  return readProvider(tester, cardLibraryProvider.notifier);
}

Future<void> add(
  WidgetTester tester,
  CardLibrary library,
  String name,
  TagType type,
) async {
  final Future<String?> pending = library.add(
    name: name,
    type: type,
    bytes: Uint8List(type == TagType.em410x ? 5 : 64 * 16),
  );
  await tester.pump(const Duration(milliseconds: 20));
  await pending;
  await pumpFrames(tester);
}

void main() {
  testWidgetsApp('the picker resolves to the chosen card', (tester) async {
    final CardLibrary library = await openCards(tester);
    await add(tester, library, 'Office badge', TagType.mifare1k);

    SavedCard? chosen;
    final BuildContext context = tester.element(find.byType(CardsPage));
    final Future<SavedCard?> pending = showCardPicker(context).then((
      SavedCard? c,
    ) {
      chosen = c;
      return c;
    });
    await pumpFrames(tester);
    expect(find.text('Choose a card'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Office badge'),
      ),
    );
    await pumpFrames(tester);
    await pending;
    expect(chosen!.name, 'Office badge');
    expect(chosen!.tagType, 'mifare1k');
  });

  testWidgetsApp('dismissing the picker resolves to null', (tester) async {
    final CardLibrary library = await openCards(tester);
    await add(tester, library, 'Office badge', TagType.mifare1k);

    final BuildContext context = tester.element(find.byType(CardsPage));
    final Future<SavedCard?> pending = showCardPicker(context);
    await pumpFrames(tester);
    await tester.tap(find.byIcon(Icons.close));
    await pumpFrames(tester);
    expect(await pending, isNull);
  });

  testWidgetsApp('isSelectable greys out the cards a caller cannot use', (
    tester,
  ) async {
    final CardLibrary library = await openCards(tester);
    await add(tester, library, 'Office badge', TagType.mifare1k);
    await add(tester, library, 'Gate fob', TagType.em410x);

    final BuildContext context = tester.element(find.byType(CardsPage));
    final Future<SavedCard?> pending = showCardPicker(
      context,
      isSelectable: (SavedCard c) =>
          tagTypeFromName(c.tagType).family == TagFamily.mifareClassic,
    );
    await pumpFrames(tester);

    final Iterable<SpectraListTile> tiles = tester.widgetList<SpectraListTile>(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(SpectraListTile),
      ),
    );
    expect(
      tiles.firstWhere((SpectraListTile t) => t.title == 'Office badge').onTap,
      isNotNull,
    );
    expect(
      tiles.firstWhere((SpectraListTile t) => t.title == 'Gate fob').onTap,
      isNull,
    );

    await tester.tap(find.byIcon(Icons.close));
    await pumpFrames(tester);
    await pending;
  });

  testWidgetsApp('an empty library shows the empty state', (tester) async {
    await openCards(tester);
    final BuildContext context = tester.element(find.byType(CardsPage));
    final Future<SavedCard?> pending = showCardPicker(context);
    await pumpFrames(tester);
    expect(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('No cards yet. Read one, or import from another app.'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(Icons.close));
    await pumpFrames(tester);
    await pending;
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/cards/card_picker_test.dart
```

Expected: FAIL — `showCardPicker` is not exported from the barrel.

- [ ] **Step 3: Add the ARB string and regenerate**

```json
  "cardsPickerTitle": "Choose a card",
  "@cardsPickerTitle": {"description": "Title of the card picker sheet other features open."},
```

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter gen-l10n
```

- [ ] **Step 4: Write the picker**

```dart
// app/lib/features/cards/ui/card_picker.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../data/data.dart';
import '../../../l10n/app_localizations.dart';
import '../state/card_codec.dart';
import '../state/saved_cards_provider.dart';

/// **The Cards feature's public API** (spec 8.3). Asks the user which saved
/// card to use, and resolves to that [SavedCard] — dump bytes and all — or
/// null if the sheet was dismissed.
///
/// Contract for the features that call it (Phase 7's "load to slot", "write
/// to card" and "quick emulate"):
///
/// - Import it as `package:spectra/features/cards/cards.dart`. Never reach
///   into `features/cards/ui/…` or `features/cards/state/…` (spec 8.4).
/// - The whole card comes back, so a caller needs no second lookup:
///   `card.bytes` is the dump and `tagTypeFromName(card.tagType)` is its
///   [TagType]. Both are exported from the same barrel.
/// - It resolves to null on dismissal, and callers must handle that: it is
///   the normal way out of the sheet, not an error.
/// - [isSelectable] filters what may be chosen — an unselectable card is
///   still listed, greyed and untappable, so the user can see why a card is
///   not on offer. Pass, say,
///   `(c) => tagTypeFromName(c.tagType).family == TagFamily.mifareClassic`
///   to restrict a MIFARE Classic write target.
/// - With an empty library the sheet shows the empty state and can only be
///   dismissed; it never reads a card of its own to fill itself.
/// - It changes nothing — not the device, not the library. Choosing a card
///   is a choice; the caller does the write.
Future<SavedCard?> showCardPicker(
  BuildContext context, {
  bool Function(SavedCard card)? isSelectable,
}) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return SpectraBottomSheet.show<SavedCard>(
    context: context,
    title: l10n.cardsPickerTitle,
    builder: (BuildContext context) => CardPicker(isSelectable: isSelectable),
  );
}

/// The picker's body, for a caller that wants it inline rather than modal.
/// Pops the enclosing route with the chosen card.
///
/// It lists the whole library newest-first — a picker is not the library
/// screen, so it deliberately carries no search, folder filter or sort.
class CardPicker extends ConsumerWidget {
  const CardPicker({this.isSelectable, super.key});

  final bool Function(SavedCard card)? isSelectable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<SavedCard> cards =
        ref.watch(savedCardsProvider).value ?? const <SavedCard>[];
    if (cards.isEmpty) return SpectraCard(child: Text(l10n.cardsEmpty));

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: cards.length,
        separatorBuilder: (BuildContext context, int i) =>
            const SizedBox(height: SpectraSpacing.sm),
        itemBuilder: (BuildContext context, int i) {
          final SavedCard card = cards[i];
          final bool selectable = isSelectable?.call(card) ?? true;
          return SpectraListTile(
            title: card.name,
            subtitle: l10n.cardsSubtitle(
              tagTypeFromName(card.tagType).name,
              card.folder ?? '',
            ),
            leading: Icon(
              Icons.circle,
              color: card.color == null
                  ? SpectraTheme.of(context).colors.border
                  : Color(card.color!),
            ),
            onTap: selectable ? () => Navigator.of(context).pop(card) : null,
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 5: Write the barrel**

`app/lib/features/cards/cards.dart`, in full:

```dart
/// The Cards feature's public API (spec 8.3): its screens, and the card
/// picker other features call to ask "which card?".
///
/// Nothing else in the app may import `features/cards/…` directly. The
/// picker's contract is on [showCardPicker].
library;

export 'state/card_codec.dart' show tagTypeFromName, tagTypeName;
export 'state/saved_cards_provider.dart' show cardColors, savedCardsProvider;
export 'ui/card_detail_page.dart';
export 'ui/card_import_sheet.dart' show showCardImportSheet;
export 'ui/card_picker.dart';
export 'ui/cards_page.dart';
export 'ui/cards_problem_view.dart';
export 'ui/read_page.dart';
```

If `show savedCardsProvider` does not compile because the generated provider's own type is needed at a call site, widen it to `show savedCardsProvider, SavedCardsProvider` — but do not export the file wholesale: the barrel is a contract, not an accident.

- [ ] **Step 6: Run the tests and watch them pass**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/cards
cd .. && dart run melos run check:all
```

Expected: PASS, and `lint:deps` stays green — the export list is the feature's only surface.

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/cards app/lib/l10n app/test/features/cards
git commit -m "feat(cards): export the card picker as the feature's public API

Spec 8.3 makes the picker the one surface other features touch, so its
contract — the whole card out, null on dismissal, no writes of its own — is
documented where Phase 7 will read it.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 12: Cards in the field for the emulated device

Spec 7.5: "Every feature works there" — the emulated Chameleon is how screenshots and manual QA happen without hardware. A bare `FakeDevice` has no card in its field (`FakeFirmware.hfCard`/`lfCard` start null), so reading in emulator mode would always answer "no card found". This task scripts the fake's reader, which is exactly what spec 4.4 says it is for.

**Files:**
- Create: `app/lib/core/emulator/demo_cards.dart`
- Modify: `app/lib/core/session/sessions.dart`
- Test: `app/test/core/emulator/demo_cards_test.dart`

**Interfaces:**
- Consumes: `FakeDevice({FakeFirmware? firmware, Duration latency, int chunkSize, TransportError? openError})`, `FakeFirmware([FakeFirmwareConfig? config])` with `void present(FakeCard card)`, `FakeMf1Card.classic1k({required Uint8List uid})`, `FakeLfCard(int scanCommandId, Uint8List idBytes)`, `DiscoveredDevice`, `TransportKind`, `Transport` (`package:chameleon/chameleon.dart`); `ChameleonTransports.transportFor` (`package:chameleon_flutter/chameleon_flutter.dart`); `transportFactoryProvider` (`app/lib/core/session/sessions.dart`).
- Produces:
  - `FakeDevice buildEmulatedDevice()` — a fake with one MIFARE Classic 1K (UID `DE AD BE EF`) in its HF field and one EM410x (`12 34 56 78 9A`) in its LF field.
  - `Transport emulatorAwareTransport(DiscoveredDevice device)` — `buildEmulatedDevice()` for `TransportKind.fake`, `ChameleonTransports.transportFor(device)` otherwise; the new body of `transportFactoryProvider`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/core/emulator/demo_cards_test.dart
import 'dart:ui';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/emulator/demo_cards.dart';

import '../../support/app_harness.dart';

void main() {
  test('the emulated device has a card in each field', () {
    final FakeDevice device = buildEmulatedDevice();
    expect(device.firmware.hfCard, isA<FakeMf1Card>());
    expect(device.firmware.lfCard, isA<FakeLfCard>());
  });

  test('a real device still goes through the platform transports', () {
    // A fake-kind device is the only one this may special-case.
    expect(
      emulatorAwareTransport(FakeScanner.emulatedUltra),
      isA<FakeDevice>(),
    );
  });

  testWidgetsApp('reading in emulator mode finds the demo card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // No transport override: the production factory runs, which is the point.
    await pumpTestApp(tester);
    await connectToEmulator(tester);
    await tester.tap(find.text('Cards').last);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Read a card'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Scan high frequency'));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('DEADBEEF'), findsOneWidget);
    expect(find.text('Save to library'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/core/emulator/demo_cards_test.dart
```

Expected: FAIL — `demo_cards.dart` does not exist, and the emulated read finds nothing.

- [ ] **Step 3: Write the demo cards**

```dart
// app/lib/core/emulator/demo_cards.dart
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';

/// The cards the emulated Chameleon's reader "sees" (spec 7.5: every feature
/// has to work in emulator mode, and a read with nothing in the field is not
/// a working Read screen).
///
/// `FakeFirmware.present` is exactly the scripting hook spec 4.4 describes;
/// there is still only one fake, at the transport level, and the real
/// `DeviceSession` runs above it.

/// The UID the demo MIFARE Classic answers with. Also what the screenshots
/// and the Phase 6 gate test look for.
final Uint8List demoMifareUid = Uint8List.fromList(<int>[
  0xDE,
  0xAD,
  0xBE,
  0xEF,
]);

/// EM410X_SCAN. The fake answers 3000, 3002, 3004 and 3014 from whichever
/// `FakeLfCard` is present (`fake_reader_handlers.dart`).
const int _em410xScanCommand = 3000;

final Uint8List demoEm410xId = Uint8List.fromList(<int>[
  0x12,
  0x34,
  0x56,
  0x78,
  0x9A,
]);

/// A fake with one card in each field.
FakeDevice buildEmulatedDevice() {
  final FakeFirmware firmware = FakeFirmware()
    ..present(FakeMf1Card.classic1k(uid: Uint8List.fromList(demoMifareUid)))
    ..present(
      FakeLfCard(_em410xScanCommand, Uint8List.fromList(demoEm410xId)),
    );
  return FakeDevice(firmware: firmware);
}

/// The app's transport factory: the emulated device gets scripted cards,
/// every real device goes through `chameleon_flutter` untouched.
Transport emulatorAwareTransport(DiscoveredDevice device) =>
    device.kind == TransportKind.fake
    ? buildEmulatedDevice()
    : ChameleonTransports.transportFor(device);
```

- [ ] **Step 4: Point the factory at it**

In `app/lib/core/session/sessions.dart`, add `import '../emulator/demo_cards.dart';` and replace the provider's body:

```dart
/// How a [DiscoveredDevice] becomes a [Transport]. Injected so tests connect
/// to a scripted `FakeDevice` (spec 8.6). The emulated device gets demo
/// cards in its field so every feature works in emulator mode (spec 7.5).
@Riverpod(keepAlive: true)
Transport Function(DiscoveredDevice) transportFactory(Ref ref) =>
    emulatorAwareTransport;
```

- [ ] **Step 5: Run the tests and watch them pass**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test
cd .. && dart run melos run check:all
```

Expected: PASS across the whole app suite — run all of it here, because this changes what every test that does *not* override `transportFactoryProvider` connects to.

- [ ] **Step 6: Commit**

```bash
git add app/lib/core app/test/core/emulator
git commit -m "feat(core): give the emulated device cards to read

Spec 7.5 says every feature works in emulator mode; a bare FakeDevice has an
empty field, so the Read screen could only ever say "no card found" there.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 13: The phase gate

The roadmap's Phase 6 gate: "integration test: scan a fake card, save, edit, import fixture". One flow widget test (fast, on every CI run) and one integration test on a real engine (the macOS job, which runs the whole `integration_test` directory — no workflow change needed; `.github/workflows/ci.yml` line 57 already runs `flutter test integration_test -d macos`).

**Files:**
- Create: `app/test/flows/cards_flow_test.dart`, `app/integration_test/cards_flow_test.dart`
- Test: both of the above are the test

**Interfaces:**
- Consumes: everything Tasks 1-12 produced, plus the harness (`pumpTestApp`, `connectToEmulator`, `testWidgetsApp`, `keepAlive`, `readProvider`), `SpectraDatabase.memory()`, `databaseProvider`, `scannersProvider`, `transportFactoryProvider`, `sessionOptionsProvider`, `FakeScanner`, `SpectraAppShell`.
- Produces: nothing importable — this is the gate.

- [ ] **Step 1: Write the flow widget test**

```dart
// app/test/flows/cards_flow_test.dart
import 'dart:io';
import 'dart:ui';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/data/data.dart';
import 'package:spectra/features/cards/state/saved_cards_provider.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/app_harness.dart';

/// The roadmap's Phase 6 gate: scan a fake card, save it, edit it, import
/// the reference-app fixture. `testWidgetsApp` (not plain `testWidgets`) so
/// the app root's stream-backed screens settle cleanly on teardown.
void main() {
  Future<void> pumpFrames(WidgetTester tester, [int frames = 15]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgetsApp('scan, save, edit, import', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // The production transport factory, so the emulated device's own demo
    // cards are what gets read (Task 12).
    await pumpTestApp(tester);
    await connectToEmulator(tester);
    expect(find.byType(SpectraAppShell), findsOneWidget);

    // 1. Scan.
    await tester.tap(find.text('Cards').last);
    await pumpFrames(tester);
    await tester.tap(find.text('Read a card'));
    await pumpFrames(tester);
    await tester.tap(find.text('Scan high frequency'));
    await pumpFrames(tester, 40);
    expect(find.text('DEADBEEF'), findsOneWidget);

    // 2. Save.
    await tester.tap(find.text('Save to library'));
    await pumpFrames(tester);
    await tester.enterText(find.byType(SpectraTextField).first, 'Gate card');
    await pumpFrames(tester, 5);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Save'),
      ),
    );
    await pumpFrames(tester, 20);

    keepAlive(tester, savedCardsProvider);
    await pumpFrames(tester);
    expect(
      (readProvider(tester, savedCardsProvider).value ?? const <SavedCard>[]),
      hasLength(1),
    );

    // 3. Edit: open the card from the library and change block 1.
    await tester.tap(find.text('Cards').last);
    await pumpFrames(tester);
    await tester.tap(find.text('Gate card'));
    await pumpFrames(tester);
    await tester.enterText(find.byKey(const Key('cardEditIndex')), '1');
    await tester.enterText(
      find.byKey(const Key('cardEditValue')),
      '000102030405060708090A0B0C0D0E0F',
    );
    await pumpFrames(tester, 5);
    await tester.tap(find.text('Apply'));
    await pumpFrames(tester);
    await tester.tap(find.text('Save changes'));
    await pumpFrames(tester, 20);

    final SavedCardsRepository repo = readProvider(
      tester,
      savedCardsRepositoryProvider,
    );
    final SavedCard edited = (await repo.all()).single;
    expect(edited.bytes.sublist(16, 32), <int>[
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
    ]);

    // 4. Import the reference-app fixture.
    await tester.tap(find.text('Cards').last);
    await pumpFrames(tester);
    await tester.tap(find.text('Import'));
    await pumpFrames(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(SpectraTextField),
      ),
      File('test/fixtures/reference_card_mifare_mini.json').readAsStringSync(),
    );
    await pumpFrames(tester, 5);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Import'),
      ),
    );
    await pumpFrames(tester, 20);

    final List<SavedCard> all = await repo.all();
    expect(all, hasLength(2));
    expect(
      all.map((SavedCard c) => c.name).toSet(),
      <String>{'Gate card', 'Reference Mini'},
    );
    expect(find.text('Reference Mini'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it and watch it pass (it should — every part landed already)**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/flows/cards_flow_test.dart
```

Expected: PASS. If it fails, the failure is real: fix the feature, not the test. Note this is the one test in the phase deliberately written after the code it exercises — it is the gate, not a unit.

- [ ] **Step 3: Write the integration test**

```dart
// app/integration_test/cards_flow_test.dart
import 'dart:io';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:spectra/app.dart';
import 'package:spectra/core/discovery/scanners.dart';
import 'package:spectra/core/session/sessions.dart';
import 'package:spectra/data/database/database_providers.dart';
import 'package:spectra/data/database/spectra_database.dart';
import 'package:spectra_ui/spectra_ui.dart';

/// The Phase 6 gate on a real engine. Emulator mode only: no hardware is
/// touched, and none is needed. Reading a *real* card is hardware-validate
/// and lives in `docs/hardware-checklist.md` (H1, H3).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('scan a fake card, save it, edit it, import a fixture', (
    tester,
  ) async {
    final SpectraDatabase db = SpectraDatabase.memory();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          databaseProvider.overrideWithValue(db),
          scannersProvider.overrideWithValue(<DeviceScanner>[FakeScanner()]),
          // No transportFactory override: the production factory gives the
          // emulated device its demo cards (spec 7.5).
          sessionOptionsProvider.overrideWithValue(
            const SessionOptions(batteryDelay: Duration.zero),
          ),
        ],
        child: const SpectraRoot(),
      ),
    );
    await tester.pump();

    Future<void> settle([int frames = 20]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await tester.tap(find.text(FakeScanner.emulatedUltra.name));
    await settle(30);
    expect(find.byType(SpectraAppShell), findsOneWidget);

    await tester.tap(find.text('Cards').last);
    await settle();
    await tester.tap(find.text('Read a card'));
    await settle();
    await tester.tap(find.text('Scan high frequency'));
    await settle(60);
    expect(find.text('DEADBEEF'), findsOneWidget);

    await tester.tap(find.text('Save to library'));
    await settle();
    await tester.enterText(find.byType(SpectraTextField).first, 'Gate card');
    await settle(5);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Save'),
      ),
    );
    await settle(30);

    await tester.tap(find.text('Cards').last);
    await settle();
    await tester.tap(find.text('Gate card'));
    await settle();
    await tester.enterText(find.byKey(const Key('cardEditIndex')), '1');
    await tester.enterText(
      find.byKey(const Key('cardEditValue')),
      '000102030405060708090A0B0C0D0E0F',
    );
    await settle(5);
    await tester.tap(find.text('Apply'));
    await settle();
    await tester.tap(find.text('Save changes'));
    await settle(30);

    await tester.tap(find.text('Cards').last);
    await settle();
    await tester.tap(find.text('Import'));
    await settle();
    await tester.enterText(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(SpectraTextField),
      ),
      File('test/fixtures/reference_card_mifare_mini.json').readAsStringSync(),
    );
    await settle(5);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Import'),
      ),
    );
    await settle(30);

    expect(find.text('Reference Mini'), findsOneWidget);
    expect(find.text('Gate card'), findsOneWidget);
  });
}
```

The fixture is read with a relative path, which resolves against the app package root under both `flutter test` and `flutter test integration_test -d macos`. If the integration run cannot find it, copy the fixture's text into a `const String` in the integration test rather than adding an asset bundle entry.

- [ ] **Step 4: Run the integration test on macOS**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test integration_test/cards_flow_test.dart -d macos
```

Expected: PASS. This is the roadmap's Phase 6 gate.

- [ ] **Step 5: Run everything**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart run melos run check:all
```

- [ ] **Step 6: Commit**

```bash
git add app/test/flows/cards_flow_test.dart app/integration_test/cards_flow_test.dart
git commit -m "test(cards): add the Phase 6 gate

The roadmap's gate is scan, save, edit, import; it runs as a fast flow test
on every CI run and on a real engine in the macOS integration job.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 14: Close-out

Every phase ends the same way (the roadmap's Global Constraints): the whole check suite green, the roadmap ticked, `AGENTS.md` current, lessons captured, decisions recorded, and the hardware checklist carrying what only a device can prove.

**Files:**
- Modify: `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md`, `AGENTS.md`, `tasks/lessons.md`, `docs/research/DECISIONS.md`, `docs/hardware-checklist.md`

- [ ] **Step 1: Run the whole suite and record the result**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd /Users/bcraig/orca/workspaces/spectra/chinook && dart run melos run check:all
cd app && flutter test integration_test -d macos
```

Both must be green before anything below is written. Do not claim a phase is done from a partial run.

- [ ] **Step 2: Tick the roadmap**

In `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md`, change the Phase 6 row's Plan cell to `2026-09-03-phase-6-cards.md (done)` and check the box:

```markdown
- [x] Phase 6
```

- [ ] **Step 3: Update `AGENTS.md`**

Replace the "Next:" paragraph of the "Current status" section with a Phase 6 entry in the same voice as the Phase 1, 2 and 5 ones:

```markdown
Phase 6 (`app/lib/features/cards`) is complete (2026-09-03): read a card
through `ReaderFacade` under its own lease with progress and cancel, the
saved-cards repository (Drift and in-memory) behind `savedCardsRepository`,
the library list with search/folders/sort, the card detail screen with the
hex viewer and a chunk editor with an unsaved-changes guard, import of the
reference app's JSON and Spectra's own versioned export, and the public
`showCardPicker` API Phase 7 consumes. The emulated device now carries demo
cards so every feature works in emulator mode (spec 7.5). Reading a real
card is hardware-validate: see `docs/hardware-checklist.md` H1 and H3.

Next: Phase 7 (write and emulate) — write its plan with the writing-plans
skill from spec 7.7 step 5.
```

Also add, to "Decisions made overnight", the line the plan's Task 10 promised:

```markdown
- Card import in v1 is paste-JSON, not a native file dialog: a file picker is
  a new dependency on five platforms and a spec section 2 amendment. Phase 9
  (export) revisits it.
```

- [ ] **Step 4: Add the lessons**

Append to `tasks/lessons.md`:

```markdown
## Phase 6 (cards)

- `ReaderFacade` takes its own reader lease per call, and `mf1ReadDump` wraps
  the whole dump in one lease and one `busy`. Feature code therefore needs no
  wakelock code at all: `sessionNeedsWakelock` polls `readerLeaseCount` and
  `isBusy`. Adding a second wakelock would have been a bug, not belt and
  braces.
- The SDK has no *reader* operation for Ultralight — `EmulatorFacade.readNtagPages`
  reads the device's emulation memory, not a card in the field. A physical
  NTAG can therefore be identified but not dumped in v1. Spec 8.2's extension
  point is the way in: one command plus one facade method.
- A bare `FakeDevice` has an empty field. Anything that reads a card in
  emulator mode needs `FakeFirmware.present`, which is what spec 4.4's
  scripted reader is for.
- Edits go to a working copy, not the row: "Apply" changes memory, "Save"
  writes. That split is what makes an unsaved-changes guard mean anything.
- The reference app's export shape is not documented in this repo, so the
  importer is permissive by design and its exact field spelling is an H3
  compatibility item rather than a claim.
```

- [ ] **Step 5: Record the decisions**

Append a "Phase 6" section to `docs/research/DECISIONS.md`:

```markdown
## Phase 6 (read, library, editor, import)

- **`SavedCard.tagType` stores `TagType.name`.** The column is a string
  because the data layer stores columns, not enums; `features/cards/state/card_codec.dart`
  is the single place that string becomes a `TagType` again, so a rename in
  the SDK is one edit.
- **Import is paste-JSON in v1.** A native file dialog means `file_selector`
  or `file_picker` plus per-platform setup on five targets and an amendment
  to spec section 2's dependency table. Pasting works everywhere today and is
  fully testable. Phase 9's export work revisits it.
- **The reference app's JSON reader is deliberately permissive.**
  `docs/research/reference-gui.md` records that the app exports cards as JSON
  with folders and colours but not the field-level shape. The reader accepts a
  bare object, a list, or an object with a `cards` list; tolerates spaces and
  colons in hex; and matches tag names case-insensitively against both the
  reference spellings and `TagType.name`. Only the format is matched — the app
  is GPL-3.0 and none of its code is used. Verifying against a real export is
  an H3 item.
- **Spectra's own export is `schemaVersion: 1`**, with the dump as one hex
  string per card so the file stays diffable.
- **The default MIFARE key list is a constant, not a dictionary.** Phase 9
  replaces `defaultMifareKeys()` with `DictionariesRepository`; the facade
  already takes keys as a parameter, so it is a one-line change at the call
  site.
- **The emulated device carries demo cards.** `transportFactoryProvider` now
  returns `emulatorAwareTransport`, which scripts the fake's reader for
  `TransportKind.fake` and leaves every real transport untouched. Without it
  the Read screen could only ever say "no card found" in emulator mode, which
  spec 7.5 forbids.
- **Ultralight cards can be stored, viewed, edited and imported, but not read
  off a card**, because `ReaderFacade` has no Ultralight read operation. This
  is an SDK gap, recorded here so Phase 7 does not assume otherwise.
```

- [ ] **Step 6: Add the hardware items**

In `docs/hardware-checklist.md`, append to the **H1** section (it already covers reader-adjacent behaviour on a real device):

```markdown
### H1 — reading real cards (Phase 6)

Run with a device attached and the app in `Cards → Read a card`.

- [ ] A blank MIFARE Classic 1K reads completely: every block, 16 sectors with
      keys found, `Save to library` enabled. Confirms
      `ReaderFacade.mf1ReadDump`'s chunked MF1_CHECK_KEYS_OF_SECTORS path
      against real firmware.
- [ ] A card whose keys are not in `defaultMifareKeyHex` reads *partially*
      and says so, rather than failing. Confirms the partial-dump contract.
- [ ] Block 0's UID is 4 bytes as `MifareClassicDump.uid` assumes. A 7-byte
      UID card is the open question flagged in `mifare_classic.dart`; note
      what block 0 actually holds if one is available.
- [ ] Cancelling mid-dump returns to the idle screen and the device is back
      in emulator mode (check the dashboard's mode chip).
- [ ] An EM410x fob reads its five id bytes, and they match what another
      reader reports.
- [ ] The screen stays awake for the whole dump (spec 7.4's wakelock).
- [ ] An NTAG215 held to the reader shows its UID and the "cannot read its
      memory yet" line — the documented v1 limit, not a crash.
```

And to the **H3** section:

```markdown
- [ ] Import a real export from the Chameleon Ultra GUI (Settings → export)
      and confirm every card lands with the right name, tag type, folder and
      colour. If a field name differs from `referenceTagNames` /
      `_readCard`'s keys in `features/cards/state/card_import.dart`, fix the
      reader and add the real file (with any personal data removed) as a
      second fixture.
- [ ] Write a card edited in Spectra back to a physical card (Phase 7) and
      re-read it: the bytes match what the editor showed.
```

- [ ] **Step 7: Commit**

```bash
git add docs AGENTS.md tasks/lessons.md
git commit -m "docs: close out Phase 6

Records what landed, what only a device can prove, and the two decisions a
later phase will want the reasoning for: paste-only import, and the
permissive reference-app reader.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Dispatch order and shared files

Serialise on the shared files, exactly as Phase 5 did:

| Resource | Tasks that write it |
|---|---|
| `app/lib/l10n/app_en.arb` | 4, 5, 6, 7, 8, 10, 11 — **never two at once** |
| `app/lib/features/cards/ui/cards_page.dart` | 4, 6, 10 |
| `app/lib/features/cards/ui/card_detail_page.dart` (+ its test) | 7, 8, 10 |
| `app/lib/features/cards/ui/read_page.dart` | 4, 5 |
| `app/lib/features/cards/state/saved_cards_provider.dart` | 5, 10 |
| `app/lib/features/cards/cards.dart` | 4, 5, 7, 10, 11 |
| `app/lib/core/routing/app_sections.dart` | 4, 7 |
| `app/test/support/app_harness.dart` | **nobody** — this phase adds no harness helper; if one seems needed, say so rather than editing the file every widget test imports |

Order: **T1 | T2 | T3 | T4 | T5 | T6 | T7 | T8 | T9 | T10 | T11 | T12 | T13 | T14**.

T2 and T9 are pure and touch nothing anyone else holds, so they may run in parallel with their neighbours if the executor wants the concurrency; everything else is sequential because of the table above.
