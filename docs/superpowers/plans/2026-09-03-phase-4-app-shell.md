# Phase 4: app shell, connect and dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `app` package's spine: Riverpod session state keyed by `DeviceIdentity`, a Drift data layer, go_router routing driven by `connectionState`, app lifecycle and wakelock, a localized error catalog, the always-on frame log, emulator mode, and the first two feature screens — connect (with identity merge, permission/adapter states, manual serial entry and a bootloader recovery entry) and the device dashboard.

**Architecture:** Three layers, one direction. `core/` owns everything a feature may share: the session registry (a `Sessions` notifier holding one `DeviceSession` per `DeviceIdentity`, plus `activeDeviceProvider` naming the one on screen), thin providers that republish the SDK's `StateStream`s, the router and its pure redirect function, lifecycle, wakelock, feature flags and the error catalog. `data/` owns one Drift database and hands features nothing but repository interfaces. `features/<x>/` are `state/` + `ui/` + a barrel; screens are layout only and every notifier is unit-tested against a real `DeviceSession` on `FakeDevice` with no widgets. The app never constructs a transport itself: `ChameleonTransports` from `chameleon_flutter` supplies the scanner list and the transport for a discovered device, and emulator mode is just that list with the SDK's `FakeScanner` in it.

**Tech Stack:** Flutter 3.47.2 / Dart 3.13, `flutter_riverpod` 3.4.2 + `riverpod_annotation` 4.0.6 + `riverpod_generator` 4.0.8, `go_router` 18.0.1, `drift` 2.34.4 + `drift_flutter` 0.3.1 + `drift_dev` 2.34.6, `wakelock_plus` 1.8.0, `freezed` 4.0.1, `json_serializable` 6.14.1, `build_runner` 2.16.1, `flutter_localizations` + `intl` 0.20.3, `integration_test`, and this repo's `chameleon`, `chameleon_flutter` and `spectra_ui`.

**Spec:** `docs/superpowers/specs/2026-09-02-spectra-design.md` sections 7 (7.1 state, 7.2 routing, 7.3 storage, 7.4 lifecycle, 7.5 emulator mode, 7.6 localization and accessibility, 7.7 step 1), 8 (8.3 app feature layout, 8.4 enforcement, 8.5 code shape, 8.6 interfaces at every seam), 9 (error handling and logging), 4.2 (discovery and identity), 5.1 (permission, adapter and pairing states), 5.5 (bootloader discovery), 6 (the design system is the UI vocabulary), 2 (the `app` dependency row), 1 (progressive disclosure). Roadmap: `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md`.

## Global Constraints

- Toolchain pinned in `mise.toml`: Flutter 3.47.2 (bundles Dart 3.13). **Once per shell, `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"`**, then plain `flutter` / `dart` / `melos`, run **from `app/`** unless a task says otherwise. mise puts its tool paths after an older fvm Dart on this machine, so the export is not optional.
- Package boundaries and the dependency table in spec section 2 are enforced by `tool/dep_lint.dart`; CI and the phase gate require it green. The `app` package (dep_lint member name `spectra`) has **no allowlist entry**, so it may depend on anything — but four structural rules apply and are enforced:
  - `app/lib/features/*` must never import `package:flutter/material.dart`. Use `package:material_ui/material_ui.dart` or `package:flutter/widgets.dart`. `material_ui` is added as a direct dependency in Task 1 for this reason.
  - Drift may only be imported under `app/lib/data/` (the rule covers `drift` and anything starting with `drift_`).
  - A feature may import another feature only through its barrel, `package:spectra/features/<x>/<x>.dart`.
  - Nothing outside `chameleon` may import `package:chameleon/src/...`. Only the barrel `package:chameleon/chameleon.dart`.
- TDD for every task: failing test, minimal code, passing test, commit. Commit messages: imperative subject, short body explaining why, trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Generated code (freezed, riverpod_generator, drift, gen-l10n) is committed; `tool/check_codegen.sh` must pass. It already loops over `app`, and picks the package up as soon as `app/pubspec.yaml` mentions `build_runner` and `app/l10n.yaml` exists.
- All user-facing strings go through ARB localization (spec 7.6). The string lint (`tool/src/string_rules.dart`) only scans `app/lib/features/<x>/ui/`, but the rule applies to `core/` UI too — put every visible string in `lib/l10n/app_en.arb`.
- `chameleon` never imports Flutter. `spectra_ui` never imports the device packages.
- Files stay under about 300 lines and hold one public type (spec 8.5). Screens are layout only; logic lives in notifiers unit-tested without widgets (spec 8.5).
- Riverpod overrides are used **at the app root only** (spec 7.1) — in `main()`, in the widget-test harness and in the integration test. Never inside a feature.
- This is a git worktree. Never use bare `git stash`.
- `dart run melos run check:all` from the worktree root stays green at every commit.
- **Phases 1 and 3 land in parallel with this plan being written.** Before writing code in a task, open the files it consumes and follow the landed signatures if they differ from the Interfaces block. In particular: `packages/chameleon/lib/chameleon.dart` (the barrel, assembled by Phase 1 Task 21) and `packages/chameleon_flutter/lib/src/transports.dart`. App code imports **only** `package:chameleon/chameleon.dart` and `package:chameleon_flutter/chameleon_flutter.dart`.
- The `dfuOverBleEnabled` flag is defined here and **defaults to false** (roadmap, hardware handoffs). Phase 8 reads it. Nothing in this phase flips it.
- Never claim hardware behavior works. Everything in this phase is proven against `FakeDevice`.

---

## File structure

```
app/pubspec.yaml                                    riverpod, go_router, drift, wakelock_plus, material_ui, l10n, dev: generators
app/build.yaml                                      build_runner: riverpod_generator, freezed, json_serializable, drift_dev
app/l10n.yaml                                       arb-dir lib/l10n, output-class AppLocalizations
app/dart_test.yaml                                  test tags
app/analysis_options.yaml                           excludes generated files from --fatal-infos
app/drift_schemas/drift_schema_v1.json              exported schema, committed
app/lib/main.dart                                   ensureInitialized + ProviderScope + SpectraRoot
app/lib/app.dart                                    SpectraRoot: SpectraApp + routerProvider + lifecycle host
app/lib/l10n/app_en.arb                             every user-facing string in the app
app/lib/l10n/app_localizations.dart                 generated, committed
app/lib/l10n/app_localizations_en.dart              generated, committed

app/lib/core/session/active_session.dart            ActiveSession value type
app/lib/core/session/session_identity.dart          resolveIdentity(), fallbackIdentity()
app/lib/core/session/sessions.dart                  Sessions notifier: connect/disconnect/disconnectAll
app/lib/core/session/active_device.dart             ActiveDevice notifier + activeSession provider
app/lib/core/session/session_streams.dart           sessionStream() helper + the seven derived providers
app/lib/core/session/frame_log_provider.dart        frameLog + frameLogSnapshot providers
app/lib/core/discovery/scanners.dart                scannersProvider, emulatorModeProvider
app/lib/core/discovery/discovery_merge.dart         DiscoveryState + DiscoveryMerge (pure)
app/lib/core/discovery/discovery_provider.dart      discoveryProvider, manualPortsProvider
app/lib/core/routing/routes.dart                    AppRoutes path constants
app/lib/core/routing/redirect.dart                  redirectFor() — the pure routing rule (spec 7.2)
app/lib/core/routing/app_sections.dart              AppSection + the appSections list (spec 8.2)
app/lib/core/routing/router.dart                    routerProvider, RouterRefresh
app/lib/core/routing/shell_scaffold.dart            ShellScaffold: SpectraAppShell + StatefulNavigationShell
app/lib/core/lifecycle/lifecycle_controller.dart    LifecycleController (pure, spec 7.4)
app/lib/core/lifecycle/lifecycle_host.dart          AppLifecycleHost widget
app/lib/core/lifecycle/wakelock.dart                WakelockGateway, WakelockController, providers
app/lib/core/errors/error_presentation.dart         ErrorRecovery + ErrorPresentation
app/lib/core/errors/error_catalog.dart              ErrorCatalog: every ChameleonException -> copy (spec 9)
app/lib/core/flags/feature_flags.dart               FeatureFlags + FeatureFlagsController + providers

app/lib/data/data.dart                              barrel: models + repository interfaces
app/lib/data/models/known_device.dart               KnownDevice, KnownTransport
app/lib/data/models/saved_card.dart                 SavedCard (schema-complete, used from Phase 6)
app/lib/data/models/key_dictionary.dart             KeyDictionary (used from Phase 9)
app/lib/data/repositories.dart                      the four repository interfaces (spec 8.6)
app/lib/data/memory/in_memory_repositories.dart     in-memory KnownDevices + Preferences, for tests
app/lib/data/database/tables.dart                   SavedCards, KeyDictionaries, KnownDevices, AppPreferences
app/lib/data/database/spectra_database.dart         @DriftDatabase, schemaVersion 1, .memory()
app/lib/data/database/spectra_database.g.dart       generated, committed
app/lib/data/database/drift_known_devices_repository.dart
app/lib/data/database/drift_preferences_repository.dart
app/lib/data/database/database_providers.dart       databaseProvider + repository providers

app/lib/features/connect/connect.dart               barrel
app/lib/features/connect/state/connect_row.dart     ConnectRow + mergeConnectRows() (spec 4.2)
app/lib/features/connect/state/connect_rows_provider.dart
app/lib/features/connect/state/connect_controller.dart
app/lib/features/connect/ui/connect_page.dart
app/lib/features/connect/ui/connect_row_tile.dart
app/lib/features/connect/ui/connect_problem_view.dart
app/lib/features/connect/ui/manual_port_field.dart
app/lib/features/dashboard/dashboard.dart           barrel
app/lib/features/dashboard/ui/dashboard_page.dart
app/lib/features/dashboard/ui/device_detail_card.dart
app/lib/features/dashboard/ui/limited_dashboard.dart
app/lib/features/tools/tools.dart                   barrel
app/lib/features/tools/ui/tools_page.dart
app/lib/features/tools/ui/frame_log_page.dart
app/lib/features/tools/ui/update_page.dart          Phase 8 placeholder + recovery instructions
app/lib/features/slots/slots.dart                   barrel
app/lib/features/slots/ui/slots_page.dart           placeholder
app/lib/features/cards/cards.dart                   barrel
app/lib/features/cards/ui/cards_page.dart           placeholder
app/lib/features/settings/settings.dart             barrel
app/lib/features/settings/ui/settings_page.dart     placeholder

app/test/support/app_harness.dart                   ProviderScope overrides used by every widget test
app/test/data/schema_test.dart                      Drift schema verification (spec 7.3)
app/test/data/repositories_test.dart
app/test/core/…                                     one test file per core unit
app/test/features/…                                 one test file per screen
app/test/generated_migrations/schema.dart           generated by drift_dev, committed
app/test/generated_migrations/schema_v1.dart        generated by drift_dev, committed
app/test/flows/connect_flow_test.dart               the gate flow as a widget test (runs in CI on Ubuntu)
app/integration_test/connect_flow_test.dart         the gate flow on a real engine (macOS)

packages/spectra_ui/test/components/text_field_test.dart   parked Phase 2 additions
packages/spectra_ui/example/test/gallery_test.dart         parked '/' redirect test
.github/workflows/ci.yml                            libsqlite3-dev on check; integration job on macOS
docs/research/DECISIONS.md                          Phase 4 decisions
tasks/lessons.md                                    Phase 4 lessons
docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md   tick Phase 4
AGENTS.md                                           current status
```

---

### Task 1: App package setup — dependencies, codegen, localization, app root

**Files:**
- Modify: `app/pubspec.yaml`, `app/analysis_options.yaml`, `app/lib/main.dart`, `app/test/widget_test.dart`, `.github/workflows/ci.yml`
- Create: `app/build.yaml`, `app/l10n.yaml`, `app/lib/l10n/app_en.arb`, `app/lib/app.dart`, `app/dart_test.yaml`
- Test: `app/test/app_test.dart`

**Interfaces:**
- Produces: `class SpectraRoot extends ConsumerWidget` in `package:spectra/app.dart` — the app root every test and `main()` pumps. Renamed from the placeholder `SpectraApp` in `main.dart`, which collided with `spectra_ui`'s `SpectraApp`.
- Produces: `AppLocalizations` (generated) in `package:spectra/l10n/app_localizations.dart`, with `AppLocalizations.delegate` and `AppLocalizationsEn()` constructible directly in tests.
- Produces: the resolved dependency set later tasks rely on.

- [ ] **Step 1: Add the dependencies**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app
flutter pub add flutter_riverpod riverpod_annotation go_router drift drift_flutter wakelock_plus material_ui intl
flutter pub add flutter_localizations --sdk=flutter
flutter pub add dev:riverpod_generator dev:build_runner dev:freezed dev:json_serializable dev:drift_dev dev:integration_test
```

`integration_test` comes from the SDK, so if the last command resolves it from pub.dev, replace that one entry by hand in `pubspec.yaml`:

```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
```

Expected resolved versions (record them in the commit body): `flutter_riverpod` 3.4.2, `riverpod_annotation` 4.0.6, `riverpod_generator` 4.0.8, `go_router` 18.0.1, `drift` 2.34.4, `drift_flutter` 0.3.1, `drift_dev` 2.34.6, `wakelock_plus` 1.8.0, `freezed` 4.0.1, `json_serializable` 6.14.1, `build_runner` 2.16.1, `material_ui` 1.1.1, `intl` 0.20.3.

Then set `generate: true` under `flutter:` in `app/pubspec.yaml` (next to `uses-material-design: true`):

```yaml
flutter:
  uses-material-design: true
  generate: true
```

- [ ] **Step 2: Add the codegen and localization config**

`app/build.yaml`:

```yaml
targets:
  $default:
    builders:
      riverpod_generator:
        options:
          provider_name_suffix: Provider
      drift_dev:
        options:
          named_parameters: true
          sql:
            dialect: sqlite
```

`app/l10n.yaml`:

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-dir: lib/l10n
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
```

`app/lib/l10n/app_en.arb` — the strings this task needs; every later task appends to this file:

```json
{
  "@@locale": "en",
  "appTitle": "Spectra",
  "@appTitle": {"description": "The application name, shown as the window title."}
}
```

`app/dart_test.yaml`:

```yaml
tags:
  hardware:
    description: Needs a real Chameleon Ultra; see docs/hardware-checklist.md.
    skip: "run with --tags hardware and a device attached"
```

Extend `app/analysis_options.yaml` so generated files do not have to satisfy `--fatal-infos`:

```yaml
analyzer:
  exclude:
    - build/**
    - android/**
    - ios/**
    - windows/**
    - macos/**
    - linux/**
    - lib/**/*.g.dart
    - lib/**/*.freezed.dart
    - lib/l10n/app_localizations*.dart
    - test/generated_migrations/**
include: ../analysis_options.yaml
```

- [ ] **Step 3: Write the failing test**

```dart
// app/test/app_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/app.dart';
import 'package:spectra/l10n/app_localizations.dart';

void main() {
  test('the generated localizations carry the app title', () {
    expect(AppLocalizationsEn().appTitle, 'Spectra');
  });

  testWidgets('the root boots inside a ProviderScope', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SpectraRoot()));
    await tester.pump();
    expect(find.byType(SpectraRoot), findsOneWidget);
  });
}
```

- [ ] **Step 4: Run it and watch it fail**

```bash
cd app && flutter test test/app_test.dart
```

Expected: FAIL — `package:spectra/app.dart` and `package:spectra/l10n/app_localizations.dart` do not exist.

- [ ] **Step 5: Generate the localizations and write the root**

```bash
cd app && flutter gen-l10n
```

Expected: writes `lib/l10n/app_localizations.dart` and `lib/l10n/app_localizations_en.dart`.

`app/lib/app.dart` — a deliberately empty shell for now; Task 10 gives it the router and Task 11 the lifecycle host:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' show Center, Scaffold, Text;

import 'l10n/app_localizations.dart';

/// The application root. Everything above it is `ProviderScope`; everything
/// below it comes from `routerProvider` once Task 10 lands.
class SpectraRoot extends ConsumerWidget {
  const SpectraRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Localizations(
      locale: const Locale('en'),
      delegates: const <LocalizationsDelegate<Object?>>[
        AppLocalizations.delegate,
      ],
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(body: Center(child: Text('Spectra'))),
      ),
    );
  }
}
```

`app/lib/main.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SpectraRoot()));
}
```

`app/test/widget_test.dart` — replace its body so it no longer references the deleted placeholder:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/app.dart';

void main() {
  testWidgets('the app boots', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SpectraRoot()));
    await tester.pump();
    expect(find.text('Spectra'), findsOneWidget);
  });
}
```

- [ ] **Step 6: Run the tests**

```bash
cd app && flutter test
```

Expected: PASS, 3 tests.

- [ ] **Step 7: Teach CI about sqlite and check the codegen loop**

`tool/check_codegen.sh` already iterates `app`; confirm it now does real work:

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook && bash tool/check_codegen.sh
```

Expected: prints `codegen: app` and `l10n: app`, then `codegen: ok`.

In `.github/workflows/ci.yml`, add `libsqlite3-dev` to the `check` job's apt line (Task 2's schema test and every Drift unit test open a native sqlite3):

```yaml
      - run: sudo apt-get update && sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev libsqlite3-dev
```

- [ ] **Step 8: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart format . && dart analyze --fatal-infos . && dart run tool/dep_lint.dart
git add app .github/workflows/ci.yml pubspec.lock
git commit -m "chore(app): set up riverpod, drift, go_router and ARB localization

Phase 4 needs the generators and the localization pipeline before any
state exists. The placeholder root is renamed SpectraRoot because
spectra_ui already exports a SpectraApp."
```

---

### Task 2: The Drift database and its schema-verification test

**Files:**
- Create: `app/lib/data/database/tables.dart`, `app/lib/data/database/spectra_database.dart`, `app/lib/data/models/known_device.dart`, `app/lib/data/models/saved_card.dart`, `app/lib/data/models/key_dictionary.dart`
- Create (generated, committed): `app/lib/data/database/spectra_database.g.dart`, `app/drift_schemas/drift_schema_v1.json`, `app/test/generated_migrations/schema.dart`, `app/test/generated_migrations/schema_v1.dart`
- Test: `app/test/data/database_test.dart`, `app/test/data/schema_test.dart`

**Interfaces:**
- Produces:

```dart
// package:spectra/data/database/spectra_database.dart
@DriftDatabase(tables: [SavedCards, KeyDictionaries, KnownDevices, AppPreferences])
class SpectraDatabase extends _$SpectraDatabase {
  SpectraDatabase(super.e);
  /// The app's on-disk database, one file named `spectra`.
  factory SpectraDatabase.app() => SpectraDatabase(driftDatabase(name: 'spectra'));
  /// A throwaway in-memory database. Tests and the integration test use this.
  factory SpectraDatabase.memory() => SpectraDatabase(NativeDatabase.memory());
  @override int get schemaVersion; // 1
}
```

- Produces the four value types features use (spec 8.6 — `data/` hands out models and interfaces, never Drift rows):

```dart
// package:spectra/data/models/known_device.dart
final class KnownTransport {
  const KnownTransport({required TransportKind kind, required String transportId});
  final TransportKind kind; final String transportId;
}
final class KnownDevice {
  const KnownDevice({required DeviceIdentity identity, required String displayName,
      required List<KnownTransport> transports, required DateTime lastSeen});
  final DeviceIdentity identity; final String displayName;
  final List<KnownTransport> transports; final DateTime lastSeen;
  bool matches(DiscoveredDevice device);   // true when a transport row matches kind+id
}
// package:spectra/data/models/saved_card.dart
final class SavedCard {
  const SavedCard({required String id, required String name, required String tagType,
      required Uint8List bytes, required DateTime updatedAt, String? folder, int? color});
}
// package:spectra/data/models/key_dictionary.dart
final class KeyDictionary {
  const KeyDictionary({required String id, required String name,
      required List<Uint8List> keys, required DateTime updatedAt});
}
```

- [ ] **Step 1: Write the failing tests**

```dart
// app/test/data/database_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/data/database/spectra_database.dart';

void main() {
  late SpectraDatabase db;

  setUp(() => db = SpectraDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('is at schema version 1', () {
    expect(db.schemaVersion, 1);
  });

  test('creates all four tables', () async {
    final names = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final tables = names.map((r) => r.read<String>('name')).toSet();
    expect(tables, containsAll(<String>[
      'saved_cards',
      'key_dictionaries',
      'known_devices',
      'app_preferences',
    ]));
  });

  test('app_preferences round trips a value', () async {
    await db.into(db.appPreferences).insert(
          AppPreferencesCompanion.insert(key: 'theme', value: 'dark'),
        );
    final row = await (db.select(db.appPreferences)
          ..where((t) => t.key.equals('theme')))
        .getSingle();
    expect(row.value, 'dark');
  });

  test('known_devices is keyed by identity', () async {
    await db.into(db.knownDevices).insert(
          KnownDevicesCompanion.insert(
            identity: 'chip-1',
            displayName: 'Ultra',
            transports: 'usb:/dev/cu.usbmodem1',
            lastSeen: DateTime.utc(2026, 9, 3),
          ),
        );
    final rows = await db.select(db.knownDevices).get();
    expect(rows.single.identity, 'chip-1');
  });
}
```

```dart
// app/test/data/schema_test.dart
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/data/database/spectra_database.dart';

import 'generated_migrations/schema.dart';

/// Spec 7.3: "Drift schema migrations with generated schema-verification
/// tests from the first table." Version 1 is the baseline, so this asserts
/// that a fresh database matches the exported v1 schema exactly. Every later
/// phase that adds a table exports a new version and adds a step here.
void main() {
  test('a fresh database matches the exported v1 schema', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.schemaAt(1);
    final db = SpectraDatabase(connection.newConnection());
    await verifier.migrateAndValidate(db, 1);
    await db.close();
  });
}
```

Note the import path: the generated helpers live in `app/test/generated_migrations/`, and `schema_test.dart` sits in `app/test/data/`, so the relative import above is wrong on purpose only if you place the files elsewhere. Generate them into `test/generated_migrations/` and change the import to `../generated_migrations/schema.dart`.

- [ ] **Step 2: Run them and watch them fail**

```bash
cd app && flutter test test/data
```

Expected: FAIL — `package:spectra/data/database/spectra_database.dart` does not exist.

- [ ] **Step 3: Write the tables**

`app/lib/data/database/tables.dart`:

```dart
import 'package:drift/drift.dart';

/// Saved card dumps (spec 7.3). Written from Phase 6; the table exists now so
/// schema version 1 is the whole v1 shape and Phase 6 needs no migration.
class SavedCards extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get tagType => text()();
  BlobColumn get bytes => blob()();
  TextColumn get folder => text().nullable()();
  IntColumn get color => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Key dictionaries (spec 7.3). Written from Phase 9. Keys are stored as one
/// newline-separated hex blob: a dictionary is read and written whole.
class KeyDictionaries extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get keys => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Identity to last-seen transports (spec 4.2). [transports] is a
/// newline-separated list of `kind:transportId`, because it is only ever read
/// and written whole and a join table would buy nothing.
class KnownDevices extends Table {
  TextColumn get identity => text()();
  TextColumn get displayName => text()();
  TextColumn get transports => text()();
  DateTimeColumn get lastSeen => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {identity};
}

/// App preferences (spec 7.3): a key/value store, one row per setting.
class AppPreferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
```

`app/lib/data/database/spectra_database.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'spectra_database.g.dart';

/// The app's one database (spec 7.3). Drift appears nowhere outside
/// `lib/data/`; features see only the repository interfaces.
@DriftDatabase(tables: [SavedCards, KeyDictionaries, KnownDevices, AppPreferences])
class SpectraDatabase extends _$SpectraDatabase {
  SpectraDatabase(super.e);

  /// The on-disk database, in the platform's application documents directory.
  factory SpectraDatabase.app() =>
      SpectraDatabase(driftDatabase(name: 'spectra'));

  /// A throwaway database. Every test and the integration test use this, so
  /// the real schema and the real queries are exercised with no file system.
  factory SpectraDatabase.memory() => SpectraDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;
}
```

Write the three model files exactly as the Interfaces block above declares. `KnownDevice.matches`:

```dart
  bool matches(DiscoveredDevice device) => transports.any(
        (t) => t.kind == device.kind && t.transportId == device.transportId,
      );
```

- [ ] **Step 4: Generate, export the schema, generate the migration helpers**

```bash
cd app
dart run build_runner build --delete-conflicting-outputs
mkdir -p drift_schemas
dart run drift_dev schema dump lib/data/database/spectra_database.dart drift_schemas/
dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
```

Expected: `lib/data/database/spectra_database.g.dart`, `drift_schemas/drift_schema_v1.json`, `test/generated_migrations/schema.dart` and `schema_v1.dart` all appear. Fix the `schema_test.dart` import to `../generated_migrations/schema.dart`.

- [ ] **Step 5: Run the tests**

```bash
cd app && flutter test test/data
```

Expected: PASS, 5 tests. If `SchemaVerifier` fails to open sqlite3, install it (`brew install sqlite` on macOS is not needed — the system library is used; on Linux `sudo apt-get install -y libsqlite3-dev`).

- [ ] **Step 6: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git add app
git commit -m "feat(app): add the Drift database and its schema-verification test

All four spec 7.3 tables land at schema version 1, including the two the
card library and dictionaries need later, so Phases 6 and 9 add rows, not
migrations. The exported v1 schema is committed and verified.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: Repository interfaces, their Drift and in-memory implementations, and their providers

