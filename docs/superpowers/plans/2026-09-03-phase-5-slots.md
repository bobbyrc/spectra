# Phase 5: slots Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Slots feature (spec 7.7 step 2): a grid of the device's eight slots, a slot editor that renames, enables and disables each sense, changes the tag type, clears a sense and sets the active slot — every mutation written through `session.slots` — plus the slot picker that spec 8.3 makes this feature's public API for Phase 6 and 7.

**Architecture:** Everything reads the SDK's already-cached slot state: `slotsProvider` and `activeSlotProvider` (`app/lib/core/session/session_streams.dart`) republish `DeviceSession.slotsState` and `DeviceSession.activeSlot`, and `SlotsFacade` writes each change through to those same caches without a re-read, so the UI needs no refresh plumbing of its own. The feature is the standard three parts: pure display/validation helpers and a `SlotView` projection in `state/`, one `SlotEditor` family notifier per slot index that turns a facade call into an `AsyncValue` the screen renders (never throws at the widget layer), and layout-only widgets in `ui/`. The slot detail screen is a deep route pushed on top of the Slots tab (spec 7.2). The picker is a modal sheet over the same `slotViewsProvider`, exported from the barrel as the feature's only cross-feature surface.

**Tech Stack:** Flutter 3.47.2 / Dart 3.13, `flutter_riverpod` 3.4.2 + `riverpod_annotation` 4.0.6 + `riverpod_generator` 4.0.8, `go_router` 18.0.1, `flutter_localizations` + `intl` 0.20.3, `integration_test`, and this repo's `chameleon` (SDK, `SlotsFacade`) and `spectra_ui` (`SpectraSlotTile`, `SpectraTextField`, `SpectraBottomSheet`, `SpectraDialog`).

**Spec:** `docs/superpowers/specs/2026-09-02-spectra-design.md` sections 7.7 step 2 (the feature), 8.1 (`session.slots`), 8.3 (feature layout and the slot picker as public API), 8.4 (enforcement), 8.5 (code shape), 8.6 (interfaces at every seam), 7.2 (deep routes push on top of their tab), 7.4 (wakelock during long operations), 7.6 (ARB localization, semantics, touch targets), 9 (errors: one sentence, a recovery action, the raw line one tap away), 6.2 (components), 10 (widget test per screen against `FakeDevice`; an `integration_test` flow for slot edit). Roadmap: `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md` (Phase 5 row: deliverable "Slots feature and its public slot picker API", gate "integration test: edit and save a slot on the emulator"). Wire facts: `docs/research/chameleon-protocol.md`.

## Global Constraints

- Toolchain pinned in `mise.toml`: Flutter 3.47.2 (bundles Dart 3.13). **Once per shell, `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"`**, then plain `flutter` / `dart` / `melos`, run **from `app/`** unless a task says otherwise. mise puts its tool paths after an older fvm Dart on this machine, so the export is not optional.
- TDD for every task: failing test, minimal code, passing test, commit. Commit messages: imperative subject, short body explaining why, trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- `dart run melos run check:all` from the worktree root stays green at every commit.
- Generated code (riverpod_generator, gen-l10n) is committed; `tool/check_codegen.sh` must pass. After editing any `@riverpod` file: `dart run build_runner build --delete-conflicting-outputs` from `app/`. After editing `app/lib/l10n/app_en.arb`: `flutter gen-l10n` from `app/`, and commit the regenerated `app/lib/l10n/app_localizations*.dart`.
- **Package boundaries** (`tool/dep_lint.dart`, spec 8.4) — the four structural rules that bite here:
  - `app/lib/features/*` must never import `package:flutter/material.dart`. Use `package:material_ui/material_ui.dart`. When a file also imports `package:chameleon/chameleon.dart`, write `import 'package:material_ui/material_ui.dart' hide ConnectionState;` — both libraries declare `ConnectionState` and an unprefixed dual import is a compile error.
  - A feature may import another feature **only** through its barrel, `package:spectra/features/<x>/<x>.dart`. Nothing in this phase imports another feature at all.
  - Nothing outside `chameleon` may import `package:chameleon/src/...`. Only the barrel `package:chameleon/chameleon.dart`. In particular `maxNickBytes` (in `packages/chameleon/lib/src/commands/device.dart`) is **not** exported — this phase declares its own `slotNicknameMaxBytes = 32` (Task 1) and cites the protocol doc.
  - Drift only under `app/lib/data/`. Nothing here touches Drift.
- All user-facing copy goes through ARB (spec 7.6). The string lint (`tool/src/string_rules.dart`) scans `app/lib/features/<x>/ui/` for bare literals passed to `Text(` or to `label:` / `labelText:` / `title:` / `subtitle:` / `hintText:` / `helperText:` / `errorText:` / `semanticsLabel:` / `tooltip:`. Put every visible string in `app/lib/l10n/app_en.arb`. **Exception, ruled in Task 1:** tag-type product names (`MIFARE Classic 1K`, `NTAG215`, `EM410x`, …) are proper nouns held in a `state/` table, not ARB entries; see Task 1's rationale.
- Files stay under about 300 lines and hold one public type (spec 8.5). Screens are layout only; logic lives in notifiers unit-tested without widgets (spec 8.5).
- Riverpod overrides are used **at the app root only** (spec 7.1) — `main()`, `app/test/support/app_harness.dart`, and the integration test. Never inside a feature.
- **riverpod 3.4.2 API notes** (Phase 4 rulings, verified against landed code):
  - `Override` is imported from `package:flutter_riverpod/misc.dart`, not from the main library.
  - There is no `AsyncValue.valueOrNull`. Use `.value`.
  - Never read `state` inside `ref.onDispose` — the element is already torn down.
  - **Ruling 20:** an autoDispose stream/async provider's `.future` can hang under `ProviderContainer.read` because nothing keeps it alive. A test that awaits `.future` must hold a `container.listen(p, (_, _) {})` first. Widget tests use `testWidgetsApp` from `app/test/support/app_harness.dart` and connect via `connectToEmulator(tester)`, which keeps the whole app mounted and sidesteps this.
  - A new `DeviceSession` is constructed per connect attempt; sessions are single-use and spent after a terminal close. Tests therefore pass `transport: (_) => FakeDevice()` (a fresh fake per attempt).
- **Cite the source for every protocol or API name.** The Phase 3 lesson: a plan that invents a method name or a byte layout gets built faithfully and wrong. Every SDK name used below was read out of the landed files; if a signature differs when you open it, follow the landed code and say so in the task report.
- This is a git worktree. Never use bare `git stash`.
- Never claim hardware behavior works. Everything in this phase is proven against `FakeDevice`. The slot round trip on real firmware is hardware handoff H1 in `docs/hardware-checklist.md`; this phase adds nothing new to that list.
- **Another implementer may be finishing Phase 4 Task 17/19** in `app/test/flows/**`, `app/integration_test/**`, `.github/workflows/ci.yml`, `app/lib/core/session/sessions.dart` and `app/test/support/app_harness.dart`. Before Task 11, `git pull`/rebase and re-read those files; add **sibling** files rather than editing the connect flow tests.

---

## File structure

```
app/lib/features/slots/slots.dart                       barrel: SlotsPage + the public picker API (spec 8.3)
app/lib/features/slots/state/slot_labels.dart           tagTypeLabel, senseLabel, slotTitle, selectableTypes
app/lib/features/slots/state/slot_nickname.dart         slotNicknameMaxBytes, validateSlotNickname
app/lib/features/slots/state/slot_view.dart             SlotView + buildSlotViews (pure)
app/lib/features/slots/state/slot_views_provider.dart   slotViewsProvider
app/lib/features/slots/state/slot_editor_controller.dart SlotEditor family notifier (one per slot index)
app/lib/features/slots/ui/slots_page.dart               the grid of eight
app/lib/features/slots/ui/slot_detail_page.dart         the editor screen (layout only)
app/lib/features/slots/ui/slot_sense_section.dart       one sense's card: name, type, enable, clear
app/lib/features/slots/ui/tag_type_sheet.dart           showTagTypeSheet
app/lib/features/slots/ui/slot_problem_view.dart        a failed mutation, in spec 9's shape
app/lib/features/slots/ui/slot_picker.dart              showSlotPicker + SlotPicker (the public API)

app/lib/core/routing/sub_page_scaffold.dart             SubPageScaffold, promoted out of features/tools
app/lib/core/routing/routes.dart                        + AppRoutes.slot(index)
app/lib/core/routing/app_sections.dart                  + the ':index' sub-route under /slots
app/lib/features/tools/ui/tool_sub_page_scaffold.dart   deleted (Task 4)
app/lib/features/tools/ui/frame_log_page.dart           uses SubPageScaffold
app/lib/features/tools/ui/update_page.dart              uses SubPageScaffold
app/lib/l10n/app_en.arb                                 + the slot strings (appended per task)

app/test/features/slots/slot_labels_test.dart
app/test/features/slots/slot_nickname_test.dart
app/test/features/slots/slot_view_test.dart
app/test/features/slots/slot_views_provider_test.dart
app/test/features/slots/slots_page_test.dart
app/test/features/slots/slot_detail_page_test.dart
app/test/features/slots/slot_editor_controller_test.dart
app/test/features/slots/tag_type_sheet_test.dart
app/test/features/slots/slot_picker_test.dart
app/test/core/routing/sub_page_scaffold_test.dart
app/test/flows/slot_edit_flow_test.dart                 the gate flow as a widget test (CI, Ubuntu)
app/integration_test/slot_edit_flow_test.dart           the gate flow on a real engine (macOS)

docs/research/DECISIONS.md                              Phase 5 decisions
tasks/lessons.md                                        Phase 5 lessons
docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md tick Phase 5
AGENTS.md                                               current status
```

---

### Task 1: Slot display vocabulary and nickname validation

Two pure files, no Flutter widgets, no providers: how a `TagType` and a `Sense` become words, and whether a proposed nickname will fit on the wire. Everything later in the phase reads these.

**Ruling carried by this task (record it in the report; Task 12 writes it to DECISIONS.md):** tag-type *product* names are proper nouns, not translatable copy. `MIFARE Classic 1K`, `NTAG215` and `EM410x` are the names printed on the parts; putting twenty-four of them in `app_en.arb` would be noise that no translator would ever touch, and the string lint does not reach `state/` anyway. They live in one exhaustive `switch` in `slot_labels.dart`. The two labels that *are* English words — the empty-slot placeholder and the two sense names — go through ARB.

**Files:**
- Create: `app/lib/features/slots/state/slot_labels.dart`, `app/lib/features/slots/state/slot_nickname.dart`
- Modify: `app/lib/l10n/app_en.arb`
- Test: `app/test/features/slots/slot_labels_test.dart`, `app/test/features/slots/slot_nickname_test.dart`

**Interfaces:**
- Consumes: `TagType`, `TagFamily`, `Sense` from `package:chameleon/chameleon.dart` (`packages/chameleon/lib/src/model/enums.dart`, exported by the barrel). `TagType` has `code`, `family` and `Sense get sense`; `TagFamily` values are `undefined, lf, mifareClassic, ultralight, iso14443_4, seos`; `Sense` values are `none, lf, hf`.
- Consumes: `AppLocalizations` from `package:spectra/l10n/app_localizations.dart`; `AppLocalizationsEn()` is directly constructible in tests.
- Produces: `String tagTypeLabel(TagType type, AppLocalizations l10n)`.
- Produces: `String senseLabel(Sense sense, AppLocalizations l10n)`.
- Produces: `List<TagType> selectableTypes(Sense sense)`.
- Produces: `const int slotNicknameMaxBytes = 32;` and `SlotNicknameError? validateSlotNickname(String value)` with `enum SlotNicknameError { tooLong }`.
- Produces: ARB keys `slotTypeEmpty`, `slotSenseHf`, `slotSenseLf`, `slotNicknameTooLong`.

- [ ] **Step 1: Write the failing tests**

