# Phase 0: Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pin the toolchain, create the four-package pub workspace with CI, boundary lint and codegen checks, and answer the two spikes the spec names, so every later phase builds on a verified skeleton.

**Architecture:** A pub workspace rooted at the repo with members `packages/chameleon`, `packages/chameleon_flutter`, `packages/spectra_ui`, `app`. Melos supplies scripts only. A small Dart tool enforces the dependency table from spec section 2. GitHub Actions runs checks on Ubuntu and debug builds on all five platforms.

**Tech Stack:** mise, Flutter 3.47.2 / Dart 3.13, pub workspaces, melos, GitHub Actions, subosito/flutter-action.

**Spec:** `docs/superpowers/specs/2026-09-02-spectra-design.md` sections 2 and 11.

## Global Constraints

- Flutter 3.47.2 stable via mise; every command is `mise x -- flutter ...` or `mise x -- dart ...`.
- Package names: `chameleon`, `chameleon_flutter`, `spectra_ui`, `spectra` (the app, in `app/`).
- Dependency table (spec 2) verbatim: chameleon may use Dart SDK, meta, collection, freezed, archive; chameleon_flutter may use chameleon, flutter, universal_ble, libserialport_plus, usb_serial; spectra_ui may use flutter, material_ui, google_fonts, flutter_animate, flutter_localizations; app may use all three packages, riverpod, go_router, drift, flutter_localizations, wakelock_plus.
- Generated files are committed; CI regenerates and fails on a diff.
- Commit after every task with the trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- This is a git worktree; never use bare `git stash`.

---

## File structure

```
mise.toml                         toolchain pin
pubspec.yaml                      workspace root, melos scripts, root dev deps
analysis_options.yaml             shared lints
.gitignore
tool/dep_lint.dart                boundary lint entry point
tool/src/dep_rules.dart           pure rule evaluation (tested)
tool/check_codegen.sh             regenerate and diff
test/dep_rules_test.dart          root-level tests for the lint rules
packages/chameleon/               pure Dart package skeleton
packages/chameleon_flutter/       Flutter package skeleton
packages/spectra_ui/              Flutter package skeleton + example/
app/                              Flutter app skeleton, all five platforms
.github/workflows/ci.yml          checks + debug build matrix
docs/research/spikes.md           spike verdicts
```

---

### Task 1: Pin the toolchain with mise

**Files:**
- Create: `mise.toml`

**Interfaces:**
- Produces: `mise x -- flutter` resolving to 3.47.2 for every later task.

- [ ] **Step 1: Write the pin**

```toml
# mise.toml
[tools]
flutter = "3.47.2"
```

- [ ] **Step 2: Install and verify**

Run: `mise install && mise x -- flutter --version && mise x -- dart --version`
Expected: `Flutter 3.47.2 • channel stable` and `Dart SDK version: 3.13.x`. If `flutter --version` without `mise x` still shows 3.32.5, that is the fvm shim earlier on PATH; it is fine because every command in these plans goes through `mise x`.

- [ ] **Step 3: Precache desktop and mobile artifacts**

Run: `mise x -- flutter precache --macos --ios --android`
Expected: completes without error.

- [ ] **Step 4: Commit**

```bash
git add mise.toml
git commit -m "build: pin Flutter 3.47.2 with mise

Spec section 2 requires mise, not FVM, and Flutter 3.47.x."
```

---

### Task 2: Workspace root and the pure-Dart SDK skeleton

**Files:**
- Create: `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`
- Create: `packages/chameleon/pubspec.yaml`, `packages/chameleon/lib/chameleon.dart`, `packages/chameleon/test/smoke_test.dart`, `packages/chameleon/analysis_options.yaml`

**Interfaces:**
- Produces: workspace resolution; `package:chameleon/chameleon.dart` exporting `const String chameleonSdkVersion`.

- [ ] **Step 1: Write the root pubspec**