**Files:**
- Create: `app/lib/data/repositories.dart`, `app/lib/data/data.dart`, `app/lib/data/memory/in_memory_repositories.dart`, `app/lib/data/database/drift_known_devices_repository.dart`, `app/lib/data/database/drift_preferences_repository.dart`, `app/lib/data/database/database_providers.dart`
- Create (generated, committed): `app/lib/data/database/database_providers.g.dart`
- Test: `app/test/data/repositories_test.dart`

**Interfaces:**
- Consumes: `SpectraDatabase`, `KnownDevice`, `KnownTransport`, `SavedCard`, `KeyDictionary` (Task 2); `DeviceIdentity`, `DiscoveredDevice`, `TransportKind` from `package:chameleon/chameleon.dart`.
- Produces (spec 8.6 — every repository is an interface):

```dart
// package:spectra/data/repositories.dart
abstract interface class KnownDevicesRepository {
  Future<List<KnownDevice>> all();
  Future<KnownDevice?> byIdentity(DeviceIdentity identity);
  /// The most recently seen device, for "Reconnect to last device" (spec 4.2).
  Future<KnownDevice?> lastSeen();
  Future<void> remember({
    required DeviceIdentity identity,
    required String displayName,
    required TransportKind kind,
    required String transportId,
    DateTime? at,
  });
  Future<void> forget(DeviceIdentity identity);
  Stream<List<KnownDevice>> watchAll();
}

abstract interface class PreferencesRepository {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

/// Declared now so the seam exists; implemented in Phase 6.
abstract interface class SavedCardsRepository {
  Future<List<SavedCard>> all();
  Future<SavedCard?> byId(String id);
  Future<void> save(SavedCard card);
  Future<void> delete(String id);
  Stream<List<SavedCard>> watchAll();
}

/// Declared now so the seam exists; implemented in Phase 9.
abstract interface class DictionariesRepository {
  Future<List<KeyDictionary>> all();
  Future<void> save(KeyDictionary dictionary);
  Future<void> delete(String id);
  Stream<List<KeyDictionary>> watchAll();
}
```

- Produces the providers every later task reads:

```dart
// package:spectra/data/database/database_providers.dart
@Riverpod(keepAlive: true) SpectraDatabase database(Ref ref);              // databaseProvider
@Riverpod(keepAlive: true) KnownDevicesRepository knownDevicesRepository(Ref ref);
@Riverpod(keepAlive: true) PreferencesRepository preferencesRepository(Ref ref);
```

- Produces `InMemoryKnownDevicesRepository()` and `InMemoryPreferencesRepository()`, for unit tests that want no database at all.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/data/repositories_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/data/database/drift_known_devices_repository.dart';
import 'package:spectra/data/database/drift_preferences_repository.dart';
import 'package:spectra/data/database/spectra_database.dart';
import 'package:spectra/data/memory/in_memory_repositories.dart';

const identity = DeviceIdentity('chip-1');