```dart
// app/test/features/slots/slot_labels_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/features/slots/state/slot_labels.dart';
import 'package:spectra/l10n/app_localizations.dart';

void main() {
  final AppLocalizations l10n = AppLocalizationsEn();

  test('a product name is the part number, not translated copy', () {
    expect(tagTypeLabel(TagType.mifare1k, l10n), 'MIFARE Classic 1K');
    expect(tagTypeLabel(TagType.ntag215, l10n), 'NTAG215');
    expect(tagTypeLabel(TagType.em410x, l10n), 'EM410x');
  });

  test('the undefined type reads as the localized empty label', () {
    expect(tagTypeLabel(TagType.undefined, l10n), l10n.slotTypeEmpty);
  });

  test('every TagType has a label', () {
    for (final TagType type in TagType.values) {
      expect(tagTypeLabel(type, l10n), isNotEmpty, reason: type.name);
    }
  });

  test('sense labels are localized', () {
    expect(senseLabel(Sense.hf, l10n), l10n.slotSenseHf);
    expect(senseLabel(Sense.lf, l10n), l10n.slotSenseLf);
  });

  test('selectable HF types are the emulatable HF families only', () {
    final List<TagType> hf = selectableTypes(Sense.hf);
    expect(hf, contains(TagType.mifare1k));
    expect(hf, contains(TagType.ntag215));
    expect(hf, isNot(contains(TagType.undefined)));
    expect(hf, isNot(contains(TagType.seos)));
    expect(hf, isNot(contains(TagType.hf14a4)));
    expect(hf.every((TagType t) => t.sense == Sense.hf), isTrue);
  });

  test('selectable LF types are the LF family, and none is undefined', () {
    final List<TagType> lf = selectableTypes(Sense.lf);
    expect(lf, contains(TagType.em410x));
    expect(lf, isNot(contains(TagType.undefined)));
    expect(lf.every((TagType t) => t.family == TagFamily.lf), isTrue);
  });

  test('Sense.none selects nothing', () {
    expect(selectableTypes(Sense.none), isEmpty);
  });
}
```

```dart
// app/test/features/slots/slot_nickname_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/features/slots/state/slot_nickname.dart';

void main() {
  test('the wire limit is 32 bytes', () {
    expect(slotNicknameMaxBytes, 32);
  });

  test('an empty name is valid — it clears the nickname', () {
    expect(validateSlotNickname(''), isNull);
  });

  test('32 ASCII characters fit', () {
    expect(validateSlotNickname('a' * 32), isNull);
  });

  test('33 ASCII characters do not', () {
    expect(validateSlotNickname('a' * 33), SlotNicknameError.tooLong);
  });

  test('the limit is bytes, not characters', () {
    // Each of these is 4 UTF-8 bytes, so nine of them overflow 32.
    expect(validateSlotNickname('😀' * 8), isNull);
    expect(validateSlotNickname('😀' * 9), SlotNicknameError.tooLong);
  });
}
```

- [ ] **Step 2: Run them and watch them fail**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter test test/features/slots
```

Expected: FAIL — `package:spectra/features/slots/state/slot_labels.dart` and `slot_nickname.dart` do not exist.

- [ ] **Step 3: Add the ARB strings and regenerate**

Append to `app/lib/l10n/app_en.arb` (before the closing brace; the file is a flat JSON object of `key` / `@key` pairs):

```json
  "slotTypeEmpty": "Empty",
  "@slotTypeEmpty": {"description": "Shown where a slot sense has no tag type set."},
  "slotSenseHf": "High frequency",
  "@slotSenseHf": {"description": "The 13.56 MHz side of a slot."},
  "slotSenseLf": "Low frequency",
  "@slotSenseLf": {"description": "The 125 kHz side of a slot."},
  "slotNicknameTooLong": "Names are limited to 32 bytes.",
  "@slotNicknameTooLong": {"description": "Validation message under the slot name field."},
```

```bash
cd app && flutter gen-l10n
```

- [ ] **Step 4: Write the implementation**

```dart
// app/lib/features/slots/state/slot_labels.dart
import 'package:chameleon/chameleon.dart';

import '../../../l10n/app_localizations.dart';

/// How a slot's SDK enums become words.
///
/// Tag-type product names are deliberately **not** in `app_en.arb`: they are
/// the names printed on the parts (proper nouns), not copy a translator
/// would ever change. Only the empty placeholder and the two sense names —
/// which are English words — go through localization (spec 7.6).
///
/// The switch is exhaustive over `TagType`, so a tag type added to the SDK
/// is a compile error here rather than a blank cell in the UI.
String tagTypeLabel(TagType type, AppLocalizations l10n) => switch (type) {
  TagType.undefined => l10n.slotTypeEmpty,
  TagType.em410x => 'EM410x',
  TagType.em410xElectra => 'EM410x Electra',
  TagType.pac => 'PAC/Stanley',
  TagType.viking => 'Viking',
  TagType.jablotron => 'Jablotron',
  TagType.hidProx => 'HID Prox',
  TagType.ioProx => 'ioProx',
  TagType.idteck => 'Idteck',
  TagType.mifareMini => 'MIFARE Classic Mini',
  TagType.mifare1k => 'MIFARE Classic 1K',
  TagType.mifare2k => 'MIFARE Classic 2K',
  TagType.mifare4k => 'MIFARE Classic 4K',
  TagType.ntag213 => 'NTAG213',
  TagType.ntag215 => 'NTAG215',
  TagType.ntag216 => 'NTAG216',
  TagType.mf0icu1 => 'Ultralight',
  TagType.mf0icu2 => 'Ultralight C',
  TagType.mf0ul11 => 'Ultralight EV1 (11)',
  TagType.mf0ul21 => 'Ultralight EV1 (21)',
  TagType.ntag210 => 'NTAG210',
  TagType.ntag212 => 'NTAG212',
  TagType.hf14a4 => 'ISO14443-4',
  TagType.seos => 'SEOS',
};

String senseLabel(Sense sense, AppLocalizations l10n) => switch (sense) {
  Sense.hf => l10n.slotSenseHf,
  Sense.lf => l10n.slotSenseLf,
  // Never rendered: `Sense.none` is the wire's "no sense named", not a
  // side of a slot the UI ever shows.
  Sense.none => l10n.slotTypeEmpty,
};

/// The tag types the user may put in a slot, derived from the SDK's own
/// families rather than a hand-typed list.
///
/// `TagFamily.iso14443_4` and `TagFamily.seos` are excluded: the SDK has no
/// emulator support for them (`FakeFirmware._dispatch` answers the whole
/// `CommandRange.iso14443_4` range with NOT_IMPLEMENTED, and
/// `FakeFirmwareConfig.defaultCapabilities` advertises none of 6000-6005),
/// so offering them would be a type the app could set but never fill.
List<TagType> selectableTypes(Sense sense) => TagType.values
    .where(
      (TagType t) =>
          t != TagType.undefined &&
          switch (sense) {
            Sense.hf =>
              t.family == TagFamily.mifareClassic ||
                  t.family == TagFamily.ultralight,
            Sense.lf => t.family == TagFamily.lf,
            Sense.none => false,
          },
    )
    .toList(growable: false);
```

```dart
// app/lib/features/slots/state/slot_nickname.dart
import 'dart:convert';

/// The firmware's nickname limit, in UTF-8 bytes.
///
/// SET_SLOT_TAG_NICK (1007) takes `slot(1) sense(1) utf8<=32`
/// (`docs/research/chameleon-protocol.md`, command table). The SDK enforces
/// the same limit in `SetSlotTagNick.encode`, but with an `ArgumentError` —
/// not a `ChameleonException` the error catalog knows — and its
/// `maxNickBytes` constant is internal to `packages/chameleon/lib/src`, so
/// the app declares its own and validates *before* sending.
const int slotNicknameMaxBytes = 32;

enum SlotNicknameError { tooLong }

/// Null when [value] can be sent as a slot nickname. An empty name is
/// valid: the firmware stores an empty nickname, which is how a name is
/// cleared.
SlotNicknameError? validateSlotNickname(String value) =>
    utf8.encode(value).length > slotNicknameMaxBytes
    ? SlotNicknameError.tooLong
    : null;
```

- [ ] **Step 5: Run the tests and watch them pass**

```bash
cd app && flutter test test/features/slots
```

Expected: PASS (11 tests).

- [ ] **Step 6: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git add app/lib/features/slots/state app/lib/l10n app/test/features/slots
git commit -m "feat(slots): add slot display vocabulary and nickname validation

Tag types and senses become words in one exhaustive switch, so a new SDK
tag type is a compile error rather than a blank cell. Nicknames are checked
against the wire's 32-byte limit before sending, because the SDK's own
check throws an ArgumentError the error catalog cannot describe.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: `SlotView` and `slotViewsProvider`

The projection every slot screen renders: a slot plus whether it is the active one, with the display decisions (which nickname wins, which types to show) made once, in a pure function, and tested without a device.

**Files:**
- Create: `app/lib/features/slots/state/slot_view.dart`, `app/lib/features/slots/state/slot_views_provider.dart`
- Test: `app/test/features/slots/slot_view_test.dart`, `app/test/features/slots/slot_views_provider_test.dart`

**Interfaces:**
- Consumes: `Slot` from `package:chameleon/chameleon.dart` — `Slot({required int index, required TagType hfType, required TagType lfType, required bool hfEnabled, required bool lfEnabled, @Default('') String hfNick, @Default('') String lfNick})` (freezed; `packages/chameleon/lib/src/model/models.dart`).
- Consumes: `slotsProvider` (`Stream<List<Slot>>`) and `activeSlotProvider` (`Stream<int?>`) from `package:spectra/core/session/session_streams.dart`.
- Consumes: `tagTypeLabel` from Task 1.
- Produces: `final class SlotView` with `final Slot slot; final bool isActive;`, `int get index`, `int get number` (1-based), `bool get isEnabled`, `String? get nickname`, `List<TagType> get presentTypes`.
- Produces: `List<SlotView> buildSlotViews(List<Slot> slots, int? activeIndex)`.
- Produces: `slotViewsProvider` — a `@riverpod List<SlotView> slotViews(Ref ref)`, empty when nothing is connected.
- Produces: `List<String> slotTypeLabels(SlotView view, AppLocalizations l10n)` in `slot_labels.dart` (appended there, next to its siblings).

- [ ] **Step 1: Write the failing tests**

```dart
// app/test/features/slots/slot_view_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/features/slots/state/slot_labels.dart';
import 'package:spectra/features/slots/state/slot_view.dart';
import 'package:spectra/l10n/app_localizations.dart';

Slot _slot(
  int index, {
  TagType hf = TagType.undefined,
  TagType lf = TagType.undefined,
  bool hfOn = false,
  bool lfOn = false,
  String hfNick = '',
  String lfNick = '',
}) => Slot(
  index: index,
  hfType: hf,
  lfType: lf,
  hfEnabled: hfOn,
  lfEnabled: lfOn,
  hfNick: hfNick,
  lfNick: lfNick,
);

void main() {
  final AppLocalizations l10n = AppLocalizationsEn();

  test('the number the device prints is one-based', () {
    expect(SlotView(slot: _slot(0), isActive: false).number, 1);
    expect(SlotView(slot: _slot(7), isActive: false).index, 7);
  });

  test('a slot is enabled when either sense is', () {
    expect(SlotView(slot: _slot(0), isActive: false).isEnabled, isFalse);
    expect(
      SlotView(slot: _slot(0, lfOn: true), isActive: false).isEnabled,
      isTrue,
    );
  });

  test('the HF nickname wins, then LF, then null', () {
    expect(
      SlotView(
        slot: _slot(0, hfNick: 'badge', lfNick: 'fob'),
        isActive: false,
      ).nickname,
      'badge',
    );
    expect(
      SlotView(slot: _slot(0, lfNick: 'fob'), isActive: false).nickname,
      'fob',
    );
    expect(SlotView(slot: _slot(0), isActive: false).nickname, isNull);
  });

  test('only defined types are shown, HF before LF', () {
    final SlotView view = SlotView(
      slot: _slot(0, hf: TagType.mifare1k, lf: TagType.em410x),
      isActive: false,
    );
    expect(view.presentTypes, <TagType>[TagType.mifare1k, TagType.em410x]);
    expect(slotTypeLabels(view, l10n), <String>[
      'MIFARE Classic 1K',
      'EM410x',
    ]);
  });

  test('an empty slot shows no type labels at all', () {
    final SlotView view = SlotView(slot: _slot(3), isActive: false);
    expect(view.presentTypes, isEmpty);
    expect(slotTypeLabels(view, l10n), isEmpty);
  });

  test('buildSlotViews marks exactly the active index', () {
    final List<SlotView> views = buildSlotViews(<Slot>[
      _slot(0),
      _slot(1),
      _slot(2),
    ], 1);
    expect(views.map((SlotView v) => v.isActive), <bool>[false, true, false]);
  });

  test('a null active index marks nothing', () {
    final List<SlotView> views = buildSlotViews(<Slot>[_slot(0)], null);
    expect(views.single.isActive, isFalse);
  });

  test('no slots means no views', () {
    expect(buildSlotViews(const <Slot>[], 0), isEmpty);
  });
}
```

```dart
// app/test/features/slots/slot_views_provider_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/features/slots/state/slot_view.dart';
import 'package:spectra/features/slots/state/slot_views_provider.dart';

import '../../support/app_harness.dart';