```yaml
# pubspec.yaml
name: spectra_workspace
description: Workspace root for Spectra. Not published.
publish_to: none

environment:
  sdk: ^3.13.0

workspace:
  - packages/chameleon

dev_dependencies:
  melos: ^8.0.0
  test: ^1.25.0

melos:
  scripts:
    analyze:
      run: dart analyze --fatal-infos .
      description: Analyze every package.
    format:
      run: dart format --set-exit-if-changed .
      description: Fail if any file is not formatted.
    test:dart:
      run: melos exec --fail-fast -- dart test
      packageFilters:
        flutter: false
        dirExists: test
    test:flutter:
      run: melos exec --fail-fast -- flutter test
      packageFilters:
        flutter: true
        dirExists: test
    lint:deps:
      run: dart run tool/dep_lint.dart
    check:codegen:
      run: bash tool/check_codegen.sh
    check:all:
      run: melos run format && melos run analyze && melos run lint:deps && melos run check:codegen && melos run test:dart && melos run test:flutter
```

(Later tasks append more members to `workspace:`.)

- [ ] **Step 2: Write shared analysis options**

```yaml
# analysis_options.yaml
include: package:lints/recommended.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"

linter:
  rules:
    - always_declare_return_types
    - avoid_dynamic_calls
    - avoid_print
    - directives_ordering
    - prefer_final_locals
    - prefer_single_quotes
    - unawaited_futures
    - implementation_imports
```

Add `lints: ^5.0.0` to root `dev_dependencies`.

- [ ] **Step 3: Write .gitignore**

```
.dart_tool/
build/
*.iml
.idea/
.vscode/
pubspec.lock
!/pubspec.lock
coverage/
.flutter-plugins-dependencies
**/ios/Pods/
**/macos/Pods/
**/*.lock
!/pubspec.lock
```

Note: with a pub workspace there is exactly one `pubspec.lock`, at the root, and it is committed.

- [ ] **Step 4: Write the SDK package skeleton**

```yaml
# packages/chameleon/pubspec.yaml
name: chameleon
description: Clean-room Dart SDK for the Chameleon Ultra and Chameleon Lite.
version: 0.1.0
publish_to: none
resolution: workspace

environment:
  sdk: ^3.13.0

dependencies:
  collection: ^1.19.0
  meta: ^1.16.0

dev_dependencies:
  test: ^1.25.0
```

```dart
// packages/chameleon/lib/chameleon.dart
/// Clean-room Dart SDK for the Chameleon Ultra and Chameleon Lite.
///
/// Pure Dart: this library never imports Flutter.
library;

/// Version of the SDK, mirrored from pubspec.yaml.
const String chameleonSdkVersion = '0.1.0';
```

```yaml
# packages/chameleon/analysis_options.yaml
include: ../../analysis_options.yaml
```

```dart
// packages/chameleon/test/smoke_test.dart
import 'package:chameleon/chameleon.dart';
import 'package:test/test.dart';

void main() {
  test('exposes an SDK version', () {
    expect(chameleonSdkVersion, '0.1.0');
  });
}
```

- [ ] **Step 5: Resolve and run**

Run: `mise x -- dart pub get && cd packages/chameleon && mise x -- dart test`
Expected: `All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock analysis_options.yaml .gitignore packages/chameleon
git commit -m "build: create pub workspace with chameleon SDK skeleton

Workspace root holds melos scripts only; chameleon is pure Dart."
```

---

### Task 3: Flutter package skeletons and the app

**Files:**
- Create: `packages/chameleon_flutter/` (via flutter create), `packages/spectra_ui/` (+ `example/`), `app/`
- Modify: `pubspec.yaml` (workspace members)

**Interfaces:**
- Produces: package names `chameleon_flutter`, `spectra_ui`, `spectra`; app entry `app/lib/main.dart`.

- [ ] **Step 1: Create the two Flutter packages**

Run from the worktree root:

```bash
mise x -- flutter create --template=package --project-name chameleon_flutter packages/chameleon_flutter
mise x -- flutter create --template=package --project-name spectra_ui packages/spectra_ui
mise x -- flutter create --template=app --org dev.spectra --project-name spectra_ui_gallery --platforms=macos,windows,linux packages/spectra_ui/example
```