void main() {
  group('every KnownDevicesRepository', () {
    late SpectraDatabase db;

    setUp(() => db = SpectraDatabase.memory());
    tearDown(() => db.close());

    for (final entry in <String, KnownDevicesRepository Function(SpectraDatabase)>{
      'drift': DriftKnownDevicesRepository.new,
      'memory': (_) => InMemoryKnownDevicesRepository(),
    }.entries) {
      test('${entry.key}: remembers a device and reads it back', () async {
        final repo = entry.value(db);
        await repo.remember(
          identity: identity,
          displayName: 'Ultra',
          kind: TransportKind.usb,
          transportId: '/dev/cu.usbmodem1',
          at: DateTime.utc(2026, 9, 1),
        );
        final found = await repo.byIdentity(identity);
        expect(found!.displayName, 'Ultra');
        expect(found.transports.single.transportId, '/dev/cu.usbmodem1');
      });

      test('${entry.key}: adds a second transport to the same identity',
          () async {
        final repo = entry.value(db);
        await repo.remember(
          identity: identity,
          displayName: 'Ultra',
          kind: TransportKind.usb,
          transportId: '/dev/cu.usbmodem1',
          at: DateTime.utc(2026, 9, 1),
        );
        await repo.remember(
          identity: identity,
          displayName: 'Ultra',
          kind: TransportKind.ble,
          transportId: 'AA:BB',
          at: DateTime.utc(2026, 9, 2),
        );
        final found = await repo.byIdentity(identity);
        expect(found!.transports, hasLength(2));
        expect(found.lastSeen, DateTime.utc(2026, 9, 2));
      });

      test('${entry.key}: lastSeen returns the newest device', () async {
        final repo = entry.value(db);
        await repo.remember(
          identity: identity,
          displayName: 'Older',
          kind: TransportKind.usb,
          transportId: 'a',
          at: DateTime.utc(2026, 9, 1),
        );
        await repo.remember(
          identity: const DeviceIdentity('chip-2'),
          displayName: 'Newer',
          kind: TransportKind.usb,
          transportId: 'b',
          at: DateTime.utc(2026, 9, 5),
        );
        expect((await repo.lastSeen())!.displayName, 'Newer');
      });

      test('${entry.key}: matches a discovered device by kind and id',
          () async {
        final repo = entry.value(db);
        await repo.remember(
          identity: identity,
          displayName: 'Ultra',
          kind: TransportKind.usb,
          transportId: '/dev/cu.usbmodem1',
        );
        final known = (await repo.all()).single;
        expect(
          known.matches(const DiscoveredDevice(
            name: 'ChameleonUltra',
            kind: TransportKind.usb,
            transportId: '/dev/cu.usbmodem1',
          )),
          isTrue,
        );
      });

      test('${entry.key}: forget removes it', () async {
        final repo = entry.value(db);
        await repo.remember(
          identity: identity,
          displayName: 'Ultra',
          kind: TransportKind.usb,
          transportId: 'a',
        );
        await repo.forget(identity);
        expect(await repo.all(), isEmpty);
      });
    }

    test('drift: watchAll emits on every change', () async {
      final repo = DriftKnownDevicesRepository(db);
      expect(
        repo.watchAll(),
        emitsInOrder(<Object>[isEmpty, hasLength(1)]),
      );
      await repo.remember(
        identity: identity,
        displayName: 'Ultra',
        kind: TransportKind.usb,
        transportId: 'a',
      );
    });
  });

  group('every PreferencesRepository', () {
    late SpectraDatabase db;

    setUp(() => db = SpectraDatabase.memory());
    tearDown(() => db.close());

    for (final entry in <String, PreferencesRepository Function(SpectraDatabase)>{
      'drift': DriftPreferencesRepository.new,
      'memory': (_) => InMemoryPreferencesRepository(),
    }.entries) {
      test('${entry.key}: reads back what it wrote, and null otherwise',
          () async {
        final repo = entry.value(db);
        expect(await repo.read('flag'), isNull);
        await repo.write('flag', 'true');
        expect(await repo.read('flag'), 'true');
        await repo.write('flag', 'false');
        expect(await repo.read('flag'), 'false');
        await repo.remove('flag');
        expect(await repo.read('flag'), isNull);
      });
    }
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd app && flutter test test/data/repositories_test.dart
```

Expected: FAIL — none of the repository libraries exist.

- [ ] **Step 3: Write the interfaces and the barrel**

`app/lib/data/repositories.dart` — exactly the Interfaces block above, with a doc comment per interface.

`app/lib/data/data.dart`:

```dart
/// The data layer's public face: models and repository interfaces. Features
/// import this and never `data/database/…` (spec 8.3).
library;

export 'models/key_dictionary.dart';
export 'models/known_device.dart';
export 'models/saved_card.dart';
export 'repositories.dart';
```

- [ ] **Step 4: Write the Drift implementations**

`app/lib/data/database/drift_known_devices_repository.dart`:

```dart
import 'package:chameleon/chameleon.dart';
import 'package:drift/drift.dart';

import '../models/known_device.dart';
import '../repositories.dart';
import 'spectra_database.dart';

/// Encodes the transport list as `kind:transportId` lines. Read and written
/// whole, so a join table would only add ceremony (spec 7.3).
const String _separator = '\n';

final class DriftKnownDevicesRepository implements KnownDevicesRepository {
  DriftKnownDevicesRepository(this._db);
  final SpectraDatabase _db;

  @override
  Future<List<KnownDevice>> all() async =>
      (await _db.select(_db.knownDevices).get()).map(_toModel).toList();

  @override
  Future<KnownDevice?> byIdentity(DeviceIdentity identity) async {
    final row = await (_db.select(_db.knownDevices)
          ..where((t) => t.identity.equals(identity.chipId)))
        .getSingleOrNull();
    return row == null ? null : _toModel(row);
  }

  @override
  Future<KnownDevice?> lastSeen() async {
    final row = await (_db.select(_db.knownDevices)
          ..orderBy([(t) => OrderingTerm.desc(t.lastSeen)])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _toModel(row);
  }

  @override
  Future<void> remember({
    required DeviceIdentity identity,
    required String displayName,
    required TransportKind kind,
    required String transportId,
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    final existing = await byIdentity(identity);
    final transports = <KnownTransport>[
      KnownTransport(kind: kind, transportId: transportId),
      if (existing != null)
        for (final t in existing.transports)
          if (t.kind != kind || t.transportId != transportId) t,
    ];
    await _db.into(_db.knownDevices).insertOnConflictUpdate(
          KnownDevicesCompanion.insert(
            identity: identity.chipId,
            displayName: displayName,
            transports: _encode(transports),
            lastSeen: now,
          ),
        );
  }

  @override
  Future<void> forget(DeviceIdentity identity) async {
    await (_db.delete(_db.knownDevices)
          ..where((t) => t.identity.equals(identity.chipId)))
        .go();
  }

  @override
  Stream<List<KnownDevice>> watchAll() =>
      _db.select(_db.knownDevices).watch().map(
            (rows) => rows.map(_toModel).toList(growable: false),
          );

  KnownDevice _toModel(KnownDevice_Row row) => KnownDevice(
        identity: DeviceIdentity(row.identity),
        displayName: row.displayName,
        transports: _decode(row.transports),
        lastSeen: row.lastSeen,
      );

  static String _encode(List<KnownTransport> transports) => transports
      .map((t) => '${t.kind.name}:${t.transportId}')
      .join(_separator);

  static List<KnownTransport> _decode(String raw) => <KnownTransport>[
        for (final line in raw.split(_separator))
          if (line.contains(':'))
            KnownTransport(
              kind: TransportKind.values.firstWhere(
                (k) => k.name == line.substring(0, line.indexOf(':')),
                orElse: () => TransportKind.usb,
              ),
              transportId: line.substring(line.indexOf(':') + 1),
            ),
      ];
}
```

The generated row class is named after the table (`KnownDevice` by default, which collides with our model). Set the row class name in `tables.dart` on the `KnownDevices` table to avoid it:

```dart
@DataClassName('KnownDeviceRow')
class KnownDevices extends Table { … }
```

and use `KnownDeviceRow` in `_toModel` above. Do the same for `SavedCards` (`@DataClassName('SavedCardRow')`) and `KeyDictionaries` (`@DataClassName('KeyDictionaryRow')`). Re-run `dart run build_runner build --delete-conflicting-outputs`, re-dump the schema and re-generate the migration helpers exactly as in Task 2 Step 4 (the dumped JSON records the data-class names).

`app/lib/data/database/drift_preferences_repository.dart`:

```dart
import 'package:drift/drift.dart';

import '../repositories.dart';
import 'spectra_database.dart';

final class DriftPreferencesRepository implements PreferencesRepository {
  DriftPreferencesRepository(this._db);
  final SpectraDatabase _db;

  @override
  Future<String?> read(String key) async {
    final row = await (_db.select(_db.appPreferences)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> write(String key, String value) async {
    await _db.into(_db.appPreferences).insertOnConflictUpdate(
          AppPreferencesCompanion.insert(key: key, value: value),
        );
  }

  @override
  Future<void> remove(String key) async {
    await (_db.delete(_db.appPreferences)..where((t) => t.key.equals(key)))
        .go();
  }
}
```

- [ ] **Step 5: Write the in-memory implementations**

`app/lib/data/memory/in_memory_repositories.dart`:

```dart
import 'dart:async';

import 'package:chameleon/chameleon.dart';

import '../models/known_device.dart';
import '../repositories.dart';

/// Repository implementations with no database behind them, for unit tests
/// that are about something else (spec 8.6).
final class InMemoryKnownDevicesRepository implements KnownDevicesRepository {
  final Map<String, KnownDevice> _rows = <String, KnownDevice>{};
  final StreamController<List<KnownDevice>> _changes =
      StreamController<List<KnownDevice>>.broadcast();

  @override
  Future<List<KnownDevice>> all() async => _sorted();

  @override
  Future<KnownDevice?> byIdentity(DeviceIdentity identity) async =>
      _rows[identity.chipId];

  @override
  Future<KnownDevice?> lastSeen() async {
    final rows = _sorted();
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<void> remember({
    required DeviceIdentity identity,
    required String displayName,
    required TransportKind kind,
    required String transportId,
    DateTime? at,
  }) async {
    final existing = _rows[identity.chipId];
    _rows[identity.chipId] = KnownDevice(
      identity: identity,
      displayName: displayName,
      transports: <KnownTransport>[
        KnownTransport(kind: kind, transportId: transportId),
        if (existing != null)
          for (final t in existing.transports)
            if (t.kind != kind || t.transportId != transportId) t,
      ],
      lastSeen: at ?? DateTime.now(),
    );
    _emit();
  }

  @override
  Future<void> forget(DeviceIdentity identity) async {
    _rows.remove(identity.chipId);
    _emit();
  }

  @override
  Stream<List<KnownDevice>> watchAll() async* {
    yield _sorted();
    yield* _changes.stream;
  }

  List<KnownDevice> _sorted() =>
      _rows.values.toList()..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));

  void _emit() {
    if (!_changes.isClosed) _changes.add(_sorted());
  }
}

final class InMemoryPreferencesRepository implements PreferencesRepository {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}
```

- [ ] **Step 6: Write the providers**

`app/lib/data/database/database_providers.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../repositories.dart';
import 'drift_known_devices_repository.dart';
import 'drift_preferences_repository.dart';
import 'spectra_database.dart';

part 'database_providers.g.dart';

/// The one database. Overridden at the app root in tests and in the
/// integration test with [SpectraDatabase.memory] (spec 7.1).
@Riverpod(keepAlive: true)
SpectraDatabase database(Ref ref) {
  final db = SpectraDatabase.app();
  ref.onDispose(db.close);
  return db;
}

@Riverpod(keepAlive: true)
KnownDevicesRepository knownDevicesRepository(Ref ref) =>
    DriftKnownDevicesRepository(ref.watch(databaseProvider));

@Riverpod(keepAlive: true)
PreferencesRepository preferencesRepository(Ref ref) =>
    DriftPreferencesRepository(ref.watch(databaseProvider));
```

```bash
cd app && dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 7: Run the tests**

```bash
cd app && flutter test test/data
```

Expected: PASS, 16 tests.

- [ ] **Step 8: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart format . && dart analyze --fatal-infos . && dart run tool/dep_lint.dart
git add app
git commit -m "feat(app): add repository interfaces and their two implementations

Features see interfaces only, so Drift stays under lib/data/ (spec 8.4) and
a unit test can swap in the in-memory pair. The same test body runs against
both implementations, which is what keeps them honest.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: The localized error catalog

**Files:**
- Create: `app/lib/core/errors/error_presentation.dart`, `app/lib/core/errors/error_catalog.dart`
- Modify: `app/lib/l10n/app_en.arb`
- Test: `app/test/core/errors/error_catalog_test.dart`

**Interfaces:**
- Consumes: every `ChameleonException` subtype from `package:chameleon/chameleon.dart` — `MalformedResponse`, `CommandTimeout`, `CommandCancelled`, `SessionNotReady`, `BackgroundTaskFailed`, `UnsupportedFirmware` (+ `UnsupportedReason`), `ReaderUnavailable`, `Disconnected`, `PermissionDenied`, `PortBusy`, `DeviceNotFound`, `PairingRequired`, `AdapterOff`, `DfuError`, and every `DeviceError` subtype (`HfTagNotFound`, `HfTagError`, `AuthenticationFailed`, `LfTagNotFound`, `LfLoginRequired`, `ParameterError`, `DeviceModeError`, `InvalidCommand`, `NotImplemented`, `FlashWriteFailed`, `FlashReadFailed`, `InvalidSlotType`, `MemoryError`, `CreateResponseError`, `CommandFailed`, `UnknownDeviceError`). Also `TransportGuidance` from `package:chameleon_flutter/chameleon_flutter.dart`.
- Produces:

```dart
// package:spectra/core/errors/error_presentation.dart
enum ErrorRecovery { retry, openSettings, platformInstructions, reconnect, update, none }

final class ErrorPresentation {
  const ErrorPresentation({
    required this.message,
    required this.recovery,
    required this.detail,
    this.instructions,
  });
  final String message;          // one plain sentence
  final ErrorRecovery recovery;  // which action the UI offers
  final String detail;           // the raw line, one tap away (spec 9)
  final String? instructions;    // platform guidance, when there is any
}

// package:spectra/core/errors/error_catalog.dart
final class ErrorCatalog {
  const ErrorCatalog(AppLocalizations l10n);
  ErrorPresentation describe(Object error);
  String guidance(TransportGuidance guidance);
}
```

- [ ] **Step 1: Write the failing test**

```dart
// app/test/core/errors/error_catalog_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/errors/error_catalog.dart';
import 'package:spectra/core/errors/error_presentation.dart';
import 'package:spectra/l10n/app_localizations.dart';

/// Every error the SDK can raise, one instance each. `ChameleonException` is
/// sealed, so a missing entry here is caught by review, and a missing entry
/// in the catalog's switch is caught by the compiler.
final List<ChameleonException> everyError = <ChameleonException>[
  const MalformedResponse('bad payload'),
  CommandTimeout(1000, const Duration(seconds: 1)),
  const CommandCancelled(),
  const SessionNotReady('not ready'),
  BackgroundTaskFailed('boom', StackTrace.empty),
  const UnsupportedFirmware(UnsupportedReason.preTwoPointZero, 'old'),
  const ReaderUnavailable(),
  const Disconnected(),
  const PermissionDenied(),
  const PortBusy(),
  const DeviceNotFound(),
  const PairingRequired(),
  const AdapterOff(),
  DfuError('bad package'),
  const HfTagNotFound(),
  const HfTagError(HfTagErrorKind.crc, 0),
  const AuthenticationFailed(),
  const LfTagNotFound(),
  const LfLoginRequired(),
  const ParameterError(),
  const DeviceModeError(),
  const InvalidCommand(),
  const NotImplemented(),
  const FlashWriteFailed(),
  const FlashReadFailed(),
  const InvalidSlotType(),
  const MemoryError(),
  const CreateResponseError(),
  const CommandFailed(),
  UnknownDeviceError(0x99),
];

void main() {
  final catalog = ErrorCatalog(AppLocalizationsEn());

  test('every SDK error gets a message and a raw detail line', () {
    for (final error in everyError) {
      final p = catalog.describe(error);
      expect(p.message, isNotEmpty, reason: '${error.runtimeType}');
      expect(p.detail, contains(error.runtimeType.toString()),
          reason: '${error.runtimeType}');
    }
  });

  test('recoverable transport problems name the right action', () {
    expect(catalog.describe(const PermissionDenied()).recovery,
        ErrorRecovery.openSettings);
    expect(catalog.describe(const AdapterOff()).recovery,
        ErrorRecovery.openSettings);
    expect(catalog.describe(const PairingRequired()).recovery,
        ErrorRecovery.platformInstructions);
    expect(catalog.describe(const Disconnected()).recovery,
        ErrorRecovery.reconnect);
    expect(catalog.describe(CommandTimeout(1000, const Duration(seconds: 1)))
        .recovery, ErrorRecovery.retry);
    expect(
      catalog
          .describe(const UnsupportedFirmware(
              UnsupportedReason.legacyMustUpdate, 'legacy'))
          .recovery,
      ErrorRecovery.update,
    );
    expect(catalog.describe(const CommandCancelled()).recovery,
        ErrorRecovery.none);
  });

  test('an unsupported-firmware message says which kind of unsupported', () {
    final pre = catalog.describe(
        const UnsupportedFirmware(UnsupportedReason.preTwoPointZero, 'x'));
    final newer = catalog.describe(
        const UnsupportedFirmware(UnsupportedReason.newerMajor, 'x'));
    expect(pre.message, isNot(newer.message));
  });

  test('a non-SDK error still gets a message', () {
    final p = catalog.describe(StateError('nope'));
    expect(p.message, isNotEmpty);
    expect(p.detail, contains('nope'));
  });

  test('every TransportGuidance value has instruction text', () {
    for (final g in TransportGuidance.values) {
      expect(catalog.guidance(g), isNotEmpty, reason: g.name);
    }
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd app && flutter test test/core/errors/error_catalog_test.dart
```

Expected: FAIL — `error_catalog.dart` does not exist.

- [ ] **Step 3: Add the strings**

Append to `app/lib/l10n/app_en.arb` (keep the file one flat JSON object; add these keys before the closing brace):

```json
  "errorMalformedResponse": "The device sent a reply Spectra could not read.",
  "@errorMalformedResponse": {"description": "A response payload did not match the expected shape."},
  "errorTimeout": "The device did not answer in time.",
  "@errorTimeout": {"description": "A command timed out."},
  "errorCancelled": "Cancelled.",
  "@errorCancelled": {"description": "The user cancelled a long operation."},
  "errorNotReady": "That needs a connected device.",
  "@errorNotReady": {"description": "A command was attempted with no ready session."},
  "errorBackgroundTask": "Something went wrong in the background.",
  "@errorBackgroundTask": {"description": "An unexpected failure in a background task."},
  "errorFirmwareTooOld": "This firmware is older than 2.0. Update it to use Spectra.",
  "@errorFirmwareTooOld": {"description": "Firmware predates the supported protocol."},
  "errorFirmwareTooNew": "This firmware is newer than Spectra supports. Update Spectra.",
  "@errorFirmwareTooNew": {"description": "Firmware major version is above the supported one."},
  "errorFirmwareLegacy": "This device runs the legacy 0.1 firmware and must be updated.",
  "@errorFirmwareLegacy": {"description": "The legacy 0.1 firmware, which only supports an update."},
  "errorNoReader": "This device has no card reader.",
  "@errorNoReader": {"description": "A reader command on a Chameleon Lite."},
  "errorDisconnected": "The connection to the device was lost.",
  "@errorDisconnected": {"description": "The transport closed unexpectedly."},
  "errorPermissionDenied": "Spectra needs permission to reach the device.",
  "@errorPermissionDenied": {"description": "Bluetooth or serial permission was refused."},
  "errorPortBusy": "That port is in use by another program.",
  "@errorPortBusy": {"description": "A serial port is held by another process."},
  "errorDeviceNotFound": "Spectra could not find that device.",
  "@errorDeviceNotFound": {"description": "The device disappeared before it could be opened."},
  "errorPairingRequired": "This device has to be paired first.",
  "@errorPairingRequired": {"description": "BLE pairing is required before use."},
  "errorAdapterOff": "Bluetooth is switched off.",
  "@errorAdapterOff": {"description": "The Bluetooth adapter is powered off."},
  "errorDfu": "The firmware update could not be completed.",
  "@errorDfu": {"description": "A failure inside the DFU stack."},
  "errorNoHfTag": "No high-frequency card was found. Hold the card against the device.",
  "@errorNoHfTag": {"description": "An HF scan found nothing."},
  "errorHfTag": "The card did not answer cleanly. Try holding it steady.",
  "@errorHfTag": {"description": "An HF communication error such as CRC or collision."},
  "errorAuthFailed": "That key was rejected by the card.",
  "@errorAuthFailed": {"description": "MIFARE authentication failed."},
  "errorNoLfTag": "No low-frequency card was found.",
  "@errorNoLfTag": {"description": "An LF scan found nothing."},
  "errorLfLoginRequired": "This card needs a password before it can be read.",
  "@errorLfLoginRequired": {"description": "The LF tag requires a login."},
  "errorParameter": "The device rejected that value.",
  "@errorParameter": {"description": "The firmware reported a parameter error."},
  "errorDeviceMode": "The device is in the wrong mode for that.",
  "@errorDeviceMode": {"description": "Reader/emulator mode mismatch."},
  "errorInvalidCommand": "This firmware does not support that action.",
  "@errorInvalidCommand": {"description": "The firmware refused an unknown command."},
  "errorNotImplemented": "That is not implemented on this firmware yet.",
  "@errorNotImplemented": {"description": "The firmware reported not-implemented."},
  "errorFlashWrite": "Writing to the device's storage failed.",
  "@errorFlashWrite": {"description": "A flash write failure."},
  "errorFlashRead": "Reading the device's storage failed.",
  "@errorFlashRead": {"description": "A flash read failure."},
  "errorInvalidSlotType": "That tag type cannot go in this slot.",
  "@errorInvalidSlotType": {"description": "The firmware rejected the slot tag type."},
  "errorMemory": "The device ran out of memory.",
  "@errorMemory": {"description": "The firmware reported a memory error."},
  "errorCreateResponse": "The device could not build a reply.",
  "@errorCreateResponse": {"description": "The firmware failed to create a response."},
  "errorCommandFailed": "The device could not carry that out.",
  "@errorCommandFailed": {"description": "A generic command failure."},
  "errorUnknownStatus": "The device reported an unknown status ({code}).",
  "@errorUnknownStatus": {
    "description": "A status code the SDK does not recognise.",
    "placeholders": {"code": {"type": "String"}}
  },
  "errorUnexpected": "Something unexpected went wrong.",
  "@errorUnexpected": {"description": "Fallback for an error that is not from the SDK."},
  "guidanceAndroidBluetoothPermission": "Open Android settings and allow Spectra to find and connect to nearby devices.",
  "@guidanceAndroidBluetoothPermission": {"description": "Android 12+ Bluetooth permission instructions."},
  "guidanceApplePairingPrompt": "Accept the pairing prompt when it appears.",
  "@guidanceApplePairingPrompt": {"description": "iOS and macOS pairing instructions."},
  "guidanceWindowsPairDevice": "Pair the Chameleon in Windows Bluetooth settings, then try again.",
  "@guidanceWindowsPairDevice": {"description": "Windows pairing instructions."},
  "guidanceLinuxPairFromSettings": "Pair the Chameleon from your system Bluetooth settings using the device's passkey, then try again.",
  "@guidanceLinuxPairFromSettings": {"description": "Linux BlueZ pairing instructions."},
  "guidanceBluetoothAdapterOff": "Switch Bluetooth on, then scan again.",
  "@guidanceBluetoothAdapterOff": {"description": "Adapter is powered off."},
  "guidanceLinuxSerialGroup": "Add your user to the dialout group, or install the Chameleon udev rule, then reconnect the cable.",
  "@guidanceLinuxSerialGroup": {"description": "Linux serial permission instructions."},
  "guidanceLinuxModemManager": "ModemManager is holding the port. Stop it, or add the Chameleon to its ignore list, then reconnect.",
  "@guidanceLinuxModemManager": {"description": "Linux port-busy instructions."},
  "guidanceWindowsPortAccessDenied": "Close any other program using the COM port, then try again.",
  "@guidanceWindowsPortAccessDenied": {"description": "Windows serial access-denied instructions."},
  "guidanceMacosSerialEntitlement": "Allow Spectra to use USB devices when macOS asks, then try again.",
  "@guidanceMacosSerialEntitlement": {"description": "macOS serial entitlement instructions."},
  "guidanceAndroidUsbPermission": "Allow Spectra to use the USB device when Android asks.",
  "@guidanceAndroidUsbPermission": {"description": "Android USB permission instructions."},
  "guidancePortNotFound": "That port is gone. Reconnect the cable and scan again.",
  "@guidancePortNotFound": {"description": "The named serial port no longer exists."}
```

Regenerate: `cd app && flutter gen-l10n`.

- [ ] **Step 4: Write the catalog**

`app/lib/core/errors/error_presentation.dart` — exactly the Interfaces block above, with a doc comment saying `detail` is the raw line spec 9 puts one tap away.

`app/lib/core/errors/error_catalog.dart`:

```dart
import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';

import '../../l10n/app_localizations.dart';
import 'error_presentation.dart';

/// Spec 9: the one place an error becomes words. Keyed by the sealed error
/// types, so a new SDK error is a compile error here rather than a silent
/// "something went wrong" in the UI.
final class ErrorCatalog {
  const ErrorCatalog(this._l10n);
  final AppLocalizations _l10n;

  ErrorPresentation describe(Object error) {
    if (error is! ChameleonException) {
      return ErrorPresentation(
        message: _l10n.errorUnexpected,
        recovery: ErrorRecovery.retry,
        detail: error.toString(),
      );
    }
    final (String message, ErrorRecovery recovery) = switch (error) {
      MalformedResponse() => (_l10n.errorMalformedResponse, ErrorRecovery.retry),
      CommandTimeout() => (_l10n.errorTimeout, ErrorRecovery.retry),
      CommandCancelled() => (_l10n.errorCancelled, ErrorRecovery.none),
      SessionNotReady() => (_l10n.errorNotReady, ErrorRecovery.reconnect),
      BackgroundTaskFailed() => (_l10n.errorBackgroundTask, ErrorRecovery.retry),
      UnsupportedFirmware(:final reason) => (
          switch (reason) {
            UnsupportedReason.preTwoPointZero => _l10n.errorFirmwareTooOld,
            UnsupportedReason.newerMajor => _l10n.errorFirmwareTooNew,
            UnsupportedReason.legacyMustUpdate => _l10n.errorFirmwareLegacy,
          },
          ErrorRecovery.update,
        ),
      ReaderUnavailable() => (_l10n.errorNoReader, ErrorRecovery.none),
      Disconnected() => (_l10n.errorDisconnected, ErrorRecovery.reconnect),
      PermissionDenied() => (
          _l10n.errorPermissionDenied,
          ErrorRecovery.openSettings,
        ),
      PortBusy() => (_l10n.errorPortBusy, ErrorRecovery.platformInstructions),
      DeviceNotFound() => (_l10n.errorDeviceNotFound, ErrorRecovery.retry),
      PairingRequired() => (
          _l10n.errorPairingRequired,
          ErrorRecovery.platformInstructions,
        ),
      AdapterOff() => (_l10n.errorAdapterOff, ErrorRecovery.openSettings),
      DfuError() => (_l10n.errorDfu, ErrorRecovery.retry),
      HfTagNotFound() => (_l10n.errorNoHfTag, ErrorRecovery.retry),
      HfTagError() => (_l10n.errorHfTag, ErrorRecovery.retry),
      AuthenticationFailed() => (_l10n.errorAuthFailed, ErrorRecovery.retry),
      LfTagNotFound() => (_l10n.errorNoLfTag, ErrorRecovery.retry),
      LfLoginRequired() => (_l10n.errorLfLoginRequired, ErrorRecovery.none),
      ParameterError() => (_l10n.errorParameter, ErrorRecovery.none),
      DeviceModeError() => (_l10n.errorDeviceMode, ErrorRecovery.retry),
      InvalidCommand() => (_l10n.errorInvalidCommand, ErrorRecovery.update),
      NotImplemented() => (_l10n.errorNotImplemented, ErrorRecovery.update),
      FlashWriteFailed() => (_l10n.errorFlashWrite, ErrorRecovery.retry),
      FlashReadFailed() => (_l10n.errorFlashRead, ErrorRecovery.retry),
      InvalidSlotType() => (_l10n.errorInvalidSlotType, ErrorRecovery.none),
      MemoryError() => (_l10n.errorMemory, ErrorRecovery.retry),
      CreateResponseError() => (_l10n.errorCreateResponse, ErrorRecovery.retry),
      CommandFailed() => (_l10n.errorCommandFailed, ErrorRecovery.retry),
      UnknownDeviceError(:final code) => (
          _l10n.errorUnknownStatus('0x${code.toRadixString(16)}'),
          ErrorRecovery.none,
        ),
    };
    return ErrorPresentation(
      message: message,
      recovery: recovery,
      detail: error.toString(),
    );
  }

  /// The platform-specific step behind [ErrorRecovery.platformInstructions]
  /// and [ErrorRecovery.openSettings]. `chameleon_flutter` ships the enum;
  /// the words live here (spec 7.6).
  String guidance(TransportGuidance guidance) => switch (guidance) {
        TransportGuidance.androidBluetoothPermission =>
          _l10n.guidanceAndroidBluetoothPermission,
        TransportGuidance.applePairingPrompt => _l10n.guidanceApplePairingPrompt,
        TransportGuidance.windowsPairDevice => _l10n.guidanceWindowsPairDevice,
        TransportGuidance.linuxPairFromSettings =>
          _l10n.guidanceLinuxPairFromSettings,
        TransportGuidance.bluetoothAdapterOff =>
          _l10n.guidanceBluetoothAdapterOff,
        TransportGuidance.linuxSerialGroup => _l10n.guidanceLinuxSerialGroup,
        TransportGuidance.linuxModemManager => _l10n.guidanceLinuxModemManager,
        TransportGuidance.windowsPortAccessDenied =>
          _l10n.guidanceWindowsPortAccessDenied,
        TransportGuidance.macosSerialEntitlement =>
          _l10n.guidanceMacosSerialEntitlement,
        TransportGuidance.androidUsbPermission =>
          _l10n.guidanceAndroidUsbPermission,
        TransportGuidance.portNotFound => _l10n.guidancePortNotFound,
      };
}
```

If the landed `TransportGuidance` has different or extra values, the switch will not compile — add the missing cases and their ARB keys rather than adding a default clause. That failure is the point.

`ErrorPresentation.instructions` is filled by the connect UI (Task 14), which knows which transport failed; the catalog itself has no transport.

- [ ] **Step 5: Run the test**

```bash
cd app && flutter test test/core/errors/error_catalog_test.dart
```

Expected: PASS, 5 tests.

- [ ] **Step 6: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git add app
git commit -m "feat(app): add the localized error catalog

Spec 9 wants every typed error to reach the user as one plain sentence plus
a recovery action, with the raw line one tap away. An exhaustive switch over
the sealed exception family means a new SDK error cannot be forgotten.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: Feature flags, with `dfuOverBleEnabled` off by default

**Files:**
- Create: `app/lib/core/flags/feature_flags.dart`
- Create (generated, committed): `app/lib/core/flags/feature_flags.g.dart`
- Modify: `app/lib/l10n/app_en.arb`
- Test: `app/test/core/flags/feature_flags_test.dart`

**Interfaces:**
- Consumes: `PreferencesRepository`, `preferencesRepositoryProvider` (Task 3); `InMemoryPreferencesRepository`.
- Produces:

```dart
// package:spectra/core/flags/feature_flags.dart
final class FeatureFlags {
  const FeatureFlags({this.dfuOverBleEnabled = false});
  final bool dfuOverBleEnabled;
  FeatureFlags copyWith({bool? dfuOverBleEnabled});
  static const String dfuOverBleKey = 'flag.dfuOverBleEnabled';
}

@Riverpod(keepAlive: true)
class FeatureFlagsController extends _$FeatureFlagsController {
  @override Future<FeatureFlags> build();                  // featureFlagsControllerProvider
  Future<void> setDfuOverBleEnabled(bool enabled);
}

/// The synchronous view every caller wants; defaults to everything off until
/// preferences have loaded.
@Riverpod(keepAlive: true)
FeatureFlags featureFlags(Ref ref);                        // featureFlagsProvider
```

- [ ] **Step 1: Write the failing test**

```dart
// app/test/core/flags/feature_flags_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/flags/feature_flags.dart';
import 'package:spectra/data/database/database_providers.dart';
import 'package:spectra/data/memory/in_memory_repositories.dart';

ProviderContainer containerWith(InMemoryPreferencesRepository prefs) {
  final container = ProviderContainer(
    overrides: [preferencesRepositoryProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('dfuOverBleEnabled defaults to off', () async {
    final container = containerWith(InMemoryPreferencesRepository());
    final flags = await container.read(featureFlagsControllerProvider.future);
    expect(flags.dfuOverBleEnabled, isFalse);
  });

  test('the synchronous view is all-off before preferences load', () {
    final container = containerWith(InMemoryPreferencesRepository());
    expect(container.read(featureFlagsProvider).dfuOverBleEnabled, isFalse);
  });

  test('a stored true is read back on the next build', () async {
    final prefs = InMemoryPreferencesRepository();
    await prefs.write(FeatureFlags.dfuOverBleKey, 'true');
    final container = containerWith(prefs);
    final flags = await container.read(featureFlagsControllerProvider.future);
    expect(flags.dfuOverBleEnabled, isTrue);
  });

  test('setting the flag persists it and updates the state', () async {
    final prefs = InMemoryPreferencesRepository();
    final container = containerWith(prefs);
    await container.read(featureFlagsControllerProvider.future);
    await container
        .read(featureFlagsControllerProvider.notifier)
        .setDfuOverBleEnabled(true);
    expect(await prefs.read(FeatureFlags.dfuOverBleKey), 'true');
    expect(container.read(featureFlagsProvider).dfuOverBleEnabled, isTrue);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd app && flutter test test/core/flags/feature_flags_test.dart
```

Expected: FAIL — `feature_flags.dart` does not exist.

- [ ] **Step 3: Write it**

```dart
// app/lib/core/flags/feature_flags.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/database/database_providers.dart';

part 'feature_flags.g.dart';

/// Flags that gate work the user's hardware has not validated yet
/// (roadmap, hardware handoffs).
final class FeatureFlags {
  const FeatureFlags({this.dfuOverBleEnabled = false});

  /// BLE and iOS DFU are built in full but stay off until the user reports
  /// hardware handoff H2 passed. Phase 8 reads this; nothing flips it here.
  final bool dfuOverBleEnabled;

  static const String dfuOverBleKey = 'flag.dfuOverBleEnabled';

  FeatureFlags copyWith({bool? dfuOverBleEnabled}) => FeatureFlags(
        dfuOverBleEnabled: dfuOverBleEnabled ?? this.dfuOverBleEnabled,
      );
}

@Riverpod(keepAlive: true)
class FeatureFlagsController extends _$FeatureFlagsController {
  @override
  Future<FeatureFlags> build() async {
    final prefs = ref.watch(preferencesRepositoryProvider);
    return FeatureFlags(
      dfuOverBleEnabled:
          await prefs.read(FeatureFlags.dfuOverBleKey) == 'true',
    );
  }

  Future<void> setDfuOverBleEnabled(bool enabled) async {
    await ref
        .read(preferencesRepositoryProvider)
        .write(FeatureFlags.dfuOverBleKey, '$enabled');
    state = AsyncData(
      (state.valueOrNull ?? const FeatureFlags())
          .copyWith(dfuOverBleEnabled: enabled),
    );
  }
}

/// Flags as a plain value. Everything off until the load finishes, which is
/// the safe direction for every flag in this file.
@Riverpod(keepAlive: true)
FeatureFlags featureFlags(Ref ref) =>
    ref.watch(featureFlagsControllerProvider).valueOrNull ??
    const FeatureFlags();
```

```bash
cd app && dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 4: Run the test**

```bash
cd app && flutter test test/core/flags/feature_flags_test.dart
```

Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git add app
git commit -m "feat(app): add feature flags with dfuOverBleEnabled off

The roadmap gates BLE and iOS DFU behind a flag that only flips after the
user reports H2. Defining it here means Phase 8 reads a flag that already
exists and is already persisted.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: The session registry — `Sessions`, `deviceSessionProvider`, `activeDeviceProvider`

**Files:**
- Create: `app/lib/core/session/active_session.dart`, `app/lib/core/session/session_identity.dart`, `app/lib/core/session/sessions.dart`, `app/lib/core/session/active_device.dart`
- Create (generated, committed): `app/lib/core/session/sessions.g.dart`, `app/lib/core/session/active_device.g.dart`
- Test: `app/test/core/session/sessions_test.dart`

**Interfaces:**
- Consumes: `DeviceSession`, `DeviceIdentity`, `DiscoveredDevice`, `Transport`, `TransportKind`, `ConnectionState` and its variants, `DisconnectCause`, `ChameleonException`, `FakeDevice`, `FakeFirmware`, `FakeFirmwareConfig`, `FakeScanner` from `package:chameleon/chameleon.dart`; `ChameleonTransports` from `package:chameleon_flutter/chameleon_flutter.dart`; `KnownDevicesRepository`, `knownDevicesRepositoryProvider` (Task 3).
- Produces:

```dart
// package:spectra/core/session/active_session.dart
final class ActiveSession {
  const ActiveSession({
    required this.identity,
    required this.device,
    required this.session,
  });
  final DeviceIdentity identity;
  final DiscoveredDevice device;
  final DeviceSession session;
}

// package:spectra/core/session/session_identity.dart
/// The identity of a device with no chip id — pre-2.0 firmware, or a session
/// that never got ready. Stable for one transport, so the registry can key
/// every session the same way (spec 7.1).
DeviceIdentity fallbackIdentity(DiscoveredDevice device);
/// The chip id when the handshake got that far, the fallback otherwise.
Future<DeviceIdentity> resolveIdentity(DeviceSession session, DiscoveredDevice device);

// package:spectra/core/session/sessions.dart
final class SessionsState {
  const SessionsState({this.sessions = const {}, this.lastDisconnected});
  final Map<DeviceIdentity, ActiveSession> sessions;
  /// The device whose link dropped without being asked to (spec 7.4): the
  /// connect screen preselects it.
  final DiscoveredDevice? lastDisconnected;
}

@Riverpod(keepAlive: true)
class Sessions extends _$Sessions {                      // sessionsProvider
  @override SessionsState build();
  /// Opens a transport and a session, runs the handshake, registers the
  /// session under its identity and remembers the device. Throws whatever
  /// the open failed with, leaving nothing registered.
  Future<DeviceIdentity> connect(DiscoveredDevice device);
  Future<void> disconnect(DeviceIdentity identity);
  Future<void> disconnectAll();
}

@Riverpod(keepAlive: true)
ActiveSession? deviceSession(Ref ref, DeviceIdentity identity);  // deviceSessionProvider(identity)

/// Injected so tests connect to a scripted FakeDevice. Production is
/// `ChameleonTransports.transportFor`.
@Riverpod(keepAlive: true)
Transport Function(DiscoveredDevice) transportFactory(Ref ref);

// package:spectra/core/session/active_device.dart
@Riverpod(keepAlive: true)
class ActiveDevice extends _$ActiveDevice {              // activeDeviceProvider
  @override DeviceIdentity? build();
  void select(DeviceIdentity? identity);
}

@Riverpod(keepAlive: true)
ActiveSession? activeSession(Ref ref);                   // activeSessionProvider
```

- [ ] **Step 1: Write the failing test**

```dart
// app/test/core/session/sessions_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/session/active_device.dart';
import 'package:spectra/core/session/session_identity.dart';
import 'package:spectra/core/session/sessions.dart';
import 'package:spectra/data/database/database_providers.dart';
import 'package:spectra/data/memory/in_memory_repositories.dart';

const emulated = FakeScanner.emulatedUltra;

/// A container whose transports are the fakes [devices] hands out, keyed by
/// transportId, and whose known-devices repository is in memory.
({ProviderContainer container, InMemoryKnownDevicesRepository known})
    harness(Map<String, Transport> devices) {
  final known = InMemoryKnownDevicesRepository();
  final container = ProviderContainer(
    overrides: [
      knownDevicesRepositoryProvider.overrideWithValue(known),
      transportFactoryProvider.overrideWithValue(
        (DiscoveredDevice d) => devices[d.transportId]!,
      ),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, known: known);
}

void main() {
  test('fallbackIdentity is stable and names the transport', () {
    expect(fallbackIdentity(emulated), fallbackIdentity(emulated));
    expect(fallbackIdentity(emulated).chipId, contains('fake-ultra'));
  });

  test('connecting registers the session under its chip id', () async {
    final device = FakeDevice();
    final h = harness({emulated.transportId: device});
    final identity = await h.container.read(sessionsProvider.notifier)
        .connect(emulated);

    expect(identity, DeviceIdentity(FakeFirmwareConfig().chipId));
    final active = h.container.read(deviceSessionProvider(identity));
    expect(active, isNotNull);
    expect(active!.session.connectionState.value, isA<SessionReady>());
    expect(active.device, emulated);

    await h.container.read(sessionsProvider.notifier).disconnectAll();
  });

  test('connecting remembers the device for the connect screen', () async {
    final h = harness({emulated.transportId: FakeDevice()});
    final identity = await h.container.read(sessionsProvider.notifier)
        .connect(emulated);

    final remembered = await h.known.byIdentity(identity);
    expect(remembered!.displayName, emulated.name);
    expect(remembered.transports.single.transportId, emulated.transportId);

    await h.container.read(sessionsProvider.notifier).disconnectAll();
  });

  test('a limited device is registered under the fallback identity',
      () async {
    final device = FakeDevice(
      firmware: FakeFirmware(config: FakeFirmwareConfig.legacy01()),
    );
    final h = harness({emulated.transportId: device});
    final identity = await h.container.read(sessionsProvider.notifier)
        .connect(emulated);

    expect(identity, fallbackIdentity(emulated));
    expect(
      h.container.read(deviceSessionProvider(identity))!
          .session.connectionState.value,
      isA<SessionLimited>(),
    );

    await h.container.read(sessionsProvider.notifier).disconnectAll();
  });

  test('a failed open registers nothing and rethrows', () async {
    final device = FakeDevice(openError: const PermissionDenied());
    final h = harness({emulated.transportId: device});

    await expectLater(
      h.container.read(sessionsProvider.notifier).connect(emulated),
      throwsA(isA<PermissionDenied>()),
    );
    expect(h.container.read(sessionsProvider).sessions, isEmpty);
  });

  test('connecting twice to the same device reuses the session', () async {
    final h = harness({emulated.transportId: FakeDevice()});
    final notifier = h.container.read(sessionsProvider.notifier);
    final first = await notifier.connect(emulated);
    final second = await notifier.connect(emulated);

    expect(second, first);
    expect(h.container.read(sessionsProvider).sessions, hasLength(1));

    await notifier.disconnectAll();
  });

  test('disconnect closes the session and drops it', () async {
    final h = harness({emulated.transportId: FakeDevice()});
    final notifier = h.container.read(sessionsProvider.notifier);
    final identity = await notifier.connect(emulated);
    final session = h.container.read(deviceSessionProvider(identity))!.session;

    await notifier.disconnect(identity);

    expect(h.container.read(sessionsProvider).sessions, isEmpty);
    expect(session.connectionState.value, isA<SessionDisconnected>());
  });

  test('a lost link drops the session and preselects the device', () async {
    final device = FakeDevice();
    final h = harness({emulated.transportId: device});
    final notifier = h.container.read(sessionsProvider.notifier);
    await notifier.connect(emulated);

    await device.dropLink();
    await Future<void>.delayed(Duration.zero);

    expect(h.container.read(sessionsProvider).sessions, isEmpty);
    expect(h.container.read(sessionsProvider).lastDisconnected, emulated);
  });

  test('the active device names one of the registered sessions', () async {
    final h = harness({emulated.transportId: FakeDevice()});
    final notifier = h.container.read(sessionsProvider.notifier);
    expect(h.container.read(activeSessionProvider), isNull);

    final identity = await notifier.connect(emulated);
    h.container.read(activeDeviceProvider.notifier).select(identity);

    expect(h.container.read(activeSessionProvider)!.identity, identity);

    await notifier.disconnectAll();
    expect(h.container.read(activeSessionProvider), isNull);
  });
}
```

`FakeDevice.dropLink()` is the fake's "the cable was pulled" affordance. **Open `packages/chameleon/lib/src/fake/fake_device.dart` first**: Phase 1 may have named it `dropLink`, `loseLink` or `closeUnexpectedly`. Use the landed name in the test and nowhere else — no production code depends on it.

- [ ] **Step 2: Run it and watch it fail**

```bash
cd app && flutter test test/core/session/sessions_test.dart
```

Expected: FAIL — `sessions.dart` does not exist.

- [ ] **Step 3: Write the value type and the identity rule**

```dart
// app/lib/core/session/active_session.dart
import 'package:chameleon/chameleon.dart';

/// One live connection plus the two things the UI needs to name it: the
/// identity it is registered under and the discovery entry it came from.
final class ActiveSession {
  const ActiveSession({
    required this.identity,
    required this.device,
    required this.session,
  });

  final DeviceIdentity identity;
  final DiscoveredDevice device;
  final DeviceSession session;
}
```

```dart
// app/lib/core/session/session_identity.dart
import 'package:chameleon/chameleon.dart';

/// Spec 4.2: identity is the chip id, and it is only known after a
/// handshake. A session that never became ready — pre-2.0 firmware, a device
/// in the bootloader — still has to be registered somewhere, so it gets an
/// identity derived from its transport. Stable for that transport, and
/// impossible to confuse with a chip id because of the prefix.
DeviceIdentity fallbackIdentity(DiscoveredDevice device) =>
    DeviceIdentity('transport:${device.kind.name}:${device.transportId}');

/// The chip id if the handshake got far enough to read one, the fallback
/// otherwise. Never throws: a device that will not answer 1011 is still a
/// device the app has to show.
Future<DeviceIdentity> resolveIdentity(
  DeviceSession session,
  DiscoveredDevice device,
) async {
  if (session.isReady) {
    final cached = session.deviceInfo.value?.identity;
    if (cached != null) return cached;
    try {
      return await session.device.readIdentity();
    } on ChameleonException {
      // Fall through: an identity is a nicety, a session is not.
    }
  }
  return fallbackIdentity(device);
}
```

- [ ] **Step 4: Write the registry**

```dart
// app/lib/core/session/sessions.dart
import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/database/database_providers.dart';
import 'active_session.dart';
import 'session_identity.dart';

part 'sessions.g.dart';

/// Every open session, keyed by identity (spec 7.1). Multi-device is not
/// built, but this is the shape that makes adding it later invisible to
/// feature code.
final class SessionsState {
  const SessionsState({
    this.sessions = const <DeviceIdentity, ActiveSession>{},
    this.lastDisconnected,
  });

  final Map<DeviceIdentity, ActiveSession> sessions;

  /// The device whose link went away without being asked to. The connect
  /// screen preselects it (spec 7.4).
  final DiscoveredDevice? lastDisconnected;

  SessionsState copyWith({
    Map<DeviceIdentity, ActiveSession>? sessions,
    DiscoveredDevice? lastDisconnected,
  }) =>
      SessionsState(
        sessions: sessions ?? this.sessions,
        lastDisconnected: lastDisconnected ?? this.lastDisconnected,
      );
}

/// How a [DiscoveredDevice] becomes a [Transport]. Injected so tests connect
/// to a scripted `FakeDevice` (spec 8.6).
@Riverpod(keepAlive: true)
Transport Function(DiscoveredDevice) transportFactory(Ref ref) =>
    ChameleonTransports.transportFor;

@Riverpod(keepAlive: true)
class Sessions extends _$Sessions {
  final Map<DeviceIdentity, StreamSubscription<ConnectionState>> _watchers =
      <DeviceIdentity, StreamSubscription<ConnectionState>>{};

  @override
  SessionsState build() {
    ref.onDispose(() {
      for (final sub in _watchers.values) {
        unawaited(sub.cancel());
      }
      for (final entry in state.sessions.values) {
        unawaited(entry.session.close());
      }
    });
    return const SessionsState();
  }

  /// Opens the transport, runs the handshake, then registers the session
  /// under the identity the handshake produced. Nothing is registered when
  /// the open fails, and the transport is closed by the session itself.
  Future<DeviceIdentity> connect(DiscoveredDevice device) async {
    final existing = state.sessions.entries
        .where((e) => e.value.device == device)
        .firstOrNull;
    if (existing != null) return existing.key;

    final session = DeviceSession(ref.read(transportFactoryProvider)(device));
    try {
      await session.open();
    } on Object {
      await session.close();
      rethrow;
    }
    final identity = await resolveIdentity(session, device);
    final entry = ActiveSession(
      identity: identity,
      device: device,
      session: session,
    );
    state = state.copyWith(
      sessions: <DeviceIdentity, ActiveSession>{
        ...state.sessions,
        identity: entry,
      },
    );
    _watch(entry);
    await ref.read(knownDevicesRepositoryProvider).remember(
          identity: identity,
          displayName: device.name,
          kind: device.kind,
          transportId: device.transportId,
        );
    return identity;
  }

  Future<void> disconnect(DeviceIdentity identity) async {
    final entry = state.sessions[identity];
    if (entry == null) return;
    await _forget(identity);
    await entry.session.close();
  }

  Future<void> disconnectAll() async {
    for (final identity in state.sessions.keys.toList()) {
      await disconnect(identity);
    }
  }

  /// A link that dies on its own drops the session and leaves the device
  /// behind for the connect screen to preselect (spec 7.4). A close the app
  /// asked for is already handled by [disconnect].
  void _watch(ActiveSession entry) {
    _watchers[entry.identity] = entry.session.connectionState.changes.listen(
      (s) async {
        if (s is! SessionDisconnected) return;
        if (!state.sessions.containsKey(entry.identity)) return;
        await _forget(entry.identity, dropped: entry.device);
        await entry.session.close();
      },
    );
  }

  Future<void> _forget(
    DeviceIdentity identity, {
    DiscoveredDevice? dropped,
  }) async {
    await _watchers.remove(identity)?.cancel();
    state = SessionsState(
      sessions: <DeviceIdentity, ActiveSession>{...state.sessions}
        ..remove(identity),
      lastDisconnected: dropped ?? state.lastDisconnected,
    );
  }
}

/// The session for one identity (spec 7.1). Null when nothing is connected
/// to that device.
@Riverpod(keepAlive: true)
ActiveSession? deviceSession(Ref ref, DeviceIdentity identity) =>
    ref.watch(sessionsProvider).sessions[identity];
```

```dart
// app/lib/core/session/active_device.dart
import 'package:chameleon/chameleon.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'active_session.dart';
import 'sessions.dart';

part 'active_device.g.dart';

/// Names the one session the UI is showing (spec 7.1). Features read
/// [activeSessionProvider] and never reach into [sessionsProvider].
@Riverpod(keepAlive: true)
class ActiveDevice extends _$ActiveDevice {
  @override
  DeviceIdentity? build() => null;

  void select(DeviceIdentity? identity) => state = identity;
}

@Riverpod(keepAlive: true)
ActiveSession? activeSession(Ref ref) {
  final identity = ref.watch(activeDeviceProvider);
  if (identity == null) return null;
  return ref.watch(deviceSessionProvider(identity));
}
```

```bash
cd app && dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 5: Run the test**

```bash
cd app && flutter test test/core/session/sessions_test.dart
```

Expected: PASS, 9 tests.

- [ ] **Step 6: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git add app
git commit -m "feat(app): add the session registry keyed by DeviceIdentity

Spec 7.1 keys sessions by identity, but identity is the chip id and only
exists after a handshake. connect() therefore opens first and registers
second, with a transport-derived fallback identity for firmware too old to
answer 1011, so limited sessions live in the same map.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: Derived session state — the seven stream providers and the frame log

**Files:**
- Create: `app/lib/core/session/session_streams.dart`, `app/lib/core/session/frame_log_provider.dart`
- Create (generated, committed): `app/lib/core/session/session_streams.g.dart`, `app/lib/core/session/frame_log_provider.g.dart`
- Test: `app/test/core/session/session_streams_test.dart`

**Interfaces:**
- Consumes: `ActiveSession`, `activeSessionProvider`, `sessionsProvider`, `transportFactoryProvider` (Task 6); `StateStream`, `ConnectionState`, `SessionDisconnected`, `DisconnectCause`, `DeviceInfo`, `BatteryInfo`, `Slot`, `DeviceMode`, `DeviceSettings`, `FrameLog`, `FrameLogEntry` from `package:chameleon/chameleon.dart`.
- Produces:

```dart
// package:spectra/core/session/session_streams.dart
/// The router needs a value now, not an AsyncValue later, so this one is a
/// notifier seeded from `StateStream.value` (spec 7.2).
@Riverpod(keepAlive: true)
class ConnectionStatus extends _$ConnectionStatus {   // connectionStatusProvider
  @override ConnectionState build();
}

@riverpod Stream<DeviceInfo?> deviceInfo(Ref ref);        // deviceInfoProvider
@riverpod Stream<BatteryInfo?> battery(Ref ref);          // batteryProvider
@riverpod Stream<List<Slot>> slots(Ref ref);              // slotsProvider
@riverpod Stream<int?> activeSlot(Ref ref);               // activeSlotProvider
@riverpod Stream<DeviceMode?> mode(Ref ref);              // modeProvider
@riverpod Stream<DeviceSettings?> settings(Ref ref);      // settingsProvider

// package:spectra/core/session/frame_log_provider.dart
@riverpod FrameLog? frameLog(Ref ref);                    // frameLogProvider
@riverpod Stream<List<FrameLogEntry>> frameLogEntries(Ref ref); // polls at 1 Hz
```

The notifier is named `ConnectionStatus`, not `ConnectionState`, because riverpod_generator would otherwise generate a `_$ConnectionState` base that collides with the SDK's `ConnectionState` in the same library. The provider is `connectionStatusProvider` everywhere in this plan.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/core/session/session_streams_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/session/active_device.dart';
import 'package:spectra/core/session/frame_log_provider.dart';
import 'package:spectra/core/session/session_streams.dart';
import 'package:spectra/core/session/sessions.dart';
import 'package:spectra/data/database/database_providers.dart';
import 'package:spectra/data/memory/in_memory_repositories.dart';

const emulated = FakeScanner.emulatedUltra;

ProviderContainer harness(Transport transport) {
  final container = ProviderContainer(
    overrides: [
      knownDevicesRepositoryProvider
          .overrideWithValue(InMemoryKnownDevicesRepository()),
      transportFactoryProvider.overrideWithValue((_) => transport),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> connectAndSelect(ProviderContainer c) async {
  final identity = await c.read(sessionsProvider.notifier).connect(emulated);
  c.read(activeDeviceProvider.notifier).select(identity);
}

void main() {
  test('with no session the status is disconnected', () {
    final container = harness(FakeDevice());
    expect(container.read(connectionStatusProvider), isA<SessionDisconnected>());
  });

  test('the status follows the active session', () async {
    final container = harness(FakeDevice());
    await connectAndSelect(container);
    expect(container.read(connectionStatusProvider), isA<SessionReady>());

    await container.read(sessionsProvider.notifier).disconnectAll();
    expect(container.read(connectionStatusProvider), isA<SessionDisconnected>());
  });

  test('deviceInfo carries the fake firmware version', () async {
    final container = harness(FakeDevice());
    await connectAndSelect(container);
    final info = await container.read(deviceInfoProvider.future);
    expect(info!.version.label, '2.2');
    expect(info.model, DeviceModel.ultra);
    await container.read(sessionsProvider.notifier).disconnectAll();
  });

  test('slots arrive from the background load', () async {
    final container = harness(FakeDevice());
    await connectAndSelect(container);
    await expectLater(
      container.read(slotsProvider.future).then((s) => s.length),
      completion(anyOf(0, 8)),
    );
    await container.read(sessionsProvider.notifier).disconnectAll();
  });

  test('the frame log is the session log and has traffic after a handshake',
      () async {
    final device = FakeDevice();
    final container = harness(device);
    await connectAndSelect(container);
    final log = container.read(frameLogProvider);
    expect(log, isNotNull);
    expect(log!.entries, isNotEmpty);
    expect(log.export(), contains('cmd='));
    await container.read(sessionsProvider.notifier).disconnectAll();
  });

  test('with no session there is no frame log', () {
    final container = harness(FakeDevice());
    expect(container.read(frameLogProvider), isNull);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd app && flutter test test/core/session/session_streams_test.dart
```

Expected: FAIL — `session_streams.dart` does not exist.

- [ ] **Step 3: Write the providers**

```dart
// app/lib/core/session/session_streams.dart
import 'package:chameleon/chameleon.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'active_device.dart';

part 'session_streams.g.dart';

/// Republishes one of the session's [StateStream]s: its current value first,
/// then every change. Returns [whenNone] while nothing is connected, so a
/// screen never has to special-case "no session" twice.
Stream<T> _sessionStream<T>(
  Ref ref,
  StateStream<T> Function(DeviceSession session) select,
  T whenNone,
) {
  final active = ref.watch(activeSessionProvider);
  if (active == null) return Stream<T>.value(whenNone);
  return select(active.session).values;
}

/// The one piece of session state routing needs synchronously (spec 7.2), so
/// it is a notifier seeded from the stream's current value rather than an
/// `AsyncValue`.
@Riverpod(keepAlive: true)
class ConnectionStatus extends _$ConnectionStatus {
  @override
  ConnectionState build() {
    final active = ref.watch(activeSessionProvider);
    if (active == null) {
      return const SessionDisconnected(DisconnectCause.requested);
    }
    final sub = active.session.connectionState.changes.listen((s) {
      state = s;
    });
    ref.onDispose(sub.cancel);
    return active.session.connectionState.value;
  }
}

@riverpod
Stream<DeviceInfo?> deviceInfo(Ref ref) =>
    _sessionStream(ref, (s) => s.deviceInfo, null);

@riverpod
Stream<BatteryInfo?> battery(Ref ref) =>
    _sessionStream(ref, (s) => s.battery, null);

@riverpod
Stream<List<Slot>> slots(Ref ref) =>
    _sessionStream(ref, (s) => s.slotsState, const <Slot>[]);

@riverpod
Stream<int?> activeSlot(Ref ref) =>
    _sessionStream(ref, (s) => s.activeSlot, null);

@riverpod
Stream<DeviceMode?> mode(Ref ref) => _sessionStream(ref, (s) => s.mode, null);

@riverpod
Stream<DeviceSettings?> settings(Ref ref) =>
    _sessionStream(ref, (s) => s.settingsState, null);
```

```dart
// app/lib/core/session/frame_log_provider.dart
import 'package:chameleon/chameleon.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'active_device.dart';

part 'frame_log_provider.g.dart';

/// Spec 9: the ring buffer is always on, and viewing and exporting it are
/// available in every build. It belongs to the session, so it is null when
/// nothing is connected.
@riverpod
FrameLog? frameLog(Ref ref) => ref.watch(activeSessionProvider)?.session.frameLog;

/// A snapshot of the log once a second. [FrameLog] is a plain ring buffer
/// with no change notification — polling is what keeps the SDK free of a
/// stream nothing else needs.
@riverpod
Stream<List<FrameLogEntry>> frameLogEntries(Ref ref) async* {
  final log = ref.watch(frameLogProvider);
  if (log == null) {
    yield const <FrameLogEntry>[];
    return;
  }
  yield log.entries;
  yield* Stream<void>.periodic(const Duration(seconds: 1))
      .map((_) => log.entries);
}
```

```bash
cd app && dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 4: Run the test**

```bash
cd app && flutter test test/core/session/session_streams_test.dart
```

Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git add app
git commit -m "feat(app): republish the session state streams as providers

Feature providers derive from session streams (spec 7.1). The connection
state is a notifier rather than a stream because routing needs a value
synchronously; everything else is an AsyncValue and screens render the
loading case.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 8: Scanners, emulator mode, merged discovery and manual serial ports

**Files:**
- Create: `app/lib/core/discovery/scanners.dart`, `app/lib/core/discovery/discovery_merge.dart`, `app/lib/core/discovery/discovery_provider.dart`
- Create (generated, committed): `app/lib/core/discovery/scanners.g.dart`, `app/lib/core/discovery/discovery_provider.g.dart`
- Test: `app/test/core/discovery/discovery_merge_test.dart`, `app/test/core/discovery/discovery_provider_test.dart`

**Interfaces:**
- Consumes: `DeviceScanner`, `DiscoveredDevice`, `TransportKind`, `FakeScanner`, `PermissionDenied` from `package:chameleon/chameleon.dart`; `ChameleonTransports.defaultScanners` from `package:chameleon_flutter/chameleon_flutter.dart`.
- Produces:

```dart
// package:spectra/core/discovery/scanners.dart
/// Spec 7.5: the emulated device is listed alongside real ones. On by
/// default — it is how screenshots and manual QA happen with no hardware.
@Riverpod(keepAlive: true)
class EmulatorMode extends _$EmulatorMode {          // emulatorModeProvider
  @override bool build();                            // true
  void setEnabled(bool enabled);
}

@Riverpod(keepAlive: true)
List<DeviceScanner> scanners(Ref ref);               // scannersProvider

// package:spectra/core/discovery/discovery_merge.dart
final class DiscoveryState {
  const DiscoveryState({this.devices = const <DiscoveredDevice>[], this.error});
  final List<DiscoveredDevice> devices;
  /// The last failure any scanner reported: a denied permission, an adapter
  /// that is off (spec 5.1). Rendered through the error catalog.
  final Object? error;
}

/// Runs every scanner at once and emits the union of their latest lists
/// (spec 4.2). Pure: no Riverpod, so it is unit-testable on its own.
final class DiscoveryMerge {
  const DiscoveryMerge(List<DeviceScanner> scanners);
  Stream<DiscoveryState> stream();
}

// package:spectra/core/discovery/discovery_provider.dart
@riverpod Stream<DiscoveryState> discovery(Ref ref);      // discoveryProvider

/// Ports the user typed in by hand on desktop (spec 5.2). They join the
/// merge as ordinary usb entries.
@Riverpod(keepAlive: true)
class ManualPorts extends _$ManualPorts {                 // manualPortsProvider
  @override List<DiscoveredDevice> build();
  void add(String path);
  void remove(String path);
}
```

- [ ] **Step 1: Write the failing tests**

```dart
// app/test/core/discovery/discovery_merge_test.dart
import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/discovery/discovery_merge.dart';

const usbUltra = DiscoveredDevice(
  name: 'ChameleonUltra',
  kind: TransportKind.usb,
  transportId: '/dev/cu.usbmodem1',
);

/// A scanner whose emissions the test drives.
final class ScriptedScanner implements DeviceScanner {
  ScriptedScanner(this.kind, this.controller);
  @override
  final TransportKind kind;
  final StreamController<List<DiscoveredDevice>> controller;
  @override
  Stream<List<DiscoveredDevice>> scan() => controller.stream;
}

void main() {
  test('emits the union of every scanner s latest list', () async {
    final ble = StreamController<List<DiscoveredDevice>>();
    final usb = StreamController<List<DiscoveredDevice>>();
    final merge = DiscoveryMerge(<DeviceScanner>[
      ScriptedScanner(TransportKind.ble, ble),
      ScriptedScanner(TransportKind.usb, usb),
    ]);
    final seen = <List<DiscoveredDevice>>[];
    final sub = merge.stream().listen((s) => seen.add(s.devices));

    ble.add(const <DiscoveredDevice>[FakeScanner.emulatedUltra]);
    await Future<void>.delayed(Duration.zero);
    usb.add(const <DiscoveredDevice>[usbUltra]);
    await Future<void>.delayed(Duration.zero);

    expect(seen.last, <DiscoveredDevice>[FakeScanner.emulatedUltra, usbUltra]);
    await sub.cancel();
    await ble.close();
    await usb.close();
  });

  test('a scanner that re-emits replaces only its own devices', () async {
    final usb = StreamController<List<DiscoveredDevice>>();
    final merge = DiscoveryMerge(<DeviceScanner>[
      FakeScanner(),
      ScriptedScanner(TransportKind.usb, usb),
    ]);
    final seen = <List<DiscoveredDevice>>[];
    final sub = merge.stream().listen((s) => seen.add(s.devices));

    usb.add(const <DiscoveredDevice>[usbUltra]);
    await Future<void>.delayed(Duration.zero);
    usb.add(const <DiscoveredDevice>[]);
    await Future<void>.delayed(Duration.zero);

    expect(seen.last, <DiscoveredDevice>[FakeScanner.emulatedUltra]);
    await sub.cancel();
    await usb.close();
  });

  test('a scanner error becomes state, not a dead stream', () async {
    final ble = StreamController<List<DiscoveredDevice>>();
    final merge = DiscoveryMerge(<DeviceScanner>[
      FakeScanner(),
      ScriptedScanner(TransportKind.ble, ble),
    ]);
    final seen = <DiscoveryState>[];
    final sub = merge.stream().listen(seen.add);

    ble.addError(const PermissionDenied());
    await Future<void>.delayed(Duration.zero);

    expect(seen.last.error, isA<PermissionDenied>());
    expect(seen.last.devices, contains(FakeScanner.emulatedUltra));
    await sub.cancel();
    await ble.close();
  });
}
```

```dart
// app/test/core/discovery/discovery_provider_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/discovery/discovery_provider.dart';
import 'package:spectra/core/discovery/scanners.dart';

void main() {
  test('emulator mode is on and puts the emulated device in the list',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(emulatorModeProvider), isTrue);
    expect(
      container.read(scannersProvider).whereType<FakeScanner>(),
      isNotEmpty,
    );
  });

  test('turning emulator mode off removes the fake scanner', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(emulatorModeProvider.notifier).setEnabled(false);
    expect(
      container.read(scannersProvider).whereType<FakeScanner>(),
      isEmpty,
    );
  });

  test('discovery reports the emulated device', () async {
    final container = ProviderContainer(
      overrides: [
        scannersProvider.overrideWithValue(<DeviceScanner>[FakeScanner()]),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(discoveryProvider.future);
    expect(state.devices, contains(FakeScanner.emulatedUltra));
  });

  test('a manual port joins the discovered list', () async {
    final container = ProviderContainer(
      overrides: [
        scannersProvider.overrideWithValue(<DeviceScanner>[FakeScanner()]),
      ],
    );
    addTearDown(container.dispose);
    await container.read(discoveryProvider.future);

    container.read(manualPortsProvider.notifier).add('/dev/cu.usbmodem9');
    final manual = container.read(manualPortsProvider).single;
    expect(manual.kind, TransportKind.usb);
    expect(manual.transportId, '/dev/cu.usbmodem9');
  });
}
```

- [ ] **Step 2: Run them and watch them fail**

```bash
cd app && flutter test test/core/discovery
```

Expected: FAIL — the discovery libraries do not exist.

- [ ] **Step 3: Write the merge**

```dart
// app/lib/core/discovery/discovery_merge.dart
import 'dart:async';

import 'package:chameleon/chameleon.dart';

/// What the connect screen knows about what is out there right now.
final class DiscoveryState {
  const DiscoveryState({
    this.devices = const <DiscoveredDevice>[],
    this.error,
  });

  final List<DiscoveredDevice> devices;

  /// The last failure a scanner reported — a denied Bluetooth permission, an
  /// adapter that is off, a serial port the user may not open (spec 5.1).
  /// Kept as the raw error so the error catalog decides the wording.
  final Object? error;

  DiscoveryState copyWith({List<DiscoveredDevice>? devices, Object? error}) =>
      DiscoveryState(devices: devices ?? this.devices, error: error ?? this.error);
}

/// Runs every scanner concurrently and emits the union of their latest
/// lists (spec 4.2). One scanner failing never stops the others: its error
/// becomes [DiscoveryState.error] and its devices are dropped.
final class DiscoveryMerge {
  const DiscoveryMerge(this.scanners);
  final List<DeviceScanner> scanners;

  Stream<DiscoveryState> stream() {
    final latest = List<List<DiscoveredDevice>>.filled(
      scanners.length,
      const <DiscoveredDevice>[],
    );
    Object? error;
    late StreamController<DiscoveryState> out;
    final subs = <StreamSubscription<List<DiscoveredDevice>>>[];

    void emit() {
      if (out.isClosed) return;
      out.add(
        DiscoveryState(
          devices: <DiscoveredDevice>[for (final l in latest) ...l],
          error: error,
        ),
      );
    }

    out = StreamController<DiscoveryState>(
      onListen: () {
        for (var i = 0; i < scanners.length; i++) {
          final index = i;
          subs.add(
            scanners[i].scan().listen(
              (devices) {
                latest[index] = devices;
                error = null;
                emit();
              },
              onError: (Object e) {
                latest[index] = const <DiscoveredDevice>[];
                error = e;
                emit();
              },
            ),
          );
        }
        emit();
      },
      onCancel: () async {
        for (final sub in subs) {
          await sub.cancel();
        }
      },
    );
    return out.stream;
  }
}
```

- [ ] **Step 4: Write the scanner and discovery providers**

```dart
// app/lib/core/discovery/scanners.dart
import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'scanners.g.dart';

/// Spec 7.5: the connect screen lists real devices plus one emulated
/// Chameleon Ultra. On by default, because it is also how screenshots and
/// manual QA happen with no hardware attached.
@Riverpod(keepAlive: true)
class EmulatorMode extends _$EmulatorMode {
  @override
  bool build() => true;

  void setEnabled(bool enabled) => state = enabled;
}

/// The platform's scanners, plus the SDK's [FakeScanner] in emulator mode
/// (spec 8.2: a plain list, no registry).
@Riverpod(keepAlive: true)
List<DeviceScanner> scanners(Ref ref) => ChameleonTransports.defaultScanners(
      emulator: ref.watch(emulatorModeProvider),
    );
```

```dart
// app/lib/core/discovery/discovery_provider.dart
import 'package:chameleon/chameleon.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'discovery_merge.dart';
import 'scanners.dart';

part 'discovery_provider.g.dart';

/// Everything visible right now, merged across transports (spec 4.2).
@riverpod
Stream<DiscoveryState> discovery(Ref ref) =>
    DiscoveryMerge(ref.watch(scannersProvider)).stream();

/// Serial ports the user typed in by hand, for the desktop fallback when
/// enumeration finds nothing (spec 5.2). They are ordinary usb entries, so
/// the rest of the app does not know the difference.
@Riverpod(keepAlive: true)
class ManualPorts extends _$ManualPorts {
  @override
  List<DiscoveredDevice> build() => const <DiscoveredDevice>[];

  void add(String path) {
    if (path.trim().isEmpty) return;
    final device = DiscoveredDevice(
      name: path,
      kind: TransportKind.usb,
      transportId: path.trim(),
    );
    if (state.contains(device)) return;
    state = <DiscoveredDevice>[...state, device];
  }

  void remove(String path) => state = <DiscoveredDevice>[
        for (final d in state)
          if (d.transportId != path) d,
      ];
}
```

```bash
cd app && dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 5: Run the tests**

```bash
cd app && flutter test test/core/discovery
```

Expected: PASS, 7 tests.

- [ ] **Step 6: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git add app
git commit -m "feat(app): merge scanner results and add emulator mode

Spec 4.2 runs every scanner at once and merges the results; a scanner that
fails reports its error without taking the others down, which is how the
connect screen shows a permission or adapter step (spec 5.1). Emulator mode
is one extra scanner in the same list (spec 7.5).

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 9: Routing rules — the path table and the pure redirect function

**Files:**
- Create: `app/lib/core/routing/routes.dart`, `app/lib/core/routing/redirect.dart`
- Modify: `app/lib/l10n/app_en.arb`
- Test: `app/test/core/routing/redirect_test.dart`

**Interfaces:**
- Consumes: `ConnectionState` and its variants from `package:chameleon/chameleon.dart`.
- Produces (Task 10 consumes all of it; the `AppSection`, `ShellScaffold` and `routerProvider` declarations below are Task 10's and are repeated there):

```dart
// package:spectra/core/routing/routes.dart
abstract final class AppRoutes {
  static const String connect  = '/connect';
  static const String device   = '/device';
  static const String slots    = '/slots';
  static const String cards    = '/cards';
  static const String tools    = '/tools';
  static const String frameLog = '/tools/frame-log';
  static const String update   = '/tools/update';
  static const String settings = '/settings';
  /// The bootloader recovery entry (spec 5.5): `/tools/update?recover=<id>`.
  static String recover(String transportId);
}

// package:spectra/core/routing/redirect.dart
/// The whole of spec 7.2 as one pure function, so routing is unit-tested
/// without a widget tree. Returns the location to go to, or null to stay.
String? redirectFor({required ConnectionState state, required String location});

// package:spectra/core/routing/app_sections.dart
final class AppSection {
  const AppSection({
    required this.path,
    required this.label,
    required this.icon,
    required this.builder,
    this.selectedIcon,
    this.subRoutes = const <RouteBase>[],
  });
  final String path;
  final String Function(AppLocalizations l10n) label;
  final IconData icon;
  final IconData? selectedIcon;
  final Widget Function(BuildContext context, GoRouterState state) builder;
  final List<RouteBase> subRoutes;
}
/// Spec 8.2: the shell is assembled from two plain lists. This is one of
/// them; the destinations are derived from it.
final List<AppSection> appSections;

// package:spectra/core/routing/router.dart
@Riverpod(keepAlive: true) GoRouter router(Ref ref);   // routerProvider

// package:spectra/core/routing/shell_scaffold.dart
class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({required StatefulNavigationShell navigationShell, super.key});
}
```

- [ ] **Step 1: Write the failing test**

```dart
// app/test/core/routing/redirect_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/routing/redirect.dart';
import 'package:spectra/core/routing/routes.dart';

const disconnected = SessionDisconnected(DisconnectCause.requested);
const connecting = SessionConnecting();
const limited = SessionLimited(UnsupportedReason.preTwoPointZero);
const updating = SessionUpdating();

SessionReady ready() => SessionReady(
      const DeviceInfo(
        model: DeviceModel.ultra,
        version: FirmwareVersion(major: 2, minor: 2),
        capabilities: Capabilities(<int>{}),
      ),
    );

void main() {
  test('no session sends every route to connect', () {
    for (final location in <String>[
      AppRoutes.device,
      AppRoutes.slots,
      AppRoutes.tools,
      AppRoutes.settings,
    ]) {
      expect(redirectFor(state: disconnected, location: location),
          AppRoutes.connect, reason: location);
    }
    expect(redirectFor(state: disconnected, location: AppRoutes.connect),
        isNull);
  });

  test('connecting stays on the connect screen', () {
    expect(redirectFor(state: connecting, location: AppRoutes.connect), isNull);
    expect(redirectFor(state: connecting, location: AppRoutes.device),
        AppRoutes.connect);
  });

  test('ready leaves the connect screen for the dashboard', () {
    expect(redirectFor(state: ready(), location: AppRoutes.connect),
        AppRoutes.device);
    expect(redirectFor(state: ready(), location: AppRoutes.slots), isNull);
    expect(redirectFor(state: ready(), location: AppRoutes.frameLog), isNull);
  });

  test('limited allows only the dashboard and the update route', () {
    expect(redirectFor(state: limited, location: AppRoutes.device), isNull);
    expect(redirectFor(state: limited, location: AppRoutes.update), isNull);
    expect(redirectFor(state: limited, location: AppRoutes.slots),
        AppRoutes.device);
    expect(redirectFor(state: limited, location: AppRoutes.connect),
        AppRoutes.device);
  });

  test('updating locks navigation on the update screen', () {
    for (final location in <String>[
      AppRoutes.connect,
      AppRoutes.device,
      AppRoutes.slots,
      AppRoutes.frameLog,
    ]) {
      expect(redirectFor(state: updating, location: location), AppRoutes.update,
          reason: location);
    }
    expect(redirectFor(state: updating, location: AppRoutes.update), isNull);
  });

  test('the recovery entry carries the transport id', () {
    expect(AppRoutes.recover('/dev/cu.usbmodem1'),
        '/tools/update?recover=%2Fdev%2Fcu.usbmodem1');
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd app && flutter test test/core/routing/redirect_test.dart
```

Expected: FAIL — `routes.dart` and `redirect.dart` do not exist.

- [ ] **Step 3: Write the routes and the rule**

```dart
// app/lib/core/routing/routes.dart
/// Every location in the app, in one place, so no screen types a path.
abstract final class AppRoutes {
  static const String connect = '/connect';
  static const String device = '/device';
  static const String slots = '/slots';
  static const String cards = '/cards';
  static const String tools = '/tools';
  static const String frameLog = '/tools/frame-log';
  static const String update = '/tools/update';
  static const String settings = '/settings';

  /// The bootloader recovery entry (spec 5.5): the update screen, told which
  /// bootloader to talk to. Phase 8 reads the `recover` query parameter.
  static String recover(String transportId) =>
      '$update?recover=${Uri.encodeComponent(transportId)}';
}
```

```dart
// app/lib/core/routing/redirect.dart
import 'package:chameleon/chameleon.dart';

import 'routes.dart';

/// Spec 7.2, whole: routing is driven by the connection state. Pure, so the
/// rule is tested without a widget tree and go_router only has to call it.
///
/// Returns the location to go to, or null to stay where we are.
String? redirectFor({
  required ConnectionState state,
  required String location,
}) {
  switch (state) {
    case SessionUpdating():
      // A running update locks navigation: the device is mid-flash and every
      // other screen would be lying about it.
      return location == AppRoutes.update ? null : AppRoutes.update;
    case SessionLimited():
      // Only a firmware update is possible, so only the reduced dashboard and
      // the update screen are reachable.
      final allowed =
          location == AppRoutes.device || location == AppRoutes.update;
      return allowed ? null : AppRoutes.device;
    case SessionConnecting():
    case SessionDisconnected():
      return location == AppRoutes.connect ? null : AppRoutes.connect;
    case SessionReady():
      return location == AppRoutes.connect ? AppRoutes.device : null;
  }
}
```

- [ ] **Step 4: Run the test**

```bash
cd app && flutter test test/core/routing/redirect_test.dart
```

Expected: PASS, 6 tests.

- [ ] **Step 5: Add the navigation strings**

Append to `app/lib/l10n/app_en.arb`:

```json
  "navDevice": "Device",
  "@navDevice": {"description": "Top-level destination: the device dashboard."},
  "navSlots": "Slots",
  "@navSlots": {"description": "Top-level destination: emulation slots."},
  "navCards": "Cards",
  "@navCards": {"description": "Top-level destination: the saved card library."},
  "navTools": "Tools",
  "@navTools": {"description": "Top-level destination: update, dictionaries, frame log."},
  "navSettings": "Settings",
  "@navSettings": {"description": "Top-level destination: app and device settings."}
```

Regenerate: `cd app && flutter gen-l10n`.

- [ ] **Step 6: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git add app
git commit -m "feat(app): route on connectionState with a pure redirect rule

Spec 7.2 makes routing a function of the session state. Keeping it a pure
function means the whole rule -- connect, reduced dashboard, locked update --
is unit-tested with no widget tree, and go_router only has to call it.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 10: The shell — placeholder pages, the section list, the router and the app root

**Files:**
- Create: `app/lib/core/routing/app_sections.dart`, `app/lib/core/routing/router.dart`, `app/lib/core/routing/shell_scaffold.dart`
- Create (generated, committed): `app/lib/core/routing/router.g.dart`
- Create: `app/lib/features/slots/slots.dart`, `app/lib/features/slots/ui/slots_page.dart`, `app/lib/features/cards/cards.dart`, `app/lib/features/cards/ui/cards_page.dart`, `app/lib/features/settings/settings.dart`, `app/lib/features/settings/ui/settings_page.dart`, `app/lib/features/dashboard/dashboard.dart`, `app/lib/features/dashboard/ui/dashboard_page.dart`, `app/lib/features/tools/tools.dart`, `app/lib/features/tools/ui/tools_page.dart`, `app/lib/features/tools/ui/frame_log_page.dart`, `app/lib/features/tools/ui/update_page.dart`, `app/lib/features/connect/connect.dart`, `app/lib/features/connect/ui/connect_page.dart`
- Create: `app/test/support/app_harness.dart`
- Modify: `app/lib/app.dart`, `app/lib/l10n/app_en.arb`, `app/test/app_test.dart`
- Test: `app/test/core/routing/router_test.dart`

**Interfaces:**
- Consumes: `AppRoutes`, `redirectFor` (Task 9); `connectionStatusProvider` (Task 7); `sessionsProvider`, `transportFactoryProvider`, `activeDeviceProvider` (Task 6); `databaseProvider`, `knownDevicesRepositoryProvider` (Task 3); `SpectraApp`, `SpectraAppShell`, `SpectraDestination`, `SpectraSectionHeader`, `SpectraCard` from `package:spectra_ui/spectra_ui.dart`.
- Produces:

```dart
// package:spectra/core/routing/app_sections.dart
final class AppSection {
  const AppSection({
    required this.path,
    required this.label,
    required this.icon,
    required this.builder,
    this.selectedIcon,
    this.subRoutes = const <RouteBase>[],
  });
  final String path;
  final String Function(AppLocalizations l10n) label;
  final IconData icon;
  final IconData? selectedIcon;
  final Widget Function(BuildContext context, GoRouterState state) builder;
  final List<RouteBase> subRoutes;
}
final List<AppSection> appSections;   // Device, Slots, Cards, Tools, Settings

// package:spectra/core/routing/shell_scaffold.dart
class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({required StatefulNavigationShell navigationShell, super.key});
}

// package:spectra/core/routing/router.dart
final class RouterRefresh extends ChangeNotifier { RouterRefresh(Ref ref); }
@Riverpod(keepAlive: true) GoRouter router(Ref ref);   // routerProvider

// the six pages, each exported from its feature barrel
class ConnectPage extends ConsumerWidget { const ConnectPage({super.key}); }
class DashboardPage extends ConsumerWidget { const DashboardPage({super.key}); }
class SlotsPage extends StatelessWidget { const SlotsPage({super.key}); }
class CardsPage extends StatelessWidget { const CardsPage({super.key}); }
class ToolsPage extends StatelessWidget { const ToolsPage({super.key}); }
class SettingsPage extends StatelessWidget { const SettingsPage({super.key}); }
class FrameLogPage extends ConsumerWidget { const FrameLogPage({super.key}); }
class UpdatePage extends ConsumerWidget {
  const UpdatePage({String? recoverTransportId, super.key});
}

// package:spectra/app.dart
class SpectraRoot extends ConsumerWidget { const SpectraRoot({super.key}); }

// app/test/support/app_harness.dart  (test-only)
/// The overrides every widget test and the gate flow use: an in-memory
/// database and a transport factory that hands out [device].
List<Override> appOverrides({Transport Function(DiscoveredDevice)? transport});
Widget testApp({Transport Function(DiscoveredDevice)? transport});
```

`ConnectPage`, `DashboardPage`, `FrameLogPage` and `UpdatePage` are written as placeholders here and filled in by Tasks 14, 15 and 16. `SlotsPage`, `CardsPage` and `SettingsPage` stay placeholders for the whole phase (Phases 5, 6 and 9 fill them).

- [ ] **Step 1: Write the failing test**

```dart
// app/test/core/routing/router_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/routing/app_sections.dart';
import 'package:spectra/core/routing/routes.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

void main() {
  test('there are five top-level sections, in spec 7.2 order', () {
    expect(
      appSections.map((s) => s.path).toList(),
      <String>[
        AppRoutes.device,
        AppRoutes.slots,
        AppRoutes.cards,
        AppRoutes.tools,
        AppRoutes.settings,
      ],
    );
  });

  testWidgets('the app opens on the connect screen with no session',
      (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pump();
    expect(find.text('Connect a device'), findsOneWidget);
    expect(find.byType(SpectraAppShell), findsNothing);
  });

  testWidgets('connecting to the emulated device shows the shell',
      (tester) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await tester.pump();

    await connectToEmulator(tester);

    expect(find.byType(SpectraAppShell), findsOneWidget);
    expect(find.text('Device'), findsWidgets);
  });

  testWidgets('the shell switches tabs without leaving the shell',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await tester.pump();
    await connectToEmulator(tester);

    await tester.tap(find.text('Slots').last);
    await tester.pump();
    await tester.pump();

    expect(find.byType(SpectraAppShell), findsOneWidget);
    expect(find.textContaining('Phase 5'), findsOneWidget);
  });
}
```

`connectToEmulator` lives in the harness (Step 3) so every later screen test reuses it.

- [ ] **Step 2: Run it and watch it fail**

```bash
cd app && flutter test test/core/routing/router_test.dart
```

Expected: FAIL — `app_sections.dart` and the harness do not exist.

- [ ] **Step 3: Write the placeholder pages**

Add the placeholder strings to `app/lib/l10n/app_en.arb`:

```json
  "connectTitle": "Connect a device",
  "@connectTitle": {"description": "Heading of the full-screen connect route."},
  "comingSoonSlots": "Slot management arrives in Phase 5.",
  "@comingSoonSlots": {"description": "Placeholder body of the Slots tab."},
  "comingSoonCards": "The card library arrives in Phase 6.",
  "@comingSoonCards": {"description": "Placeholder body of the Cards tab."},
  "comingSoonSettings": "Settings arrive in Phase 9.",
  "@comingSoonSettings": {"description": "Placeholder body of the Settings tab."},
  "comingSoonUpdate": "Firmware update arrives in Phase 8.",
  "@comingSoonUpdate": {"description": "Placeholder body of the update screen."},
  "toolsTitle": "Tools",
  "@toolsTitle": {"description": "Heading of the Tools tab."},
  "toolsFrameLog": "Frame log",
  "@toolsFrameLog": {"description": "Tools entry opening the frame log."},
  "toolsFrameLogSubtitle": "Everything sent to and received from the device.",
  "@toolsFrameLogSubtitle": {"description": "Explains what the frame log is."},
  "toolsUpdate": "Firmware update",
  "@toolsUpdate": {"description": "Tools entry opening the firmware update screen."},
  "frameLogTitle": "Frame log",
  "@frameLogTitle": {"description": "Heading of the frame log screen."},
  "updateTitle": "Firmware update",
  "@updateTitle": {"description": "Heading of the firmware update screen."},
  "dashboardTitle": "Device",
  "@dashboardTitle": {"description": "Heading of the device dashboard."}
```

Regenerate: `cd app && flutter gen-l10n`.

Each placeholder page follows the same shape. `slots_page.dart`:

```dart
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../l10n/app_localizations.dart';

/// Placeholder until Phase 5 builds the slot grid.
class SlotsPage extends StatelessWidget {
  const SlotsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(SpectraSpacing.lg),
      children: <Widget>[
        SpectraSectionHeader(title: l10n.navSlots),
        SpectraCard(child: Text(l10n.comingSoonSlots)),
      ],
    );
  }
}
```

Write `cards_page.dart` and `settings_page.dart` identically with `navCards`/`comingSoonCards` and `navSettings`/`comingSoonSettings`.

`tools_page.dart` — a real list from the start, because Task 16 only fills in the pages behind it:

```dart
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/routing/routes.dart';
import '../../../l10n/app_localizations.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(SpectraSpacing.lg),
      children: <Widget>[
        SpectraSectionHeader(title: l10n.toolsTitle),
        SpectraListTile(
          title: l10n.toolsFrameLog,
          subtitle: l10n.toolsFrameLogSubtitle,
          leading: const Icon(Icons.receipt_long_outlined),
          onTap: () => GoRouter.of(context).go(AppRoutes.frameLog),
        ),
        SpectraListTile(
          title: l10n.toolsUpdate,
          leading: const Icon(Icons.system_update_alt),
          onTap: () => GoRouter.of(context).go(AppRoutes.update),
        ),
      ],
    );
  }
}
```

`frame_log_page.dart`, `update_page.dart`, `dashboard_page.dart` and `connect_page.dart` are placeholders of the same shape for now — a `SpectraSectionHeader` with the screen's title (`frameLogTitle`, `updateTitle`, `dashboardTitle`, `connectTitle`) and, for `update_page.dart`, `comingSoonUpdate`. `UpdatePage` already takes and stores `recoverTransportId`; Task 16 uses it.

Each barrel exports only the feature's public surface (spec 8.3):

```dart
// app/lib/features/tools/tools.dart
/// The Tools feature's public API: its screens. Nothing else in the app may
/// import `features/tools/…` directly (spec 8.3).
library;

export 'ui/frame_log_page.dart';
export 'ui/tools_page.dart';
export 'ui/update_page.dart';
```

Write the other five barrels the same way.

- [ ] **Step 4: Write the section list, the shell and the router**

The section builders point at the pages Step 3 just created.

```dart
// app/lib/core/routing/app_sections.dart
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/cards/cards.dart';
import '../../features/dashboard/dashboard.dart';
import '../../features/settings/settings.dart';
import '../../features/slots/slots.dart';
import '../../features/tools/tools.dart';
import '../../l10n/app_localizations.dart';
import 'routes.dart';

/// One top-level destination and the routes behind it. Spec 8.2: the shell
/// is assembled from two plain lists — this one, and the destinations
/// derived from it. Adding a feature is one entry here.
final class AppSection {
  const AppSection({
    required this.path,
    required this.label,
    required this.icon,
    required this.builder,
    this.selectedIcon,
    this.subRoutes = const <RouteBase>[],
  });

  final String path;
  final String Function(AppLocalizations l10n) label;
  final IconData icon;
  final IconData? selectedIcon;
  final Widget Function(BuildContext context, GoRouterState state) builder;

  /// Deep routes that push on top of this tab (spec 7.2).
  final List<RouteBase> subRoutes;
}

final List<AppSection> appSections = <AppSection>[
  AppSection(
    path: AppRoutes.device,
    label: (l10n) => l10n.navDevice,
    icon: Icons.memory_outlined,
    selectedIcon: Icons.memory,
    builder: (context, state) => const DashboardPage(),
  ),
  AppSection(
    path: AppRoutes.slots,
    label: (l10n) => l10n.navSlots,
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    builder: (context, state) => const SlotsPage(),
  ),
  AppSection(
    path: AppRoutes.cards,
    label: (l10n) => l10n.navCards,
    icon: Icons.style_outlined,
    selectedIcon: Icons.style,
    builder: (context, state) => const CardsPage(),
  ),
  AppSection(
    path: AppRoutes.tools,
    label: (l10n) => l10n.navTools,
    icon: Icons.build_outlined,
    selectedIcon: Icons.build,
    builder: (context, state) => const ToolsPage(),
    subRoutes: <RouteBase>[
      GoRoute(
        path: 'frame-log',
        builder: (context, state) => const FrameLogPage(),
      ),
      GoRoute(
        path: 'update',
        builder: (context, state) => UpdatePage(
          recoverTransportId: state.uri.queryParameters['recover'],
        ),
      ),
    ],
  ),
  AppSection(
    path: AppRoutes.settings,
    label: (l10n) => l10n.navSettings,
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    builder: (context, state) => const SettingsPage(),
  ),
];
```

```dart
// app/lib/core/routing/shell_scaffold.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../l10n/app_localizations.dart';
import 'app_sections.dart';

/// The adaptive frame around every tab. Layout only: which branch is showing
/// is go_router's business, and the destinations come from [appSections].
class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SpectraAppShell(
      destinations: <SpectraDestination>[
        for (final AppSection section in appSections)
          SpectraDestination(
            label: section.label(l10n),
            icon: section.icon,
            selectedIcon: section.selectedIcon,
          ),
      ],
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (int index) =>
          navigationShell.goBranch(index, initialLocation: false),
      title: appSections[navigationShell.currentIndex].label(l10n),
      child: navigationShell,
    );
  }
}
```

```dart
// app/lib/core/routing/router.dart
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/connect/connect.dart';
import '../session/session_streams.dart';
import 'app_sections.dart';
import 'redirect.dart';
import 'routes.dart';
import 'shell_scaffold.dart';

part 'router.g.dart';

/// Wakes go_router whenever the connection state changes, so [redirectFor]
/// runs again (spec 7.2).
final class RouterRefresh extends ChangeNotifier {
  RouterRefresh(Ref ref) {
    ref.listen(connectionStatusProvider, (_, __) => notifyListeners());
  }
}

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final refresh = RouterRefresh(ref);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: AppRoutes.connect,
    refreshListenable: refresh,
    redirect: (context, state) => redirectFor(
      state: ref.read(connectionStatusProvider),
      location: state.uri.path,
    ),
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.connect,
        builder: (context, state) => const ConnectPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScaffold(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          for (final AppSection section in appSections)
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: section.path,
                  builder: section.builder,
                  routes: section.subRoutes,
                ),
              ],
            ),
        ],
      ),
    ],
  );
}
```

```bash
cd app && dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 5: Wire the app root**