void main() {
  testWidgetsApp('the provider reports the fake device\'s eight slots', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);

    final List<SlotView> views = readProvider(tester, slotViewsProvider);
    expect(views, hasLength(8));
    // FakeFirmware's constructor seeds slot 0 with a 1K + EM410x pair and
    // makes it the active slot.
    expect(views.first.isActive, isTrue);
    expect(views.first.nickname, 'Fake 1K');
    expect(views.first.presentTypes, <TagType>[
      TagType.mifare1k,
      TagType.em410x,
    ]);
    expect(views[1].isEnabled, isFalse);
  });
}
```

`readProvider` does not exist yet — add it to the harness in this task (it is a read-only helper; it does not touch anything the concurrent Phase 4 implementer owns semantically, but rebase first and re-check):

```dart
// append to app/test/support/app_harness.dart
/// Reads a provider from inside a pumped app, without a second container.
/// The app root's own `ProviderScope` keeps autoDispose providers alive
/// (ruling 20), so this never has to await a `.future`.
T readProvider<T>(WidgetTester tester, ProviderListenable<T> provider) =>
    ProviderScope.containerOf(
      tester.element(find.byType(SpectraRoot)),
    ).read(provider);
```

- [ ] **Step 2: Run them and watch them fail**

```bash
cd app && flutter test test/features/slots
```

Expected: FAIL — `slot_view.dart` / `slot_views_provider.dart` missing, `readProvider` undefined.

- [ ] **Step 3: Write the implementation**

```dart
// app/lib/features/slots/state/slot_view.dart
import 'package:chameleon/chameleon.dart';

/// One slot as the UI sees it: the SDK's [Slot] plus the one fact that
/// lives outside it, and the display decisions made once so no widget makes
/// them twice.
final class SlotView {
  const SlotView({required this.slot, required this.isActive});

  final Slot slot;

  /// True for the slot the device is emulating right now
  /// (`DeviceSession.activeSlot`).
  final bool isActive;

  int get index => slot.index;

  /// The device labels its slots 1..8; the wire indexes them 0..7.
  int get number => slot.index + 1;

  bool get isEnabled => slot.hfEnabled || slot.lfEnabled;

  /// One name per slot in list contexts: the HF nickname if there is one,
  /// otherwise the LF one, otherwise nothing (the tile then shows its own
  /// "empty" placeholder).
  String? get nickname {
    if (slot.hfNick.isNotEmpty) return slot.hfNick;
    if (slot.lfNick.isNotEmpty) return slot.lfNick;
    return null;
  }

  /// The types actually set on this slot, HF first.
  List<TagType> get presentTypes => <TagType>[
    if (slot.hfType != TagType.undefined) slot.hfType,
    if (slot.lfType != TagType.undefined) slot.lfType,
  ];
}

/// Pairs each slot with whether it is the active one. Pure, so the rule is
/// tested without a session.
List<SlotView> buildSlotViews(List<Slot> slots, int? activeIndex) => <SlotView>[
  for (final Slot slot in slots)
    SlotView(slot: slot, isActive: slot.index == activeIndex),
];
```

```dart
// app/lib/features/slots/state/slot_views_provider.dart
import 'package:chameleon/chameleon.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/session/session_streams.dart';
import 'slot_view.dart';

part 'slot_views_provider.g.dart';

/// The eight slots, ready to render. Empty while nothing is connected —
/// `slotsProvider` yields `const []` in that case, so no screen has to
/// special-case "no session" a second time.
///
/// `.value` (never `valueOrNull`, which riverpod 3 does not have) because a
/// stream provider's first frame is `AsyncLoading` and an empty grid is the
/// right thing to show for that one frame.
@riverpod
List<SlotView> slotViews(Ref ref) {
  final List<Slot> slots = ref.watch(slotsProvider).value ?? const <Slot>[];
  final int? active = ref.watch(activeSlotProvider).value;
  return buildSlotViews(slots, active);
}
```

Append to `app/lib/features/slots/state/slot_labels.dart`:

```dart
/// The type labels a slot tile shows, HF first, empty for an empty slot.
List<String> slotTypeLabels(SlotView view, AppLocalizations l10n) =>
    view.presentTypes
        .map((TagType t) => tagTypeLabel(t, l10n))
        .toList(growable: false);
```

…with `import 'slot_view.dart';` added at the top of that file.

- [ ] **Step 4: Generate and run**

```bash
cd app && dart run build_runner build --delete-conflicting-outputs && flutter test test/features/slots
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git add app/lib/features/slots app/test/features/slots app/test/support/app_harness.dart
git commit -m "feat(slots): project the session's slot cache into SlotView

Which nickname wins and which types are present are display decisions; make
them once in a pure function so the grid, the editor and the picker cannot
disagree about what a slot looks like.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: The slots grid

Replaces the Phase 4 placeholder with the real screen: eight `SpectraSlotTile`s, the active one marked, an empty state when nothing is connected. Layout only — no taps go anywhere yet (Task 4 wires the route).

**Files:**
- Modify: `app/lib/features/slots/ui/slots_page.dart`, `app/lib/l10n/app_en.arb`
- Test: `app/test/features/slots/slots_page_test.dart`

**Interfaces:**
- Consumes: `slotViewsProvider`, `SlotView`, `slotTypeLabels` (Tasks 1-2).
- Consumes: `SpectraSlotTile({required int number, required bool enabled, String? nickname, List<String> tagTypes = const [], bool active = false, VoidCallback? onTap})`, `SpectraSectionHeader({required String title})`, `SpectraCard({required Widget child, ...})`, `SpectraSpacing.{xs,sm,md,lg,xl,xxl}` — all from `package:spectra_ui/spectra_ui.dart`.
- Produces: `class SlotsPage extends ConsumerWidget` (was `StatelessWidget`), still exported from `app/lib/features/slots/slots.dart`.
- Produces: ARB keys `slotsTitle`, `slotsEmpty`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/slots/slots_page_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

Future<void> _openSlots(WidgetTester tester) async {
  await tester.tap(find.text('Slots').last);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgetsApp('the grid shows eight slots with the active one marked', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await _openSlots(tester);

    expect(find.byType(SpectraSlotTile), findsNWidgets(8));
    expect(find.text('Fake 1K'), findsOneWidget);
    expect(find.text('MIFARE Classic 1K'), findsOneWidget);
    expect(find.text('EM410x'), findsOneWidget);

    final SpectraSlotTile first = tester.widget<SpectraSlotTile>(
      find.byType(SpectraSlotTile).first,
    );
    expect(first.number, 1);
    expect(first.active, isTrue);
    expect(first.enabled, isTrue);

    final SpectraSlotTile second = tester.widget<SpectraSlotTile>(
      find.byType(SpectraSlotTile).at(1),
    );
    expect(second.active, isFalse);
    expect(second.enabled, isFalse);
  });

  testWidgetsApp('the empty state replaces the grid with nothing connected', (
    tester,
  ) async {
    await pumpTestAppWithNoDevices(tester);
    await tester.pump();

    // Nothing is connected, so routing holds the connect screen and the
    // grid is never built; the page itself still renders its empty state
    // when mounted directly.
    expect(find.byType(SpectraSlotTile), findsNothing);
  });
}
```

Note the second test only asserts the grid is absent: with no session the redirect keeps the app on `/connect` (spec 7.2, `redirectFor`), which is the real behaviour. The empty-state copy is proven by the flow test in Task 11 after a disconnect is not possible (routing bounces first), so the empty state exists for the one frame between a session dropping and the redirect firing — keep it, keep it cheap, and do not build a test that fakes a session-less `/slots`.

- [ ] **Step 2: Run it and watch it fail**

```bash
cd app && flutter test test/features/slots/slots_page_test.dart
```

Expected: FAIL — the placeholder renders `comingSoonSlots`, no `SpectraSlotTile` anywhere.

- [ ] **Step 3: Add the ARB strings and regenerate**

```json
  "slotsTitle": "Slots",
  "@slotsTitle": {"description": "Heading of the slots grid."},
  "slotsEmpty": "Connect a device to see its slots.",
  "@slotsEmpty": {"description": "Shown on the slots screen with no session."},
```

Remove the now-dead `comingSoonSlots` entry and its `@comingSoonSlots` description.

```bash
cd app && flutter gen-l10n
```

- [ ] **Step 4: Write the screen**

```dart
// app/lib/features/slots/ui/slots_page.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../state/slot_labels.dart';
import '../state/slot_view.dart';
import '../state/slot_views_provider.dart';

/// Spec 7.7 step 2: the grid of eight. Layout only — the state is
/// `slotViewsProvider` and every mutation lives in the detail screen.
class SlotsPage extends ConsumerWidget {
  const SlotsPage({super.key});

  /// Wide enough for a nickname plus two type labels, narrow enough that a
  /// phone gets one column and a desktop window gets three or four.
  static const double _tileMaxWidth = 320;
  static const double _tileHeight = 132;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<SlotView> views = ref.watch(slotViewsProvider);

    if (views.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(SpectraSpacing.lg),
        children: <Widget>[
          SpectraSectionHeader(title: l10n.slotsTitle),
          SpectraCard(child: Text(l10n.slotsEmpty)),
        ],
      );
    }

    return CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            SpectraSpacing.lg,
            SpectraSpacing.lg,
            SpectraSpacing.lg,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: SpectraSectionHeader(title: l10n.slotsTitle),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(SpectraSpacing.lg),
          sliver: SliverGrid.builder(
            gridDelegate:
                const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: _tileMaxWidth,
                  mainAxisExtent: _tileHeight,
                  crossAxisSpacing: SpectraSpacing.md,
                  mainAxisSpacing: SpectraSpacing.md,
                ),
            itemCount: views.length,
            itemBuilder: (BuildContext context, int i) {
              final SlotView view = views[i];
              return SpectraSlotTile(
                number: view.number,
                enabled: view.isEnabled,
                nickname: view.nickname,
                tagTypes: slotTypeLabels(view, l10n),
                active: view.isActive,
              );
            },
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Run the tests and watch them pass**

```bash
cd app && flutter test test/features/slots && flutter test
```

Expected: PASS. The whole app suite must stay green — the Phase 4 shell test that asserted `comingSoonSlots` (if any) has to be updated in this task; search for it with `grep -rn "comingSoonSlots" app/`.

- [ ] **Step 6: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git add app/lib/features/slots app/lib/l10n app/test
git commit -m "feat(slots): render the eight-slot grid

Replaces the Phase 4 placeholder. The tile is spec 6.2's SpectraSlotTile,
so number, nickname, types, enabled and active all come from the kit rather
than from a layout invented here.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: The slot detail route

A deep route pushed on top of the Slots tab (spec 7.2), and the back affordance it needs. Phase 4's `ToolSubPageScaffold` already solves the back-affordance problem and its own doc comment anticipates exactly this moment ("before reusing it there (or anywhere else a sub-route is pushed), check whether the shell has grown its own per-route title/back handling by then"). The shell has not; so promote the widget to `core/` rather than copying it — a feature may not import another feature's internals (spec 8.4), and a second copy is the thing that file exists to prevent.

**Files:**
- Create: `app/lib/core/routing/sub_page_scaffold.dart`, `app/lib/features/slots/ui/slot_detail_page.dart`
- Modify: `app/lib/core/routing/routes.dart`, `app/lib/core/routing/app_sections.dart`, `app/lib/features/tools/ui/frame_log_page.dart`, `app/lib/features/tools/ui/update_page.dart`, `app/lib/features/slots/ui/slots_page.dart`, `app/lib/l10n/app_en.arb`
- Delete: `app/lib/features/tools/ui/tool_sub_page_scaffold.dart`
- Test: `app/test/core/routing/sub_page_scaffold_test.dart`, `app/test/features/slots/slot_detail_page_test.dart`

**Interfaces:**
- Consumes: `AppSection({required String path, required String Function(AppLocalizations) label, required IconData icon, required Widget Function(BuildContext, GoRouterState) builder, IconData? selectedIcon, List<RouteBase> subRoutes = const []})` from `package:spectra/core/routing/app_sections.dart`.
- Consumes: `AppRoutes.slots == '/slots'` from `package:spectra/core/routing/routes.dart`.
- Consumes: `slotViewsProvider`, `SlotView`, `tagTypeLabel`, `senseLabel`, `slotTypeLabels`.
- Produces: `class SubPageScaffold extends StatelessWidget` with `const SubPageScaffold({required String title, required Widget body, super.key})` in `package:spectra/core/routing/sub_page_scaffold.dart`. Same body as the deleted `ToolSubPageScaffold`, renamed.
- Produces: `static String slot(int index) => '/slots/$index';` on `AppRoutes`.
- Produces: `class SlotDetailPage extends ConsumerWidget` with `const SlotDetailPage({required this.index, super.key})` and `final int index;`. Renders the sense sections in Tasks 6-8; this task gives it the header, the not-found state and the back affordance.
- Produces: ARB keys `slotDetailTitle` (placeholder `number`, `int`), `slotNotFound`.

- [ ] **Step 1: Write the failing tests**

```dart
// app/test/core/routing/sub_page_scaffold_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra/core/routing/sub_page_scaffold.dart';

void main() {
  testWidgets('it shows a title and a back button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SubPageScaffold(title: 'Slot 3', body: Text('body')),
      ),
    );
    expect(find.text('Slot 3'), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });
}
```