In each generated `pubspec.yaml`: set `publish_to: none`, add `resolution: workspace`, set `environment: sdk: ^3.13.0`, delete the generated `pubspec.lock` if any, and replace `analysis_options.yaml` with `include: ../../analysis_options.yaml` (`../../../analysis_options.yaml` for the example). Replace the generated `lib/<name>.dart` bodies with a doc comment and one const, and the generated test with a smoke test, following the Task 2 pattern:

```dart
// packages/chameleon_flutter/lib/chameleon_flutter.dart
/// Platform transports and DFU channels for the chameleon SDK.
library;

const String chameleonFlutterVersion = '0.1.0';
```

```dart
// packages/spectra_ui/lib/spectra_ui.dart
/// Spectra design system: tokens, theme and core components.
library;

const String spectraUiVersion = '0.1.0';
```

Add `chameleon: ^0.1.0` under `dependencies` in `packages/chameleon_flutter/pubspec.yaml` and `spectra_ui: ^0.1.0` in the example's pubspec.

- [ ] **Step 2: Create the app**

```bash
mise x -- flutter create --template=app --org dev.spectra --project-name spectra --platforms=windows,macos,linux,android,ios app
```

Apply the same pubspec edits (`publish_to: none`, `resolution: workspace`, sdk `^3.13.0`). Add dependencies `chameleon`, `chameleon_flutter`, `spectra_ui` at `^0.1.0`. Replace `app/lib/main.dart`:

```dart
import 'package:flutter/widgets.dart';

void main() {
  runApp(const SpectraApp());
}

/// Placeholder root until Phase 4 builds the shell.
class SpectraApp extends StatelessWidget {
  const SpectraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Color(0xFFFFFFFF),
        child: Center(child: Text('Spectra')),
      ),
    );
  }
}
```

Replace `app/test/widget_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/main.dart';

void main() {
  testWidgets('renders the placeholder', (tester) async {
    await tester.pumpWidget(const SpectraApp());
    expect(find.text('Spectra'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Register members and resolve**

Set the root `workspace:` list to:

```yaml
workspace:
  - packages/chameleon
  - packages/chameleon_flutter
  - packages/spectra_ui
  - packages/spectra_ui/example
  - app
```

Run: `mise x -- flutter pub get`
Expected: resolves with one root `pubspec.lock`.

- [ ] **Step 4: Run every test**

Run: `mise x -- dart run melos run test:dart && mise x -- dart run melos run test:flutter`
Expected: all four packages report passing tests.

- [ ] **Step 5: Build the app once on macOS**

Run: `cd app && mise x -- flutter build macos --debug`
Expected: `Build succeeded`. Fix any generated-project warnings before committing.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock packages app
git commit -m "build: add chameleon_flutter, spectra_ui and app skeletons

All five app platforms are generated now so CI can build them from
the first pull request."
```

---

### Task 4: Dependency lint

**Files:**
- Create: `tool/src/dep_rules.dart`, `tool/dep_lint.dart`, `test/dep_rules_test.dart`

**Interfaces:**
- Produces: `List<Violation> checkFile({required String packageName, required String relativePath, required List<String> imports})` and `int runDepLint(Directory root)`; melos script `lint:deps`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/dep_rules_test.dart
import 'package:test/test.dart';

import '../tool/src/dep_rules.dart';