```dart
// app/lib/app.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spectra_ui/spectra_ui.dart';

import 'core/routing/router.dart';
import 'l10n/app_localizations.dart';

/// The application root: the design system's app widget, driven by
/// `routerProvider`. Task 11 wraps this in the lifecycle host.
class SpectraRoot extends ConsumerWidget {
  const SpectraRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SpectraApp(
      routerConfig: ref.watch(routerProvider),
      extraDelegates: const <LocalizationsDelegate<Object?>>[
        AppLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
```

`SpectraApp`'s `title` defaults to `'Spectra'`, which is what `appTitle` says; leave it.

- [ ] **Step 6: Write the test harness**

```dart
// app/test/support/app_harness.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/app.dart';
import 'package:spectra/core/discovery/scanners.dart';
import 'package:spectra/core/session/sessions.dart';
import 'package:spectra/data/database/database_providers.dart';
import 'package:spectra/data/database/spectra_database.dart';

/// The overrides every widget test uses. Spec 7.1: overrides live at the app
/// root only — this is that root. The database is real Drift, in memory, so
/// the real queries run; the transport is a FakeDevice, so the real
/// DeviceSession runs (spec 8.6).
List<Override> appOverrides({Transport Function(DiscoveredDevice)? transport}) {
  final db = SpectraDatabase.memory();
  addTearDown(db.close);
  return <Override>[
    databaseProvider.overrideWithValue(db),
    scannersProvider.overrideWithValue(<DeviceScanner>[FakeScanner()]),
    if (transport != null)
      transportFactoryProvider.overrideWithValue(transport),
  ];
}

Widget testApp({Transport Function(DiscoveredDevice)? transport}) =>
    ProviderScope(
      overrides: appOverrides(transport: transport),
      child: const SpectraRoot(),
    );

/// Taps the emulated device on the connect screen and waits for the shell.
/// The fake answers immediately, so a bounded pump loop is enough and
/// `pumpAndSettle` is avoided (the shell has running animations).
Future<void> connectToEmulator(WidgetTester tester) async {
  await tester.pump();
  await tester.tap(find.text(FakeScanner.emulatedUltra.name));
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
```