```dart
// app/test/features/slots/slot_detail_page_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

void main() {
  testWidgetsApp('tapping a slot opens its detail screen', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 1);

    expect(find.text('Slot 1'), findsWidgets);
    expect(find.byType(SpectraSlotTile), findsNothing);
  });

  testWidgetsApp('the back button returns to the grid', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 1);

    await tester.tap(find.byType(BackButton));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(SpectraSlotTile), findsNWidgets(8));
  });
}
```

Add the two navigation helpers to the harness (alongside `openFrameLog` / `openUpdate`, which follow the same shape):

```dart
// append to app/test/support/app_harness.dart
Future<void> _pumpFrames(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Opens the Slots tab. The shell is wide enough in tests that the
/// destination is a rail item.
Future<void> openSlots(WidgetTester tester) async {
  await tester.tap(find.text('Slots').last);
  await _pumpFrames(tester);
}

/// Taps the tile for the given one-based slot number and waits for the
/// detail route.
Future<void> openSlot(WidgetTester tester, int number) async {
  await tester.tap(find.byType(SpectraSlotTile).at(number - 1));
  await _pumpFrames(tester);
}
```

(`app_harness.dart` will then need `import 'package:material_ui/material_ui.dart';` for `BackButton` only in the *test* file, not the harness; the harness needs `package:spectra_ui/spectra_ui.dart` for `SpectraSlotTile`. Add whichever imports the analyzer asks for.)

- [ ] **Step 2: Run them and watch them fail**

```bash
cd app && flutter test test/core/routing/sub_page_scaffold_test.dart test/features/slots/slot_detail_page_test.dart
```

Expected: FAIL — `sub_page_scaffold.dart` missing; tapping a tile does nothing.

- [ ] **Step 3: Promote the sub-page scaffold**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git mv app/lib/features/tools/ui/tool_sub_page_scaffold.dart \
       app/lib/core/routing/sub_page_scaffold.dart
```

Then in `app/lib/core/routing/sub_page_scaffold.dart` rename the class and rewrite the doc comment:

```dart
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The back affordance for a route pushed on top of a shell branch, in one
/// place.
///
/// `SpectraAppShell`'s own `AppBar` (`ShellScaffold`) sits above the branch
/// navigator and keeps showing the top-level section's title, so a pushed
/// sub-route has no way back on its own. Nesting a second `Scaffold`/
/// `AppBar` here, with a [BackButton] that pops the branch's navigator, is
/// that way back — used by `/tools/frame-log`, `/tools/update` and
/// `/slots/:index`.
///
/// This lives in `core/` because a feature may not import another feature's
/// internals (spec 8.4) and three copies of one `Scaffold` is exactly what
/// this file exists to prevent.
class SubPageScaffold extends StatelessWidget {
  const SubPageScaffold({required this.title, required this.body, super.key});

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: Text(title),
      ),
      body: body,
    );
  }
}
```

Update the two callers: in `app/lib/features/tools/ui/frame_log_page.dart` and `app/lib/features/tools/ui/update_page.dart`, replace `import 'tool_sub_page_scaffold.dart';` with `import '../../../core/routing/sub_page_scaffold.dart';` and every `ToolSubPageScaffold(` with `SubPageScaffold(`.

- [ ] **Step 4: Add the route, the ARB strings and the detail page**

`app/lib/core/routing/routes.dart` — add next to `recover`:

```dart
  /// The slot editor (spec 7.2: a deep route pushed on top of its tab).
  /// [index] is the wire index, 0..7.
  static String slot(int index) => '$slots/$index';
```

`app/lib/core/routing/app_sections.dart` — give the Slots section its sub-route, and import the page:

```dart
  AppSection(
    path: AppRoutes.slots,
    label: (l10n) => l10n.navSlots,
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    builder: (context, state) => const SlotsPage(),
    subRoutes: <RouteBase>[
      GoRoute(
        path: ':index',
        builder: (context, state) => SlotDetailPage(
          // A path that is not a slot index renders the not-found state
          // rather than throwing in a route builder.
          index: int.tryParse(state.pathParameters['index'] ?? '') ?? -1,
        ),
      ),
    ],
  ),
```

`SlotDetailPage` is exported from the slots barrel, so add `export 'ui/slot_detail_page.dart';` to `app/lib/features/slots/slots.dart` — `app_sections.dart` imports the barrel, never the file.

ARB additions:

```json
  "slotDetailTitle": "Slot {number}",
  "@slotDetailTitle": {
    "description": "Title of the slot editor; the device's one-based slot number.",
    "placeholders": {"number": {"type": "int"}}
  },
  "slotNotFound": "That slot does not exist.",
  "@slotNotFound": {"description": "Shown when a slot route names an index the device does not have."},
```

```bash
cd app && flutter gen-l10n
```

```dart
// app/lib/features/slots/ui/slot_detail_page.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/routing/sub_page_scaffold.dart';
import '../../../l10n/app_localizations.dart';
import '../state/slot_view.dart';
import '../state/slot_views_provider.dart';

/// Spec 7.7 step 2's editor: everything one slot can be changed to. Layout
/// only — every mutation goes through `slotEditorProvider` (Task 5).
class SlotDetailPage extends ConsumerWidget {
  const SlotDetailPage({required this.index, super.key});

  /// The wire index, 0..7. `-1` when the route named something that is not
  /// an index at all.
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<SlotView> views = ref.watch(slotViewsProvider);
    final SlotView? view = views
        .where((SlotView v) => v.index == index)
        .firstOrNull;

    if (view == null) {
      return SubPageScaffold(
        title: l10n.slotsTitle,
        body: Padding(
          padding: const EdgeInsets.all(SpectraSpacing.lg),
          child: SpectraCard(child: Text(l10n.slotNotFound)),
        ),
      );
    }

    return SubPageScaffold(
      title: l10n.slotDetailTitle(view.number),
      body: ListView(
        padding: const EdgeInsets.all(SpectraSpacing.lg),
        children: const <Widget>[],
      ),
    );
  }
}
```

Wire the tap in `app/lib/features/slots/ui/slots_page.dart` — add `import 'package:go_router/go_router.dart';` and `import '../../../core/routing/routes.dart';`, then on the tile:

```dart
                onTap: () =>
                    GoRouter.of(context).go(AppRoutes.slot(view.index)),
```

- [ ] **Step 5: Run the tests and watch them pass**

```bash
cd app && flutter test
```

Expected: PASS, whole suite (the tools tests still pass through the renamed scaffold).

- [ ] **Step 6: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git add -A app/lib app/test
git commit -m "feat(slots): push a slot detail route on top of the Slots tab

Promotes ToolSubPageScaffold to core/routing/SubPageScaffold as its own doc
comment anticipated: a feature may not import another feature's internals,
and three sub-routes now need the same back affordance.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: `SlotEditor` — every mutation, as an `AsyncValue`

The one place a facade call happens. It never throws at the widget layer: a failure lands in the notifier's `AsyncError` and the screen renders it through the error catalog (spec 9), exactly as `ConnectController` does for connect.

Note what this task does **not** have to do: the wakelock. `SlotsFacade` wraps every mutation in `DeviceSession.busy`, and `sessionNeedsWakelock` (`app/lib/core/lifecycle/wakelock.dart`) already returns true whenever `session.isBusy` — so spec 7.4's "during a long operation the app holds a wakelock" is satisfied by construction. Step 1 proves it rather than assuming it.

**Files:**
- Create: `app/lib/features/slots/state/slot_editor_controller.dart`
- Test: `app/test/features/slots/slot_editor_controller_test.dart`

**Interfaces:**
- Consumes: `activeSessionProvider` (`ActiveSession?`) from `package:spectra/core/session/active_device.dart`; `ActiveSession` has `final DeviceSession session;`.
- Consumes: `SlotsFacade` via `session.slots` (`packages/chameleon/lib/src/session/facades/slots.dart`) — exactly these methods:
  - `Future<void> setActive(int index)`
  - `Future<void> setEnabled(int index, Sense sense, bool enabled)`
  - `Future<void> rename(int index, Sense sense, String nick)`
  - `Future<void> setTagType(int index, TagType type)` — **no sense parameter**; `TagType.sense` decides which side changes
  - `Future<void> resetToDefault(int index, TagType type)`
  - `Future<void> deleteSense(int index, Sense sense)`
  - `Future<List<Slot>> refresh()`
  Each of these already ends with SLOT_DATA_CONFIG_SAVE and writes through to `DeviceSession.slotsState`, so nothing here refreshes afterwards.
- Consumes: `SessionNotReady` from `package:chameleon/chameleon.dart` (a `ChameleonException` the error catalog maps to "That needs a connected device").
- Consumes: `sessionNeedsWakelock(DeviceSession?, ConnectionState)` from `package:spectra/core/lifecycle/wakelock.dart` (test only).
- Produces: `slotEditorProvider(int index)` — a `@riverpod class SlotEditor extends _$SlotEditor` with `Future<void> build(int index)` and the methods `makeActive()`, `setEnabled(Sense, bool)`, `rename(Sense, String)`, `setTagType(TagType)`, `clearSense(Sense)`, `reset()`.

- [ ] **Step 1: Write the failing tests**

```dart
// app/test/features/slots/slot_editor_controller_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/lifecycle/wakelock.dart';
import 'package:spectra/core/session/active_device.dart';
import 'package:spectra/features/slots/state/slot_editor_controller.dart';
import 'package:spectra/features/slots/state/slot_view.dart';
import 'package:spectra/features/slots/state/slot_views_provider.dart';

import '../../support/app_harness.dart';

SlotView _view(WidgetTester tester, int index) =>
    readProvider(tester, slotViewsProvider).firstWhere(
      (SlotView v) => v.index == index,
    );

void main() {
  testWidgetsApp('rename writes through to the slot cache', (tester) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);

    await readNotifier(tester, slotEditorProvider(2).notifier)
        .rename(Sense.hf, 'Front door');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(_view(tester, 2).slot.hfNick, 'Front door');
    expect(readProvider(tester, slotEditorProvider(2)).hasError, isFalse);
  });

  testWidgetsApp('setEnabled flips one sense and leaves the other alone', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);

    await readNotifier(tester, slotEditorProvider(0).notifier)
        .setEnabled(Sense.lf, false);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(_view(tester, 0).slot.lfEnabled, isFalse);
    expect(_view(tester, 0).slot.hfEnabled, isTrue);
  });

  testWidgetsApp('setTagType puts an HF type on the HF side', (tester) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);

    await readNotifier(tester, slotEditorProvider(3).notifier)
        .setTagType(TagType.ntag215);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(_view(tester, 3).slot.hfType, TagType.ntag215);
    expect(_view(tester, 3).slot.lfType, TagType.undefined);
  });

  testWidgetsApp('clearSense empties and disables that sense', (tester) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);

    await readNotifier(
      tester,
      slotEditorProvider(0).notifier,
    ).clearSense(Sense.hf);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(_view(tester, 0).slot.hfType, TagType.undefined);
    expect(_view(tester, 0).slot.hfEnabled, isFalse);
    // The LF side is untouched.
    expect(_view(tester, 0).slot.lfType, TagType.em410x);
  });

  testWidgetsApp('makeActive moves the active marker', (tester) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);

    await readNotifier(tester, slotEditorProvider(5).notifier).makeActive();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(_view(tester, 5).isActive, isTrue);
    expect(_view(tester, 0).isActive, isFalse);
  });

  testWidgetsApp('a facade failure becomes an AsyncError, never a throw', (
    tester,
  ) async {
    final FakeDevice device = FakeDevice();
    await tester.pumpWidget(testApp(transport: (_) => device));
    await connectToEmulator(tester);

    // Slot 9 does not exist: the firmware answers PAR_ERR, which the SDK
    // raises as ParameterError.
    await readNotifier(tester, slotEditorProvider(9).notifier).makeActive();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    final AsyncValue<void> state = readProvider(
      tester,
      slotEditorProvider(9),
    );
    expect(state.hasError, isTrue);
    expect(state.error, isA<ParameterError>());
  });

  testWidgetsApp('reset clears a failure', (tester) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);

    await readNotifier(tester, slotEditorProvider(9).notifier).makeActive();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(readProvider(tester, slotEditorProvider(9)).hasError, isTrue);

    readNotifier(tester, slotEditorProvider(9).notifier).reset();
    await tester.pump();
    expect(readProvider(tester, slotEditorProvider(9)).hasError, isFalse);
  });

  testWidgetsApp('a slot mutation holds the wakelock while it is in flight', (
    tester,
  ) async {
    final FakeDevice device = FakeDevice();
    await tester.pumpWidget(testApp(transport: (_) => device));
    await connectToEmulator(tester);

    final DeviceSession session =
        readProvider(tester, activeSessionProvider)!.session;
    expect(
      sessionNeedsWakelock(session, session.connectionState.value),
      isFalse,
      reason: 'idle',
    );

    // Slow the fake down so the mutation is observably in flight.
    device.latency = const Duration(milliseconds: 200);
    final Future<void> pending = readNotifier(
      tester,
      slotEditorProvider(4).notifier,
    ).rename(Sense.hf, 'slow');
    await tester.pump(const Duration(milliseconds: 20));

    expect(
      sessionNeedsWakelock(session, session.connectionState.value),
      isTrue,
      reason: 'SlotsFacade wraps every mutation in DeviceSession.busy',
    );

    device.latency = Duration.zero;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await pending;
    expect(
      sessionNeedsWakelock(session, session.connectionState.value),
      isFalse,
    );
  });
}
```

Add the notifier reader to the harness next to `readProvider`:

```dart
// append to app/test/support/app_harness.dart
/// The notifier behind a provider, read from inside a pumped app.
NotifierT readNotifier<NotifierT, T>(
  WidgetTester tester,
  ProviderListenable<NotifierT> notifierProvider,
) => ProviderScope.containerOf(
  tester.element(find.byType(SpectraRoot)),
).read(notifierProvider);
```

The argument is always the provider's `.notifier` — `slotEditorProvider(2).notifier` is the `ProviderListenable<SlotEditor>` this helper takes, and every call above is written that way.

- [ ] **Step 2: Run them and watch them fail**

```bash
cd app && flutter test test/features/slots/slot_editor_controller_test.dart
```

Expected: FAIL — `slot_editor_controller.dart` does not exist.

- [ ] **Step 3: Write the controller**

```dart
// app/lib/features/slots/state/slot_editor_controller.dart
import 'package:chameleon/chameleon.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/session/active_device.dart';