void main() {
  group('package allowlists', () {
    test('chameleon may not import flutter', () {
      final v = checkFile(
        packageName: 'chameleon',
        relativePath: 'lib/src/codec/frame.dart',
        imports: ['package:flutter/material.dart'],
      );
      expect(v.map((e) => e.rule), contains('package-allowlist'));
    });

    test('chameleon may import collection and dart core', () {
      final v = checkFile(
        packageName: 'chameleon',
        relativePath: 'lib/src/codec/frame.dart',
        imports: ['dart:typed_data', 'package:collection/collection.dart', 'lrc.dart'],
      );
      expect(v, isEmpty);
    });

    test('spectra_ui may not import chameleon', () {
      final v = checkFile(
        packageName: 'spectra_ui',
        relativePath: 'lib/src/slot_tile.dart',
        imports: ['package:chameleon/chameleon.dart'],
      );
      expect(v.map((e) => e.rule), contains('package-allowlist'));
    });

    test('test files may import test-only packages', () {
      final v = checkFile(
        packageName: 'chameleon',
        relativePath: 'test/frame_test.dart',
        imports: ['package:test/test.dart', 'package:fake_async/fake_async.dart'],
      );
      expect(v, isEmpty);
    });
  });

  group('app structure', () {
    test('feature may not import another feature internals', () {
      final v = checkFile(
        packageName: 'spectra',
        relativePath: 'lib/features/cards/ui/card_list.dart',
        imports: ['package:spectra/features/slots/state/slots_notifier.dart'],
      );
      expect(v.map((e) => e.rule), contains('feature-internals'));
    });

    test('feature may import another feature barrel', () {
      final v = checkFile(
        packageName: 'spectra',
        relativePath: 'lib/features/cards/ui/card_list.dart',
        imports: ['package:spectra/features/slots/slots.dart'],
      );
      expect(v, isEmpty);
    });

    test('drift only under data', () {
      final bad = checkFile(
        packageName: 'spectra',
        relativePath: 'lib/features/cards/state/cards_notifier.dart',
        imports: ['package:drift/drift.dart'],
      );
      expect(bad.map((e) => e.rule), contains('drift-in-data-only'));
      final ok = checkFile(
        packageName: 'spectra',
        relativePath: 'lib/data/cards_repository.dart',
        imports: ['package:drift/drift.dart'],
      );
      expect(ok, isEmpty);
    });

    test('no material import under features', () {
      final v = checkFile(
        packageName: 'spectra',
        relativePath: 'lib/features/slots/ui/slot_grid.dart',
        imports: ['package:flutter/material.dart'],
      );
      expect(v.map((e) => e.rule), contains('no-material-in-features'));
    });

    test('nobody imports chameleon src', () {
      final v = checkFile(
        packageName: 'spectra',
        relativePath: 'lib/core/session.dart',
        imports: ['package:chameleon/src/commands/device.dart'],
      );
      expect(v.map((e) => e.rule), contains('sdk-internals'));
    });
  });

  test('extracts imports from source text', () {
    const src = '''
import 'dart:async';
import "package:meta/meta.dart";
export 'foo.dart';
part 'bar.g.dart';
// import 'not/real.dart';
''';
    expect(extractImports(src), ['dart:async', 'package:meta/meta.dart', 'foo.dart']);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `mise x -- dart test test/dep_rules_test.dart`
Expected: FAIL, `dep_rules.dart` not found.

- [ ] **Step 3: Write the rules**

```dart
// tool/src/dep_rules.dart
/// Pure evaluation of the dependency rules from spec section 2 and 8.4.
library;

final class Violation {
  const Violation(this.rule, this.file, this.import, this.message);
  final String rule;
  final String file;
  final String import;
  final String message;

  @override
  String toString() => '$file: [$rule] $import: $message';
}

/// Packages each workspace member may import, besides itself and `dart:`.
const Map<String, Set<String>> allowlists = {
  'chameleon': {
    'meta', 'collection', 'freezed_annotation', 'archive', 'crypto',
  },
  'chameleon_flutter': {
    'chameleon', 'flutter', 'universal_ble', 'libserialport_plus', 'usb_serial',
  },
  'spectra_ui': {
    'flutter', 'material_ui', 'google_fonts', 'flutter_animate',
    'flutter_localizations', 'intl',
  },
  'spectra_ui_gallery': {'flutter', 'spectra_ui', 'material_ui'},
};

/// Packages any member may import from `test/` or `integration_test/`.
const Set<String> testOnly = {
  'test', 'flutter_test', 'fake_async', 'mocktail', 'alchemist',
  'integration_test',
};

const String appPackage = 'spectra';

List<String> extractImports(String source) {
  final out = <String>[];
  final re = RegExp(r'''^\s*(import|export)\s+['"]([^'"]+)['"]''', multiLine: true);
  for (final m in re.allMatches(source)) {
    out.add(m.group(2)!);
  }
  return out;
}

String? _packageOf(String import) {
  if (!import.startsWith('package:')) return null;
  final rest = import.substring('package:'.length);
  final slash = rest.indexOf('/');
  return slash < 0 ? rest : rest.substring(0, slash);
}

bool _isTestPath(String p) =>
    p.startsWith('test/') || p.startsWith('integration_test/');

List<Violation> checkFile({
  required String packageName,
  required String relativePath,
  required List<String> imports,
}) {
  final out = <Violation>[];
  for (final imp in imports) {
    final pkg = _packageOf(imp);
    if (pkg == null) continue; // dart: or relative

    if (pkg == 'chameleon' &&
        imp.startsWith('package:chameleon/src/') &&
        packageName != 'chameleon') {
      out.add(Violation('sdk-internals', relativePath, imp,
          'commands and internals are private to the SDK'));
    }

    if (packageName == appPackage) {
      out.addAll(_checkApp(relativePath, imp, pkg));
      continue;
    }

    if (pkg == packageName) continue;
    final allowed = allowlists[packageName];
    if (allowed == null) continue; // unknown package: no rule
    final ok = allowed.contains(pkg) ||
        (_isTestPath(relativePath) && testOnly.contains(pkg));
    if (!ok) {
      out.add(Violation('package-allowlist', relativePath, imp,
          '$packageName may not depend on $pkg'));
    }
  }
  return out;
}

List<Violation> _checkApp(String path, String imp, String pkg) {
  final out = <Violation>[];
  final inFeatures = path.startsWith('lib/features/');
  if (inFeatures && pkg == 'flutter' && imp.endsWith('/material.dart')) {
    out.add(Violation('no-material-in-features', path, imp,
        'use spectra_ui components instead of raw Material'));
  }
  if (pkg == 'drift' && !path.startsWith('lib/data/')) {
    out.add(Violation('drift-in-data-only', path, imp,
        'Drift may only appear under lib/data/'));
  }
  if (inFeatures && imp.startsWith('package:$appPackage/features/')) {
    final me = path.split('/')[2];
    final target = imp.substring('package:$appPackage/features/'.length);
    final parts = target.split('/');
    final other = parts.first;
    final isBarrel = parts.length == 2 && parts[1] == '$other.dart';
    if (other != me && !isBarrel) {
      out.add(Violation('feature-internals', path, imp,
          'feature $me may only import features/$other/$other.dart'));
    }
  }
  return out;
}
```

```dart
// tool/dep_lint.dart
import 'dart:io';

import 'src/dep_rules.dart';

const _members = {
  'chameleon': 'packages/chameleon',
  'chameleon_flutter': 'packages/chameleon_flutter',
  'spectra_ui': 'packages/spectra_ui',
  'spectra_ui_gallery': 'packages/spectra_ui/example',
  'spectra': 'app',
};

int runDepLint(Directory root) {
  var count = 0;
  for (final entry in _members.entries) {
    final dir = Directory('${root.path}/${entry.value}');
    if (!dir.existsSync()) continue;
    for (final sub in const ['lib', 'test', 'integration_test']) {
      final d = Directory('${dir.path}/$sub');
      if (!d.existsSync()) continue;
      for (final f in d.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final rel = f.path.substring(dir.path.length + 1);
        final violations = checkFile(
          packageName: entry.key,
          relativePath: rel,
          imports: extractImports(f.readAsStringSync()),
        );
        for (final v in violations) {
          stderr.writeln('${entry.value}/$v');
          count++;
        }
      }
    }
  }
  return count;
}

void main() {
  final count = runDepLint(Directory.current);
  if (count > 0) {
    stderr.writeln('dep_lint: $count violation(s)');
    exit(1);
  }
  stdout.writeln('dep_lint: ok');
}
```

- [ ] **Step 4: Run tests and the lint**

Run: `mise x -- dart test test/dep_rules_test.dart && mise x -- dart run tool/dep_lint.dart`
Expected: tests pass; `dep_lint: ok`.

- [ ] **Step 5: Commit**

```bash
git add tool test
git commit -m "build: add dependency lint for package and feature boundaries

Encodes the spec section 2 table and the section 8.4 app rules so
CI, not convention, keeps the SDK pure and features isolated."
```

---

### Task 5: Codegen freshness check

**Files:**
- Create: `tool/check_codegen.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# Regenerates code in every package that uses build_runner and fails if
# the committed generated files differ.
set -euo pipefail
cd "$(dirname "$0")/.."
# Locally, commands go through mise. On CI mise is absent: set MISE_X="".
MISE_X="${MISE_X-mise x --}"
for pkg in packages/chameleon packages/chameleon_flutter packages/spectra_ui app; do
  if grep -q "build_runner" "$pkg/pubspec.yaml" 2>/dev/null; then
    echo "codegen: $pkg"
    (cd "$pkg" && $MISE_X dart run build_runner build --delete-conflicting-outputs >/dev/null)
  fi
done
if ! git diff --quiet -- '*.g.dart' '*.freezed.dart' '*.drift.dart'; then
  echo "codegen: committed generated files are stale:" >&2
  git --no-pager diff --stat -- '*.g.dart' '*.freezed.dart' '*.drift.dart' >&2
  exit 1
fi
echo "codegen: ok"
```

- [ ] **Step 2: Run it**

Run: `chmod +x tool/check_codegen.sh && bash tool/check_codegen.sh`
Expected: `codegen: ok` (no package uses build_runner yet).

- [ ] **Step 3: Commit**

```bash
git add tool/check_codegen.sh
git commit -m "build: add generated-code freshness check"
```

---

### Task 6: CI workflow

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Write the workflow**

```yaml
name: ci
on:
  pull_request:
  push:
    branches: [main]

env:
  FLUTTER_VERSION: 3.47.2

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: stable
          cache: true
      - run: sudo apt-get update && sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev
      - run: flutter pub get
      - run: dart format --set-exit-if-changed .
      - run: dart analyze --fatal-infos .
      - run: dart run tool/dep_lint.dart
      - run: bash tool/check_codegen.sh
        env:
          MISE_X: ""
      - run: dart run melos run test:dart
      - run: dart run melos run test:flutter

  build:
    needs: check
    strategy:
      fail-fast: false
      matrix:
        include:
          - os: ubuntu-latest
            target: linux
            cmd: flutter build linux --debug
          - os: windows-latest
            target: windows
            cmd: flutter build windows --debug
          - os: macos-latest
            target: macos
            cmd: flutter build macos --debug
          - os: macos-latest
            target: ios
            cmd: flutter build ios --debug --no-codesign
          - os: ubuntu-latest
            target: android
            cmd: flutter build apk --debug
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: stable
          cache: true
      - if: matrix.target == 'linux'
        run: sudo apt-get update && sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev
      - if: matrix.target == 'android'
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
      - run: flutter pub get
      - run: ${{ matrix.cmd }}
        working-directory: app
```

- [ ] **Step 2: Run the same checks locally**

Run: `mise x -- dart run melos run check:all`
Expected: every script passes.

- [ ] **Step 3: Commit and push**

```bash
git add .github
git commit -m "ci: run checks on Ubuntu and debug builds on all five platforms

Building every platform on each pull request surfaces platform
breakage early instead of at release time (spec section 10)."
git push -u origin HEAD
```

Open a pull request and confirm the `check` and all five `build` jobs are green before starting Task 7. If a build job fails on a generated-project detail (for example a Linux CMake version), fix it in this task.

---

### Task 7: Spike A, serial build hooks on desktop

**Files:**
- Modify: `packages/chameleon_flutter/pubspec.yaml`
- Create: `packages/chameleon_flutter/example/` (flutter create, macOS/Windows/Linux), `docs/research/spikes.md`

This is a spike: the deliverable is a verdict, and any code written here is deleted or rewritten in Phase 3.

- [ ] **Step 1: Add the dependency and a probe**

Run: `cd packages/chameleon_flutter && mise x -- dart pub add libserialport_plus`

Create `packages/chameleon_flutter/example` with `flutter create --template=app --platforms=macos,windows,linux --project-name serial_probe`. Add it to the workspace. In its `main.dart`, list serial ports on start and print each port's name, manufacturer and USB VID/PID using the package's port enumeration API (read the package README for the exact call; record the call you used in the spike notes).

- [ ] **Step 2: Run on macOS with the device plugged in**

Ask the user to plug in the Chameleon Ultra, then run: `cd packages/chameleon_flutter/example && mise x -- flutter run -d macos`
Expected: a port with VID 0x6868 and PID 0x8686 is printed. If the user is unavailable, run without the device and record that enumeration itself works.

- [ ] **Step 3: Build on Windows and Linux through CI**

Add the probe to the CI build matrix temporarily (`working-directory: packages/chameleon_flutter/example`), push, and record whether the build hooks compile libserialport on both runners.

- [ ] **Step 4: Record the verdict**

Write `docs/research/spikes.md` with a section "Spike A: libserialport_plus build hooks" containing: package version, the enumeration call used, macOS result, Windows result, Linux result, sandbox or signing observations, and the verdict: keep `libserialport_plus`, or fall back to a named alternative. If falling back, amend spec section 5.2 in the same commit.

- [ ] **Step 5: Clean up and commit**

Remove the probe from the CI matrix. Keep the example app only if the verdict is "keep" (Phase 3 turns it into the transport example); otherwise delete it.

```bash
git add -A packages/chameleon_flutter docs/research/spikes.md pubspec.yaml pubspec.lock .github
git commit -m "spike: validate libserialport_plus build hooks on desktop"
```

---

### Task 8: Spike B, material_ui with go_router and alchemist

**Files:**
- Modify: `packages/spectra_ui/pubspec.yaml`, `packages/spectra_ui/example/`
- Modify: `docs/research/spikes.md`

- [ ] **Step 1: Add the dependencies**

Run in `packages/spectra_ui`: `mise x -- dart pub add material_ui && mise x -- dart pub add dev:alchemist`. In `packages/spectra_ui/example`: `mise x -- dart pub add go_router`.

- [ ] **Step 2: Build the probe**

In the example app: a `GoRouter` with two routes. Each route's page contains one `material_ui` button and one text field styled through whatever theming entry point `material_ui` exposes (read its README and API docs; record the names). Verify: the app runs on macOS, navigation works, and the components take the theme.

- [ ] **Step 3: Golden probe**

In `packages/spectra_ui/test/spike_golden_test.dart`, write one alchemist golden test rendering the same `material_ui` button in light and dark. Run: `mise x -- flutter test --update-goldens && mise x -- flutter test`.
Expected: golden files generate and the test passes on a second run.

- [ ] **Step 4: Record the verdict**

Append "Spike B: material_ui coexistence" to `docs/research/spikes.md`: package version, the theming entry point, whether `material_ui` uses the in-SDK `ThemeData` or its own, how go_router page transitions behaved, whether alchemist needed a `MaterialApp` wrapper, and the verdict: build `spectra_ui` on `material_ui` with a bridge file, or fall back to in-SDK Material 3. If falling back, amend spec section 6 in the same commit.

- [ ] **Step 5: Clean up and commit**

Delete the spike golden test and its files; keep the example app as the future gallery shell.

```bash
git add -A packages/spectra_ui docs/research/spikes.md pubspec.yaml pubspec.lock
git commit -m "spike: validate material_ui with go_router and alchemist"
```

---

### Task 9: Close the phase

**Files:**
- Modify: `AGENTS.md`, `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md`, `tasks/lessons.md`

- [ ] **Step 1: Run the full check**

Run: `mise x -- dart run melos run check:all`
Expected: all pass.

- [ ] **Step 2: Update status**

In `AGENTS.md` "Current status", state that Phase 0 is complete, name the spike verdicts, and point at Phase 1 and Phase 2 plans as the next steps. Tick Phase 0 in the roadmap. Add any lessons (toolchain quirks, CI fixes) to `tasks/lessons.md`.

- [ ] **Step 3: Commit**

```bash
git add AGENTS.md docs tasks
git commit -m "docs: close Phase 0 foundation"
```