- [ ] **Step 7: Run the tests**

```bash
cd app && dart run build_runner build --delete-conflicting-outputs && flutter test
```

Expected: PASS. `router_test.dart` contributes 4 tests. If `connectToEmulator` cannot find the device name, the placeholder `ConnectPage` from Step 3 is not listing anything yet — give it the minimal list now:

```dart
// app/lib/features/connect/ui/connect_page.dart — placeholder body
    final AsyncValue<DiscoveryState> discovery = ref.watch(discoveryProvider);
    …
        for (final DiscoveredDevice device
            in discovery.valueOrNull?.devices ?? const <DiscoveredDevice>[])
          SpectraListTile(
            title: device.name,
            onTap: () async {
              final identity =
                  await ref.read(sessionsProvider.notifier).connect(device);
              ref.read(activeDeviceProvider.notifier).select(identity);
            },
          ),
```

Task 14 replaces this whole page with the merged, badge-carrying version.

- [ ] **Step 8: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart format . && dart analyze --fatal-infos . && dart run tool/dep_lint.dart
git add app
git commit -m "feat(app): boot the adaptive shell and the five destinations

Spec 8.2 assembles the shell from two plain lists, so a feature is one
AppSection entry. The app now starts on the connect route, connects to the
emulated device and lands on the dashboard tab.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 11: Lifecycle — the 30 second grace period and the one silent reconnect

**Files:**
- Create: `app/lib/core/lifecycle/lifecycle_controller.dart`, `app/lib/core/lifecycle/lifecycle_host.dart`
- Create (generated, committed): `app/lib/core/lifecycle/lifecycle_host.g.dart`
- Modify: `app/lib/app.dart`
- Test: `app/test/core/lifecycle/lifecycle_controller_test.dart`

**Interfaces:**
- Consumes: `sessionsProvider`, `activeDeviceProvider`, `SessionsState` (Task 6); `knownDevicesRepositoryProvider`, `KnownDevice` (Task 3); `discoveryProvider` (Task 8).
- Produces:

```dart
// package:spectra/core/lifecycle/lifecycle_controller.dart
/// Spec 7.4, as a plain object with injected effects so it is unit-tested
/// with no binding, no widgets and no real clock.
final class LifecycleController {
  LifecycleController({
    required Future<void> Function() closeSessions,
    required Future<void> Function() reconnectLast,
    required bool Function() hasSession,
    Duration grace = const Duration(seconds: 30),
  });
  static const Duration defaultGrace = Duration(seconds: 30);
  void onPaused();
  Future<void> onResumed();
  void dispose();
}

// package:spectra/core/lifecycle/lifecycle_host.dart
@Riverpod(keepAlive: true) LifecycleController lifecycleController(Ref ref);
/// Forwards the platform's lifecycle events to [LifecycleController]. Layout
/// does nothing: it just wraps [child].
class AppLifecycleHost extends ConsumerStatefulWidget {
  const AppLifecycleHost({required Widget child, super.key});
}
```

- [ ] **Step 1: Write the failing test**