part 'slot_editor_controller.g.dart';

/// Every change to one slot, as an [AsyncValue] the screen renders.
///
/// Failures stay in the state rather than being thrown, so the editor shows
/// them through the error catalog (spec 9) instead of catching. One notifier
/// per slot index, so a failure on slot 3 does not grey out slot 4.
///
/// Nothing here refreshes afterwards: every [SlotsFacade] method already
/// ends with SLOT_DATA_CONFIG_SAVE and writes the change through to
/// `DeviceSession.slotsState`, which `slotViewsProvider` is watching. The
/// facade also wraps each call in `DeviceSession.busy`, which is what
/// `sessionNeedsWakelock` polls — so spec 7.4's wakelock is held for the
/// duration with nothing to do here.
@riverpod
class SlotEditor extends _$SlotEditor {
  @override
  Future<void> build(int index) async {}

  /// Emulate this slot from now on (SET_ACTIVE_SLOT).
  Future<void> makeActive() =>
      _run((SlotsFacade slots) => slots.setActive(index));

  Future<void> setEnabled(Sense sense, bool enabled) =>
      _run((SlotsFacade slots) => slots.setEnabled(index, sense, enabled));

  /// The caller validates with `validateSlotNickname` first: the SDK's own
  /// length check throws an `ArgumentError`, which is not a
  /// `ChameleonException` and would reach the catalog as "something
  /// unexpected went wrong".
  Future<void> rename(Sense sense, String nick) =>
      _run((SlotsFacade slots) => slots.rename(index, sense, nick));

  /// [type] carries its own sense, so this changes exactly one side.
  Future<void> setTagType(TagType type) =>
      _run((SlotsFacade slots) => slots.setTagType(index, type));

  /// Empties one sense: the type becomes undefined and the sense is
  /// disabled (DELETE_SLOT_SENSE_TYPE).
  Future<void> clearSense(Sense sense) =>
      _run((SlotsFacade slots) => slots.deleteSense(index, sense));

  /// Clears a failed change back to idle, so the screen can offer the
  /// action again (spec 9's retry).
  void reset() => state = const AsyncData<void>(null);

  Future<void> _run(Future<void> Function(SlotsFacade slots) body) async {
    final ActiveSession? active = ref.read(activeSessionProvider);
    if (active == null) {
      state = AsyncError<void>(
        const SessionNotReady('no active session'),
        StackTrace.current,
      );
      return;
    }
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard<void>(() => body(active.session.slots));
  }
}
```

`ActiveSession` comes from `package:spectra/core/session/active_session.dart`; add that import if the analyzer asks (`active_device.dart` re-exports nothing).

- [ ] **Step 4: Generate and run**

```bash
cd app && dart run build_runner build --delete-conflicting-outputs \
  && flutter test test/features/slots/slot_editor_controller_test.dart
```

Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git add app/lib/features/slots app/test
git commit -m "feat(slots): add the per-slot editor notifier

One notifier per slot index turns each SlotsFacade call into an AsyncValue,
so the screen renders a failure through the error catalog instead of
catching. The facade's own busy wrapper already holds the wakelock; a test
pins that rather than leaving it assumed.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: The detail screen's header — active slot and per-sense enable

The first half of the editor: which slot this is, whether it is the active one, and a switch per sense. The form is disabled while a change is in flight, so a second tap cannot race the first.

**Files:**
- Create: `app/lib/features/slots/ui/slot_sense_section.dart`
- Modify: `app/lib/features/slots/ui/slot_detail_page.dart`, `app/lib/l10n/app_en.arb`
- Test: `app/test/features/slots/slot_detail_page_test.dart` (append)

**Interfaces:**
- Consumes: `SlotView`, `slotViewsProvider`, `slotEditorProvider(index)`, `senseLabel`, `tagTypeLabel`.
- Consumes: `Switch({required bool value, required ValueChanged<bool>? onChanged, ...})` from `package:material_ui/material_ui.dart` (`material_ui-1.1.1/lib/src/switch.dart`). A null `onChanged` renders it disabled.
- Consumes: `SpectraListTile`, `SpectraCard`, `SpectraSectionHeader`, `SpectraButton`, `SpectraStatusChip` from `package:spectra_ui/spectra_ui.dart`.
- Produces: `class SlotSenseSection extends ConsumerWidget` with `const SlotSenseSection({required SlotView view, required Sense sense, required bool busy, super.key})`. This task gives it the enable switch and the type row; Tasks 7 and 8 add the name field and the type/clear actions to the same widget.
- Produces: ARB keys `slotActive`, `slotInactive`, `slotMakeActive`, `slotEnabled`.

- [ ] **Step 1: Write the failing tests**

Append to `app/test/features/slots/slot_detail_page_test.dart`:

```dart
  testWidgetsApp('slot 1 says it is already the active slot', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 1);

    expect(find.text('Active'), findsWidgets);
    expect(find.text('Make active'), findsNothing);
  });

  testWidgetsApp('making slot 4 active moves the marker on the grid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 4);

    await tester.tap(find.text('Make active'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Make active'), findsNothing);

    await tester.tap(find.byType(BackButton));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final SpectraSlotTile fourth = tester.widget<SpectraSlotTile>(
      find.byType(SpectraSlotTile).at(3),
    );
    expect(fourth.active, isTrue);
  });

  testWidgetsApp('turning the LF sense off writes through to the device', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 1);

    // Two switches: HF first, then LF.
    expect(find.byType(Switch), findsNWidgets(2));
    expect(tester.widget<Switch>(find.byType(Switch).at(1)).value, isTrue);

    await tester.tap(find.byType(Switch).at(1));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.widget<Switch>(find.byType(Switch).at(1)).value, isFalse);
  });
```

- [ ] **Step 2: Run and watch fail**

```bash
cd app && flutter test test/features/slots/slot_detail_page_test.dart
```

Expected: FAIL — the detail body is still an empty list.

- [ ] **Step 3: Add the ARB strings and regenerate**

```json
  "slotActive": "Active",
  "@slotActive": {"description": "Marks the slot the device is emulating."},
  "slotMakeActive": "Make active",
  "@slotMakeActive": {"description": "Button that switches the device to this slot."},
  "slotInactive": "Not the active slot",
  "@slotInactive": {"description": "Shown on a slot the device is not currently emulating."},
  "slotEnabled": "Enabled",
  "@slotEnabled": {"description": "Label of the per-sense enable switch."},
```

```bash
cd app && flutter gen-l10n
```

- [ ] **Step 4: Write the sense section and fill in the page**

```dart
// app/lib/features/slots/ui/slot_sense_section.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../state/slot_editor_controller.dart';
import '../state/slot_labels.dart';
import '../state/slot_view.dart';

/// One side of a slot: its tag type, its enable switch, its name and the
/// actions that change them. Layout only.
class SlotSenseSection extends ConsumerWidget {
  const SlotSenseSection({
    required this.view,
    required this.sense,
    required this.busy,
    super.key,
  });

  final SlotView view;
  final Sense sense;

  /// True while a change to this slot is in flight: every control is
  /// disabled so a second tap cannot race the first.
  final bool busy;

  TagType get _type =>
      sense == Sense.lf ? view.slot.lfType : view.slot.hfType;

  bool get _enabled =>
      sense == Sense.lf ? view.slot.lfEnabled : view.slot.hfEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SlotEditor editor = ref.read(
      slotEditorProvider(view.index).notifier,
    );

    return SpectraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SpectraSectionHeader(title: senseLabel(sense, l10n)),
          SpectraListTile(
            title: l10n.slotEnabled,
            subtitle: tagTypeLabel(_type, l10n),
            trailing: Switch(
              value: _enabled,
              onChanged: busy
                  ? null
                  : (bool next) => editor.setEnabled(sense, next),
            ),
          ),
        ],
      ),
    );
  }
}
```

`app/lib/features/slots/ui/slot_detail_page.dart` — replace the empty body with the header plus the two sections:

```dart
    final AsyncValue<void> editing = ref.watch(slotEditorProvider(index));
    final bool busy = editing.isLoading;

    return SubPageScaffold(
      title: l10n.slotDetailTitle(view.number),
      body: ListView(
        padding: const EdgeInsets.all(SpectraSpacing.lg),
        children: <Widget>[
          SpectraCard(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    view.isActive ? l10n.slotActive : l10n.slotInactive,
                  ),
                ),
                if (!view.isActive)
                  SpectraButton(
                    label: l10n.slotMakeActive,
                    variant: SpectraButtonVariant.secondary,
                    onPressed: busy
                        ? null
                        : () => ref
                              .read(slotEditorProvider(index).notifier)
                              .makeActive(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: SpectraSpacing.md),
          SlotSenseSection(view: view, sense: Sense.hf, busy: busy),
          const SizedBox(height: SpectraSpacing.md),
          SlotSenseSection(view: view, sense: Sense.lf, busy: busy),
        ],
      ),
    );
```

…with `import 'package:chameleon/chameleon.dart';`, `import 'package:material_ui/material_ui.dart' hide ConnectionState;`, `import '../state/slot_editor_controller.dart';` and `import 'slot_sense_section.dart';` added, plus `import 'package:flutter_riverpod/flutter_riverpod.dart';` for `AsyncValue`.

`SlotEditor` methods return futures the widget layer does not await; `onPressed` is a `VoidCallback`, so wrap each call in a block body and mark it `unawaited(...)` (`import 'dart:async';`) to keep `--fatal-infos` happy.

- [ ] **Step 5: Run the tests and watch them pass**

```bash
cd app && flutter test test/features/slots
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git add app/lib/features/slots app/lib/l10n app/test
git commit -m "feat(slots): edit the active slot and each sense's enable flag

The form disables itself while a change is in flight, so a second tap
cannot race the first down one transport.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: Renaming a slot, with validation

A name field per sense: seeded from the device's nickname, validated against the 32-byte wire limit before anything is sent, saved with an explicit action (a rename per keystroke would be eight commands a second down a BLE link).

**Files:**
- Modify: `app/lib/features/slots/ui/slot_sense_section.dart`, `app/lib/l10n/app_en.arb`
- Test: `app/test/features/slots/slot_detail_page_test.dart` (append)

**Interfaces:**
- Consumes: `validateSlotNickname`, `SlotNicknameError`, `slotNicknameMaxBytes` (Task 1); `slotEditorProvider(index).notifier.rename(Sense, String)` (Task 5).
- Consumes: `SpectraTextField({required String label, TextEditingController? controller, String? hint, String? errorText, ValueChanged<String>? onChanged, bool enabled = true, ValueChanged<String>? onSubmitted, ...})`.
- Produces: `SlotSenseSection` becomes a `ConsumerStatefulWidget` — it owns a `TextEditingController` seeded from the slot's nickname and re-seeded in `didUpdateWidget` when the device's nickname changes underneath it.
- Produces: ARB keys `slotNameLabel`, `slotSaveName`.

- [ ] **Step 1: Write the failing tests**

Append to `app/test/features/slots/slot_detail_page_test.dart`:

```dart
  testWidgetsApp('the name field is seeded from the device', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 1);

    expect(find.widgetWithText(SpectraTextField, 'Fake 1K'), findsOneWidget);
  });

  testWidgetsApp('renaming a slot writes through and shows on the grid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 2);

    await tester.enterText(find.byType(SpectraTextField).first, 'Office');
    await tester.pump();
    await tester.tap(find.text('Save name').first);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    await tester.tap(find.byType(BackButton));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Office'), findsOneWidget);
  });

  testWidgetsApp('a name over 32 bytes is refused before it is sent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final FakeDevice device = FakeDevice();
    await tester.pumpWidget(testApp(transport: (_) => device));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 2);

    final int before = device.received.length;
    await tester.enterText(find.byType(SpectraTextField).first, 'x' * 33);
    await tester.pump();

    expect(find.text('Names are limited to 32 bytes.'), findsOneWidget);
    // The save action is disabled, so nothing reached the wire.
    expect(
      tester
          .widget<SpectraButton>(
            find.widgetWithText(SpectraButton, 'Save name').first,
          )
          .onPressed,
      isNull,
    );
    expect(device.received.length, before);
  });
```

- [ ] **Step 2: Run and watch fail**

```bash
cd app && flutter test test/features/slots/slot_detail_page_test.dart
```

Expected: FAIL — no `SpectraTextField` on the screen.

- [ ] **Step 3: Add the ARB strings and regenerate**

```json
  "slotNameLabel": "Name",
  "@slotNameLabel": {"description": "Label of the slot nickname field."},
  "slotSaveName": "Save name",
  "@slotSaveName": {"description": "Sends the edited slot nickname to the device."},
```

```bash
cd app && flutter gen-l10n
```

- [ ] **Step 4: Turn `SlotSenseSection` into a stateful section with a name field**

```dart
// app/lib/features/slots/ui/slot_sense_section.dart — full file
import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../state/slot_editor_controller.dart';
import '../state/slot_labels.dart';
import '../state/slot_nickname.dart';
import '../state/slot_view.dart';

/// One side of a slot: its tag type, its enable switch, its name and the
/// actions that change them. Layout only — every mutation is
/// `slotEditorProvider`.
///
/// Stateful purely for the name field's controller. The name is saved with
/// an explicit action rather than on every keystroke: a rename is two
/// commands (SET_SLOT_TAG_NICK then SLOT_DATA_CONFIG_SAVE), and sending
/// that per character would flood a BLE link.
class SlotSenseSection extends ConsumerStatefulWidget {
  const SlotSenseSection({
    required this.view,
    required this.sense,
    required this.busy,
    super.key,
  });

  final SlotView view;
  final Sense sense;
  final bool busy;

  @override
  ConsumerState<SlotSenseSection> createState() => _SlotSenseSectionState();
}

class _SlotSenseSectionState extends ConsumerState<SlotSenseSection> {
  late final TextEditingController _name = TextEditingController(
    text: _deviceNick,
  );

  String get _deviceNick => widget.sense == Sense.lf
      ? widget.view.slot.lfNick
      : widget.view.slot.hfNick;

  TagType get _type => widget.sense == Sense.lf
      ? widget.view.slot.lfType
      : widget.view.slot.hfType;

  bool get _enabled => widget.sense == Sense.lf
      ? widget.view.slot.lfEnabled
      : widget.view.slot.hfEnabled;

  @override
  void didUpdateWidget(SlotSenseSection old) {
    super.didUpdateWidget(old);
    // The device's own nickname changed (a save landed, or a refresh): pick
    // it up, unless the user is part-way through typing a different one.
    final String previous = old.sense == Sense.lf
        ? old.view.slot.lfNick
        : old.view.slot.hfNick;
    if (previous != _deviceNick && _name.text == previous) {
      _name.text = _deviceNick;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SlotEditor editor = ref.read(
      slotEditorProvider(widget.view.index).notifier,
    );
    final SlotNicknameError? nameError = validateSlotNickname(_name.text);
    final bool canSave =
        !widget.busy && nameError == null && _name.text != _deviceNick;

    return SpectraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SpectraSectionHeader(title: senseLabel(widget.sense, l10n)),
          SpectraListTile(
            title: l10n.slotEnabled,
            subtitle: tagTypeLabel(_type, l10n),
            trailing: Switch(
              value: _enabled,
              onChanged: widget.busy
                  ? null
                  : (bool next) => unawaited(
                      editor.setEnabled(widget.sense, next),
                    ),
            ),
          ),
          const SizedBox(height: SpectraSpacing.md),
          SpectraTextField(
            label: l10n.slotNameLabel,
            controller: _name,
            enabled: !widget.busy,
            errorText: switch (nameError) {
              SlotNicknameError.tooLong => l10n.slotNicknameTooLong,
              null => null,
            },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: SpectraSpacing.md),
          SpectraButton(
            label: l10n.slotSaveName,
            variant: SpectraButtonVariant.secondary,
            onPressed: canSave
                ? () => unawaited(editor.rename(widget.sense, _name.text))
                : null,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run the tests and watch them pass**

```bash
cd app && flutter test test/features/slots
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git add app/lib/features/slots app/lib/l10n app/test
git commit -m "feat(slots): rename a slot, validated against the wire limit

The nickname is checked for the firmware's 32-byte limit before it is sent,
because the SDK's own check throws an ArgumentError the error catalog
cannot describe. Saving is an explicit action so a rename is not two
commands per keystroke.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 8: Changing and clearing the tag type

A sheet to pick the type for a sense, and a confirmed destructive action to clear it. Clearing is `DELETE_SLOT_SENSE_TYPE` (the facade's `deleteSense`), which empties the type and disables the sense — so it gets a dialog, not a bare button.

**Files:**
- Create: `app/lib/features/slots/ui/tag_type_sheet.dart`
- Modify: `app/lib/features/slots/ui/slot_sense_section.dart`, `app/lib/l10n/app_en.arb`
- Test: `app/test/features/slots/tag_type_sheet_test.dart`

**Interfaces:**
- Consumes: `selectableTypes(Sense)`, `tagTypeLabel`, `senseLabel` (Task 1); `slotEditorProvider(index).notifier.setTagType(TagType)` and `.clearSense(Sense)` (Task 5).
- Consumes: `SpectraBottomSheet.show<T>({required BuildContext context, required String title, required WidgetBuilder builder})` — returns the popped value; `SpectraDialog.show<T>({required BuildContext context, required String title, required Widget content, required List<Widget> Function(BuildContext) actions})`.
- Produces: `Future<TagType?> showTagTypeSheet(BuildContext context, {required Sense sense, required TagType current})` in `tag_type_sheet.dart`.
- Produces: ARB keys `slotTagType`, `slotChangeType`, `slotChooseType`, `slotClear`, `slotClearTitle`, `slotClearBody` (placeholder `sense`, `String`), `commonCancel`.

- [ ] **Step 1: Write the failing tests**

```dart
// app/test/features/slots/tag_type_sheet_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

void main() {
  testWidgetsApp('picking a type from the sheet writes it to the slot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 3);

    // The HF section's "Change type" is the first one on the screen.
    await tester.tap(find.text('Change type').first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Choose a tag type'), findsOneWidget);
    expect(find.text('NTAG215'), findsOneWidget);
    // The sheet offers HF types only.
    expect(find.text('EM410x'), findsNothing);

    await tester.tap(find.text('NTAG215'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('NTAG215'), findsWidgets);
    await tester.tap(find.byType(BackButton));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final SpectraSlotTile third = tester.widget<SpectraSlotTile>(
      find.byType(SpectraSlotTile).at(2),
    );
    expect(third.tagTypes, contains('NTAG215'));
  });

  testWidgetsApp('clearing a sense asks first, then empties it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 1);

    await tester.tap(find.text('Clear').first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Clear this slot?'), findsOneWidget);

    // Cancelling changes nothing.
    await tester.tap(find.text('Cancel'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('MIFARE Classic 1K'), findsWidgets);

    await tester.tap(find.text('Clear').first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Clear').last);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('MIFARE Classic 1K'), findsNothing);
    expect(find.text('Empty'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run and watch fail**

```bash
cd app && flutter test test/features/slots/tag_type_sheet_test.dart
```

Expected: FAIL — no "Change type" or "Clear" on the screen.

- [ ] **Step 3: Add the ARB strings and regenerate**

```json
  "slotTagType": "Tag type",
  "@slotTagType": {"description": "Label of the row showing a sense's tag type."},
  "slotChangeType": "Change type",
  "@slotChangeType": {"description": "Opens the tag type picker for one sense."},
  "slotChooseType": "Choose a tag type",
  "@slotChooseType": {"description": "Title of the tag type sheet."},
  "slotClear": "Clear",
  "@slotClear": {"description": "Empties one sense of a slot."},
  "slotClearTitle": "Clear this slot?",
  "@slotClearTitle": {"description": "Title of the clear-sense confirmation."},
  "slotClearBody": "This removes the tag type and the emulated data on the {sense} side. It cannot be undone.",
  "@slotClearBody": {
    "description": "Body of the clear-sense confirmation; the sense's name.",
    "placeholders": {"sense": {"type": "String"}}
  },
  "commonCancel": "Cancel",
  "@commonCancel": {"description": "Dismisses a dialog without acting."},
```

```bash
cd app && flutter gen-l10n
```

- [ ] **Step 4: Write the sheet and wire the two actions**

```dart
// app/lib/features/slots/ui/tag_type_sheet.dart
import 'package:chameleon/chameleon.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../state/slot_labels.dart';

/// Asks which tag type a sense should hold. Resolves to the chosen type, or
/// null when the sheet is dismissed.
///
/// The list is `selectableTypes(sense)` — derived from the SDK's own
/// [TagFamily] classification, so it can never name a type the SDK does not
/// have.
Future<TagType?> showTagTypeSheet(
  BuildContext context, {
  required Sense sense,
  required TagType current,
}) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return SpectraBottomSheet.show<TagType>(
    context: context,
    title: l10n.slotChooseType,
    builder: (BuildContext context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          for (final TagType type in selectableTypes(sense))
            SpectraListTile(
              title: tagTypeLabel(type, l10n),
              trailing: type == current
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(context).pop(type),
            ),
        ],
      ),
    ),
  );
}
```

In `slot_sense_section.dart`, add the type row's action and the clear action below the name field (inside the same `Column`, after the save button):

```dart
          const SizedBox(height: SpectraSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: SpectraButton(
                  label: l10n.slotChangeType,
                  variant: SpectraButtonVariant.secondary,
                  onPressed: widget.busy ? null : _changeType,
                ),
              ),
              const SizedBox(width: SpectraSpacing.sm),
              Expanded(
                child: SpectraButton(
                  label: l10n.slotClear,
                  variant: SpectraButtonVariant.danger,
                  onPressed: widget.busy || _type == TagType.undefined
                      ? null
                      : _clear,
                ),
              ),
            ],
          ),