```dart
// app/test/core/lifecycle/lifecycle_controller_test.dart
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/lifecycle/lifecycle_controller.dart';

void main() {
  test('pausing closes the session after the grace period', () {
    fakeAsync((async) {
      var closed = 0;
      final controller = LifecycleController(
        closeSessions: () async => closed++,
        reconnectLast: () async {},
        hasSession: () => true,
        grace: const Duration(seconds: 30),
      );

      controller.onPaused();
      async.elapse(const Duration(seconds: 29));
      expect(closed, 0);
      async.elapse(const Duration(seconds: 2));
      expect(closed, 1);
      controller.dispose();
    });
  });

  test('resuming inside the grace period keeps the session', () {
    fakeAsync((async) {
      var closed = 0;
      var reconnects = 0;
      final controller = LifecycleController(
        closeSessions: () async => closed++,
        reconnectLast: () async => reconnects++,
        hasSession: () => true,
      );

      controller.onPaused();
      async.elapse(const Duration(seconds: 5));
      controller.onResumed();
      async.elapse(const Duration(minutes: 1));

      expect(closed, 0);
      expect(reconnects, 0, reason: 'the session was never closed');
      controller.dispose();
    });
  });

  test('resuming after the grace period reconnects once', () {
    fakeAsync((async) {
      var reconnects = 0;
      final controller = LifecycleController(
        closeSessions: () async {},
        reconnectLast: () async => reconnects++,
        hasSession: () => false,
      );

      controller.onPaused();
      async.elapse(const Duration(seconds: 31));
      controller.onResumed();
      async.flushMicrotasks();
      controller.onResumed();
      async.flushMicrotasks();

      expect(reconnects, 1, reason: 'one silent attempt, not one per resume');
      controller.dispose();
    });
  });

  test('a failed reconnect is swallowed', () {
    fakeAsync((async) {
      final controller = LifecycleController(
        closeSessions: () async {},
        reconnectLast: () async => throw StateError('no device'),
        hasSession: () => false,
      );
      controller.onPaused();
      async.elapse(const Duration(seconds: 31));
      expect(controller.onResumed, returnsNormally);
      async.flushMicrotasks();
      controller.dispose();
    });
  });
}
```

Add `fake_async` to `app`'s dev dependencies if it is not already transitively available as a direct import: `cd app && flutter pub add dev:fake_async`. It is already on `tool/src/dep_rules.dart`'s `testOnly` list.

- [ ] **Step 2: Run it and watch it fail**

```bash
cd app && flutter test test/core/lifecycle/lifecycle_controller_test.dart
```

Expected: FAIL — `lifecycle_controller.dart` does not exist.

- [ ] **Step 3: Write the controller**

```dart
// app/lib/core/lifecycle/lifecycle_controller.dart
import 'dart:async';

/// Spec 7.4. Backgrounding does not drop the link straight away — switching
/// apps for five seconds is not a disconnect — but a session cannot be held
/// open for ever either, so it is closed after [defaultGrace]. On the way
/// back, exactly one silent reconnect is attempted, and only if the grace
/// period actually expired.
///
/// Every effect is injected, so this is unit-tested with no binding and no
/// real clock.
final class LifecycleController {
  LifecycleController({
    required Future<void> Function() closeSessions,
    required Future<void> Function() reconnectLast,
    required bool Function() hasSession,
    this.grace = defaultGrace,
  })  : _closeSessions = closeSessions,
        _reconnectLast = reconnectLast,
        _hasSession = hasSession;

  static const Duration defaultGrace = Duration(seconds: 30);

  final Future<void> Function() _closeSessions;
  final Future<void> Function() _reconnectLast;
  final bool Function() _hasSession;
  final Duration grace;

  Timer? _timer;
  bool _closedWhilePaused = false;
  bool _reconnecting = false;

  void onPaused() {
    _timer?.cancel();
    _timer = Timer(grace, () async {
      _closedWhilePaused = true;
      await _closeSessions();
    });
  }

  Future<void> onResumed() async {
    _timer?.cancel();
    _timer = null;
    if (!_closedWhilePaused || _reconnecting || _hasSession()) return;
    _closedWhilePaused = false;
    _reconnecting = true;
    try {
      await _reconnectLast();
    } on Object {
      // One silent attempt (spec 7.4). A failure is not worth a dialog: the
      // connect screen is already what the user is looking at.
    } finally {
      _reconnecting = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
```

- [ ] **Step 4: Write the host and its provider**

```dart
// app/lib/core/lifecycle/lifecycle_host.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/database/database_providers.dart';
import '../discovery/discovery_provider.dart';
import '../session/active_device.dart';
import '../session/sessions.dart';
import 'lifecycle_controller.dart';

part 'lifecycle_host.g.dart';

@Riverpod(keepAlive: true)
LifecycleController lifecycleController(Ref ref) {
  final controller = LifecycleController(
    closeSessions: () => ref.read(sessionsProvider.notifier).disconnectAll(),
    hasSession: () => ref.read(sessionsProvider).sessions.isNotEmpty,
    reconnectLast: () async {
      final known = await ref.read(knownDevicesRepositoryProvider).lastSeen();
      if (known == null) return;
      final discovery = await ref.read(discoveryProvider.future);
      final device = discovery.devices.where(known.matches).firstOrNull;
      if (device == null) return;
      final identity =
          await ref.read(sessionsProvider.notifier).connect(device);
      ref.read(activeDeviceProvider.notifier).select(identity);
    },
  );
  ref.onDispose(controller.dispose);
  return controller;
}

/// Turns the platform's lifecycle callbacks into [LifecycleController] calls.
/// Contributes no layout of its own.
class AppLifecycleHost extends ConsumerStatefulWidget {
  const AppLifecycleHost({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<AppLifecycleHost> createState() => _AppLifecycleHostState();
}

class _AppLifecycleHostState extends ConsumerState<AppLifecycleHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(lifecycleControllerProvider);
    switch (state) {
      case AppLifecycleState.paused:
        controller.onPaused();
      case AppLifecycleState.resumed:
        unawaited(controller.onResumed());
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
```

Add `import 'dart:async';` for `unawaited`. Then wrap the root in `app/lib/app.dart`:

```dart
    return AppLifecycleHost(
      child: SpectraApp(
        routerConfig: ref.watch(routerProvider),
        extraDelegates: const <LocalizationsDelegate<Object?>>[
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
```

```bash
cd app && dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 5: Run the tests**

```bash
cd app && flutter test
```

Expected: PASS, including the 4 new lifecycle tests.

- [ ] **Step 6: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git add app
git commit -m "feat(app): keep a backgrounded session for 30 seconds, then close it

Spec 7.4. Switching apps briefly is not a disconnect, so the session is held
through a grace period and closed after it; coming back attempts exactly one
silent reconnect to the last identity. The rule is a plain object with
injected effects, so it is tested with fake_async and no binding.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 12: The wakelock, held during reader leases and long operations

**Files:**
- Create: `app/lib/core/lifecycle/wakelock.dart`
- Create (generated, committed): `app/lib/core/lifecycle/wakelock.g.dart`
- Modify: `app/lib/app.dart`
- Test: `app/test/core/lifecycle/wakelock_test.dart`

**Interfaces:**
- Consumes: `activeSessionProvider` (Task 6); `SessionPolling`'s `readerLeaseCount` and `isBusy` extension getters, `SessionUpdating`, `FakeDevice`, `DeviceSession` from `package:chameleon/chameleon.dart`; `WakelockPlus` from `package:wakelock_plus/wakelock_plus.dart`.
- Produces:

```dart
// package:spectra/core/lifecycle/wakelock.dart
abstract interface class WakelockGateway {
  Future<void> enable();
  Future<void> disable();
}
final class WakelockPlusGateway implements WakelockGateway { const WakelockPlusGateway(); }

/// Spec 7.4: the app holds a wakelock during a flash or a reader lease.
final class WakelockController {
  WakelockController({
    required WakelockGateway gateway,
    required bool Function() shouldHold,
    Duration interval = const Duration(seconds: 1),
  });
  bool get held;
  /// One evaluation. The timer calls this; tests call it directly.
  Future<void> poll();
  void start();
  void stop();
}

/// True while the active session holds a reader lease, is running a long
/// operation, or is updating.
bool sessionNeedsWakelock(DeviceSession? session, ConnectionState state);

@Riverpod(keepAlive: true) WakelockController wakelock(Ref ref);  // wakelockProvider
```

- [ ] **Step 1: Write the failing test**

```dart
// app/test/core/lifecycle/wakelock_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/lifecycle/wakelock.dart';

final class RecordingGateway implements WakelockGateway {
  final List<bool> calls = <bool>[];
  @override
  Future<void> enable() async => calls.add(true);
  @override
  Future<void> disable() async => calls.add(false);
}

void main() {
  test('holds while asked to and releases once when no longer asked',
      () async {
    var wanted = false;
    final gateway = RecordingGateway();
    final controller = WakelockController(
      gateway: gateway,
      shouldHold: () => wanted,
    );

    await controller.poll();
    expect(gateway.calls, isEmpty, reason: 'nothing to hold yet');

    wanted = true;
    await controller.poll();
    await controller.poll();
    expect(gateway.calls, <bool>[true], reason: 'enabled exactly once');
    expect(controller.held, isTrue);

    wanted = false;
    await controller.poll();
    await controller.poll();
    expect(gateway.calls, <bool>[true, false]);
    expect(controller.held, isFalse);
  });

  test('a reader lease asks for the wakelock', () async {
    final session = DeviceSession(FakeDevice());
    await session.open();

    expect(
      sessionNeedsWakelock(session, session.connectionState.value),
      isFalse,
    );

    final lease = await session.acquireReaderMode();
    expect(
      sessionNeedsWakelock(session, session.connectionState.value),
      isTrue,
    );
    await lease.release();
    expect(
      sessionNeedsWakelock(session, session.connectionState.value),
      isFalse,
    );

    await session.close();
  });

  test('an updating session asks for the wakelock', () {
    expect(sessionNeedsWakelock(null, const SessionUpdating()), isTrue);
  });

  test('no session asks for nothing', () {
    expect(
      sessionNeedsWakelock(
        null,
        const SessionDisconnected(DisconnectCause.requested),
      ),
      isFalse,
    );
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd app && flutter test test/core/lifecycle/wakelock_test.dart
```

Expected: FAIL — `wakelock.dart` does not exist.

- [ ] **Step 3: Write it**

```dart
// app/lib/core/lifecycle/wakelock.dart
import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../session/active_device.dart';
import '../session/session_streams.dart';

part 'wakelock.g.dart';

/// The seam over `wakelock_plus`, so the rule above it is testable with no
/// plugin channel (spec 8.6).
abstract interface class WakelockGateway {
  Future<void> enable();
  Future<void> disable();
}

final class WakelockPlusGateway implements WakelockGateway {
  const WakelockPlusGateway();

  @override
  Future<void> enable() => WakelockPlus.enable();

  @override
  Future<void> disable() => WakelockPlus.disable();
}

/// Spec 7.4: hold the screen awake during a flash or a reader lease. The
/// lease count and the busy depth are plain getters on the session with no
/// change notification, so this polls — which keeps the SDK free of a stream
/// nothing else would use.
bool sessionNeedsWakelock(DeviceSession? session, ConnectionState state) {
  if (state is SessionUpdating) return true;
  if (session == null) return false;
  return session.readerLeaseCount > 0 || session.isBusy;
}

final class WakelockController {
  WakelockController({
    required WakelockGateway gateway,
    required bool Function() shouldHold,
    this.interval = const Duration(seconds: 1),
  })  : _gateway = gateway,
        _shouldHold = shouldHold;

  final WakelockGateway _gateway;
  final bool Function() _shouldHold;
  final Duration interval;

  Timer? _timer;
  bool _held = false;

  bool get held => _held;

  /// One evaluation. Idempotent: the gateway is only touched on a change.
  Future<void> poll() async {
    final want = _shouldHold();
    if (want == _held) return;
    _held = want;
    await (want ? _gateway.enable() : _gateway.disable());
  }

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(poll()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    if (_held) {
      _held = false;
      unawaited(_gateway.disable());
    }
  }
}

@Riverpod(keepAlive: true)
WakelockController wakelock(Ref ref) {
  final controller = WakelockController(
    gateway: const WakelockPlusGateway(),
    shouldHold: () => sessionNeedsWakelock(
      ref.read(activeSessionProvider)?.session,
      ref.read(connectionStatusProvider),
    ),
  );
  controller.start();
  ref.onDispose(controller.stop);
  return controller;
}
```

Start it from the lifecycle host so it exists for the life of the app. In `_AppLifecycleHostState.initState`, after adding the observer:

```dart
    // Reading it once is enough: the provider is keepAlive and starts its own
    // timer. Deferred so the first frame is not blocked by a plugin call.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(wakelockProvider),
    );
```

```bash
cd app && dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 4: Run the tests**

```bash
cd app && flutter test test/core/lifecycle
```

Expected: PASS, 8 tests.

- [ ] **Step 5: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git add app
git commit -m "feat(app): hold a wakelock during leases, long operations and flashes

Spec 7.4. The SDK exposes the lease count and the busy depth as getters, not
streams, so this polls once a second rather than adding a notification the
SDK has no other use for. The plugin sits behind a gateway interface so the
rule is tested with no channel.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 13: The connect feature's state — identity merge and the connect controller

**Files:**
- Create: `app/lib/features/connect/state/connect_row.dart`, `app/lib/features/connect/state/connect_rows_provider.dart`, `app/lib/features/connect/state/connect_controller.dart`
- Create (generated, committed): `app/lib/features/connect/state/connect_rows_provider.g.dart`, `app/lib/features/connect/state/connect_controller.g.dart`
- Modify: `app/lib/features/connect/connect.dart`
- Test: `app/test/features/connect/connect_row_test.dart`, `app/test/features/connect/connect_controller_test.dart`

**Interfaces:**
- Consumes: `DiscoveredDevice`, `DeviceIdentity`, `TransportKind`, `FakeScanner`, `FakeDevice`, `PermissionDenied` from `package:chameleon/chameleon.dart`; `KnownDevice`, `KnownDevicesRepository` (Task 3); `discoveryProvider`, `manualPortsProvider` (Task 8); `sessionsProvider`, `activeDeviceProvider` (Task 6).
- Produces:

```dart
// package:spectra/features/connect/state/connect_row.dart
/// One device on the connect screen — possibly reachable over more than one
/// transport (spec 4.2).
final class ConnectRow {
  const ConnectRow({
    required this.key,
    required this.name,
    required this.devices,
    required this.isBootloader,
    this.identity,
    this.lastSeen,
  });
  final String key;
  final String name;
  final List<DiscoveredDevice> devices;
  final bool isBootloader;
  final DeviceIdentity? identity;
  final DateTime? lastSeen;
  bool get isKnown => identity != null;
  List<TransportKind> get kinds;
  /// The transport to connect over: usb first, because it is faster and
  /// needs no pairing.
  DiscoveredDevice get preferred;
}

/// Spec 4.2: merge discovered entries by identity when the identity is
/// known, otherwise by name plus transport kind. One row per device, with
/// transport badges. Pure, so the whole rule is unit-tested.
List<ConnectRow> mergeConnectRows({
  required List<DiscoveredDevice> discovered,
  required List<KnownDevice> known,
});

// package:spectra/features/connect/state/connect_rows_provider.dart
@riverpod List<ConnectRow> connectRows(Ref ref);      // connectRowsProvider
@riverpod Stream<List<KnownDevice>> knownDevices(Ref ref);  // knownDevicesProvider

// package:spectra/features/connect/state/connect_controller.dart
@riverpod
class ConnectController extends _$ConnectController {   // connectControllerProvider
  @override Future<void> build();
  /// Opens a session and makes it the active device. Failures land in
  /// `state.error` for the screen to render through the error catalog.
  Future<void> connect(DiscoveredDevice device);
  /// "Reconnect to last device" (spec 4.2). Does nothing when the last known
  /// device is not currently visible.
  Future<void> reconnectLast();
}
```

- [ ] **Step 1: Write the failing merge test**

```dart
// app/test/features/connect/connect_row_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/features/connect/connect.dart';

const usb = DiscoveredDevice(
  name: 'ChameleonUltra',
  kind: TransportKind.usb,
  transportId: '/dev/cu.usbmodem1',
);
const ble = DiscoveredDevice(
  name: 'ChameleonUltra_1234',
  kind: TransportKind.ble,
  transportId: 'AA:BB:CC',
);
const otherUsb = DiscoveredDevice(
  name: 'ChameleonUltra',
  kind: TransportKind.usb,
  transportId: '/dev/cu.usbmodem2',
);
const bootloader = DiscoveredDevice(
  name: 'CU',
  kind: TransportKind.usb,
  transportId: '/dev/cu.usbmodem3',
  isBootloader: true,
);

KnownDevice knownBoth() => KnownDevice(
      identity: const DeviceIdentity('chip-1'),
      displayName: 'My Ultra',
      transports: const <KnownTransport>[
        KnownTransport(kind: TransportKind.usb, transportId: '/dev/cu.usbmodem1'),
        KnownTransport(kind: TransportKind.ble, transportId: 'AA:BB:CC'),
      ],
      lastSeen: DateTime.utc(2026, 9, 3),
    );

void main() {
  test('an unknown device is one row per name and kind', () {
    final rows = mergeConnectRows(
      discovered: const <DiscoveredDevice>[usb, ble],
      known: const <KnownDevice>[],
    );
    expect(rows, hasLength(2));
    expect(rows.every((r) => r.isKnown), isFalse);
  });

  test('two unknown devices with the same name and kind share a row', () {
    final rows = mergeConnectRows(
      discovered: const <DiscoveredDevice>[usb, otherUsb],
      known: const <KnownDevice>[],
    );
    expect(rows, hasLength(1));
    expect(rows.single.devices, hasLength(2));
  });

  test('a known identity merges both transports into one row', () {
    final rows = mergeConnectRows(
      discovered: const <DiscoveredDevice>[usb, ble],
      known: <KnownDevice>[knownBoth()],
    );
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row.identity, const DeviceIdentity('chip-1'));
    expect(row.name, 'My Ultra', reason: 'the remembered name wins');
    expect(row.kinds, <TransportKind>[TransportKind.usb, TransportKind.ble]);
    expect(row.preferred.kind, TransportKind.usb);
    expect(row.lastSeen, DateTime.utc(2026, 9, 3));
  });

  test('a bootloader never merges with an application device', () {
    final rows = mergeConnectRows(
      discovered: const <DiscoveredDevice>[usb, bootloader],
      known: <KnownDevice>[knownBoth()],
    );
    expect(rows, hasLength(2));
    expect(rows.where((r) => r.isBootloader), hasLength(1));
  });

  test('known devices sort first, newest first', () {
    final rows = mergeConnectRows(
      discovered: const <DiscoveredDevice>[
        DiscoveredDevice(
          name: 'Unknown',
          kind: TransportKind.usb,
          transportId: 'x',
        ),
        usb,
      ],
      known: <KnownDevice>[knownBoth()],
    );
    expect(rows.first.isKnown, isTrue);
    expect(rows.last.name, 'Unknown');
  });

  test('the emulated device is an ordinary row', () {
    final rows = mergeConnectRows(
      discovered: const <DiscoveredDevice>[FakeScanner.emulatedUltra],
      known: const <KnownDevice>[],
    );
    expect(rows.single.name, 'Emulated Chameleon Ultra');
    expect(rows.single.kinds, <TransportKind>[TransportKind.fake]);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd app && flutter test test/features/connect/connect_row_test.dart
```

Expected: FAIL — `connect_row.dart` does not exist.

- [ ] **Step 3: Write the merge**

```dart
// app/lib/features/connect/state/connect_row.dart
import 'package:chameleon/chameleon.dart';

import '../../../data/data.dart';

/// One device on the connect screen. A device reachable over both USB and
/// BLE is one row with two transport badges (spec 4.2).
final class ConnectRow {
  const ConnectRow({
    required this.key,
    required this.name,
    required this.devices,
    required this.isBootloader,
    this.identity,
    this.lastSeen,
  });

  final String key;
  final String name;
  final List<DiscoveredDevice> devices;
  final bool isBootloader;
  final DeviceIdentity? identity;
  final DateTime? lastSeen;

  bool get isKnown => identity != null;

  List<TransportKind> get kinds =>
      devices.map((d) => d.kind).toSet().toList(growable: false);

  /// USB first: it is faster and needs no pairing. The fake comes last, so a
  /// real device is never shadowed by the emulator.
  DiscoveredDevice get preferred {
    for (final kind in const <TransportKind>[
      TransportKind.usb,
      TransportKind.ble,
      TransportKind.fake,
    ]) {
      final match = devices.where((d) => d.kind == kind).firstOrNull;
      if (match != null) return match;
    }
    return devices.first;
  }
}

/// Spec 4.2: entries merge by identity when the identity is known, and by
/// name plus transport kind otherwise. A device in the bootloader never
/// merges with an application device — it is a different thing to connect to
/// (spec 5.5).
List<ConnectRow> mergeConnectRows({
  required List<DiscoveredDevice> discovered,
  required List<KnownDevice> known,
}) {
  final groups = <String, List<DiscoveredDevice>>{};
  final identities = <String, KnownDevice>{};

  for (final device in discovered) {
    final match =
        device.isBootloader ? null : known.where((k) => k.matches(device)).firstOrNull;
    final key = match != null
        ? 'id:${match.identity.chipId}'
        : 'name:${device.name}|${device.kind.name}|${device.isBootloader}';
    groups.putIfAbsent(key, () => <DiscoveredDevice>[]).add(device);
    if (match != null) identities[key] = match;
  }

  final rows = <ConnectRow>[
    for (final entry in groups.entries)
      ConnectRow(
        key: entry.key,
        name: identities[entry.key]?.displayName ?? entry.value.first.name,
        devices: List<DiscoveredDevice>.unmodifiable(entry.value),
        isBootloader: entry.value.first.isBootloader,
        identity: identities[entry.key]?.identity,
        lastSeen: identities[entry.key]?.lastSeen,
      ),
  ];

  // Known devices first, newest first, then everything else by name — so
  // "the one I used yesterday" is always the top row.
  rows.sort((a, b) {
    if (a.isKnown != b.isKnown) return a.isKnown ? -1 : 1;
    if (a.isKnown && b.isKnown) return b.lastSeen!.compareTo(a.lastSeen!);
    return a.name.compareTo(b.name);
  });
  return List<ConnectRow>.unmodifiable(rows);
}
```

- [ ] **Step 4: Write the failing controller test**

```dart
// app/test/features/connect/connect_controller_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/discovery/scanners.dart';
import 'package:spectra/core/session/active_device.dart';
import 'package:spectra/core/session/session_streams.dart';
import 'package:spectra/core/session/sessions.dart';
import 'package:spectra/data/database/database_providers.dart';
import 'package:spectra/data/memory/in_memory_repositories.dart';
import 'package:spectra/features/connect/connect.dart';

const emulated = FakeScanner.emulatedUltra;

ProviderContainer harness(Transport Function(DiscoveredDevice) factory) {
  final container = ProviderContainer(
    overrides: [
      knownDevicesRepositoryProvider
          .overrideWithValue(InMemoryKnownDevicesRepository()),
      scannersProvider.overrideWithValue(<DeviceScanner>[FakeScanner()]),
      transportFactoryProvider.overrideWithValue(factory),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('connecting makes the session the active device', () async {
    final container = harness((_) => FakeDevice());
    await container.read(connectControllerProvider.notifier).connect(emulated);

    expect(container.read(activeDeviceProvider), isNotNull);
    expect(container.read(connectionStatusProvider), isA<SessionReady>());
    expect(container.read(connectControllerProvider).hasError, isFalse);

    await container.read(sessionsProvider.notifier).disconnectAll();
  });

  test('a refused permission lands in the controller state, not a throw',
      () async {
    final container = harness(
      (_) => FakeDevice(openError: const PermissionDenied()),
    );
    await container.read(connectControllerProvider.notifier).connect(emulated);

    final state = container.read(connectControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<PermissionDenied>());
    expect(container.read(activeDeviceProvider), isNull);
  });

  test('reconnectLast connects to the last remembered device', () async {
    final container = harness((_) => FakeDevice());
    final notifier = container.read(connectControllerProvider.notifier);
    await notifier.connect(emulated);
    await container.read(sessionsProvider.notifier).disconnectAll();
    container.read(activeDeviceProvider.notifier).select(null);

    await notifier.reconnectLast();

    expect(container.read(connectionStatusProvider), isA<SessionReady>());
    await container.read(sessionsProvider.notifier).disconnectAll();
  });

  test('reconnectLast with nothing remembered is a no-op', () async {
    final container = harness((_) => FakeDevice());
    await container.read(connectControllerProvider.notifier).reconnectLast();
    expect(container.read(activeDeviceProvider), isNull);
    expect(container.read(connectControllerProvider).hasError, isFalse);
  });
}
```

- [ ] **Step 5: Write the providers and the controller**

```dart
// app/lib/features/connect/state/connect_rows_provider.dart
import 'package:chameleon/chameleon.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/discovery/discovery_provider.dart';
import '../../../data/data.dart';
import '../../../data/database/database_providers.dart';
import 'connect_row.dart';

part 'connect_rows_provider.g.dart';

@riverpod
Stream<List<KnownDevice>> knownDevices(Ref ref) =>
    ref.watch(knownDevicesRepositoryProvider).watchAll();

/// What the connect screen draws: discovery plus the manual ports, merged
/// against what the app remembers (spec 4.2).
@riverpod
List<ConnectRow> connectRows(Ref ref) => mergeConnectRows(
      discovered: <DiscoveredDevice>[
        ...?ref.watch(discoveryProvider).valueOrNull?.devices,
        ...ref.watch(manualPortsProvider),
      ],
      known: ref.watch(knownDevicesProvider).valueOrNull ??
          const <KnownDevice>[],
    );
```

```dart
// app/lib/features/connect/state/connect_controller.dart
import 'package:chameleon/chameleon.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/discovery/discovery_provider.dart';
import '../../../core/session/active_device.dart';
import '../../../core/session/sessions.dart';
import '../../../data/database/database_providers.dart';

part 'connect_controller.g.dart';

/// The connect action, with its progress and its failure. Failures stay in
/// the state rather than being thrown, so the screen renders them through
/// the error catalog (spec 9) instead of catching.
@riverpod
class ConnectController extends _$ConnectController {
  @override
  Future<void> build() async {}

  Future<void> connect(DiscoveredDevice device) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard<void>(() async {
      final identity =
          await ref.read(sessionsProvider.notifier).connect(device);
      ref.read(activeDeviceProvider.notifier).select(identity);
    });
  }

  /// "Reconnect to last device" (spec 4.2): the newest known identity, if it
  /// is visible right now. Silent when it is not — a device that is asleep or
  /// unplugged is not an error worth a dialog.
  Future<void> reconnectLast() async {
    final known = await ref.read(knownDevicesRepositoryProvider).lastSeen();
    if (known == null) return;
    final visible = ref.read(discoveryProvider).valueOrNull?.devices ??
        const <DiscoveredDevice>[];
    final device = visible.where(known.matches).firstOrNull;
    if (device == null) return;
    await connect(device);
  }
}
```

Extend the barrel:

```dart
// app/lib/features/connect/connect.dart
/// The Connect feature's public API (spec 8.3).
library;

export 'state/connect_controller.dart';
export 'state/connect_row.dart';
export 'state/connect_rows_provider.dart';
export 'ui/connect_page.dart';
```

```bash
cd app && dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 6: Run the tests**

```bash
cd app && flutter test test/features/connect
```

Expected: PASS, 10 tests.

- [ ] **Step 7: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git add app
git commit -m "feat(connect): merge discovery by identity and add the connect action

Spec 4.2 merges rows by identity when it is known and by name plus kind when
it is not, so one device reachable over USB and BLE is one row with two
badges. The rule is a pure function over discovery plus the known-device map,
which is what makes every case testable.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 14: The connect screen

**Files:**
- Create: `app/lib/features/connect/ui/connect_row_tile.dart`, `app/lib/features/connect/ui/connect_problem_view.dart`, `app/lib/features/connect/ui/manual_port_field.dart`
- Modify: `app/lib/features/connect/ui/connect_page.dart`, `app/lib/l10n/app_en.arb`
- Test: `app/test/features/connect/connect_page_test.dart`

**Interfaces:**
- Consumes: `connectRowsProvider`, `connectControllerProvider`, `ConnectRow` (Task 13); `discoveryProvider`, `manualPortsProvider`, `emulatorModeProvider` (Task 8); `ErrorCatalog`, `ErrorPresentation`, `ErrorRecovery` (Task 4); `AppRoutes.recover` (Task 9); `currentHostPlatform`, `HostPlatform` from `package:chameleon_flutter/chameleon_flutter.dart`; `SpectraCard`, `SpectraListTile`, `SpectraSectionHeader`, `SpectraButton`, `SpectraStatusChip`, `SpectraTextField`, `SpectraDisclosure`, `SpectraProgressIndicator` from `package:spectra_ui/spectra_ui.dart`.
- Produces:

```dart
class ConnectPage extends ConsumerWidget { const ConnectPage({super.key}); }
class ConnectRowTile extends StatelessWidget {
  const ConnectRowTile({
    required ConnectRow row,
    required VoidCallback onConnect,
    required VoidCallback onRecover,
    super.key,
  });
}
/// Renders a discovery or connect failure through the error catalog, with
/// the platform step underneath (spec 5.1, spec 9).
class ConnectProblemView extends StatelessWidget {
  const ConnectProblemView({required Object error, required VoidCallback onRetry, super.key});
}
/// Desktop only (spec 5.2): type a port path when enumeration finds nothing.
class ManualPortField extends ConsumerWidget { const ManualPortField({super.key}); }
```

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/connect/connect_page_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

void main() {
  testWidgets('lists the emulated device and connects to it', (tester) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await tester.pump();

    expect(find.text('Connect a device'), findsOneWidget);
    expect(find.text('Emulated Chameleon Ultra'), findsOneWidget);

    await connectToEmulator(tester);
    expect(find.byType(SpectraAppShell), findsOneWidget);
  });

  testWidgets('a refused permission shows the message and the platform step',
      (tester) async {
    await tester.pumpWidget(
      testApp(transport: (_) => FakeDevice(openError: const PermissionDenied())),
    );
    await tester.pump();

    await tester.tap(find.text('Emulated Chameleon Ultra'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Spectra needs permission to reach the device.'),
        findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('an empty scan explains that the device sleeps', (tester) async {
    await tester.pumpWidget(testAppWithNoDevices());
    await tester.pump();
    await tester.pump();

    expect(
      find.textContaining('press a button on the device'),
      findsOneWidget,
    );
  });

  testWidgets('a bootloader row offers Recover', (tester) async {
    await tester.pumpWidget(testAppWithBootloader());
    await tester.pump();
    await tester.pump();

    expect(find.text('Recover'), findsOneWidget);
  });
}
```

Add the two extra harness builders to `app/test/support/app_harness.dart`:

```dart
/// A scanner that reports [devices] once. Lets a screen test set the scene
/// without a transport.
final class StaticScanner implements DeviceScanner {
  const StaticScanner(this.devices);
  final List<DiscoveredDevice> devices;
  @override
  TransportKind get kind => TransportKind.fake;
  @override
  Stream<List<DiscoveredDevice>> scan() => Stream.value(devices);
}

Widget testAppWithScanner(DeviceScanner scanner) {
  final db = SpectraDatabase.memory();
  addTearDown(db.close);
  return ProviderScope(
    overrides: <Override>[
      databaseProvider.overrideWithValue(db),
      scannersProvider.overrideWithValue(<DeviceScanner>[scanner]),
    ],
    child: const SpectraRoot(),
  );
}

Widget testAppWithNoDevices() =>
    testAppWithScanner(const StaticScanner(<DiscoveredDevice>[]));

Widget testAppWithBootloader() => testAppWithScanner(
      const StaticScanner(<DiscoveredDevice>[FakeScanner.emulatedBootloader]),
    );
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd app && flutter test test/features/connect/connect_page_test.dart
```

Expected: FAIL — the placeholder page shows no bootloader action, no sleep hint and no error copy.

- [ ] **Step 3: Add the strings**

Append to `app/lib/l10n/app_en.arb`:

```json
  "connectSubtitle": "Choose a Chameleon to connect to.",
  "@connectSubtitle": {"description": "One-line explanation under the connect heading."},
  "connectScanning": "Looking for devices…",
  "@connectScanning": {"description": "Shown while the first scan is running."},
  "connectNothingFound": "No devices found. Over Bluetooth, press a button on the device to wake it — it sleeps eight seconds after losing a connection.",
  "@connectNothingFound": {"description": "Empty-scan hint covering the device's sleep behaviour (spec 5.1)."},
  "connectReconnectLast": "Reconnect to last device",
  "@connectReconnectLast": {"description": "Button that reopens the most recently used device."},
  "connectConnecting": "Connecting…",
  "@connectConnecting": {"description": "Progress label while a session is opening."},
  "connectRecover": "Recover",
  "@connectRecover": {"description": "Action on a device sitting in its bootloader."},
  "connectBootloaderBadge": "In bootloader",
  "@connectBootloaderBadge": {"description": "Marks a device that is in DFU mode."},
  "connectKindUsb": "USB",
  "@connectKindUsb": {"description": "Transport badge for a USB connection."},
  "connectKindBle": "Bluetooth",
  "@connectKindBle": {"description": "Transport badge for a Bluetooth connection."},
  "connectKindFake": "Emulated",
  "@connectKindFake": {"description": "Transport badge for the emulated device."},
  "connectManualPortTitle": "Add a serial port",
  "@connectManualPortTitle": {"description": "Heading of the manual port entry on desktop."},
  "connectManualPortLabel": "Port path",
  "@connectManualPortLabel": {"description": "Label of the manual serial port field."},
  "connectManualPortHint": "/dev/cu.usbmodem1",
  "@connectManualPortHint": {"description": "Example serial port path."},
  "connectManualPortAdd": "Add",
  "@connectManualPortAdd": {"description": "Confirms a manually typed port."},
  "commonRetry": "Try again",
  "@commonRetry": {"description": "Retries the failed action."},
  "commonOpenSettings": "Open settings",
  "@commonOpenSettings": {"description": "Sends the user to system settings."},
  "commonDetails": "Details",
  "@commonDetails": {"description": "Reveals the raw error line."},
  "commonUpdateFirmware": "Update firmware",
  "@commonUpdateFirmware": {"description": "Opens the firmware update screen."}
```

Regenerate: `cd app && flutter gen-l10n`.

- [ ] **Step 4: Write the row tile, the problem view and the manual field**

```dart
// app/lib/features/connect/ui/connect_row_tile.dart
import 'package:chameleon/chameleon.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../state/connect_row.dart';

/// One device: its name, its transport badges, and either connect or, for a
/// device sitting in its bootloader, recover (spec 5.5).
class ConnectRowTile extends StatelessWidget {
  const ConnectRowTile({
    required this.row,
    required this.onConnect,
    required this.onRecover,
    super.key,
  });

  final ConnectRow row;
  final VoidCallback onConnect;
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String subtitle = <String>[
      if (row.isBootloader) l10n.connectBootloaderBadge,
      for (final TransportKind kind in row.kinds) _kindLabel(l10n, kind),
    ].join(' · ');

    return SpectraListTile(
      title: row.name,
      subtitle: subtitle,
      leading: Icon(row.isBootloader ? Icons.build_circle : Icons.memory),
      trailing: row.isBootloader
          ? SpectraButton(
              label: l10n.connectRecover,
              onPressed: onRecover,
              variant: SpectraButtonVariant.secondary,
            )
          : const Icon(Icons.chevron_right),
      onTap: row.isBootloader ? onRecover : onConnect,
    );
  }

  static String _kindLabel(AppLocalizations l10n, TransportKind kind) =>
      switch (kind) {
        TransportKind.usb => l10n.connectKindUsb,
        TransportKind.ble => l10n.connectKindBle,
        TransportKind.fake => l10n.connectKindFake,
      };
}
```

```dart
// app/lib/features/connect/ui/connect_problem_view.dart
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/error_catalog.dart';
import '../../../core/errors/error_presentation.dart';
import '../../../l10n/app_localizations.dart';

/// A failure, in the shape spec 9 asks for: one plain sentence, a recovery
/// action, and the raw line one tap away.
class ConnectProblemView extends StatelessWidget {
  const ConnectProblemView({
    required this.error,
    required this.onRetry,
    super.key,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ErrorPresentation p = ErrorCatalog(l10n).describe(error);
    return SpectraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(p.message),
          if (p.instructions != null) ...<Widget>[
            const SizedBox(height: SpectraSpacing.sm),
            Text(p.instructions!),
          ],
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
              _ => l10n.commonRetry,
            },
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
```

`ErrorRecovery.openSettings` shows a settings label but still calls `onRetry`: opening system settings is a platform call this phase does not own, and the instructions line already tells the user where to go. Note that in a doc comment.

```dart
// app/lib/features/connect/ui/manual_port_field.dart
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/discovery/discovery_provider.dart';
import '../../../l10n/app_localizations.dart';

/// Desktop fallback for a port enumeration that finds nothing (spec 5.2).
/// Renders nothing on mobile, where there are no port paths to type.
class ManualPortField extends ConsumerStatefulWidget {
  const ManualPortField({super.key});

  @override
  ConsumerState<ManualPortField> createState() => _ManualPortFieldState();
}

class _ManualPortFieldState extends ConsumerState<ManualPortField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    ref.read(manualPortsProvider.notifier).add(_controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    const Set<HostPlatform> desktop = <HostPlatform>{
      HostPlatform.macos,
      HostPlatform.windows,
      HostPlatform.linux,
    };
    if (!desktop.contains(currentHostPlatform())) {
      return const SizedBox.shrink();
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SpectraDisclosure(
      summary: Text(l10n.connectManualPortTitle),
      detail: Row(
        children: <Widget>[
          Expanded(
            child: SpectraTextField(
              label: l10n.connectManualPortLabel,
              hint: l10n.connectManualPortHint,
              controller: _controller,
              onSubmitted: (_) => _add(),
            ),
          ),
          const SizedBox(width: SpectraSpacing.md),
          SpectraButton(label: l10n.connectManualPortAdd, onPressed: _add),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Write the page**

```dart
// app/lib/features/connect/ui/connect_page.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/discovery/discovery_merge.dart';
import '../../../core/discovery/discovery_provider.dart';
import '../../../core/routing/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../state/connect_controller.dart';
import '../state/connect_row.dart';
import '../state/connect_rows_provider.dart';
import 'connect_problem_view.dart';
import 'connect_row_tile.dart';
import 'manual_port_field.dart';

/// The full-screen connect route (spec 7.7 step 1). Layout only: the merge
/// is `connectRowsProvider` and the action is `connectControllerProvider`.
class ConnectPage extends ConsumerWidget {
  const ConnectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<ConnectRow> rows = ref.watch(connectRowsProvider);
    final AsyncValue<DiscoveryState> discovery = ref.watch(discoveryProvider);
    final AsyncValue<void> connect = ref.watch(connectControllerProvider);
    final Object? problem = connect.error ?? discovery.valueOrNull?.error;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SpectraSpacing.lg),
          children: <Widget>[
            SpectraSectionHeader(title: l10n.connectTitle),
            Text(l10n.connectSubtitle),
            const SizedBox(height: SpectraSpacing.lg),
            if (connect.isLoading)
              SpectraProgressIndicator(label: l10n.connectConnecting),
            if (problem != null)
              ConnectProblemView(
                error: problem,
                onRetry: () => ref.invalidate(discoveryProvider),
              ),
            for (final ConnectRow row in rows)
              ConnectRowTile(
                row: row,
                onConnect: () => ref
                    .read(connectControllerProvider.notifier)
                    .connect(row.preferred),
                onRecover: () => GoRouter.of(context)
                    .go(AppRoutes.recover(row.preferred.transportId)),
              ),
            if (rows.isEmpty)
              SpectraCard(
                child: Text(
                  discovery.isLoading
                      ? l10n.connectScanning
                      : l10n.connectNothingFound,
                ),
              ),
            const SizedBox(height: SpectraSpacing.lg),
            SpectraButton(
              label: l10n.connectReconnectLast,
              variant: SpectraButtonVariant.secondary,
              onPressed: () =>
                  ref.read(connectControllerProvider.notifier).reconnectLast(),
            ),
            const SizedBox(height: SpectraSpacing.md),
            const ManualPortField(),
          ],
        ),
      ),
    );
  }
}
```

The bootloader row routes to `/tools/update?recover=…` while the session is disconnected, so add the update route to the routes `redirectFor` allows from a disconnected state — otherwise the redirect bounces it straight back to connect. Change the `SessionDisconnected`/`SessionConnecting` case in `app/lib/core/routing/redirect.dart` to:

```dart
    case SessionConnecting():
    case SessionDisconnected():
      // The recovery entry is reachable with nothing connected: a device left
      // in its bootloader has no session and must still be recoverable
      // (spec 5.6).
      final allowed =
          location == AppRoutes.connect || location == AppRoutes.update;
      return allowed ? null : AppRoutes.connect;
```

and add the matching case to `app/test/core/routing/redirect_test.dart`:

```dart
  test('the update route is reachable with no session, for recovery', () {
    expect(redirectFor(state: disconnected, location: AppRoutes.update),
        isNull);
  });
```

- [ ] **Step 6: Run the tests**

```bash
cd app && flutter test test/features/connect test/core/routing
```

Expected: PASS, 15 tests.

- [ ] **Step 7: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart format . && dart analyze --fatal-infos . && dart run tool/dep_lint.dart
git add app
git commit -m "feat(connect): build the connect screen

One row per device with transport badges (spec 4.2), the sleep hint an empty
BLE scan needs (spec 5.1), manual port entry on desktop (spec 5.2), a Recover
action for a device in its bootloader (spec 5.5), and every failure rendered
through the error catalog with the raw line one tap away (spec 9).

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 15: The device dashboard, with its limited variant

**Files:**
- Create: `app/lib/features/dashboard/ui/device_detail_card.dart`, `app/lib/features/dashboard/ui/limited_dashboard.dart`
- Modify: `app/lib/features/dashboard/ui/dashboard_page.dart`, `app/lib/features/dashboard/dashboard.dart`, `app/lib/l10n/app_en.arb`
- Test: `app/test/features/dashboard/dashboard_page_test.dart`

**Interfaces:**
- Consumes: `connectionStatusProvider`, `deviceInfoProvider`, `batteryProvider`, `modeProvider`, `activeSlotProvider` (Task 7); `sessionsProvider`, `activeDeviceProvider` (Task 6); `AppRoutes` (Task 9); `SpectraCard`, `SpectraStatusChip`, `SpectraConnectionStatus`, `SpectraDisclosure`, `SpectraListTile`, `SpectraSectionHeader`, `SpectraButton` from `package:spectra_ui/spectra_ui.dart`.
- Produces:

```dart
class DashboardPage extends ConsumerWidget { const DashboardPage({super.key}); }
/// Progressive disclosure (spec 1): the summary is the model and version;
/// chip id, git version and BLE address are one tap away.
class DeviceDetailCard extends StatelessWidget {
  const DeviceDetailCard({required DeviceInfo info, super.key});
}
/// Spec 7.2: a `limited` session gets a reduced dashboard whose only action
/// is update.
class LimitedDashboard extends ConsumerWidget {
  const LimitedDashboard({required SessionLimited state, super.key});
}
```

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/dashboard/dashboard_page_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

void main() {
  testWidgets('shows the fake device model, version and disconnect',
      (tester) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);

    expect(find.textContaining('Ultra'), findsWidgets);
    expect(find.textContaining('2.2'), findsWidgets);
    expect(find.text('Disconnect'), findsOneWidget);
  });

  testWidgets('reveals the chip id behind the disclosure', (tester) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);

    expect(find.textContaining('0102030405060708'), findsNothing);
    await tester.tap(find.text('Details'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('0102030405060708'), findsWidgets);
  });

  testWidgets('disconnecting returns to the connect screen', (tester) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);

    await tester.tap(find.text('Disconnect'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Connect a device'), findsOneWidget);
  });

  testWidgets('a limited session offers only the update action',
      (tester) async {
    await tester.pumpWidget(
      testApp(
        transport: (_) => FakeDevice(
          firmware: FakeFirmware(config: FakeFirmwareConfig.legacy01()),
        ),
      ),
    );
    await connectToEmulator(tester);

    expect(find.text('Update firmware'), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);
    expect(find.textContaining('must be updated'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd app && flutter test test/features/dashboard/dashboard_page_test.dart
```

Expected: FAIL — the dashboard is still the Task 10 placeholder.

- [ ] **Step 3: Add the strings**

Append to `app/lib/l10n/app_en.arb`:

```json
  "dashboardDisconnect": "Disconnect",
  "@dashboardDisconnect": {"description": "Closes the session with the connected device."},
  "dashboardModel": "Model",
  "@dashboardModel": {"description": "Label for the device model."},
  "dashboardFirmware": "Firmware",
  "@dashboardFirmware": {"description": "Label for the running firmware version."},
  "dashboardGitVersion": "Build",
  "@dashboardGitVersion": {"description": "Label for the firmware git version string."},
  "dashboardChipId": "Chip ID",
  "@dashboardChipId": {"description": "Label for the device's unique chip identifier."},
  "dashboardBleAddress": "Bluetooth address",
  "@dashboardBleAddress": {"description": "Label for the device's BLE address."},
  "dashboardActiveSlot": "Active slot",
  "@dashboardActiveSlot": {"description": "Label for the slot the device is emulating."},
  "dashboardModeReader": "Reader mode",
  "@dashboardModeReader": {"description": "Chip label when the device is in reader mode."},
  "dashboardModeEmulator": "Emulator mode",
  "@dashboardModeEmulator": {"description": "Chip label when the device is emulating."},
  "dashboardModelUltra": "Chameleon Ultra",
  "@dashboardModelUltra": {"description": "Display name of the Ultra."},
  "dashboardModelLite": "Chameleon Lite",
  "@dashboardModelLite": {"description": "Display name of the Lite."},
  "dashboardUnknown": "Unknown",
  "@dashboardUnknown": {"description": "Placeholder for a value the device has not reported."},
  "dashboardLimitedTitle": "This device needs a firmware update",
  "@dashboardLimitedTitle": {"description": "Heading of the reduced dashboard."}
```

Regenerate: `cd app && flutter gen-l10n`.

- [ ] **Step 4: Write the detail card and the limited variant**

```dart
// app/lib/features/dashboard/ui/device_detail_card.dart
import 'package:chameleon/chameleon.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../l10n/app_localizations.dart';

/// Spec 1: the summary is what the device is; chip id, build string and BLE
/// address are expert detail, one tap away.
class DeviceDetailCard extends StatelessWidget {
  const DeviceDetailCard({required this.info, super.key});

  final DeviceInfo info;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String model = switch (info.model) {
      DeviceModel.ultra => l10n.dashboardModelUltra,
      DeviceModel.lite => l10n.dashboardModelLite,
    };
    return SpectraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SpectraListTile(title: model, subtitle: l10n.dashboardModel),
          SpectraListTile(
            title: info.version.label,
            subtitle: l10n.dashboardFirmware,
          ),
          SpectraDisclosure(
            summary: Text(l10n.commonDetails),
            detail: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SpectraListTile(
                  title: info.gitVersion ?? l10n.dashboardUnknown,
                  subtitle: l10n.dashboardGitVersion,
                ),
                SpectraListTile(
                  title: info.identity?.chipId ?? l10n.dashboardUnknown,
                  subtitle: l10n.dashboardChipId,
                ),
                SpectraListTile(
                  title: info.bleAddress ?? l10n.dashboardUnknown,
                  subtitle: l10n.dashboardBleAddress,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

```dart
// app/lib/features/dashboard/ui/limited_dashboard.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/errors/error_catalog.dart';
import '../../../core/routing/routes.dart';
import '../../../l10n/app_localizations.dart';

/// Spec 7.2: a `limited` session can do exactly one thing, so this screen
/// offers exactly one action.
class LimitedDashboard extends ConsumerWidget {
  const LimitedDashboard({required this.state, required this.onDisconnect, super.key});