```

…and the two handlers on the state class:

```dart
  Future<void> _changeType() async {
    final TagType? chosen = await showTagTypeSheet(
      context,
      sense: widget.sense,
      current: _type,
    );
    if (chosen == null || !mounted) return;
    await ref
        .read(slotEditorProvider(widget.view.index).notifier)
        .setTagType(chosen);
  }

  Future<void> _clear() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? confirmed = await SpectraDialog.show<bool>(
      context: context,
      title: l10n.slotClearTitle,
      content: Text(l10n.slotClearBody(senseLabel(widget.sense, l10n))),
      actions: (BuildContext context) => <Widget>[
        SpectraButton(
          label: l10n.commonCancel,
          variant: SpectraButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        SpectraButton(
          label: l10n.slotClear,
          variant: SpectraButtonVariant.danger,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    await ref
        .read(slotEditorProvider(widget.view.index).notifier)
        .clearSense(widget.sense);
  }
```

…with `import 'tag_type_sheet.dart';` added. `_changeType` and `_clear` are `Future<void> Function()`s, which a `VoidCallback` slot accepts only via a wrapper — write `onPressed: widget.busy ? null : () => unawaited(_changeType())` and the same for `_clear`.

- [ ] **Step 5: Run the tests and watch them pass**

```bash
cd app && flutter test test/features/slots
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git add app/lib/features/slots app/lib/l10n app/test
git commit -m "feat(slots): change and clear a sense's tag type

The picker's list is derived from the SDK's TagFamily classification rather
than hand-typed, so it cannot offer a type the SDK has never heard of.
Clearing is destructive, so it asks first.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 9: Failures, in spec 9's shape

A change that fails has to say so on the screen it failed on: one plain sentence, a recovery action, the raw line one tap away. The connect screen already has this widget shape (`ConnectProblemView`); the slot editor needs its own because the retry semantics differ — retrying a slot change means clearing the editor's error, not re-scanning.

**Files:**
- Create: `app/lib/features/slots/ui/slot_problem_view.dart`
- Modify: `app/lib/features/slots/ui/slot_detail_page.dart`, `app/lib/l10n/app_en.arb`
- Test: `app/test/features/slots/slot_detail_page_test.dart` (append)

**Interfaces:**
- Consumes: `ErrorCatalog(AppLocalizations)` with `ErrorPresentation describe(Object error)`; `ErrorPresentation({required String message, required ErrorRecovery recovery, required String detail, String? instructions})`; `enum ErrorRecovery { retry, openSettings, platformInstructions, reconnect, update, none }` — all from `package:spectra/core/errors/error_catalog.dart` and `error_presentation.dart`.
- Consumes: `SpectraDisclosure({required Widget summary, required Widget detail, ...})`, `SpectraProgressIndicator({required String label, double? value, String? detail, VoidCallback? onCancel})`.
- Consumes: `l10n.commonDetails`, `l10n.commonRetry`, `l10n.commonOpenSettings`, `l10n.commonUpdateFirmware` (all already in the ARB from Phase 4).
- Produces: `class SlotProblemView extends StatelessWidget` with `const SlotProblemView({required Object error, required VoidCallback onDismiss, super.key})`.
- Produces: ARB key `slotSaving`.

- [ ] **Step 1: Write the failing test**

Append to `app/test/features/slots/slot_detail_page_test.dart`:

```dart
  testWidgetsApp('a dropped link takes the editor back to connect', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final FakeDevice device = FakeDevice();
    await tester.pumpWidget(testApp(transport: (_) => device));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 2);

    // The link dies, so the next command cannot be answered.
    await device.simulateLinkLoss();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    // Routing bounces a dropped session to /connect (spec 7.2), so the
    // editor's own failure path is proven on the notifier instead: the
    // screen renders whatever the notifier holds.
    expect(find.text('Connect a device'), findsOneWidget);
  });

  testWidgetsApp('the editor renders a notifier error through the catalog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);
    await openSlot(tester, 2);

    // The message has to be on the *visible* slot's editor to reach the
    // screen, and every operation slot 2 offers succeeds against the fake.
    // So put the failure there directly rather than inventing a command the
    // firmware would refuse.
    readNotifier(tester, slotEditorProvider(2).notifier).state =
        AsyncError<void>(const ParameterError(), StackTrace.current);
    await tester.pump();

    expect(
      find.text('The device rejected that value.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Details'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('ParameterError'), findsWidgets);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(
      find.text('The device rejected that value.'),
      findsNothing,
    );
  });
```

Two notes for the implementer:

1. `SlotEditor.state` is protected on a riverpod notifier. If assigning it from a test does not compile, add a test-only method to the notifier — `@visibleForTesting void debugFail(Object error) => state = AsyncError<void>(error, StackTrace.current);` — rather than loosening the production API. Use whichever the analyzer accepts and say which in the report.
2. `l10n.errorParameter`'s exact wording is in `app/lib/l10n/app_en.arb`; read it and use that string in the expectation rather than the one written above if they differ.

- [ ] **Step 2: Run and watch fail**

```bash
cd app && flutter test test/features/slots/slot_detail_page_test.dart
```

Expected: FAIL — the editor renders nothing for an error.

- [ ] **Step 3: Add the ARB string and regenerate**

```json
  "slotSaving": "Saving to the device…",
  "@slotSaving": {"description": "Progress label while a slot change is in flight."},
```

```bash
cd app && flutter gen-l10n
```

- [ ] **Step 4: Write the problem view and mount it**

```dart
// app/lib/features/slots/ui/slot_problem_view.dart
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/error_catalog.dart';
import '../../../core/errors/error_presentation.dart';
import '../../../l10n/app_localizations.dart';

/// A slot change that failed, in the shape spec 9 asks for: one plain
/// sentence, a recovery action, and the raw line one tap away.
///
/// Unlike the connect screen's version, the only action here is "dismiss
/// and try again" — a slot change has nothing to reconnect or re-scan, and
/// the controls that produced the failure are still on screen. The recovery
/// enum still chooses the button's words so the copy stays consistent with
/// the rest of the app.
class SlotProblemView extends StatelessWidget {
  const SlotProblemView({
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

In `slot_detail_page.dart`, above the header card in the `ListView`:

```dart
          if (busy)
            SpectraProgressIndicator(label: l10n.slotSaving),
          if (editing.error case final Object problem) ...<Widget>[
            SlotProblemView(
              error: problem,
              onDismiss: () =>
                  ref.read(slotEditorProvider(index).notifier).reset(),
            ),
            const SizedBox(height: SpectraSpacing.md),
          ],
```

…with `import 'slot_problem_view.dart';` added.

- [ ] **Step 5: Run the tests and watch them pass**

```bash
cd app && flutter test test/features/slots && flutter test
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git add app/lib/features/slots app/lib/l10n app/test
git commit -m "feat(slots): show a failed slot change in spec 9's shape

One sentence, a recovery action and the raw line one tap away, from the
same localized catalog every other screen uses.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 10: The public slot picker API

Spec 8.3: "`slots` exports the slot picker and its providers". This is the contract Phase 6's "save a read card to a slot" and Phase 7's "load a saved card into a slot" call. It is the only surface another feature may touch, so it is documented as a contract, exported from the barrel, and tested from outside the feature.

**Files:**
- Create: `app/lib/features/slots/ui/slot_picker.dart`
- Modify: `app/lib/features/slots/slots.dart`, `app/lib/l10n/app_en.arb`
- Test: `app/test/features/slots/slot_picker_test.dart`

**Interfaces:**
- Consumes: `slotViewsProvider`, `SlotView`, `slotTypeLabels`, `SpectraSlotTile`, `SpectraBottomSheet.show`.
- Produces, and these names are frozen for Phases 6-7:
  - `Future<int?> showSlotPicker(BuildContext context, {int? initialIndex, bool Function(SlotView slot)? isSelectable})` — presents the sheet and resolves to the chosen **wire index** (0..7), or null if dismissed.
  - `class SlotPicker extends ConsumerWidget` with `const SlotPicker({int? initialIndex, bool Function(SlotView)? isSelectable, super.key})` — the sheet's body, so a caller that wants it inline rather than modal has it.
  - Re-exported from `package:spectra/features/slots/slots.dart`, together with `SlotView`, `slotViewsProvider`, `tagTypeLabel` and `senseLabel`.
- Produces: ARB key `slotPickerTitle`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/slots/slot_picker_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/features/slots/slots.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

void main() {
  testWidgetsApp('the picker resolves to the chosen wire index', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);

    int? chosen;
    final BuildContext context = tester.element(find.byType(SlotsPage));
    final Future<int?> pending = showSlotPicker(context).then((int? i) {
      chosen = i;
      return i;
    });
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Choose a slot'), findsOneWidget);
    // Eight tiles in the sheet, on top of the eight on the grid behind it.
    expect(find.byType(SpectraSlotTile), findsNWidgets(16));

    await tester.tap(find.byType(SpectraSlotTile).at(12));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await pending;
    expect(chosen, 4, reason: 'the fifth tile in the sheet is wire index 4');
  });

  testWidgetsApp('dismissing the picker resolves to null', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);

    final BuildContext context = tester.element(find.byType(SlotsPage));
    final Future<int?> pending = showSlotPicker(context);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byIcon(Icons.close));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(await pending, isNull);
  });

  testWidgetsApp('isSelectable greys out the slots a caller cannot use', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openSlots(tester);

    final BuildContext context = tester.element(find.byType(SlotsPage));
    final Future<int?> pending = showSlotPicker(
      context,
      // Only the seeded slot 0 has an HF type.
      isSelectable: (SlotView v) => v.slot.hfType != TagType.undefined,
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Sheet tiles are the last eight.
    final Iterable<SpectraSlotTile> sheetTiles = tester
        .widgetList<SpectraSlotTile>(find.byType(SpectraSlotTile))
        .skip(8);
    expect(sheetTiles.first.onTap, isNotNull);
    expect(sheetTiles.elementAt(1).onTap, isNull);

    await tester.tap(find.byIcon(Icons.close));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await pending;
  });
}
```

- [ ] **Step 2: Run and watch fail**

```bash
cd app && flutter test test/features/slots/slot_picker_test.dart
```

Expected: FAIL — `showSlotPicker` is not exported from the barrel.

- [ ] **Step 3: Add the ARB string and regenerate**

```json
  "slotPickerTitle": "Choose a slot",
  "@slotPickerTitle": {"description": "Title of the slot picker sheet other features open."},
```

```bash
cd app && flutter gen-l10n
```

- [ ] **Step 4: Write the picker**

```dart
// app/lib/features/slots/ui/slot_picker.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../state/slot_labels.dart';
import '../state/slot_view.dart';
import '../state/slot_views_provider.dart';

/// **The Slots feature's public API** (spec 8.3). Asks the user which of the
/// device's eight slots to use, and resolves to that slot's **wire index**
/// (0..7) — the same number `SlotsFacade` takes — or null if the sheet was
/// dismissed.
///
/// Contract for the features that call it (Phase 6 "save to slot", Phase 7
/// "load to slot"):
///
/// - Import it as `package:spectra/features/slots/slots.dart`. Never reach
///   into `features/slots/ui/…` or `features/slots/state/…` (spec 8.4).
/// - The returned index is a wire index, not a display number. Pass it
///   straight to `session.slots`; add one only when showing it to a person.
/// - It resolves to null on dismissal, and callers must handle that: it is
///   the normal way out of the sheet, not an error.
/// - [isSelectable] filters what may be chosen — an unselectable slot is
///   still shown, greyed and untappable, so the user can see why a slot is
///   not on offer. Pass, say, `(v) => v.slot.hfType.family ==
///   TagFamily.mifareClassic` to restrict a MIFARE Classic write target.
/// - With nothing connected the sheet shows the empty state and can only be
///   dismissed; it never opens a session of its own.
/// - It changes nothing on the device. Choosing a slot is a choice, not a
///   write — the caller does the write.
Future<int?> showSlotPicker(
  BuildContext context, {
  int? initialIndex,
  bool Function(SlotView slot)? isSelectable,
}) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return SpectraBottomSheet.show<int>(
    context: context,
    title: l10n.slotPickerTitle,
    builder: (BuildContext context) => SlotPicker(
      initialIndex: initialIndex,
      isSelectable: isSelectable,
    ),
  );
}

/// The picker's body, for a caller that wants it inline rather than modal.
/// Pops the enclosing route with the chosen wire index.
class SlotPicker extends ConsumerWidget {
  const SlotPicker({this.initialIndex, this.isSelectable, super.key});

  final int? initialIndex;
  final bool Function(SlotView slot)? isSelectable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<SlotView> views = ref.watch(slotViewsProvider);
    if (views.isEmpty) return SpectraCard(child: Text(l10n.slotsEmpty));

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: views.length,
        separatorBuilder: (BuildContext context, int i) =>
            const SizedBox(height: SpectraSpacing.sm),
        itemBuilder: (BuildContext context, int i) {
          final SlotView view = views[i];
          final bool selectable = isSelectable?.call(view) ?? true;
          return SpectraSlotTile(
            number: view.number,
            enabled: view.isEnabled && selectable,
            nickname: view.nickname,
            tagTypes: slotTypeLabels(view, l10n),
            active: view.index == (initialIndex ?? -1) || view.isActive,
            onTap: selectable
                ? () => Navigator.of(context).pop(view.index)
                : null,
          );
        },
      ),
    );
  }
}
```

`app/lib/features/slots/slots.dart` — the whole barrel:

```dart
/// The Slots feature's public API (spec 8.3): its screens, and the slot
/// picker other features call to ask "which slot?".
///
/// Nothing else in the app may import `features/slots/…` directly. The
/// picker's contract is on [showSlotPicker].
library;

export 'state/slot_labels.dart' show senseLabel, tagTypeLabel;
export 'state/slot_view.dart' show SlotView;
export 'state/slot_views_provider.dart' show slotViewsProvider;
export 'ui/slot_detail_page.dart';
export 'ui/slot_picker.dart';
export 'ui/slots_page.dart';
```

- [ ] **Step 5: Run the tests and watch them pass**

```bash
cd app && flutter test test/features/slots && dart run melos run lint:deps
```

Expected: PASS, and the dependency lint stays green (the export list is the feature's only surface).

Note on `export ... show`: `slot_views_provider.dart` also declares the generated `SlotViews` element class; exporting only the provider keeps the barrel a contract rather than an accident. If `show slotViewsProvider` does not compile because the generated provider's type is needed too, widen to `show slotViewsProvider, SlotViewsProvider` — but do not export the file wholesale.

- [ ] **Step 6: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git add app/lib/features/slots app/lib/l10n app/test
git commit -m "feat(slots): export the slot picker as the feature's public API

Spec 8.3 makes the picker the one surface other features touch, so its
contract — wire index in, null on dismissal, no writes of its own — is
documented where Phase 6 and 7 will read it.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 11: The phase gate — edit and save a slot on the emulator

The roadmap's Phase 5 gate. Two files, the same flow: a widget test that runs in CI's Ubuntu `check` job, and an `integration_test` on a real engine that the macOS `integration` job picks up.

**Do not touch `.github/workflows/ci.yml`.** The `integration` job already runs `flutter test integration_test -d macos` over the whole directory, so a new file in it is picked up with no workflow change. Phase 4 ruling 14 (that job is push-only and not `continue-on-error`) stands untouched by construction.

**Files:**
- Create: `app/test/flows/slot_edit_flow_test.dart`, `app/integration_test/slot_edit_flow_test.dart`
- Test: those two files

**Interfaces:**
- Consumes: `testWidgetsApp`, `pumpTestApp`, `connectToEmulator`, `openSlots`, `openSlot`, `settleApp` from `app/test/support/app_harness.dart`.
- Consumes, in the integration test only (it builds its own root, as the Phase 4 integration test does — copy that file's override block verbatim after re-reading it): `SpectraDatabase.memory()`, `databaseProvider`, `scannersProvider`, `transportFactoryProvider`, `sessionOptionsProvider`, `SessionOptions(batteryDelay: Duration.zero)`, `FakeScanner()`, `FakeScanner.emulatedUltra.name`, `FakeDevice()`, `SpectraRoot`, `Override` from `package:flutter_riverpod/misc.dart`.
- Produces: nothing importable — these are the gate.

- [ ] **Step 1: Rebase and re-read the Phase 4 gate files**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git pull --rebase
cat app/test/flows/connect_flow_test.dart app/integration_test/connect_flow_test.dart
```