  final SessionLimited state;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(SpectraSpacing.lg),
      children: <Widget>[
        SpectraSectionHeader(title: l10n.dashboardLimitedTitle),
        SpectraCard(
          child: Text(
            ErrorCatalog(l10n)
                .describe(UnsupportedFirmware(state.reason, 'limited'))
                .message,
          ),
        ),
        const SizedBox(height: SpectraSpacing.lg),
        SpectraButton(
          label: l10n.commonUpdateFirmware,
          onPressed: () => GoRouter.of(context).go(AppRoutes.update),
        ),
        const SizedBox(height: SpectraSpacing.md),
        SpectraButton(
          label: l10n.dashboardDisconnect,
          variant: SpectraButtonVariant.secondary,
          onPressed: onDisconnect,
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Write the page**

```dart
// app/lib/features/dashboard/ui/dashboard_page.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/session/active_device.dart';
import '../../../core/session/session_streams.dart';
import '../../../core/session/sessions.dart';
import '../../../l10n/app_localizations.dart';
import 'device_detail_card.dart';
import 'limited_dashboard.dart';

/// Spec 7.7 step 1: what the device is, how it is doing, and how to let go
/// of it. Layout only.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ConnectionState status = ref.watch(connectionStatusProvider);

    Future<void> disconnect() async {
      final identity = ref.read(activeDeviceProvider);
      ref.read(activeDeviceProvider.notifier).select(null);
      if (identity != null) {
        await ref.read(sessionsProvider.notifier).disconnect(identity);
      }
    }

    if (status is SessionLimited) {
      return LimitedDashboard(state: status, onDisconnect: disconnect);
    }

    final DeviceInfo? info = ref.watch(deviceInfoProvider).valueOrNull;
    final BatteryInfo? battery = ref.watch(batteryProvider).valueOrNull;
    final DeviceMode? mode = ref.watch(modeProvider).valueOrNull;
    final int? slot = ref.watch(activeSlotProvider).valueOrNull;

    return ListView(
      padding: const EdgeInsets.all(SpectraSpacing.lg),
      children: <Widget>[
        SpectraSectionHeader(title: l10n.dashboardTitle),
        Wrap(
          spacing: SpectraSpacing.sm,
          runSpacing: SpectraSpacing.sm,
          children: <Widget>[
            SpectraStatusChip.connection(
              status is SessionReady
                  ? SpectraConnectionStatus.connected
                  : SpectraConnectionStatus.connecting,
            ),
            if (battery != null)
              SpectraStatusChip.battery(percent: battery.percent),
          ],
        ),
        const SizedBox(height: SpectraSpacing.lg),
        if (info != null) DeviceDetailCard(info: info),
        const SizedBox(height: SpectraSpacing.md),
        SpectraCard(
          child: Column(
            children: <Widget>[
              SpectraListTile(
                title: switch (mode) {
                  DeviceMode.reader => l10n.dashboardModeReader,
                  DeviceMode.emulator => l10n.dashboardModeEmulator,
                  null => l10n.dashboardUnknown,
                },
                subtitle: l10n.dashboardActiveSlot,
                trailing: Text(
                  slot == null ? l10n.dashboardUnknown : '${slot + 1}',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SpectraSpacing.lg),
        SpectraButton(
          label: l10n.dashboardDisconnect,
          variant: SpectraButtonVariant.secondary,
          onPressed: disconnect,
        ),
      ],
    );
  }
}
```

Export `DeviceDetailCard` and `LimitedDashboard` from `dashboard.dart` only if another feature needs them — they are internal, so the barrel exports `ui/dashboard_page.dart` alone (spec 8.3).

- [ ] **Step 6: Run the tests**

```bash
cd app && flutter test test/features/dashboard
```

Expected: PASS, 4 tests.

- [ ] **Step 7: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git add app
git commit -m "feat(dashboard): show the connected device, with a limited variant

Spec 7.7 step 1 and spec 1: model, firmware, battery, mode and active slot in
plain words, with chip id, build string and BLE address behind a disclosure.
A limited session gets the reduced screen spec 7.2 requires, whose only
action is update.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 16: The frame log viewer and the bootloader recovery entry

**Files:**
- Modify: `app/lib/features/tools/ui/frame_log_page.dart`, `app/lib/features/tools/ui/update_page.dart`, `app/lib/l10n/app_en.arb`
- Test: `app/test/features/tools/frame_log_page_test.dart`, `app/test/features/tools/update_page_test.dart`

**Interfaces:**
- Consumes: `frameLogProvider`, `frameLogEntriesProvider` (Task 7); `featureFlagsProvider` (Task 5); `AppRoutes` (Task 9); `Clipboard`, `ClipboardData` from `package:flutter/services.dart`; `SpectraSectionHeader`, `SpectraCard`, `SpectraButton`, `SpectraListTile` from `package:spectra_ui/spectra_ui.dart`.
- Produces:

```dart
/// Spec 9: viewing and exporting the frame log ship in every build, because
/// it is the first thing asked for in a bug report.
class FrameLogPage extends ConsumerWidget { const FrameLogPage({super.key}); }

/// The Phase 8 screen's placeholder. It already reads the recovery target
/// (spec 5.5) and the `dfuOverBleEnabled` flag, so Phase 8 replaces the body
/// and nothing else.
class UpdatePage extends ConsumerWidget {
  const UpdatePage({String? recoverTransportId, super.key});
  final String? recoverTransportId;
}
```

- [ ] **Step 1: Write the failing tests**

```dart
// app/test/features/tools/frame_log_page_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

void main() {
  testWidgets('lists frames after a handshake and copies them', (tester) async {
    final List<MethodCall> clipboard = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') clipboard.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openFrameLog(tester);

    expect(find.text('Frame log'), findsWidgets);
    expect(find.textContaining('cmd='), findsWidgets);

    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(clipboard, hasLength(1));
  });
}
```

```dart
// app/test/features/tools/update_page_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

void main() {
  testWidgets('the placeholder names the phase and the BLE notice',
      (tester) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openUpdate(tester);

    expect(find.textContaining('Phase 8'), findsOneWidget);
    expect(find.textContaining('pending hardware validation'), findsOneWidget);
  });

  testWidgets('recovering from the connect screen carries the transport id',
      (tester) async {
    await tester.pumpWidget(testAppWithBootloader());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Recover'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.textContaining('fake-bootloader'), findsOneWidget);
  });
}
```

Add the two navigation helpers to `app/test/support/app_harness.dart`:

```dart
/// Taps through to a Tools sub-page. The shell is wide enough in tests that
/// the destination is a rail item.
Future<void> _openTool(WidgetTester tester, String title) async {
  await tester.tap(find.text('Tools').last);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.tap(find.text(title));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> openFrameLog(WidgetTester tester) =>
    _openTool(tester, 'Frame log');
Future<void> openUpdate(WidgetTester tester) =>
    _openTool(tester, 'Firmware update');
```

- [ ] **Step 2: Run them and watch them fail**

```bash
cd app && flutter test test/features/tools
```

Expected: FAIL — both pages are still Task 10 placeholders.

- [ ] **Step 3: Add the strings**

Append to `app/lib/l10n/app_en.arb`:

```json
  "frameLogEmpty": "No frames yet. Connect a device and the log fills up.",
  "@frameLogEmpty": {"description": "Shown when the frame log has no entries."},
  "frameLogCopy": "Copy",
  "@frameLogCopy": {"description": "Copies the whole frame log to the clipboard."},
  "frameLogCopied": "Frame log copied.",
  "@frameLogCopied": {"description": "Confirms the frame log reached the clipboard."},
  "updateRecoverTarget": "Recovering the device at {transportId}.",
  "@updateRecoverTarget": {
    "description": "Names the bootloader a recovery was started for.",
    "placeholders": {"transportId": {"type": "String"}}
  },
  "updateRecoverInstructions": "If the device is not listed, hold button B while plugging in the USB cable to enter the bootloader from any state.",
  "@updateRecoverInstructions": {"description": "Spec 5.6 recovery instructions."},
  "updateBleNotice": "Bluetooth firmware update is pending hardware validation and is switched off in this build.",
  "@updateBleNotice": {"description": "Shown while dfuOverBleEnabled is false."}
```

Regenerate: `cd app && flutter gen-l10n`.

- [ ] **Step 4: Write the frame log page**

```dart
// app/lib/features/tools/ui/frame_log_page.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/session/frame_log_provider.dart';
import '../../../l10n/app_localizations.dart';

/// Spec 9: the ring buffer is always on, and viewing and exporting it are in
/// every build. Export is the clipboard — no share plugin, because a bug
/// report is pasted, not attached.
class FrameLogPage extends ConsumerWidget {
  const FrameLogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<FrameLogEntry> entries =
        ref.watch(frameLogEntriesProvider).valueOrNull ??
            const <FrameLogEntry>[];

    return ListView(
      padding: const EdgeInsets.all(SpectraSpacing.lg),
      children: <Widget>[
        SpectraSectionHeader(
          title: l10n.frameLogTitle,
          actionLabel: l10n.frameLogCopy,
          onAction: () async {
            final String text = ref.read(frameLogProvider)?.export() ?? '';
            await Clipboard.setData(ClipboardData(text: text));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.frameLogCopied)),
            );
          },
        ),
        if (entries.isEmpty) SpectraCard(child: Text(l10n.frameLogEmpty)),
        for (final FrameLogEntry entry in entries.reversed)
          SpectraListTile(
            title: _line(entry),
            subtitle: entry.at.toIso8601String(),
          ),
      ],
    );
  }

  /// The same one-line shape `FrameLog.export()` writes, so what is on screen
  /// and what is pasted into a bug report match.
  static String _line(FrameLogEntry entry) {
    final String arrow = entry.direction == FrameDirection.sent ? '>' : '<';
    return '$arrow cmd=${entry.frame.command} '
        'status=0x${entry.frame.status.toRadixString(16)} '
        'len=${entry.frame.data.length}';
  }
}
```

`_line` is not user-facing copy — it is a wire dump — so mark its `title:` argument `// l10n-exempt` for the string lint.

- [ ] **Step 5: Write the update placeholder**

```dart
// app/lib/features/tools/ui/update_page.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/flags/feature_flags.dart';
import '../../../l10n/app_localizations.dart';

/// Phase 8 fills this in. What exists now is the seam it needs: the
/// recovery target from the connect screen (spec 5.5) and the
/// `dfuOverBleEnabled` notice the roadmap requires while the flag is off.
class UpdatePage extends ConsumerWidget {
  const UpdatePage({this.recoverTransportId, super.key});

  /// The bootloader a "Recover" action named, from `?recover=`.
  final String? recoverTransportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final FeatureFlags flags = ref.watch(featureFlagsProvider);
    final String? target = recoverTransportId;

    return ListView(
      padding: const EdgeInsets.all(SpectraSpacing.lg),
      children: <Widget>[
        SpectraSectionHeader(title: l10n.updateTitle),
        if (target != null) ...<Widget>[
          SpectraCard(child: Text(l10n.updateRecoverTarget(target))),
          const SizedBox(height: SpectraSpacing.md),
          SpectraCard(child: Text(l10n.updateRecoverInstructions)),
          const SizedBox(height: SpectraSpacing.md),
        ],
        if (!flags.dfuOverBleEnabled)
          SpectraCard(child: Text(l10n.updateBleNotice)),
        const SizedBox(height: SpectraSpacing.md),
        SpectraCard(child: Text(l10n.comingSoonUpdate)),
      ],
    );
  }
}
```

- [ ] **Step 6: Run the tests**

```bash
cd app && flutter test test/features/tools
```

Expected: PASS, 3 tests.

- [ ] **Step 7: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git add app
git commit -m "feat(tools): add the frame log viewer and the recovery entry

Spec 9 puts the frame log in every build, so it ships now rather than with
the feature that needs it; export is the clipboard because a bug report is
pasted. The update screen is Phase 8's, but its two seams — the recovery
target from spec 5.5 and the dfuOverBleEnabled notice — exist now.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 17: The phase gate — the connect flow as a widget test and as an integration test

**Files:**
- Create: `app/test/flows/connect_flow_test.dart`, `app/integration_test/connect_flow_test.dart`
- Modify: `.github/workflows/ci.yml`
- Test: both of the above

**Interfaces:**
- Consumes: `testApp`, `connectToEmulator` (Task 10 harness); `SpectraRoot`; `databaseProvider`, `scannersProvider`, `transportFactoryProvider`; `FakeDevice`, `FakeScanner`.
- Produces: nothing importable. The deliverable is the roadmap's Phase 4 gate: *connect to emulator, see dashboard, disconnect, reconnect.*

**Integration-test strategy (decided here, recorded in DECISIONS.md):** the gate flow exists twice. The widget test in `test/flows/` runs on every CI job on Ubuntu inside `melos run test:flutter` — that is the gate CI enforces. The `integration_test/` copy runs the same flow on a real engine and is enforced by a `macos-latest` CI job, because `flutter test integration_test -d macos` needs a desktop session that the Ubuntu container does not have. If the macOS job proves unstable during this phase, mark that one job `continue-on-error: true` and say so in the close-out — the widget-test twin still gates the phase. Do not delete either copy: the widget test is fast and always runs; the integration test is what proves the real engine, the real Drift file path and the real plugin registrations do not fall over.

- [ ] **Step 1: Write the failing widget flow test**

```dart
// app/test/flows/connect_flow_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/app_harness.dart';

/// The roadmap's Phase 4 gate: connect to the emulator, see the dashboard,
/// disconnect, reconnect.
void main() {
  testWidgets('connect, dashboard, disconnect, reconnect', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // One fake per connect: a session owns its transport and closes it.
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await tester.pump();

    expect(find.text('Connect a device'), findsOneWidget);
    expect(find.text('Emulated Chameleon Ultra'), findsOneWidget);

    await connectToEmulator(tester);

    expect(find.byType(SpectraAppShell), findsOneWidget);
    expect(find.textContaining('Chameleon Ultra'), findsWidgets);
    expect(find.textContaining('2.2'), findsWidgets,
        reason: 'the fake firmware version is on the dashboard');

    await tester.tap(find.text('Disconnect'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Connect a device'), findsOneWidget);

    // The device is remembered now, so the row carries its identity.
    await connectToEmulator(tester);
    expect(find.byType(SpectraAppShell), findsOneWidget);
    expect(find.textContaining('2.2'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run it**

```bash
cd app && flutter test test/flows/connect_flow_test.dart
```

Expected: PASS. If the second connect finds no row, the known-device merge renamed the row to the remembered display name — which is the emulated device's own name, so the finder still matches. If it does not, assert on `find.byType(ConnectRowTile)` instead and tap that.

- [ ] **Step 3: Write the integration test**

```dart
// app/integration_test/connect_flow_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:spectra/app.dart';
import 'package:spectra/core/discovery/scanners.dart';
import 'package:spectra/core/session/sessions.dart';
import 'package:spectra/data/database/database_providers.dart';
import 'package:spectra/data/database/spectra_database.dart';
import 'package:spectra_ui/spectra_ui.dart';

/// The Phase 4 gate on a real engine. Emulator mode only: no hardware is
/// touched, and none is needed.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('connect, dashboard, disconnect, reconnect', (tester) async {
    final db = SpectraDatabase.memory();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          databaseProvider.overrideWithValue(db),
          scannersProvider.overrideWithValue(<DeviceScanner>[FakeScanner()]),
          transportFactoryProvider.overrideWithValue((_) => FakeDevice()),
        ],
        child: const SpectraRoot(),
      ),
    );
    await tester.pump();

    Future<void> connect() async {
      await tester.tap(find.text(FakeScanner.emulatedUltra.name));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    expect(find.text('Connect a device'), findsOneWidget);
    await connect();
    expect(find.byType(SpectraAppShell), findsOneWidget);
    expect(find.textContaining('2.2'), findsWidgets);

    await tester.tap(find.text('Disconnect'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Connect a device'), findsOneWidget);

    await connect();
    expect(find.byType(SpectraAppShell), findsOneWidget);
  });
}
```

- [ ] **Step 4: Run it on macOS**

```bash
cd app && flutter test integration_test -d macos
```

Expected: PASS, 1 test. This is the roadmap's Phase 4 gate, run on a real engine. If the macOS build needs entitlements Phase 3 added, they are already in `app/macos/Runner/*.entitlements`.

- [ ] **Step 5: Add the CI job**

In `.github/workflows/ci.yml`, after the `check` job:

```yaml
  integration:
    needs: check
    runs-on: macos-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: stable
          cache: true
      - run: flutter pub get
      # The Phase 4 gate on a real engine, in emulator mode: no hardware.
      - run: flutter test integration_test -d macos
        working-directory: app
```

- [ ] **Step 6: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git add app .github/workflows/ci.yml
git commit -m "test(app): add the Phase 4 gate flow twice

The roadmap's gate is connect, dashboard, disconnect, reconnect. It runs as
a widget test in every CI job, and as an integration test on a macOS runner
so the real engine, the real database and the real plugin registrations are
exercised too.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 18: The parked Phase 2 items

**Files:**
- Modify: `packages/spectra_ui/test/components/text_field_test.dart`, `packages/spectra_ui/example/test/gallery_test.dart`

**Interfaces:**
- Consumes: `SpectraTextField`'s parameters `keyboardType`, `textInputAction`, `onSubmitted`, `focusNode`, `autofocus`, `readOnly`, `semanticsLabel`; `buildGalleryRouter()`, `galleryEntries` from the gallery.
- Produces: nothing importable. Closes the two items Phase 2 left open.

- [ ] **Step 1: Write the text field tests**

Append to `packages/spectra_ui/test/components/text_field_test.dart`:

```dart
  testWidgets('forwards keyboardType, textInputAction and readOnly', (
    tester,
  ) async {
    await tester.pumpWidget(
      spectraHarness(
        child: const SpectraTextField(
          label: 'Port',
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          readOnly: true,
        ),
      ),
    );
    final TextField field = tester.widget(find.byType(TextField));
    expect(field.keyboardType, TextInputType.number);
    expect(field.textInputAction, TextInputAction.done);
    expect(field.readOnly, isTrue);
  });

  testWidgets('reports submission through onSubmitted', (tester) async {
    final submitted = <String>[];
    await tester.pumpWidget(
      spectraHarness(
        child: SpectraTextField(label: 'Port', onSubmitted: submitted.add),
      ),
    );
    await tester.enterText(find.byType(TextField), '/dev/cu.usbmodem1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(submitted, <String>['/dev/cu.usbmodem1']);
  });

  testWidgets('takes focus from an external focus node and autofocus', (
    tester,
  ) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(
      spectraHarness(
        child: SpectraTextField(
          label: 'Port',
          focusNode: node,
          autofocus: true,
        ),
      ),
    );
    await tester.pump();
    expect(node.hasFocus, isTrue);
  });

  testWidgets('semanticsLabel overrides the visible label for screen readers',
      (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        child: const SpectraTextField(
          label: 'Port',
          semanticsLabel: 'Serial port path',
        ),
      ),
    );
    expect(find.bySemanticsLabel('Serial port path'), findsWidgets);
  });
```

- [ ] **Step 2: Write the gallery redirect test**

Append to `packages/spectra_ui/example/test/gallery_test.dart`:

```dart
  testWidgets('/ redirects to the first component page', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = buildGalleryRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      SpectraApp(routerConfig: router),
    );
    await _pumpFrames(tester);

    router.go('/');
    await _pumpFrames(tester);

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      galleryEntries.first.path,
    );
  });
```

- [ ] **Step 3: Run both suites**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd packages/spectra_ui && flutter test test/components/text_field_test.dart
cd ../spectra_ui/example && flutter test test/gallery_test.dart
```

Expected: PASS, 7 text-field tests and the gallery suite plus one.

- [ ] **Step 4: Commit**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git add packages/spectra_ui
git commit -m "test(spectra_ui): cover the parked text field and gallery cases

Phase 2 added SpectraTextField's keyboard, focus and read-only parameters
without tests, and never asserted the gallery's / redirect. Both are used by
Phase 4's connect screen, so they get proved now.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 19: Close-out

**Files:**
- Modify: `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md`, `AGENTS.md`, `tasks/lessons.md`, `docs/research/DECISIONS.md`
- Test: the full check suite

- [ ] **Step 1: Run the whole check suite from the worktree root**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd /Users/bcraig/orca/workspaces/spectra/chinook
dart run melos run check:all
```

Expected: `format`, `analyze`, `lint:deps`, `test:root`, `check:codegen`, `test:dart` and `test:flutter` all green. Paste the summary counts into the commit body. If anything fails, fix it here — this command is the phase gate.

- [ ] **Step 2: Confirm the phase gate explicitly**

```bash
cd app
flutter test test/flows/connect_flow_test.dart
flutter test integration_test -d macos
```

Expected: both PASS. The roadmap's Phase 4 gate is "integration test: connect to emulator, see dashboard, disconnect, reconnect" — that is these two runs. **No hardware is involved and none is claimed.**

- [ ] **Step 3: Tick the roadmap**

In `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md`, change `- [ ] Phase 4` to `- [x] Phase 4`, and in the phase table change the Phase 4 `Plan` cell to `` `2026-09-03-phase-4-app-shell.md` (written) ``.

- [ ] **Step 4: Update AGENTS.md**

Rewrite the "Current status" section so a fresh session knows where things stand: Phase 4 complete; `app/` has the session registry keyed by `DeviceIdentity`, the Drift data layer at schema version 1, routing driven by `connectionState`, lifecycle and wakelock, the error catalog, the frame log, emulator mode, the connect screen and the dashboard; `SlotsPage`, `CardsPage` and `SettingsPage` are placeholders for Phases 5, 6 and 9; the update screen is a placeholder that already carries the recovery target and the `dfuOverBleEnabled` notice; the flag is defined in `core/flags/feature_flags.dart` and defaults to false. Add the Phase 4 plan to the plans list and note Phase 5 is written next from spec 7.7 step 2 and 8.3.

- [ ] **Step 5: Record the decisions**

Append to `docs/research/DECISIONS.md`:

```markdown
- **Sessions are keyed by identity, but registered after the handshake.**
  Spec 7.1 wants a family keyed by `DeviceIdentity`; the identity is the chip
  id and only exists once the handshake has run. `Sessions.connect` therefore
  opens first and registers second, and a session that never became ready —
  pre-2.0 firmware, a device in its bootloader — gets
  `fallbackIdentity(device)`, derived from the transport and prefixed
  `transport:` so it can never be confused with a chip id. One map, no
  nullable key, no second code path for limited sessions.
- **The connection state is a notifier; everything else derived is a stream
  provider.** Routing needs a synchronous value (spec 7.2), and
  `StateStream.values` only delivers its current value asynchronously. The
  notifier is named `ConnectionStatus` because riverpod_generator would
  otherwise generate a `_$ConnectionState` base colliding with the SDK type.
- **Drift schema version 1 contains all four tables**, including
  `saved_cards` and `key_dictionaries`, which nothing reads until Phases 6
  and 9. The alternative was a migration per phase for tables whose shape is
  already known. The v1 schema is exported to `app/drift_schemas/` and
  verified by `test/data/schema_test.dart` with `drift_dev`'s
  `SchemaVerifier`.
- **Tests use real Drift in memory, not a mock.** `SpectraDatabase.memory()`
  runs the real queries with no file system, so the repositories are proved
  rather than stubbed. Sqlite3 native is needed on CI — `libsqlite3-dev` is
  installed in the check job.
- **The gate flow exists twice.** The widget test in `app/test/flows/` runs
  on every CI job on Ubuntu; the `integration_test/` copy runs on a
  `macos-latest` job, because a desktop integration test needs a display
  session the Ubuntu container has not got. The widget test is the enforced
  gate; the integration test proves the real engine.
- **Emulator mode defaults to on.** Spec 7.5 says the connect screen lists
  real devices plus the emulated one, and it is also how screenshots and
  manual QA happen. `emulatorModeProvider` exists so a settings toggle can
  hide it later.
- **The wakelock polls.** The SDK exposes `readerLeaseCount` and `isBusy` as
  getters with no change notification. A one-second poll behind a
  `WakelockGateway` interface was cheaper than adding a stream to the SDK
  that nothing else would use.
- **`dfuOverBleEnabled` is stored in the `app_preferences` table**, read
  through `PreferencesRepository`, and defaults to false with an all-off
  synchronous view while preferences load. Phase 8 reads
  `featureFlagsProvider`.
- **Package versions pinned in Phase 4:** `flutter_riverpod` 3.4.2,
  `riverpod_annotation` 4.0.6, `riverpod_generator` 4.0.8, `go_router`
  18.0.1, `drift` 2.34.4, `drift_flutter` 0.3.1, `drift_dev` 2.34.6,
  `wakelock_plus` 1.8.0, `freezed` 4.0.1, `json_serializable` 6.14.1,
  `build_runner` 2.16.1.
```

- [ ] **Step 6: Record the lessons**

Append to `tasks/lessons.md` whatever actually bit during the phase. At minimum, if they held true:

```markdown
- **`pumpAndSettle` never returns in this app.** The shell and the progress
  indicator animate continuously. Every widget test pumps a bounded number
  of frames instead, through the `connectToEmulator` helper.
- **riverpod_generator names the provider after the declaration**, so a
  notifier called `ConnectionState` generates a base class that collides
  with an imported type of the same name. Name notifiers for what they hold,
  not for the type they hold.
- **A drift table's generated data class takes the table's singular name.**
  `KnownDevices` generated a `KnownDevice` that collided with the model of
  the same name; `@DataClassName('KnownDeviceRow')` fixes it, and the
  exported schema has to be re-dumped afterwards.
```

- [ ] **Step 7: Commit and push**

```bash
cd /Users/bcraig/orca/workspaces/spectra/chinook
git add AGENTS.md tasks docs
git commit -m "docs: close out Phase 4

Records the session-registry shape, the Drift setup, the two-copy
integration-test strategy and where the dfuOverBleEnabled flag lives, ticks
the roadmap and points the next session at Phase 5.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push
```

- [ ] **Step 8: Confirm CI is green**

```bash
gh run list --branch "$(git branch --show-current)" --limit 1
gh run watch
```

Expected: `check`, `integration` and every `build` matrix job green. If the macOS `integration` job is flaky, mark that job `continue-on-error: true`, say so in `AGENTS.md`, and keep the widget-test twin as the enforced gate — do not weaken the widget test.

---

## Self-review

Run after writing, fixed inline:

1. **Spec coverage.** 7.1 state → Tasks 6, 7 (family, active device, derived providers, overrides at the root only). 7.2 routing → Tasks 9, 10 (redirect rule, five destinations, deep routes on the Tools tab). 7.3 storage → Tasks 2, 3 (four tables, schema verification, repository interfaces, Drift only under `data/`); import/export of the reference app's JSON is explicitly Phase 6, not this phase. 7.4 lifecycle → Tasks 11, 12 (grace period, one silent reconnect, unexpected disconnect preselects the device in Task 6's `lastDisconnected`, wakelock). 7.5 emulator mode → Task 8. 7.6 localization → every UI task adds ARB keys; the accessibility half is inherited from `spectra_ui`'s components, which already set semantics and touch targets. 7.7 step 1 → Tasks 13 to 15. 8.3 layout → the file structure section. 8.4 enforcement → the Global Constraints, enforced by the existing `tool/dep_lint.dart`. 8.5 code shape → screens are layout only and every controller has a widget-free test. 8.6 interfaces → repositories, `WakelockGateway`, `transportFactoryProvider`; the session stays concrete and real. 9 errors and logging → Tasks 4, 16. 4.2 identity merge → Task 13. 5.1 permission and adapter states → Tasks 8, 14. 5.5 bootloader recovery entry → Tasks 14, 16. 1 progressive disclosure → Task 15's disclosure and Task 14's details row.
2. **Placeholder scan.** No "TBD", no "add error handling", no "similar to Task N". The three screens that stay placeholders (`SlotsPage`, `CardsPage`, `SettingsPage`) are placeholders *in the product*, with their full code given, not gaps in the plan.
3. **Type consistency.** `connectionStatusProvider` (not `connectionStateProvider`) is used in Tasks 7, 9, 10, 12, 15. `sessionsProvider`/`SessionsState`/`ActiveSession` agree across Tasks 6, 7, 11, 13, 15. `transportFactoryProvider` is defined in Task 6 and overridden in Tasks 6, 7, 10, 13, 17. `KnownDevice.matches` is defined in Task 2 and used in Tasks 3, 11, 13. `ErrorCatalog(AppLocalizations)` is constructed the same way in Tasks 4, 14, 15. `AppRoutes.recover` is defined in Task 9 and used in Tasks 14, 16. `FakeScanner.emulatedUltra`/`emulatedBootloader` are the SDK's constants throughout.