Another implementer may have changed the override block or the pump loops. Follow whatever is on disk.

- [ ] **Step 2: Write the flow widget test**

```dart
// app/test/flows/slot_edit_flow_test.dart
import 'dart:ui';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/app_harness.dart';

/// The roadmap's Phase 5 gate: edit and save a slot on the emulator.
/// `testWidgetsApp` (not plain `testWidgets`) so the app root's
/// stream-backed `ConnectPage` settles cleanly on teardown — see its own
/// doc comment.
void main() {
  testWidgetsApp('rename a slot, set its type, make it active', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await tester.pump();
    await connectToEmulator(tester);
    await openSlots(tester);

    expect(find.byType(SpectraSlotTile), findsNWidgets(8));
    await openSlot(tester, 3);

    // Name it.
    await tester.enterText(find.byType(SpectraTextField).first, 'Front door');
    await tester.pump();
    await tester.tap(find.text('Save name').first);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Give it a tag type.
    await tester.tap(find.text('Change type').first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('NTAG215'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Emulate it.
    await tester.tap(find.text('Make active'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Make active'), findsNothing);

    // Back on the grid, all three changes are visible.
    await tester.tap(find.byType(BackButton));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final SpectraSlotTile third = tester.widget<SpectraSlotTile>(
      find.byType(SpectraSlotTile).at(2),
    );
    expect(third.nickname, 'Front door');
    expect(third.tagTypes, contains('NTAG215'));
    expect(third.active, isTrue);
  });
}
```

`BackButton` comes from `package:material_ui/material_ui.dart`; add that import (this file is under `test/`, not `lib/features/`, so the material lint does not apply — but keep to `material_ui` anyway for consistency with everything else).

- [ ] **Step 3: Run it and watch it pass**

```bash
cd app && flutter test test/flows/slot_edit_flow_test.dart
```

Expected: PASS. (It is written after the feature, so it passes first time; if it does not, the feature is wrong, not the test.)

- [ ] **Step 4: Write the integration test**

```dart
// app/integration_test/slot_edit_flow_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/app.dart';
import 'package:spectra/core/discovery/scanners.dart';
import 'package:spectra/core/session/sessions.dart';
import 'package:spectra/data/database/database_providers.dart';
import 'package:spectra/data/database/spectra_database.dart';
import 'package:spectra_ui/spectra_ui.dart';

/// The Phase 5 gate on a real engine: edit and save a slot in emulator
/// mode. No hardware is touched, and none is needed.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('edit and save a slot on the emulator', (tester) async {
    final db = SpectraDatabase.memory();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          databaseProvider.overrideWithValue(db),
          scannersProvider.overrideWithValue(<DeviceScanner>[FakeScanner()]),
          transportFactoryProvider.overrideWithValue((_) => FakeDevice()),
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

    await tester.tap(find.text('Slots').last);
    await settle();
    expect(find.byType(SpectraSlotTile), findsNWidgets(8));

    await tester.tap(find.byType(SpectraSlotTile).at(2));
    await settle();

    await tester.enterText(find.byType(SpectraTextField).first, 'Front door');
    await tester.pump();
    await tester.tap(find.text('Save name').first);
    await settle();

    await tester.tap(find.text('Make active'));
    await settle();

    await tester.tap(find.byType(BackButton));
    await settle();

    final SpectraSlotTile third = tester.widget<SpectraSlotTile>(
      find.byType(SpectraSlotTile).at(2),
    );
    expect(third.nickname, 'Front door');
    expect(third.active, isTrue);
  });
}
```

- [ ] **Step 5: Run it on a real engine**

```bash
cd app && flutter test integration_test/slot_edit_flow_test.dart -d macos
```

Expected: PASS. If the grid is off-screen at the window size the engine picks, scroll it into view with `tester.scrollUntilVisible(find.byType(SpectraSlotTile).at(2), 200, scrollable: find.byType(Scrollable).last)` rather than resizing the view.

- [ ] **Step 6: Run everything, then commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
dart run melos run check:all
git add app/test/flows app/integration_test
git commit -m "test(slots): add the Phase 5 gate flow

Edits and saves a slot on the emulator, as a widget test for CI's Ubuntu
check job and as an integration test the existing macOS job picks up — the
workflow needs no change because that job already runs the whole
integration_test directory.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 12: Phase close-out

**Files:**
- Modify: `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md`, `AGENTS.md`, `tasks/lessons.md`, `docs/research/DECISIONS.md`
- Test: the whole suite

**Interfaces:**
- Consumes: nothing. Produces: nothing importable.

- [ ] **Step 1: Prove the suite is green**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart run melos run check:all
```

Expected: format, analyze, dep lint, root tests, codegen freshness, dart tests and flutter tests all pass. Paste the tail of the output into the task report — do not claim it passed without it (`superpowers:verification-before-completion`).

- [ ] **Step 2: Tick the roadmap**

In `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md`, change `- [ ] Phase 5` to `- [x] Phase 5`, and mark the Phase 5 row's plan cell `2026-09-03-phase-5-slots.md (done)`.

- [ ] **Step 3: Update `AGENTS.md`**

Rewrite the "Current status" section's tail so it reads (adjusting the date and the test count to what Step 1 actually printed):

```markdown
Phase 5 (slots) is complete (2026-09-03): the slots grid, the slot editor
(rename with byte-level validation, per-sense enable, tag type, clear,
set active), every mutation written through `SlotsFacade` with no re-read,
failures rendered through the error catalog, and `showSlotPicker` exported
from `features/slots/slots.dart` as the public API Phase 6 and 7 consume.
Gate green: `app/test/flows/slot_edit_flow_test.dart` and
`app/integration_test/slot_edit_flow_test.dart` edit and save a slot on the
emulator.

Next: Phase 6 (read cards, library, dump editor, import) — write the plan
from spec 7.7 steps 3-4, 7.3 and 3.5 with the writing-plans skill.
```

- [ ] **Step 4: Add the lessons**

Append to `tasks/lessons.md`:

```markdown
## Phase 5 (slots)

- Ruling 20 keeps biting: an autoDispose provider read outside a mounted
  app needs a listener first. The `readProvider`/`readNotifier` helpers in
  `app/test/support/app_harness.dart` read through the pumped app's own
  container, which is why they never have to await a `.future`.
- The wakelock needed no feature code: `SlotsFacade` wraps every mutation in
  `DeviceSession.busy`, and `sessionNeedsWakelock` already polls `isBusy`.
  Check what the SDK already guarantees before building a second mechanism
  in the app — and pin it with a test so the guarantee is not silent.
- Validate against the wire limit in the app, not by catching the SDK's
  `ArgumentError`: the error catalog is keyed by `ChameleonException`, so an
  `ArgumentError` reaches the user as "something unexpected went wrong".
- Product names (`NTAG215`, `MIFARE Classic 1K`) are proper nouns and stay
  out of ARB. Only English words go through localization.
```

- [ ] **Step 5: Record the decisions**

Append a Phase 5 section to `docs/research/DECISIONS.md`:

```markdown
## Phase 5 (slots)

- **Tag-type product names are not localized.** `MIFARE Classic 1K`,
  `NTAG215` and `EM410x` are the names printed on the parts. They live in an
  exhaustive `switch` in `app/lib/features/slots/state/slot_labels.dart`;
  only the empty placeholder and the two sense names go through ARB. Spec
  7.6's rule is about copy, and twenty-four brand names in `app_en.arb`
  would be noise no translator would touch.
- **The picker's list of selectable types is derived, not typed.**
  `selectableTypes(Sense)` filters `TagType.values` by `TagFamily`, so it
  cannot name a type the SDK does not have. `iso14443_4` and `seos` are
  excluded because the SDK has no emulator support for them (the whole
  `CommandRange.iso14443_4` range answers NOT_IMPLEMENTED in `FakeFirmware`
  and is absent from `FakeFirmwareConfig.defaultCapabilities`).
- **`ToolSubPageScaffold` was promoted to `core/routing/SubPageScaffold`.**
  Its own doc comment asked for this check before a third sub-route reused
  it; a feature may not import another feature's internals (spec 8.4), so
  `core/` was the only place it could go.
- **`slotNicknameMaxBytes` is declared in the app.** The SDK's `maxNickBytes`
  is internal to `packages/chameleon/lib/src`, and its check throws an
  `ArgumentError` rather than a `ChameleonException`, so the app validates
  before sending. Source: SET_SLOT_TAG_NICK (1007) `slot(1) sense(1)
  utf8<=32` in `docs/research/chameleon-protocol.md`.
- **The picker returns a wire index, not a display number.** Documented on
  `showSlotPicker`, because the one thing Phase 6 and 7 can get silently
  wrong is an off-by-one between the 0..7 the facade takes and the 1..8 the
  device prints.
```

- [ ] **Step 6: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git add AGENTS.md tasks/lessons.md docs/
git commit -m "docs: close out Phase 5

Ticks the roadmap, records the four rulings this phase made, and points the
next session at Phase 6.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Self-review

Run after the last task, before declaring the phase done.

**Spec coverage.**

| Requirement | Task |
|---|---|
| 7.7 step 2: grid of eight | 3 |
| 7.7 step 2: enable per sense | 6 |
| 7.7 step 2: rename | 7 |
| 7.7 step 2: change tag type | 8 |
| 7.7 step 2: set active | 6 |
| 7.7 step 2: save to device | 5 (every facade method ends with SLOT_DATA_CONFIG_SAVE) |
| 7.7 step 2: exposes a slot picker sheet as its public API | 10 |
| 8.1: `session.slots` is the only way to the device | 5 |
| 8.3: `state/` + `ui/` + barrel; the barrel is the only import surface | 2-10 |
| 8.4: no `flutter/material.dart` under features; no cross-feature internals | Global Constraints; 4 (the scaffold promotion) |
| 8.5: files under ~300 lines, one public type, screens layout only | 3-10 |
| 8.6: interfaces at every seam | 5 (the facade is the seam; the session stays concrete and real in tests) |
| 7.2: deep routes push on top of their tab | 4 |
| 7.4: wakelock during long operations | 5 (proven, not added) |
| 7.6: ARB copy, semantics, 48px targets | every UI task (the kit's components carry the semantics and the targets) |
| 9: typed errors, one sentence, recovery action, raw line one tap away | 9 |
| 10: widget test per screen against `FakeDevice`; integration flow | 3, 4, 6-10; 11 |
| Roadmap gate: integration test edits and saves a slot on the emulator | 11 |

**Placeholder scan.** Every code step carries real code. The only deliberately deferred items are named as such and belong to later phases: "load to slot" (Phase 7) consumes Task 10's contract but is not built here, and `resetToDefault` on the facade is left unused — clearing uses `deleteSense`, which is what "clear the slot" means; a future "reset to a factory tag" action would use it.

**Type consistency.** `SlotView` (Task 2) is used with the same field names in Tasks 3, 4, 6, 7, 8 and 10. `slotEditorProvider(index)` and its six methods (`makeActive`, `setEnabled`, `rename`, `setTagType`, `clearSense`, `reset`) are defined in Task 5 and called with those exact names in Tasks 6-9. `SubPageScaffold({title, body})` is defined in Task 4 and used in Task 4 only (plus the two tools pages it replaces). `showSlotPicker(context, {initialIndex, isSelectable})` returns `Future<int?>` in both its definition and its tests. `SlotsFacade`'s six methods are quoted with the signatures read out of `packages/chameleon/lib/src/session/facades/slots.dart` — note `setTagType(int, TagType)` takes no `Sense`.
