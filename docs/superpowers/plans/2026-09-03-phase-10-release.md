# Phase 10: Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the working app into a shippable release: a `release.yml`
workflow that builds signed-when-possible artifacts for all five platforms
and attaches them to a GitHub pre-release, a changelog, a release runbook,
the H3 hardware checklist, and an annotated `v1.0.0-rc.1` tag.

**Architecture:** Every packaging decision lives in a script under
`tool/package/` (shell/PowerShell) or a pure-Dart module under `tool/src/`
that is unit-tested from the workspace root's `dart test` suite, exactly the
way `tool/src/dep_rules.dart` is tested by `test/dep_rules_test.dart`. The
workflow is a thin caller: it never contains a signing decision of its own,
it hands the scripts environment variables, and each script degrades to an
unsigned/ad-hoc artifact when its secret is absent, so a fork or a
`workflow_dispatch` without secrets still produces every artifact.
`.github/workflows/release.yml` gains no duplicate of the `check` job: it
calls `ci.yml` through a new `workflow_call` trigger, which also gives the
release the existing macOS `integration` job for free.

**Tech Stack:** GitHub Actions (`actions/checkout@v4`,
`subosito/flutter-action@v2`, `actions/setup-java@v4`,
`actions/upload-artifact@v4`, `actions/download-artifact@v4`,
`softprops/action-gh-release@v2`), Flutter 3.47.2, Dart 3.13, bash,
PowerShell, `hdiutil`/`codesign`/`notarytool`, Inno Setup (`ISCC`, preinstalled
on `windows-latest`), `appimagetool`, Gradle Kotlin DSL.

**Spec:** `docs/superpowers/specs/2026-09-02-spectra-design.md` (section 10
"Testing, CI and release"; section 5.7 platform setup; section 2 workspace
and dependency table). Roadmap row: `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md`.

## Global Constraints

Everything in the roadmap's Global Constraints applies. Repeated here with
the Phase 6 standing rulings that survive into this phase, because a task
implementer sees only their own task.

- Toolchain pinned in `mise.toml`: `flutter = "3.47.2"` (bundles Dart 3.13).
  On this Mac `mise x --` does not put Flutter first on PATH; run
  `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"` in the
  same shell command before any `dart`, `flutter` or `melos` invocation.
- **Cite landed source for every name.** Before writing a file path, an env
  var, a build-output path or a Dart identifier into code, open the landed
  file and confirm it. Do not invent names. Everything this plan names was
  read out of the repo on 2026-09-03; if a name has moved, fix the plan's
  reference rather than guessing a new one.
- **Foreground test runs only.** Never background a test run and poll it.
- `dart run melos run check:all` must be green at every commit. It chains
  `format`, `analyze`, `lint:deps`, `test:root`, `check:codegen`,
  `test:dart`, `test:flutter`.
- New Dart under `tool/` is formatted by `dart format --set-exit-if-changed
  packages app tool test` and analysed by `dart analyze --fatal-infos packages
  app tool test` against root `analysis_options.yaml`
  (`package:lints/recommended.yaml`, strict casts/inference/raw-types, plus
  `avoid_print`, `prefer_final_locals`, `prefer_single_quotes`,
  `always_declare_return_types`, `directives_ordering`). Write to
  `stdout`/`stderr`, never `print`.
- TDD for every task: failing test, minimal code, passing test, commit.
  Commit messages: imperative subject, short body explaining why, trailer
  `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- **Every CI change follows the existing job shape and never weakens an
  existing job.** `ci.yml`'s `check`, `integration` and `build` jobs keep
  their current triggers, `concurrency` group (`ci-${{ github.ref }}`,
  `cancel-in-progress: true`), `env.FLUTTER_VERSION: 3.47.2`, timeouts and
  step order. The only permitted edit to `ci.yml` in this phase is adding a
  `workflow_call:` trigger (Task 9).
- **Every action is pinned to a major version tag** (`@v4`, `@v2`), matching
  the landed workflows.
- **Secrets are referenced by name only** — `secrets.MACOS_CERT_P12`,
  `secrets.MACOS_CERT_PASSWORD`, `secrets.MACOS_SIGN_IDENTITY`,
  `secrets.MACOS_NOTARY_APPLE_ID`, `secrets.MACOS_NOTARY_TEAM_ID`,
  `secrets.MACOS_NOTARY_PASSWORD`, `secrets.WINDOWS_CERT_PFX`,
  `secrets.WINDOWS_CERT_PASSWORD`, `secrets.ANDROID_KEYSTORE_BASE64`,
  `secrets.ANDROID_KEYSTORE_PASSWORD`, `secrets.ANDROID_KEY_ALIAS`,
  `secrets.ANDROID_KEY_PASSWORD`. No value, fingerprint, team id or Apple ID
  is written into the repo. **Every signing step degrades gracefully when its
  secret is absent** — the artifact is still produced, unsigned or ad-hoc
  signed, and the script says so on stdout. The decision lives in the script,
  never in a workflow `if:`, so a fork PR build behaves identically.
- **Nothing in this phase tags `v1.0.0`.** The only tag created is the
  annotated `v1.0.0-rc.1` (Task 11), and only after CI is green. `v1.0.0`
  waits for the user's H3 report and is created by the user or by a later
  session, never by this plan.
- **The LICENSE decision is the user's.** `packages/spectra_ui/LICENSE` and
  `packages/chameleon_flutter/LICENSE` both read `TODO: Add your license
  here.`; `packages/chameleon` and `app` have no LICENSE file at all. This
  plan must **not** choose a licence. It adds a checklist item and makes the
  release preflight report the state as a warning that never fails the job.
- Never claim hardware behaviour works without the user running
  `docs/hardware-checklist.md`. Items stay `- [ ] pending` until the user
  reports back.
- All user-facing app strings go through `app/lib/l10n/app_en.arb`. This
  phase adds no app strings; if a task thinks it needs one, it is out of
  scope.
- This is a git worktree. Never use bare `git stash`.

## Landed facts this plan is written against

Read on 2026-09-03; every task below depends on these being true.

| Fact | Source |
|---|---|
| App version `1.0.0+1` | `app/pubspec.yaml` |
| Bundle id `dev.spectra.spectra` on all five platforms | `app/macos/Runner/Configs/AppInfo.xcconfig`, `app/ios/Runner.xcodeproj/project.pbxproj`, `app/android/app/build.gradle.kts`, `app/linux/CMakeLists.txt` |
| Desktop binary name `spectra`; macOS `PRODUCT_NAME = spectra` | `app/linux/CMakeLists.txt:7`, `app/windows/CMakeLists.txt:7`, `app/macos/Runner/Configs/AppInfo.xcconfig` |
| macOS release entitlements: sandbox, bluetooth, serial | `app/macos/Runner/Release.entitlements` |
| Android release build signs with the **debug** keystore, marked `// TODO` | `app/android/app/build.gradle.kts:33-37` |
| iOS Info.plist carries both Bluetooth usage strings | `app/ios/Runner/Info.plist` |
| Repo-file assertions belong in root `test/*.dart` and run under `dart test` | `test/platform_setup_test.dart` |
| Vendored `usb_serial` override at `third_party/usb_serial` | root `pubspec.yaml` `dependency_overrides` |
| App icons are still the `flutter create` defaults | `app/macos/Runner/Assets.xcassets/AppIcon.appiconset/`, `app/android/app/src/main/res/mipmap-*/` |

Flutter 3.47.2 release output paths, relative to `app/`:

- macOS: `build/macos/Build/Products/Release/spectra.app`
- Windows: `build/windows/x64/runner/Release/` (contains `spectra.exe`)
- Linux: `build/linux/x64/release/bundle/` (contains `spectra`)
- Android: `build/app/outputs/flutter-apk/app-release.apk`,
  `build/app/outputs/bundle/release/app-release.aab`
- iOS: `build/ios/iphoneos/Runner.app`

## File structure

**Created**

| File | Responsibility |
|---|---|
| `tool/src/release_version.dart` | Parse a `v*` tag, reconcile it with `app/pubspec.yaml`, expose build-name/build-number/apple-build-name/slug |
| `tool/src/changelog.dart` | Parse Keep a Changelog, expose the latest released entry |
| `tool/src/license_status.dart` | Classify each package's LICENSE as chosen/todo/missing |
| `tool/check_release.dart` | Preflight CLI: validates version + changelog, warns on LICENSE, writes `GITHUB_OUTPUT` keys |
| `CHANGELOG.md` | Keep a Changelog file with the v1.0.0 entry |
| `tool/package/macos_dmg.sh` | Sign (or ad-hoc sign), package and notarize the macOS `.app` into a `.dmg` |
| `tool/package/windows_installer.ps1` | Build the Inno Setup installer and the portable zip, sign when a cert exists |
| `tool/package/windows/spectra.iss` | Inno Setup script |
| `tool/package/linux_appimage.sh` | Build the AppImage and the tarball from the Linux bundle |
| `tool/package/linux/spectra.desktop` | Freedesktop entry used by the AppImage |
| `tool/package/ios_ipa.sh` | Wrap the unsigned `Runner.app` into an `.ipa` |
| `app/android/key.properties.example` | Documents the four keystore properties; the real file is git-ignored |
| `.github/workflows/release.yml` | The release workflow |
| `docs/RELEASING.md` | The release runbook (secrets, versioning, TestFlight path, licence and icon decisions) |
| `test/release_version_test.dart`, `test/changelog_test.dart`, `test/license_status_test.dart`, `test/packaging_test.dart`, `test/release_workflow_test.dart`, `test/release_docs_test.dart` | The tests for all of the above |

**Modified**

| File | Change |
|---|---|
| `app/android/app/build.gradle.kts` | Real release signing config with a debug fallback (Task 7) |
| `.gitignore` | Ignore `app/android/key.properties` and `*.keystore`/`*.jks` (Task 7) |
| `.github/workflows/ci.yml` | Add a `workflow_call:` trigger — nothing else (Task 9) |
| `pubspec.yaml` | Add the `check:release` melos script (Task 3) |
| `docs/hardware-checklist.md` | Replace the H3 stub with the full section (Task 10) |
| `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md`, `AGENTS.md`, `docs/research/DECISIONS.md`, `tasks/lessons.md` | Close-out (Task 11) |

---

### Task 1: Release version tooling

**Files:**
- Create: `tool/src/release_version.dart`
- Test: `test/release_version_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class ReleaseVersion` with fields `String tag`, `String core`,
    `String? preRelease`, `int buildNumber`, and getters
    `String get buildName`, `String get appleBuildName`,
    `bool get isPreRelease`, `String get slug`,
    `Map<String, String> get outputs`.
  - `ReleaseVersion parseRelease({required String tag, required String pubspecSource})`
  - `String pubspecVersion(String pubspecSource)`

- [ ] **Step 1: Write the failing test**

Create `test/release_version_test.dart`:

```dart
import 'dart:io';

import 'package:test/test.dart';

import '../tool/src/release_version.dart';

const String _pubspec = '''
name: spectra
publish_to: none
version: 1.0.0+1

environment:
  sdk: ^3.13.0
''';

void main() {
  group('pubspecVersion', () {
    test('reads the version line', () {
      expect(pubspecVersion(_pubspec), '1.0.0+1');
    });

    test('throws when there is no version line', () {
      expect(() => pubspecVersion('name: spectra\n'), throwsFormatException);
    });
  });

  group('parseRelease', () {
    test('a final tag carries no pre-release', () {
      final ReleaseVersion v = parseRelease(
        tag: 'v1.0.0',
        pubspecSource: _pubspec,
      );
      expect(v.core, '1.0.0');
      expect(v.preRelease, isNull);
      expect(v.isPreRelease, isFalse);
      expect(v.buildName, '1.0.0');
      expect(v.appleBuildName, '1.0.0');
      expect(v.buildNumber, 1);
      expect(v.slug, 'spectra-1.0.0');
    });

    test('a release candidate keeps the pre-release in the build name', () {
      final ReleaseVersion v = parseRelease(
        tag: 'v1.0.0-rc.1',
        pubspecSource: _pubspec,
      );
      expect(v.preRelease, 'rc.1');
      expect(v.isPreRelease, isTrue);
      expect(v.buildName, '1.0.0-rc.1');
      expect(v.slug, 'spectra-1.0.0-rc.1');
    });

    test('appleBuildName drops the pre-release', () {
      // CFBundleShortVersionString has to be three numbers; a build named
      // 1.0.0-rc.1 is rejected by Apple's tooling.
      final ReleaseVersion v = parseRelease(
        tag: 'v1.0.0-rc.1',
        pubspecSource: _pubspec,
      );
      expect(v.appleBuildName, '1.0.0');
    });

    test('rejects a tag that does not start with v', () {
      expect(
        () => parseRelease(tag: '1.0.0', pubspecSource: _pubspec),
        throwsFormatException,
      );
    });

    test('rejects a tag whose core disagrees with the pubspec', () {
      expect(
        () => parseRelease(tag: 'v1.1.0', pubspecSource: _pubspec),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('app/pubspec.yaml'),
          ),
        ),
      );
    });

    test('outputs are the keys the workflow reads', () {
      final ReleaseVersion v = parseRelease(
        tag: 'v1.0.0-rc.1',
        pubspecSource: _pubspec,
      );
      expect(v.outputs, <String, String>{
        'tag': 'v1.0.0-rc.1',
        'version': '1.0.0-rc.1',
        'build_name': '1.0.0-rc.1',
        'apple_build_name': '1.0.0',
        'build_number': '1',
        'slug': 'spectra-1.0.0-rc.1',
        'prerelease': 'true',
      });
    });

    test('the repository pubspec agrees with v1.0.0-rc.1', () {
      // Guards the real file, not a fixture: the RC tag this phase creates
      // must match the landed app version.
      final ReleaseVersion v = parseRelease(
        tag: 'v1.0.0-rc.1',
        pubspecSource: File('app/pubspec.yaml').readAsStringSync(),
      );
      expect(v.buildName, '1.0.0-rc.1');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart test test/release_version_test.dart
```

Expected: FAIL — `Error: Couldn't resolve the package 'tool/src/release_version.dart'` / target of URI doesn't exist.

- [ ] **Step 3: Write minimal implementation**

Create `tool/src/release_version.dart`:

```dart
/// Reconciles a `v*` git tag with `app/pubspec.yaml` and derives every
/// version string the release workflow needs (spec 10: semantic versions).
library;

/// The version identity of one release build.
class ReleaseVersion {
  const ReleaseVersion({
    required this.tag,
    required this.core,
    required this.preRelease,
    required this.buildNumber,
  });

  /// The git tag, including the leading `v`.
  final String tag;

  /// `major.minor.patch`.
  final String core;

  /// The part after `-`, or null for a final release.
  final String? preRelease;

  /// The `+N` from `app/pubspec.yaml`.
  final int buildNumber;

  bool get isPreRelease => preRelease != null;

  /// What `flutter build --build-name` gets everywhere but Apple.
  String get buildName => preRelease == null ? core : '$core-$preRelease';

  /// CFBundleShortVersionString must be three dotted numbers, so Apple
  /// targets get the core only; the RC identity lives in the tag and in the
  /// artifact file names.
  String get appleBuildName => core;

  /// The artifact file-name stem.
  String get slug => 'spectra-$buildName';

  /// `key=value` pairs the workflow copies into `GITHUB_OUTPUT`.
  Map<String, String> get outputs => <String, String>{
    'tag': tag,
    'version': buildName,
    'build_name': buildName,
    'apple_build_name': appleBuildName,
    'build_number': '$buildNumber',
    'slug': slug,
    'prerelease': '$isPreRelease',
  };
}

final RegExp _tagPattern = RegExp(
  r'^v(\d+\.\d+\.\d+)(?:-([0-9A-Za-z.-]+))?$',
);
final RegExp _versionLine = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true);

/// The `version:` line of a pubspec, e.g. `1.0.0+1`.
String pubspecVersion(String pubspecSource) {
  final RegExpMatch? match = _versionLine.firstMatch(pubspecSource);
  if (match == null) {
    throw const FormatException('no version: line in the pubspec');
  }
  return match.group(1)!;
}

/// Parses [tag] and checks it against the pubspec's own version.
ReleaseVersion parseRelease({
  required String tag,
  required String pubspecSource,
}) {
  final RegExpMatch? match = _tagPattern.firstMatch(tag);
  if (match == null) {
    throw FormatException(
      'release tag "$tag" is not vMAJOR.MINOR.PATCH[-PRERELEASE]',
    );
  }
  final String core = match.group(1)!;
  final String raw = pubspecVersion(pubspecSource);
  final List<String> parts = raw.split('+');
  if (parts.first != core) {
    throw FormatException(
      'tag "$tag" says $core but app/pubspec.yaml says ${parts.first}; '
      'bump the pubspec or fix the tag',
    );
  }
  final int buildNumber = parts.length > 1 ? int.parse(parts[1]) : 1;
  return ReleaseVersion(
    tag: tag,
    core: core,
    preRelease: match.group(2),
    buildNumber: buildNumber,
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart test test/release_version_test.dart && dart format tool/src/release_version.dart test/release_version_test.dart && dart analyze --fatal-infos tool test
```

Expected: all 9 tests PASS, `dart analyze` reports no issues.

- [ ] **Step 5: Commit**

```bash
git add tool/src/release_version.dart test/release_version_test.dart
git commit -m "feat(release): derive release versions from the git tag

The workflow needs one place that reconciles a v* tag with the pubspec and
knows Apple rejects a pre-release in CFBundleShortVersionString."
```

---

### Task 2: CHANGELOG.md and its parser

**Files:**
- Create: `CHANGELOG.md`, `tool/src/changelog.dart`
- Test: `test/changelog_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class ChangelogEntry { final String version; final String date; final String body; }`
  - `ChangelogEntry latestReleasedEntry(String source)` — skips
    `## [Unreleased]`, throws `FormatException` when there is no released
    entry.

Note the resolved ambiguity: **a release candidate does not get its own
changelog entry.** `v1.0.0-rc.1` is validated against the `1.0.0` entry,
because the RC is a candidate for exactly that release.

- [ ] **Step 1: Write the failing test**

Create `test/changelog_test.dart`:

```dart
import 'dart:io';

import 'package:test/test.dart';

import '../tool/src/changelog.dart';

const String _sample = '''
# Changelog

## [Unreleased]

## [1.0.0] - 2026-09-03

### Added

- Everything.

## [0.9.0] - 2026-08-01

### Added

- Less.
''';

void main() {
  test('skips Unreleased and returns the newest released entry', () {
    final ChangelogEntry entry = latestReleasedEntry(_sample);
    expect(entry.version, '1.0.0');
    expect(entry.date, '2026-09-03');
    expect(entry.body, contains('Everything.'));
    expect(entry.body, isNot(contains('Less.')));
  });

  test('throws when only Unreleased exists', () {
    expect(
      () => latestReleasedEntry('# Changelog\n\n## [Unreleased]\n'),
      throwsFormatException,
    );
  });

  group('the repository changelog', () {
    late String source;
    setUpAll(() => source = File('CHANGELOG.md').readAsStringSync());

    test('follows Keep a Changelog', () {
      expect(source, contains('Keep a Changelog'));
      expect(source, contains('Semantic Versioning'));
      expect(source, contains('## [Unreleased]'));
    });

    test('its newest entry is 1.0.0 and matches app/pubspec.yaml', () {
      final ChangelogEntry entry = latestReleasedEntry(source);
      expect(entry.version, '1.0.0');
      final String pubspec = File('app/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('version: ${entry.version}+'));
    });

    test('the v1 entry names the shipped features', () {
      final ChangelogEntry entry = latestReleasedEntry(source);
      for (final String feature in const <String>[
        'Connect',
        'Slots',
        'Cards',
        'firmware update',
        'Dictionaries',
      ]) {
        expect(entry.body, contains(feature), reason: 'missing $feature');
      }
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart test test/changelog_test.dart
```

Expected: FAIL — target of URI `../tool/src/changelog.dart` doesn't exist.

- [ ] **Step 3: Write minimal implementation**

Create `tool/src/changelog.dart`:

```dart
/// Reads `CHANGELOG.md`, which follows Keep a Changelog 1.1.0 (spec 10:
/// "semantic versions, a changelog").
library;

/// One `## [x.y.z] - date` section.
class ChangelogEntry {
  const ChangelogEntry({
    required this.version,
    required this.date,
    required this.body,
  });

  final String version;
  final String date;

  /// Everything under the heading, up to the next heading.
  final String body;
}

final RegExp _heading = RegExp(
  r'^## \[([^\]]+)\](?:\s*-\s*(\d{4}-\d{2}-\d{2}))?\s*$',
  multiLine: true,
);

/// The newest entry that is not `[Unreleased]`.
ChangelogEntry latestReleasedEntry(String source) {
  final List<RegExpMatch> headings = _heading.allMatches(source).toList();
  for (int i = 0; i < headings.length; i++) {
    final RegExpMatch h = headings[i];
    final String version = h.group(1)!;
    if (version.toLowerCase() == 'unreleased') continue;
    final int start = h.end;
    final int end = i + 1 < headings.length ? headings[i + 1].start : source.length;
    return ChangelogEntry(
      version: version,
      date: h.group(2) ?? '',
      body: source.substring(start, end).trim(),
    );
  }
  throw const FormatException('CHANGELOG.md has no released entry');
}
```

- [ ] **Step 4: Write `CHANGELOG.md`**

Create `CHANGELOG.md`:

```markdown
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
- Firmware update: release feed, package selection, and an orchestrated
  Nordic Secure DFU over USB with a recovery path for an interrupted flash.
  DFU over Bluetooth is built but ships behind the `dfuOverBleEnabled` flag,
  off by default until hardware validation completes.
- Dictionaries: key lists with import and export.
- Settings: device settings, app settings, and a frame log that can be
  exported with any bug report.
- A design system with light and dark themes, adaptive navigation, and
  localized copy throughout.

### Known limitations

- Bluetooth DFU and iOS DFU are behind the `dfuOverBleEnabled` flag.
- Mobile app stores are a later step; Android artifacts are published as an
  APK and an AAB on the release page.
```

- [ ] **Step 5: Run test to verify it passes**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart test test/changelog_test.dart && dart format tool/src/changelog.dart test/changelog_test.dart && dart analyze --fatal-infos tool test
```

Expected: 5 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add CHANGELOG.md tool/src/changelog.dart test/changelog_test.dart
git commit -m "docs(release): add the Keep a Changelog file and its parser

The release job has to prove the tag it is building has a changelog entry,
so the changelog is machine-readable from the start."
```

---

### Task 3: Release preflight CLI (version, changelog, licence warning)

**Files:**
- Create: `tool/src/license_status.dart`, `tool/check_release.dart`
- Test: `test/license_status_test.dart`
- Modify: `pubspec.yaml` (melos `check:release` script)

**Interfaces:**
- Consumes: `parseRelease`, `ReleaseVersion` (Task 1); `latestReleasedEntry`,
  `ChangelogEntry` (Task 2).
- Produces:
  - `enum LicenseState { chosen, todo, missing }`
  - `LicenseState licenseStateOf(String? contents)`
  - `Map<String, LicenseState> licenseStates(Directory root)` keyed by the
    relative package directory (`packages/chameleon`, `packages/chameleon_flutter`,
    `packages/spectra_ui`, `app`).
  - CLI `dart run tool/check_release.dart --tag v1.0.0-rc.1` — exit 0 on
    success, exit 1 on a version or changelog problem, **never** on a
    licence TODO. Appends the Task 1 `outputs` map as `key=value` lines to
    the file named by `$GITHUB_OUTPUT` when that variable is set.

- [ ] **Step 1: Write the failing test**

Create `test/license_status_test.dart`:

```dart
import 'dart:io';

import 'package:test/test.dart';

import '../tool/src/license_status.dart';

void main() {
  group('licenseStateOf', () {
    test('a missing file is missing', () {
      expect(licenseStateOf(null), LicenseState.missing);
    });

    test('the flutter create template is a TODO', () {
      expect(
        licenseStateOf('TODO: Add your license here.\n'),
        LicenseState.todo,
      );
    });

    test('anything else counts as chosen', () {
      expect(
        licenseStateOf('MIT License\n\nCopyright (c) 2026\n'),
        LicenseState.chosen,
      );
    });

    test('an empty file is still a TODO, not a licence', () {
      expect(licenseStateOf('   \n'), LicenseState.todo);
    });
  });

  test('the repository still has an undecided licence', () {
    // The user chooses the licence, not an agent. This test documents the
    // current state; when a licence is chosen, update the expectation.
    final Map<String, LicenseState> states = licenseStates(Directory.current);
    expect(states.keys, containsAll(<String>[
      'packages/chameleon',
      'packages/chameleon_flutter',
      'packages/spectra_ui',
      'app',
    ]));
    expect(states.values, isNot(everyElement(LicenseState.chosen)));
  });

  test('check_release exits 0 despite the licence TODO', () async {
    final ProcessResult r = await Process.run('dart', <String>[
      'run',
      'tool/check_release.dart',
      '--tag',
      'v1.0.0-rc.1',
    ]);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    expect(r.stdout, contains('license: '));
    expect(r.stdout, contains('build_name=1.0.0-rc.1'));
  });

  test('check_release rejects a tag with no changelog entry', () async {
    final ProcessResult r = await Process.run('dart', <String>[
      'run',
      'tool/check_release.dart',
      '--tag',
      'v9.9.9',
    ]);
    expect(r.exitCode, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart test test/license_status_test.dart
```

Expected: FAIL — target of URI `../tool/src/license_status.dart` doesn't exist.

- [ ] **Step 3: Write the licence module**

Create `tool/src/license_status.dart`:

```dart
/// Reports each package's LICENSE state without judging it. Choosing a
/// licence is the user's decision (AGENTS.md, "Decisions made overnight"),
/// so the release preflight warns and carries on.
library;

import 'dart:io';

enum LicenseState { chosen, todo, missing }

/// Directories that ship a LICENSE, relative to the workspace root.
const List<String> licensedPackages = <String>[
  'packages/chameleon',
  'packages/chameleon_flutter',
  'packages/spectra_ui',
  'app',
];

LicenseState licenseStateOf(String? contents) {
  if (contents == null) return LicenseState.missing;
  final String text = contents.trim();
  if (text.isEmpty || text.startsWith('TODO')) return LicenseState.todo;
  return LicenseState.chosen;
}

Map<String, LicenseState> licenseStates(Directory root) {
  return <String, LicenseState>{
    for (final String pkg in licensedPackages)
      pkg: licenseStateOf(_read('${root.path}/$pkg/LICENSE')),
  };
}

String? _read(String path) {
  final File file = File(path);
  return file.existsSync() ? file.readAsStringSync() : null;
}
```

- [ ] **Step 4: Write the preflight CLI**

Create `tool/check_release.dart`:

```dart
/// Release preflight (spec 10). Validates the tag against
/// `app/pubspec.yaml` and `CHANGELOG.md`, reports the licence state as a
/// warning, and emits the workflow outputs.
///
///   dart run tool/check_release.dart --tag v1.0.0-rc.1
library;

import 'dart:io';

import 'src/changelog.dart';
import 'src/license_status.dart';
import 'src/release_version.dart';

void main(List<String> args) {
  final int i = args.indexOf('--tag');
  if (i < 0 || i + 1 >= args.length) {
    stderr.writeln('usage: dart run tool/check_release.dart --tag vX.Y.Z');
    exit(64);
  }
  final String tag = args[i + 1];

  final ReleaseVersion version;
  final ChangelogEntry entry;
  try {
    version = parseRelease(
      tag: tag,
      pubspecSource: File('app/pubspec.yaml').readAsStringSync(),
    );
    entry = latestReleasedEntry(File('CHANGELOG.md').readAsStringSync());
  } on FormatException catch (e) {
    stderr.writeln('check_release: ${e.message}');
    exit(1);
  }

  if (entry.version != version.core) {
    stderr.writeln(
      'check_release: CHANGELOG.md\'s newest entry is ${entry.version} but '
      'the tag builds ${version.core}; add the entry before tagging',
    );
    exit(1);
  }

  // A licence TODO never fails the release: the user picks the licence.
  licenseStates(Directory.current).forEach((String pkg, LicenseState state) {
    final String note = switch (state) {
      LicenseState.chosen => 'ok',
      LicenseState.todo => 'TODO — the user has not chosen a licence yet',
      LicenseState.missing => 'no LICENSE file yet',
    };
    stdout.writeln('license: $pkg: $note');
  });

  final String? outputPath = Platform.environment['GITHUB_OUTPUT'];
  final StringBuffer buffer = StringBuffer();
  version.outputs.forEach((String k, String v) => buffer.writeln('$k=$v'));
  stdout.write(buffer);
  if (outputPath != null && outputPath.isNotEmpty) {
    File(outputPath).writeAsStringSync(buffer.toString(), mode: FileMode.append);
  }
  stdout.writeln('check_release: ok (${version.buildName})');
}
```

- [ ] **Step 5: Add the melos script**

In root `pubspec.yaml`, under `melos: scripts:`, immediately after the
`check:codegen:` entry and before `check:all:`, insert:

```yaml
    check:release:
      run: dart run tool/check_release.dart --tag "${RELEASE_TAG:-v1.0.0-rc.1}"
      description: >-
        Release preflight: the tag must agree with app/pubspec.yaml and
        CHANGELOG.md. A LICENSE TODO warns but never fails.
```

Leave `check:all:` unchanged — the preflight is release-only and must not
join the per-commit gate.

- [ ] **Step 6: Run test to verify it passes**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart test test/license_status_test.dart && dart run melos run check:release && dart format tool test && dart analyze --fatal-infos tool test
```

Expected: 6 tests PASS; `check:release` prints four `license:` lines, the
seven output keys and `check_release: ok (1.0.0-rc.1)`; exit 0.

- [ ] **Step 7: Commit**

```bash
git add tool/check_release.dart tool/src/license_status.dart \
  test/license_status_test.dart pubspec.yaml
git commit -m "feat(release): add the release preflight check

One command proves a tag is buildable — version, changelog, licence state —
and the licence TODO stays a warning because that call is the user's."
```

---

### Task 4: macOS `.dmg` packaging with optional signing and notarization

**Files:**
- Create: `tool/package/macos_dmg.sh`
- Test: `test/packaging_test.dart` (created here, extended by Tasks 5, 6, 8)

**Interfaces:**
- Consumes: `ReleaseVersion.slug` (Task 1) via the caller, which passes the
  output path.
- Produces: `tool/package/macos_dmg.sh <app-path> <output-dmg>` — signs
  `<app-path>` with `$MACOS_SIGN_IDENTITY` when set (hardened runtime,
  `app/macos/Runner/Release.entitlements`), otherwise ad-hoc (`-`); builds
  the dmg with `hdiutil`; notarizes and staples when `MACOS_NOTARY_APPLE_ID`,
  `MACOS_NOTARY_TEAM_ID` and `MACOS_NOTARY_PASSWORD` are all set. Exit 0 in
  every path where the dmg exists.

- [ ] **Step 1: Write the failing test**

Create `test/packaging_test.dart`:

```dart
import 'dart:io';

import 'package:test/test.dart';

String _read(String path) => File(path).readAsStringSync();

bool _isExecutable(String path) =>
    // 0o100 is the owner-execute bit.
    File(path).statSync().mode & 0x40 != 0;

void main() {
  group('macOS dmg script', () {
    late String script;
    setUpAll(() => script = _read('tool/package/macos_dmg.sh'));

    test('is executable and fails fast', () {
      expect(_isExecutable('tool/package/macos_dmg.sh'), isTrue);
      expect(script, contains('set -euo pipefail'));
    });

    test('signs with the release entitlements and the hardened runtime', () {
      expect(script, contains('app/macos/Runner/Release.entitlements'));
      expect(script, contains('--options runtime'));
      expect(script, contains('codesign'));
    });

    test('falls back to an ad-hoc signature with no identity', () {
      expect(script, contains(r'${MACOS_SIGN_IDENTITY:-}'));
      expect(script, contains('ad-hoc'));
      expect(script, contains('--sign -'));
    });

    test('notarizes only when all three credentials are present', () {
      expect(script, contains('notarytool submit'));
      expect(script, contains('stapler staple'));
      expect(script, contains(r'${MACOS_NOTARY_APPLE_ID:-}'));
      expect(script, contains(r'${MACOS_NOTARY_TEAM_ID:-}'));
      expect(script, contains(r'${MACOS_NOTARY_PASSWORD:-}'));
      expect(script, contains('skipping notarization'));
    });

    test('builds the dmg with hdiutil', () {
      expect(script, contains('hdiutil create'));
      expect(script, contains('/Applications'));
    });

    test('never echoes a secret', () {
      for (final String secret in const <String>[
        'MACOS_CERT_P12',
        'MACOS_CERT_PASSWORD',
        'MACOS_NOTARY_PASSWORD',
      ]) {
        expect(
          script,
          isNot(contains('echo "\$$secret')),
          reason: '$secret must never be echoed',
        );
      }
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart test test/packaging_test.dart
```

Expected: FAIL — `PathNotFoundException` on `tool/package/macos_dmg.sh`.

- [ ] **Step 3: Write the script**

Create `tool/package/macos_dmg.sh`:

```bash
#!/usr/bin/env bash
# Packages a built Spectra.app into a .dmg, signed and notarized when the
# credentials are present and ad-hoc signed when they are not, so a fork or
# a secretless workflow_dispatch still produces an artifact (spec 10:
# "signing and notarization are added at the first release").
#
#   tool/package/macos_dmg.sh app/build/macos/Build/Products/Release/spectra.app \
#     dist/spectra-1.0.0-rc.1-macos.dmg
#
# Environment (all optional, all supplied by the workflow from secrets):
#   MACOS_CERT_P12        base64 of a Developer ID Application .p12
#   MACOS_CERT_PASSWORD   its password
#   MACOS_SIGN_IDENTITY   e.g. "Developer ID Application: ... (TEAMID)"
#   MACOS_NOTARY_APPLE_ID / MACOS_NOTARY_TEAM_ID / MACOS_NOTARY_PASSWORD
set -euo pipefail
cd "$(dirname "$0")/../.."

APP_PATH="${1:?usage: macos_dmg.sh <app-path> <output-dmg>}"
OUT_DMG="${2:?usage: macos_dmg.sh <app-path> <output-dmg>}"
ENTITLEMENTS="app/macos/Runner/Release.entitlements"

mkdir -p "$(dirname "$OUT_DMG")"

# 1. Import the certificate into a throwaway keychain, if we were given one.
if [ -n "${MACOS_CERT_P12:-}" ] && [ -n "${MACOS_CERT_PASSWORD:-}" ]; then
  KEYCHAIN="$RUNNER_TEMP/spectra-signing.keychain-db"
  KEYCHAIN_PASSWORD="$(uuidgen)"
  security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
  security set-keychain-settings -lut 21600 "$KEYCHAIN"
  security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
  printf '%s' "$MACOS_CERT_P12" | base64 --decode > "$RUNNER_TEMP/cert.p12"
  security import "$RUNNER_TEMP/cert.p12" -k "$KEYCHAIN" \
    -P "$MACOS_CERT_PASSWORD" -T /usr/bin/codesign
  security set-key-partition-list -S apple-tool:,apple:,codesign: \
    -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
  security list-keychains -d user -s "$KEYCHAIN" \
    "$(security list-keychains -d user | tr -d '" ' | tr '\n' ' ')"
  rm -f "$RUNNER_TEMP/cert.p12"
  echo "macos_dmg: imported the signing certificate"
fi

# 2. Sign. No identity means an ad-hoc signature: the app still launches
#    locally (after the Gatekeeper prompt) and CI still yields an artifact.
if [ -n "${MACOS_SIGN_IDENTITY:-}" ]; then
  echo "macos_dmg: signing with a Developer ID identity"
  codesign --force --deep --timestamp --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign "$MACOS_SIGN_IDENTITY" "$APP_PATH"
else
  echo "macos_dmg: no MACOS_SIGN_IDENTITY — ad-hoc signing, unnotarized"
  codesign --force --deep --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign - "$APP_PATH"
fi
codesign --verify --verbose=2 "$APP_PATH"

# 3. Build the dmg: the .app plus a symlink to /Applications to drag onto.
STAGE="$(mktemp -d)"
cp -R "$APP_PATH" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$OUT_DMG"
hdiutil create -volname "Spectra" -srcfolder "$STAGE" -ov -format UDZO "$OUT_DMG"
rm -rf "$STAGE"

# 4. Notarize, when we have all three credentials.
if [ -n "${MACOS_NOTARY_APPLE_ID:-}" ] && [ -n "${MACOS_NOTARY_TEAM_ID:-}" ] \
  && [ -n "${MACOS_NOTARY_PASSWORD:-}" ]; then
  echo "macos_dmg: submitting to notarytool"
  xcrun notarytool submit "$OUT_DMG" \
    --apple-id "$MACOS_NOTARY_APPLE_ID" \
    --team-id "$MACOS_NOTARY_TEAM_ID" \
    --password "$MACOS_NOTARY_PASSWORD" \
    --wait
  xcrun stapler staple "$OUT_DMG"
  echo "macos_dmg: notarized and stapled"
else
  echo "macos_dmg: notary credentials absent — skipping notarization"
fi

echo "macos_dmg: wrote $OUT_DMG"
```

Then:

```bash
chmod +x tool/package/macos_dmg.sh
```

- [ ] **Step 4: Run test to verify it passes**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart test test/packaging_test.dart
```

Expected: 6 tests PASS.

- [ ] **Step 5: Smoke the unsigned path locally (macOS only)**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
cd app && flutter build macos --release --build-name 1.0.0 --build-number 1 && cd ..
RUNNER_TEMP=/tmp tool/package/macos_dmg.sh \
  app/build/macos/Build/Products/Release/spectra.app \
  dist/spectra-1.0.0-macos.dmg
```

Expected: prints `no MACOS_SIGN_IDENTITY — ad-hoc signing, unnotarized`,
`notary credentials absent — skipping notarization`, and
`macos_dmg: wrote dist/spectra-1.0.0-macos.dmg`; the dmg exists and mounts.
If the box is not a Mac, note that and let the workflow prove it (Task 9).

- [ ] **Step 6: Commit**

```bash
rm -rf dist
git add tool/package/macos_dmg.sh test/packaging_test.dart
git commit -m "feat(release): package macOS as a dmg, signed when we can

Signing lives in the script, not a workflow if:, so a secretless build
produces the same artifact ad-hoc signed instead of failing."
```

---

### Task 5: Windows installer and portable zip

**Files:**
- Create: `tool/package/windows/spectra.iss`, `tool/package/windows_installer.ps1`
- Modify: `test/packaging_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks at runtime; the caller passes the
  version.
- Produces: `tool/package/windows_installer.ps1 -BuildDir <dir> -Version <v>
  -OutDir <dir>` — writes `<OutDir>\spectra-<Version>-windows-setup.exe` and
  `<OutDir>\spectra-<Version>-windows.zip`; signs both with `signtool` when
  `WINDOWS_CERT_PFX` (base64) and `WINDOWS_CERT_PASSWORD` are set, and skips
  signing with a message otherwise.

- [ ] **Step 1: Write the failing test**

Append to `test/packaging_test.dart`, inside `main()` after the macOS group:

```dart
  group('Windows installer', () {
    late String ps1;
    late String iss;
    setUpAll(() {
      ps1 = _read('tool/package/windows_installer.ps1');
      iss = _read('tool/package/windows/spectra.iss');
    });

    test('stops on the first error', () {
      expect(ps1, contains(r"$ErrorActionPreference = 'Stop'"));
    });

    test('produces both an installer and a portable zip', () {
      expect(ps1, contains('ISCC'));
      expect(ps1, contains('Compress-Archive'));
      expect(ps1, contains('-windows-setup.exe'));
      expect(ps1, contains('-windows.zip'));
    });

    test('signing degrades when the certificate is absent', () {
      expect(ps1, contains('WINDOWS_CERT_PFX'));
      expect(ps1, contains('WINDOWS_CERT_PASSWORD'));
      expect(ps1, contains('signtool'));
      expect(ps1, contains('skipping code signing'));
    });

    test('the Inno script names the landed app identity', () {
      expect(iss, contains('AppName=Spectra'));
      expect(iss, contains('dev.spectra.spectra'));
      expect(iss, contains('spectra.exe'));
      expect(iss, contains('{#AppVersion}'));
      expect(iss, contains('ArchitecturesInstallIn64BitMode=x64compatible'));
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart test test/packaging_test.dart
```

Expected: FAIL — `PathNotFoundException` on `tool/package/windows_installer.ps1`.

- [ ] **Step 3: Write the Inno Setup script**

Create `tool/package/windows/spectra.iss`:

```
; Inno Setup script for Spectra. ISCC is preinstalled on GitHub's
; windows-latest runners. Driven by tool/package/windows_installer.ps1,
; which passes AppVersion, BuildDir and OutDir with /D switches.
#define AppPublisher "Spectra"
#define AppId "dev.spectra.spectra"

[Setup]
AppId={#AppId}
AppName=Spectra
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\Spectra
DefaultGroupName=Spectra
DisableProgramGroupPage=yes
OutputDir={#OutDir}
OutputBaseFilename=spectra-{#AppVersion}-windows-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
UninstallDisplayIcon={app}\spectra.exe

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\Spectra"; Filename: "{app}\spectra.exe"
Name: "{autodesktop}\Spectra"; Filename: "{app}\spectra.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts"; Flags: unchecked

[Run]
Filename: "{app}\spectra.exe"; Description: "Launch Spectra"; Flags: nowait postinstall skipifsilent
```

- [ ] **Step 4: Write the PowerShell driver**

Create `tool/package/windows_installer.ps1`:

```powershell
# Builds the Spectra Windows installer and portable zip, signing both when a
# certificate is available and shipping them unsigned when it is not, so a
# fork or a secretless run still gets artifacts (spec 10).
#
#   pwsh tool/package/windows_installer.ps1 `
#     -BuildDir app\build\windows\x64\runner\Release `
#     -Version 1.0.0-rc.1 -OutDir dist
#
# Environment (optional): WINDOWS_CERT_PFX (base64 .pfx),
# WINDOWS_CERT_PASSWORD.
param(
  [Parameter(Mandatory = $true)][string]$BuildDir,
  [Parameter(Mandatory = $true)][string]$Version,
  [Parameter(Mandatory = $true)][string]$OutDir
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$BuildDir = (Resolve-Path $BuildDir).Path
$OutDir = (Resolve-Path $OutDir).Path

# Locate signtool once; it may be absent on a machine with no Windows SDK.
function Get-SignTool {
  $found = Get-ChildItem `
    'C:\Program Files (x86)\Windows Kits\10\bin\*\x64\signtool.exe' `
    -ErrorAction SilentlyContinue | Sort-Object FullName | Select-Object -Last 1
  if ($found) { return $found.FullName }
  return $null
}

$pfxPath = $null
if ($env:WINDOWS_CERT_PFX -and $env:WINDOWS_CERT_PASSWORD) {
  $signtool = Get-SignTool
  if ($signtool) {
    $pfxPath = Join-Path $env:RUNNER_TEMP 'spectra.pfx'
    [IO.File]::WriteAllBytes($pfxPath,
      [Convert]::FromBase64String($env:WINDOWS_CERT_PFX))
    Write-Host 'windows_installer: code signing enabled'
  } else {
    Write-Host 'windows_installer: signtool not found, skipping code signing'
  }
} else {
  Write-Host 'windows_installer: no certificate, skipping code signing'
}

function Invoke-Sign([string]$Path) {
  if (-not $pfxPath) { return }
  & (Get-SignTool) sign /fd SHA256 /f $pfxPath `
    /p $env:WINDOWS_CERT_PASSWORD /tr http://timestamp.digicert.com `
    /td SHA256 $Path
  if ($LASTEXITCODE -ne 0) { throw "signtool failed on $Path" }
}

# Sign the executable before it is packaged, so both artifacts carry it.
Invoke-Sign (Join-Path $BuildDir 'spectra.exe')

$zip = Join-Path $OutDir "spectra-$Version-windows.zip"
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path (Join-Path $BuildDir '*') -DestinationPath $zip
Write-Host "windows_installer: wrote $zip"

$iss = Join-Path $PSScriptRoot 'windows\spectra.iss'
& ISCC.exe "/DAppVersion=$Version" "/DBuildDir=$BuildDir" "/DOutDir=$OutDir" $iss
if ($LASTEXITCODE -ne 0) { throw 'ISCC failed' }

$setup = Join-Path $OutDir "spectra-$Version-windows-setup.exe"
Invoke-Sign $setup
Write-Host "windows_installer: wrote $setup"

if ($pfxPath) { Remove-Item $pfxPath -Force }
```

- [ ] **Step 5: Run test to verify it passes**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart test test/packaging_test.dart
```

Expected: 10 tests PASS (6 macOS + 4 Windows).

- [ ] **Step 6: Commit**

```bash
git add tool/package/windows/spectra.iss tool/package/windows_installer.ps1 \
  test/packaging_test.dart
git commit -m "feat(release): build the Windows installer and portable zip

Inno Setup is preinstalled on the runner, and skipping the signature when
there is no certificate keeps fork builds working."
```

---

### Task 6: Linux AppImage and tarball

**Files:**
- Create: `tool/package/linux_appimage.sh`, `tool/package/linux/spectra.desktop`
- Modify: `test/packaging_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `tool/package/linux_appimage.sh <bundle-dir> <version> <out-dir>`
  — writes `<out-dir>/spectra-<version>-linux-x86_64.AppImage` and
  `<out-dir>/spectra-<version>-linux-x64.tar.gz`. Linux desktop artifacts
  are unsigned by design (spec 10 names an AppImage, no Linux signing), so
  there is no secret and no degradation path here.

Resolved ambiguity: spec 10 says "Linux as an AppImage" and does not ask for
a `.deb`. This task ships the AppImage plus a plain tarball (the tarball is
what a distro packager or a `--verbose` bug report wants); no `.deb`.

- [ ] **Step 1: Write the failing test**

Append to `test/packaging_test.dart`, inside `main()`:

```dart
  group('Linux AppImage', () {
    late String script;
    late String desktop;
    setUpAll(() {
      script = _read('tool/package/linux_appimage.sh');
      desktop = _read('tool/package/linux/spectra.desktop');
    });

    test('is executable and fails fast', () {
      expect(_isExecutable('tool/package/linux_appimage.sh'), isTrue);
      expect(script, contains('set -euo pipefail'));
    });

    test('runs appimagetool without FUSE', () {
      // GitHub runners have no FUSE; the AppImage has to extract itself.
      expect(script, contains('appimagetool'));
      expect(script, contains('--appimage-extract-and-run'));
    });

    test('emits both the AppImage and a tarball', () {
      expect(script, contains('linux-x86_64.AppImage'));
      expect(script, contains('linux-x64.tar.gz'));
    });

    test('writes an AppRun that launches the landed binary name', () {
      expect(script, contains('AppRun'));
      expect(script, contains('spectra'));
      expect(script, contains('usr/lib'));
    });

    test('the desktop entry uses the landed application id', () {
      expect(desktop, contains('Name=Spectra'));
      expect(desktop, contains('Exec=spectra'));
      expect(desktop, contains('Categories=Utility;'));
      expect(desktop, contains('Icon=dev.spectra.spectra'));
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart test test/packaging_test.dart
```

Expected: FAIL — `PathNotFoundException` on `tool/package/linux_appimage.sh`.

- [ ] **Step 3: Write the desktop entry**

Create `tool/package/linux/spectra.desktop`:

```
[Desktop Entry]
Type=Application
Name=Spectra
GenericName=Chameleon Ultra companion
Comment=Manage and interact with a Chameleon Ultra
Exec=spectra
Icon=dev.spectra.spectra
Terminal=false
Categories=Utility;Development;
Keywords=chameleon;nfc;rfid;
```

- [ ] **Step 4: Write the script**

Create `tool/package/linux_appimage.sh`:

```bash
#!/usr/bin/env bash
# Packages the Flutter Linux bundle as an AppImage plus a plain tarball
# (spec 10: "Linux as an AppImage"). Linux artifacts are unsigned; there is
# no Linux signing story in the spec, so there is no secret here.
#
#   tool/package/linux_appimage.sh app/build/linux/x64/release/bundle \
#     1.0.0-rc.1 dist
set -euo pipefail
cd "$(dirname "$0")/../.."

BUNDLE="${1:?usage: linux_appimage.sh <bundle-dir> <version> <out-dir>}"
VERSION="${2:?usage: linux_appimage.sh <bundle-dir> <version> <out-dir>}"
OUT_DIR="${3:?usage: linux_appimage.sh <bundle-dir> <version> <out-dir>}"
mkdir -p "$OUT_DIR"

# 1. The tarball is just the bundle, named.
tar -czf "$OUT_DIR/spectra-$VERSION-linux-x64.tar.gz" \
  -C "$(dirname "$BUNDLE")" "$(basename "$BUNDLE")"
echo "linux_appimage: wrote $OUT_DIR/spectra-$VERSION-linux-x64.tar.gz"

# 2. Lay out the AppDir.
APPDIR="$(mktemp -d)/Spectra.AppDir"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/lib" "$APPDIR/usr/share/applications"
cp -r "$BUNDLE/." "$APPDIR/usr/lib/"
mv "$APPDIR/usr/lib/spectra" "$APPDIR/usr/bin/spectra"
cp tool/package/linux/spectra.desktop \
  "$APPDIR/usr/share/applications/dev.spectra.spectra.desktop"
cp "$APPDIR/usr/share/applications/dev.spectra.spectra.desktop" \
  "$APPDIR/dev.spectra.spectra.desktop"
# The icon: Flutter's Linux template ships none, so use the macOS 256px
# asset until real branding lands (docs/RELEASING.md tracks the decision).
cp app/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png \
  "$APPDIR/dev.spectra.spectra.png"

cat > "$APPDIR/AppRun" <<'APPRUN'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
# The Flutter bundle expects data/ and lib/ next to the executable.
export LD_LIBRARY_PATH="$HERE/usr/lib/lib:${LD_LIBRARY_PATH:-}"
cd "$HERE/usr/lib"
exec "$HERE/usr/bin/spectra" "$@"
APPRUN
chmod +x "$APPDIR/AppRun"

# 3. Build it. GitHub runners have no FUSE, hence extract-and-run.
TOOL="$(mktemp -d)/appimagetool"
curl -fsSL -o "$TOOL" \
  https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x "$TOOL"
ARCH=x86_64 "$TOOL" --appimage-extract-and-run "$APPDIR" \
  "$OUT_DIR/spectra-$VERSION-linux-x86_64.AppImage"
echo "linux_appimage: wrote $OUT_DIR/spectra-$VERSION-linux-x86_64.AppImage"
```

Then:

```bash
chmod +x tool/package/linux_appimage.sh
```

- [ ] **Step 5: Run test to verify it passes**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart test test/packaging_test.dart
```

Expected: 15 tests PASS (6 macOS + 4 Windows + 5 Linux).

- [ ] **Step 6: Commit**

```bash
git add tool/package/linux_appimage.sh tool/package/linux/spectra.desktop \
  test/packaging_test.dart
git commit -m "feat(release): package Linux as an AppImage and a tarball

Spec 10 asks for an AppImage; the runner has no FUSE, so appimagetool runs
with --appimage-extract-and-run."
```

---

### Task 7: Android release signing with a debug fallback

**Files:**
- Modify: `app/android/app/build.gradle.kts:31-38`, `.gitignore`
- Create: `app/android/key.properties.example`
- Modify: `test/packaging_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: a `release` build type that signs with a real keystore when
  `app/android/key.properties` exists (or the four `ANDROID_*` environment
  variables are set) and falls back to the debug keystore otherwise, so
  `flutter build apk --release` keeps working on a machine with no keystore
  exactly as it does today.

- [ ] **Step 1: Write the failing test**

Append to `test/packaging_test.dart`, inside `main()`:

```dart
  group('Android signing', () {
    late String gradle;
    setUpAll(() => gradle = _read('app/android/app/build.gradle.kts'));

    test('the flutter create signing TODO is gone', () {
      expect(gradle, isNot(contains('TODO: Add your own signing config')));
    });

    test('reads a keystore from key.properties or the environment', () {
      expect(gradle, contains('key.properties'));
      expect(gradle, contains('ANDROID_KEYSTORE_BASE64'));
      expect(gradle, contains('ANDROID_KEYSTORE_PASSWORD'));
      expect(gradle, contains('ANDROID_KEY_ALIAS'));
      expect(gradle, contains('ANDROID_KEY_PASSWORD'));
    });

    test('falls back to the debug keystore when there is none', () {
      expect(gradle, contains('signingConfigs.getByName("debug")'));
      expect(gradle, contains('release-unsigned'));
    });

    test('keystores and key.properties are git-ignored', () {
      final String ignore = _read('.gitignore');
      expect(ignore, contains('app/android/key.properties'));
      expect(ignore, contains('*.jks'));
      expect(ignore, contains('*.keystore'));
    });

    test('the example documents all four properties', () {
      final String example = _read('app/android/key.properties.example');
      for (final String key in const <String>[
        'storeFile',
        'storePassword',
        'keyAlias',
        'keyPassword',
      ]) {
        expect(example, contains(key));
      }
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart test test/packaging_test.dart
```

Expected: FAIL — the TODO string is still present and
`key.properties.example` does not exist.

- [ ] **Step 3: Edit the Gradle file**

In `app/android/app/build.gradle.kts`, add these imports at the very top of
the file, above `plugins {`:

```kotlin
import java.io.FileInputStream
import java.util.Properties
```

Immediately after the `plugins { ... }` block and before `android {`, insert:

```kotlin
// Release signing (spec 10). Three ways in, in priority order:
//   1. android/key.properties (a local release build; git-ignored)
//   2. the ANDROID_* environment variables, which CI fills from secrets and
//      which write a keystore decoded from ANDROID_KEYSTORE_BASE64
//   3. nothing at all — fall back to the debug keystore so
//      `flutter build apk --release` still works for anyone, including a
//      fork's CI run. The artifact is then named release-unsigned.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
} else if (!System.getenv("ANDROID_KEYSTORE_BASE64").isNullOrEmpty()) {
    val decoded = java.util.Base64.getDecoder()
        .decode(System.getenv("ANDROID_KEYSTORE_BASE64"))
    val target = File(rootProject.buildDir, "spectra-release.jks")
    target.parentFile.mkdirs()
    target.writeBytes(decoded)
    keystoreProperties["storeFile"] = target.absolutePath
    keystoreProperties["storePassword"] = System.getenv("ANDROID_KEYSTORE_PASSWORD") ?: ""
    keystoreProperties["keyAlias"] = System.getenv("ANDROID_KEY_ALIAS") ?: ""
    keystoreProperties["keyPassword"] = System.getenv("ANDROID_KEY_PASSWORD") ?: ""
}
val hasReleaseKeystore = keystoreProperties["storeFile"] != null
```

Replace the whole existing `buildTypes { ... }` block with:

```kotlin
    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // No keystore: the debug keys keep `flutter build apk
                // --release` working. The workflow renames the artifact
                // release-unsigned so nobody mistakes it for a shippable one.
                logger.lifecycle("spectra: no release keystore; signing release-unsigned with the debug key")
                signingConfigs.getByName("debug")
            }
        }
    }
```

- [ ] **Step 4: Add the example and the ignores**

Create `app/android/key.properties.example`:

```properties
# Copy to app/android/key.properties for a locally signed release build.
# That file is git-ignored; never commit a keystore or a password.
# CI supplies the same four values from the ANDROID_KEYSTORE_BASE64,
# ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS and ANDROID_KEY_PASSWORD
# secrets instead.
storeFile=/absolute/path/to/spectra-release.jks
storePassword=
keyAlias=spectra
keyPassword=
```

Append to `.gitignore`:

```gitignore

# Release signing material (Phase 10). Never commit a keystore.
app/android/key.properties
*.jks
*.keystore
```

- [ ] **Step 5: Run test to verify it passes**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart test test/packaging_test.dart
cd app && flutter build apk --release --build-name 1.0.0-rc.1 --build-number 1; cd ..
```

Expected: 20 tests PASS; the APK build logs
`spectra: no release keystore; signing release-unsigned with the debug key`
and writes `app/build/app/outputs/flutter-apk/app-release.apk`.

- [ ] **Step 6: Commit**

```bash
git add app/android/app/build.gradle.kts app/android/key.properties.example \
  .gitignore test/packaging_test.dart
git commit -m "feat(release): sign Android releases when a keystore exists

Replaces the flutter create TODO. Falling back to the debug key keeps
release builds working on machines and forks with no keystore."
```

---

### Task 8: iOS `.ipa` packaging (unsigned)

**Files:**
- Create: `tool/package/ios_ipa.sh`
- Modify: `test/packaging_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `tool/package/ios_ipa.sh <app-path> <output-ipa>` — wraps an
  unsigned `Runner.app` into a `Payload/` ipa.

Resolved ambiguity: spec 10 says "mobile stores are a later step", and no
Apple Developer team id is available to the repo. So iOS ships an **unsigned**
`.ipa` — installable only by re-signing or by sideloading tools — and the
TestFlight path is documented in `docs/RELEASING.md` (Task 10) rather than
automated. No `ExportOptions.plist` is committed, because every plausible one
needs a real team id.

- [ ] **Step 1: Write the failing test**

Append to `test/packaging_test.dart`, inside `main()`:

```dart
  group('iOS ipa script', () {
    late String script;
    setUpAll(() => script = _read('tool/package/ios_ipa.sh'));

    test('is executable and fails fast', () {
      expect(_isExecutable('tool/package/ios_ipa.sh'), isTrue);
      expect(script, contains('set -euo pipefail'));
    });

    test('wraps the app in a Payload directory', () {
      expect(script, contains('Payload'));
      expect(script, contains('zip -r'));
    });

    test('says out loud that the ipa is unsigned', () {
      expect(script, contains('unsigned'));
      expect(script, contains('docs/RELEASING.md'));
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart test test/packaging_test.dart
```

Expected: FAIL — `PathNotFoundException` on `tool/package/ios_ipa.sh`.

- [ ] **Step 3: Write the script**

Create `tool/package/ios_ipa.sh`:

```bash
#!/usr/bin/env bash
# Wraps an unsigned Runner.app into an .ipa (spec 10: "mobile stores are a
# later step"). The repo holds no Apple team id, so the ipa carries no
# signature and cannot be installed straight onto a device — it exists so
# the RC has an iOS artifact to inspect and re-sign. The TestFlight route is
# in docs/RELEASING.md.
#
#   tool/package/ios_ipa.sh app/build/ios/iphoneos/Runner.app \
#     dist/spectra-1.0.0-rc.1-ios-unsigned.ipa
set -euo pipefail

APP_PATH="${1:?usage: ios_ipa.sh <app-path> <output-ipa>}"
OUT_IPA="${2:?usage: ios_ipa.sh <app-path> <output-ipa>}"

mkdir -p "$(dirname "$OUT_IPA")"
OUT_IPA="$(cd "$(dirname "$OUT_IPA")" && pwd)/$(basename "$OUT_IPA")"

STAGE="$(mktemp -d)"
mkdir -p "$STAGE/Payload"
cp -R "$APP_PATH" "$STAGE/Payload/"
rm -f "$OUT_IPA"
(cd "$STAGE" && zip -r -q "$OUT_IPA" Payload)
rm -rf "$STAGE"

echo "ios_ipa: wrote $OUT_IPA (unsigned — see docs/RELEASING.md)"
```

Then:

```bash
chmod +x tool/package/ios_ipa.sh
```

- [ ] **Step 4: Run test to verify it passes**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart test test/packaging_test.dart
```

Expected: 23 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add tool/package/ios_ipa.sh test/packaging_test.dart
git commit -m "feat(release): produce an unsigned iOS ipa

There is no team id in the repo, so the RC ships an inspectable unsigned
ipa and RELEASING.md carries the TestFlight route."
```

---

### Task 9: The release workflow

**Files:**
- Create: `.github/workflows/release.yml`
- Modify: `.github/workflows/ci.yml` (add `workflow_call:` — nothing else)
- Test: `test/release_workflow_test.dart`

**Interfaces:**
- Consumes: `tool/check_release.dart` (Task 3), all four packaging scripts
  (Tasks 4-8), the Android signing config (Task 7).
- Produces: a workflow with jobs `preflight`, `ci` (reusable call),
  `macos`, `windows`, `linux`, `android`, `ios`, `publish`. `preflight`
  exposes the outputs `tag`, `version`, `build_name`, `apple_build_name`,
  `build_number`, `slug`, `prerelease`.

- [ ] **Step 1: Write the failing test**

Create `test/release_workflow_test.dart`:

```dart
import 'dart:io';

import 'package:test/test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('ci.yml keeps its shape', () {
    late String ci;
    setUpAll(() => ci = _read('.github/workflows/ci.yml'));

    test('is callable by the release workflow', () {
      expect(ci, contains('workflow_call:'));
    });

    test('keeps every existing trigger, job and guard', () {
      expect(ci, contains('pull_request:'));
      expect(ci, contains('workflow_dispatch:'));
      expect(ci, contains('branches: [main]'));
      expect(ci, contains('group: ci-\${{ github.ref }}'));
      expect(ci, contains('FLUTTER_VERSION: 3.47.2'));
      for (final String job in const <String>['check:', 'integration:', 'build:']) {
        expect(ci, contains('  $job'), reason: 'lost the $job job');
      }
      expect(ci, contains("if: github.event_name != 'pull_request'"));
      expect(ci, contains('flutter test integration_test -d macos'));
    });
  });

  group('release.yml', () {
    late String yaml;
    setUpAll(() => yaml = _read('.github/workflows/release.yml'));

    test('triggers on a v* tag and on manual dispatch', () {
      expect(yaml, contains('workflow_dispatch:'));
      expect(yaml, contains("- 'v*'"));
      expect(yaml, contains('tags:'));
    });

    test('runs the full CI workflow before packaging anything', () {
      expect(yaml, contains('uses: ./.github/workflows/ci.yml'));
    });

    test('preflight publishes the version outputs', () {
      expect(yaml, contains('tool/check_release.dart'));
      for (final String key in const <String>[
        'build_name',
        'apple_build_name',
        'build_number',
        'slug',
        'prerelease',
      ]) {
        expect(yaml, contains('$key:'), reason: 'missing output $key');
      }
    });

    test('builds a release binary for all five platforms', () {
      expect(yaml, contains('flutter build macos --release'));
      expect(yaml, contains('flutter build windows --release'));
      expect(yaml, contains('flutter build linux --release'));
      expect(yaml, contains('flutter build apk --release'));
      expect(yaml, contains('flutter build appbundle --release'));
      expect(yaml, contains('flutter build ios --release --no-codesign'));
    });

    test('calls every packaging script', () {
      expect(yaml, contains('tool/package/macos_dmg.sh'));
      expect(yaml, contains('tool/package/windows_installer.ps1'));
      expect(yaml, contains('tool/package/linux_appimage.sh'));
      expect(yaml, contains('tool/package/ios_ipa.sh'));
    });

    test('every action is pinned to a major version tag', () {
      final Iterable<String> uses = RegExp(r'uses: ([^\s]+)')
          .allMatches(yaml)
          .map((RegExpMatch m) => m.group(1)!)
          .where((String u) => !u.startsWith('./'));
      expect(uses, isNotEmpty);
      for (final String u in uses) {
        expect(u, matches(RegExp(r'@v\d+$')), reason: '$u is not pinned');
      }
      expect(uses, contains('actions/checkout@v4'));
      expect(uses, contains('subosito/flutter-action@v2'));
      expect(uses, contains('actions/upload-artifact@v4'));
      expect(uses, contains('actions/download-artifact@v4'));
      expect(uses, contains('softprops/action-gh-release@v2'));
      expect(uses, contains('actions/setup-java@v4'));
    });

    test('references the signing secrets by name only', () {
      for (final String secret in const <String>[
        'MACOS_CERT_P12',
        'MACOS_CERT_PASSWORD',
        'MACOS_SIGN_IDENTITY',
        'MACOS_NOTARY_APPLE_ID',
        'MACOS_NOTARY_TEAM_ID',
        'MACOS_NOTARY_PASSWORD',
        'WINDOWS_CERT_PFX',
        'WINDOWS_CERT_PASSWORD',
        'ANDROID_KEYSTORE_BASE64',
        'ANDROID_KEYSTORE_PASSWORD',
        'ANDROID_KEY_ALIAS',
        'ANDROID_KEY_PASSWORD',
      ]) {
        expect(
          yaml,
          contains('secrets.$secret'),
          reason: '$secret is not wired',
        );
      }
    });

    test('no signing step is gated by an if:, so forks still build', () {
      expect(yaml, isNot(contains('if: \${{ secrets.')));
    });

    test('publishes a pre-release driven by the tag, and never tags 1.0.0', () {
      expect(yaml, contains('prerelease: \${{ needs.preflight.outputs.prerelease'));
      expect(yaml, isNot(contains('git tag')));
      expect(yaml, isNot(contains('v1.0.0\n')));
    });

    test('keeps the CI concurrency shape', () {
      expect(yaml, contains('concurrency:'));
      expect(yaml, contains('cancel-in-progress: false'));
      expect(yaml, contains('FLUTTER_VERSION: 3.47.2'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart test test/release_workflow_test.dart
```

Expected: FAIL — `PathNotFoundException` on `.github/workflows/release.yml`,
and the `workflow_call:` expectation on `ci.yml` fails.

- [ ] **Step 3: Make `ci.yml` reusable**

In `.github/workflows/ci.yml`, change only the `on:` block, from:

```yaml
on:
  pull_request:
  push:
    branches: [main]
  workflow_dispatch:
```

to:

```yaml
on:
  pull_request:
  push:
    branches: [main]
  workflow_dispatch:
  # release.yml calls this workflow so a release never packages a tree that
  # would fail CI, and so the release inherits the macOS integration job.
  workflow_call:
```

Nothing else in `ci.yml` changes. Under `workflow_call` the `integration`
job's `if: github.event_name != 'pull_request'` sees the caller's event
(`push` or `workflow_dispatch`), so it runs — which is the release-mode
integration run the gate asks for.

- [ ] **Step 4: Write the release workflow**

Create `.github/workflows/release.yml`:

```yaml
name: release
# Builds every release artifact and attaches it to a GitHub release
# (spec 10). Trigger it either by pushing a v* tag or by dispatching it with
# the tag name; the dispatch path is how a release is rehearsed before the
# tag exists. Every signing step degrades to an unsigned or ad-hoc artifact
# when its secret is missing, so a fork run produces the same file list.
on:
  workflow_dispatch:
    inputs:
      tag:
        description: The release tag to build, e.g. v1.0.0-rc.1
        required: true
        type: string
  push:
    tags:
      - 'v*'

# Unlike ci.yml, a release run is never cancelled by a newer one.
concurrency:
  group: release-${{ github.ref }}
  cancel-in-progress: false

permissions:
  contents: write

env:
  FLUTTER_VERSION: 3.47.2

jobs:
  preflight:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    outputs:
      tag: ${{ steps.version.outputs.tag }}
      version: ${{ steps.version.outputs.version }}
      build_name: ${{ steps.version.outputs.build_name }}
      apple_build_name: ${{ steps.version.outputs.apple_build_name }}
      build_number: ${{ steps.version.outputs.build_number }}
      slug: ${{ steps.version.outputs.slug }}
      prerelease: ${{ steps.version.outputs.prerelease }}
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: stable
          cache: true
      - run: flutter pub get
      # Validates the tag against app/pubspec.yaml and CHANGELOG.md, warns
      # (never fails) on the LICENSE TODO, and writes the outputs above.
      - id: version
        run: dart run tool/check_release.dart --tag "$RELEASE_TAG"
        env:
          RELEASE_TAG: ${{ inputs.tag || github.ref_name }}

  ci:
    needs: preflight
    uses: ./.github/workflows/ci.yml

  macos:
    needs: [preflight, ci]
    runs-on: macos-latest
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: stable
          cache: true
      - run: flutter pub get
      - name: Build
        run: >-
          flutter build macos --release
          --build-name ${{ needs.preflight.outputs.apple_build_name }}
          --build-number ${{ needs.preflight.outputs.build_number }}
        working-directory: app
      - name: Package
        run: >-
          tool/package/macos_dmg.sh
          app/build/macos/Build/Products/Release/spectra.app
          dist/${{ needs.preflight.outputs.slug }}-macos.dmg
        env:
          MACOS_CERT_P12: ${{ secrets.MACOS_CERT_P12 }}
          MACOS_CERT_PASSWORD: ${{ secrets.MACOS_CERT_PASSWORD }}
          MACOS_SIGN_IDENTITY: ${{ secrets.MACOS_SIGN_IDENTITY }}
          MACOS_NOTARY_APPLE_ID: ${{ secrets.MACOS_NOTARY_APPLE_ID }}
          MACOS_NOTARY_TEAM_ID: ${{ secrets.MACOS_NOTARY_TEAM_ID }}
          MACOS_NOTARY_PASSWORD: ${{ secrets.MACOS_NOTARY_PASSWORD }}
      - uses: actions/upload-artifact@v4
        with:
          name: macos
          path: dist/*

  windows:
    needs: [preflight, ci]
    runs-on: windows-latest
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: stable
          cache: true
      - run: flutter pub get
      - name: Build
        run: >-
          flutter build windows --release
          --build-name ${{ needs.preflight.outputs.build_name }}
          --build-number ${{ needs.preflight.outputs.build_number }}
        working-directory: app
      - name: Package
        shell: pwsh
        run: >-
          pwsh tool/package/windows_installer.ps1
          -BuildDir app\build\windows\x64\runner\Release
          -Version ${{ needs.preflight.outputs.build_name }}
          -OutDir dist
        env:
          WINDOWS_CERT_PFX: ${{ secrets.WINDOWS_CERT_PFX }}
          WINDOWS_CERT_PASSWORD: ${{ secrets.WINDOWS_CERT_PASSWORD }}
      - uses: actions/upload-artifact@v4
        with:
          name: windows
          path: dist/*

  linux:
    needs: [preflight, ci]
    runs-on: ubuntu-latest
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: stable
          cache: true
      - run: sudo apt-get update && sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev libsqlite3-dev
      - run: flutter pub get
      - name: Build
        run: >-
          flutter build linux --release
          --build-name ${{ needs.preflight.outputs.build_name }}
          --build-number ${{ needs.preflight.outputs.build_number }}
        working-directory: app
      - name: Package
        run: >-
          tool/package/linux_appimage.sh app/build/linux/x64/release/bundle
          ${{ needs.preflight.outputs.build_name }} dist
      - uses: actions/upload-artifact@v4
        with:
          name: linux
          path: dist/*

  android:
    needs: [preflight, ci]
    runs-on: ubuntu-latest
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: stable
          cache: true
      - run: flutter pub get
      # The Gradle config signs with the keystore when these are set and
      # falls back to the debug key when they are not.
      - name: Build apk and aab
        run: |
          flutter build apk --release \
            --build-name ${{ needs.preflight.outputs.build_name }} \
            --build-number ${{ needs.preflight.outputs.build_number }}
          flutter build appbundle --release \
            --build-name ${{ needs.preflight.outputs.build_name }} \
            --build-number ${{ needs.preflight.outputs.build_number }}
        working-directory: app
        env:
          ANDROID_KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
          ANDROID_KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          ANDROID_KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
          ANDROID_KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
      # The secret goes through the environment, never into the script text.
      - name: Name the artifacts
        run: |
          mkdir -p dist
          SUFFIX=android
          if [ -z "${ANDROID_KEYSTORE_BASE64:-}" ]; then
            SUFFIX=android-unsigned
          fi
          cp app/build/app/outputs/flutter-apk/app-release.apk \
            "dist/${SLUG}-$SUFFIX.apk"
          cp app/build/app/outputs/bundle/release/app-release.aab \
            "dist/${SLUG}-$SUFFIX.aab"
        env:
          ANDROID_KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
          SLUG: ${{ needs.preflight.outputs.slug }}
      - uses: actions/upload-artifact@v4
        with:
          name: android
          path: dist/*

  ios:
    needs: [preflight, ci]
    runs-on: macos-latest
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: stable
          cache: true
      - run: flutter pub get
      # No team id in the repo, so the ipa is unsigned; docs/RELEASING.md
      # carries the TestFlight route.
      - name: Build
        run: >-
          flutter build ios --release --no-codesign
          --build-name ${{ needs.preflight.outputs.apple_build_name }}
          --build-number ${{ needs.preflight.outputs.build_number }}
        working-directory: app
      - name: Package
        run: >-
          tool/package/ios_ipa.sh app/build/ios/iphoneos/Runner.app
          dist/${{ needs.preflight.outputs.slug }}-ios-unsigned.ipa
      - uses: actions/upload-artifact@v4
        with:
          name: ios
          path: dist/*

  publish:
    needs: [preflight, macos, windows, linux, android, ios]
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with:
          path: artifacts
      - run: ls -R artifacts
      - name: Extract the changelog entry for the release body
        run: |
          {
            echo "Artifacts for ${{ needs.preflight.outputs.tag }}."
            echo
            sed -n '/^## \[/,$p' CHANGELOG.md | sed -n '/^## \[[0-9]/,/^## \[[0-9].*\]/p' | head -n 60
          } > release-body.md
      - uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ needs.preflight.outputs.tag }}
          name: Spectra ${{ needs.preflight.outputs.version }}
          body_path: release-body.md
          prerelease: ${{ needs.preflight.outputs.prerelease == 'true' }}
          draft: true
          files: artifacts/**/*
```

- [ ] **Step 5: Run test to verify it passes**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart test test/release_workflow_test.dart
```

Expected: 12 tests PASS.

- [ ] **Step 6: Prove the workflow actually runs**

Push the branch, then dispatch it against the branch (the tag does not exist
yet — this is exactly what the `workflow_dispatch` input is for):

```bash
git push
gh workflow run release.yml --ref bobbyrc/chinook -f tag=v1.0.0-rc.1
gh run list --workflow release.yml --limit 1
gh run watch "$(gh run list --workflow release.yml --limit 1 --json databaseId -q '.[0].databaseId')"
```

Expected: every job green; the `publish` job's `ls -R artifacts` lists a dmg,
a Windows setup exe and zip, an AppImage and a tarball, an apk and an aab
(both named `-android-unsigned`), and an `-ios-unsigned.ipa`. Fix any red job
before continuing — a red release workflow blocks the phase gate. Delete the
draft release the dispatch created (`gh release delete v1.0.0-rc.1 --yes`)
once the artifacts are confirmed; the real one is created in Task 11.

- [ ] **Step 7: Commit**

```bash
git add .github/workflows/release.yml .github/workflows/ci.yml \
  test/release_workflow_test.dart
git commit -m "ci: add the release workflow

One workflow builds and publishes every platform's artifact. It calls ci.yml
rather than restating it, so a release can never ship a tree that fails CI."
```

---

### Task 10: The release runbook and the H3 hardware section

**Files:**
- Create: `docs/RELEASING.md`
- Modify: `docs/hardware-checklist.md` (the `## H3` section)
- Test: `test/release_docs_test.dart`

**Interfaces:**
- Consumes: every artifact name from Tasks 4-9 and the secret names from
  Global Constraints.
- Produces: documentation only. No code depends on it.

- [ ] **Step 1: Write the failing test**

Create `test/release_docs_test.dart`:

```dart
import 'dart:io';

import 'package:test/test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('docs/RELEASING.md', () {
    late String doc;
    setUpAll(() => doc = _read('docs/RELEASING.md'));

    test('names every secret the workflow reads', () {
      for (final String secret in const <String>[
        'MACOS_CERT_P12',
        'MACOS_SIGN_IDENTITY',
        'MACOS_NOTARY_TEAM_ID',
        'WINDOWS_CERT_PFX',
        'ANDROID_KEYSTORE_BASE64',
      ]) {
        expect(doc, contains(secret));
      }
    });

    test('carries the two open user decisions', () {
      expect(doc, contains('LICENSE'));
      expect(doc, contains('app icon'));
    });

    test('documents the TestFlight route and the RC-to-final steps', () {
      expect(doc, contains('TestFlight'));
      expect(doc, contains('v1.0.0-rc.1'));
      expect(doc, contains('v1.0.0'));
    });

    test('records that the vendored usb_serial override is release-blocking to re-check', () {
      expect(doc, contains('usb_serial'));
      expect(doc, contains('third_party'));
    });
  });

  group('the H3 checklist', () {
    late String doc;
    late String h3;
    setUpAll(() {
      doc = _read('docs/hardware-checklist.md');
      h3 = doc.substring(doc.indexOf('## H3'));
    });

    test('is no longer a stub', () {
      expect(h3, isNot(contains('Written in Phase 10.')));
      expect(h3.length, greaterThan(2000));
    });

    test('every spec 10 hardware item is present', () {
      for (final String item in const <String>[
        'connect',
        'pairing',
        'slot round trip',
        'HF',
        'LF',
        'USB DFU',
        'BLE DFU',
        'interrupted',
      ]) {
        expect(h3.toLowerCase(), contains(item.toLowerCase()));
      }
    });

    test('every item is still pending', () {
      final Iterable<RegExpMatch> boxes = RegExp(r'^- \[( |x)\]', multiLine: true)
          .allMatches(h3);
      expect(boxes, isNotEmpty);
      for (final RegExpMatch m in boxes) {
        expect(m.group(1), ' ', reason: 'an H3 box was ticked without a report');
      }
      expect(h3, contains('pending'));
    });

    test('tells the user which artifact to install per platform', () {
      expect(h3, contains('.dmg'));
      expect(h3, contains('setup.exe'));
      expect(h3, contains('AppImage'));
      expect(h3, contains('.apk'));
    });

    test('has a sign-off list that gates v1.0.0', () {
      expect(h3, contains('sign-off'));
      expect(h3, contains('v1.0.0'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart test test/release_docs_test.dart
```

Expected: FAIL — `PathNotFoundException` on `docs/RELEASING.md`.

- [ ] **Step 3: Write `docs/RELEASING.md`**

```markdown
# Releasing Spectra

Spec 10. Everything here is driven by `.github/workflows/release.yml`; this
file is the human half.

## The shape of a release

1. `app/pubspec.yaml` holds the version, e.g. `version: 1.0.0+1`. The `+N`
   is the build number every platform gets.
2. `CHANGELOG.md` holds one entry per released version, Keep a Changelog
   style. A release candidate does **not** get its own entry: `v1.0.0-rc.1`
   is validated against the `1.0.0` entry.
3. The git tag decides what is built. `v1.0.0-rc.1` publishes a
   pre-release; `v1.0.0` publishes a final release. Apple targets get the
   version core only (`1.0.0`), because `CFBundleShortVersionString` must be
   three dotted numbers; the RC identity survives in the tag and in every
   artifact file name.
4. `dart run melos run check:release` (or
   `dart run tool/check_release.dart --tag v1.0.0-rc.1`) proves 1-3 agree
   before anything is tagged.

## Running a release

Rehearse first, without a tag:

```bash
gh workflow run release.yml --ref <branch> -f tag=v1.0.0-rc.1
```

Then, for the real thing:

```bash
git tag -a v1.0.0-rc.1 -m "Spectra 1.0.0-rc.1"
git push origin v1.0.0-rc.1
```

The workflow calls `ci.yml` first (format, analyze, dependency lint, codegen
freshness, every test, the macOS integration run in emulator mode, and the
debug build matrix), then builds and packages each platform, then attaches
everything to a **draft** release. Review the draft and publish it by hand.

## Artifacts

| Platform | File | Signed? |
|---|---|---|
| macOS | `spectra-<version>-macos.dmg` | Developer ID + notarized when the secrets exist, ad-hoc otherwise |
| Windows | `spectra-<version>-windows-setup.exe`, `spectra-<version>-windows.zip` | Authenticode when `WINDOWS_CERT_PFX` exists |
| Linux | `spectra-<version>-linux-x86_64.AppImage`, `spectra-<version>-linux-x64.tar.gz` | Unsigned by design |
| Android | `spectra-<version>-android[-unsigned].apk` / `.aab` | Release keystore when `ANDROID_KEYSTORE_BASE64` exists, debug key otherwise |
| iOS | `spectra-<version>-ios-unsigned.ipa` | Never — see below |

## Secrets

Set these in the repository's Actions secrets. Every one is optional: when a
secret is missing the corresponding artifact is still built, unsigned or
ad-hoc signed, and the job says so in its log. That is deliberate, so a fork
and a secretless rehearsal produce the same file list.

- `MACOS_CERT_P12` — base64 of a Developer ID Application `.p12`
- `MACOS_CERT_PASSWORD` — that file's password
- `MACOS_SIGN_IDENTITY` — e.g. `Developer ID Application: Name (TEAMID)`
- `MACOS_NOTARY_APPLE_ID`, `MACOS_NOTARY_TEAM_ID`, `MACOS_NOTARY_PASSWORD` —
  an app-specific password for `notarytool`; all three or none
- `WINDOWS_CERT_PFX` — base64 of a code-signing `.pfx`
- `WINDOWS_CERT_PASSWORD`
- `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
  `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`

For a local Android release build, copy
`app/android/key.properties.example` to `app/android/key.properties`. That
path and `*.jks`/`*.keystore` are git-ignored; never commit a keystore.

## iOS and TestFlight

The repo carries no Apple Developer team id, so CI produces an **unsigned**
`.ipa`: useful for inspection and for re-signing, not installable as-is.
Spec 10 puts the mobile stores after v1. When a team is available, the route
is: add the team to `app/ios/Runner.xcodeproj`, add an `ExportOptions.plist`
with `method: app-store-connect` and that team id, then replace the `ios`
job's package step with
`flutter build ipa --export-options-plist=<that file>` and an
`xcrun altool`/`notarytool` upload. Nothing else in the workflow changes.

## Decisions still open (the user's, not an agent's)

- **LICENSE.** `packages/spectra_ui/LICENSE` and
  `packages/chameleon_flutter/LICENSE` still read
  `TODO: Add your license here.`; `packages/chameleon` and `app` have no
  LICENSE file. `tool/check_release.dart` prints this as a warning and
  never fails on it, so a release can be cut before the choice is made — but
  do not publish a public v1.0.0 without one.
- **App icon and launch assets.** Every platform still ships the
  `flutter create` defaults: `app/macos/Runner/Assets.xcassets/AppIcon.appiconset/`,
  `app/android/app/src/main/res/mipmap-*/ic_launcher.png`,
  `app/ios/Runner/Assets.xcassets/AppIcon.appiconset/`, and no Linux icon at
  all (the AppImage borrows the macOS 256px asset). Real branding is a
  design task, not a release-engineering one.
- **The vendored `usb_serial` override.** Root `pubspec.yaml` overrides
  `usb_serial` 0.5.2 with the patched copy at `third_party/usb_serial`
  (see `docs/research/DECISIONS.md`, Phase 3). Re-check for a fixed upstream
  release before shipping and drop the override then.

## Cutting v1.0.0

`v1.0.0` is **not** tagged until the user has run the H3 section of
`docs/hardware-checklist.md` against the `v1.0.0-rc.1` artifacts and
reported every item passing. Then:

1. Record the H3 results in `docs/hardware-checklist.md`.
2. Flip `dfuOverBleEnabled` to default-on only if the H2 and H3 BLE DFU
   items passed.
3. Move the `CHANGELOG.md` date if it has drifted.
4. `git tag -a v1.0.0 -m "Spectra 1.0.0" && git push origin v1.0.0`.
5. Publish the draft release the workflow creates.
```

- [ ] **Step 4: Replace the H3 section of `docs/hardware-checklist.md`**

Replace everything from `## H3 (before release): full checklist (spec section 10)`
to the end of the file with:

```markdown
## H3 (before release): the release-candidate pass (spec section 10)

Run against the **`v1.0.0-rc.1` artifacts**, not a `flutter run` debug
build — the point of H3 is that the thing being shipped works. Download them
from the release page:

```bash
gh release download v1.0.0-rc.1 -D ~/Downloads/spectra-rc1
```

Nothing below may be ticked from inference or from a green CI run. Report
each result and the agent records it here.

### Install the RC on each platform you have

- [ ] pending: **macOS.** Open `spectra-1.0.0-rc.1-macos.dmg`, drag Spectra
      to Applications, launch it. The dmg is ad-hoc signed unless the
      Developer ID secrets were set, so Gatekeeper will refuse the first
      launch: right-click the app and choose Open, or
      `xattr -dr com.apple.quarantine /Applications/spectra.app`. Report
      whether it launches and what Gatekeeper said.
- [ ] pending: **Windows.** Run
      `spectra-1.0.0-rc.1-windows-setup.exe`, accept the SmartScreen prompt
      (expected while unsigned), and confirm the Start-menu entry launches.
      Also unzip `spectra-1.0.0-rc.1-windows.zip` and run `spectra.exe` from
      it. Report both.
- [ ] pending: **Linux.**
      `chmod +x spectra-1.0.0-rc.1-linux-x86_64.AppImage &&
      ./spectra-1.0.0-rc.1-linux-x86_64.AppImage`. Report whether it starts
      and whether the window title and icon are right.
- [ ] pending: **Android.**
      `adb install spectra-1.0.0-rc.1-android-unsigned.apk` (or sideload it)
      and launch. Report whether Android complains about the debug
      signature.
- [ ] pending: **iOS.** The `.ipa` is unsigned and cannot be installed
      as-is. Confirm only that it unzips and that `Payload/Runner.app`
      exists; leave the install for the TestFlight route in
      `docs/RELEASING.md`.

### The hardware pass, on the RC build (macOS at minimum)

Chameleon Ultra attached over USB unless the item says otherwise. Turn
emulator mode **off** in Settings first, so no item can be satisfied by the
`Emulated Chameleon Ultra` row.

- [ ] pending: **connect over USB.** The connect screen lists the device;
      connecting reaches the dashboard. Report the firmware version, chip
      id and battery the dashboard shows.
- [ ] pending: **connect over BLE and pairing.** Unplug USB, wake the device
      with a button press, connect from the RC build. Report whether the OS
      pairing prompt appears, whether accepting it reaches the dashboard,
      and whether a second connect skips the prompt.
- [ ] pending: **slot round trip.** Rename a slot, change its tag type,
      make it active, disconnect, power-cycle the device, reconnect, and
      report whether all three survived.
- [ ] pending: **HF scan.** Present a MIFARE Classic card on the Read
      screen. Report the UID, ATQA/SAK, and whether the key check finds
      keys and the dump saves to the library.
- [ ] pending: **LF scan.** Present an EM410x tag. Report the id shown and
      whether it saves.
- [ ] pending: **write and emulate.** Load a saved card into a slot, make
      the slot active, and read it back with a second reader (or the
      Chameleon itself in reader mode). Report whether the emulated card is
      seen with the right UID.
- [ ] pending: **USB DFU with the RC build.** Update the device from the
      Tools tab over USB with a real Chameleon release package. Report the
      progress behaviour, the total time, and the firmware version after the
      reboot.
- [ ] pending: **recovery from an interrupted DFU.** Start a USB DFU and
      unplug the cable mid-transfer. Report whether the app detects the
      bootloader on reconnect and completes the recovery flow.
- [ ] pending: **BLE DFU — only if `dfuOverBleEnabled` is on.** The flag
      defaults off and flips only after H2 passed. If it is on, run a DFU
      over BLE from macOS and report the result; if it is off, report that
      and tick nothing.
- [ ] pending: **background and foreground on mobile.** On Android (and iOS
      if a signed build is available), connect, send the app to the
      background for under 30 seconds and return: the session should still
      be live. Then background it for over a minute and return: it should
      have closed and silently reconnected. Report both.
- [ ] pending: **USB detach.** With the app connected, unplug the device.
      Report whether the app returns to the connect screen with that device
      preselected, and the message it shows.
- [ ] pending: **the frame log.** Open Tools -> frame log after the runs
      above and export it. Attach the export to the report; it is the
      evidence for every item here.

### Sign-off list for `v1.0.0`

`v1.0.0` is tagged only when all of these are true. An agent may not tick
any of them.

- [ ] pending: every H1 item above reported and recorded.
- [ ] pending: every H2 item above reported and recorded.
- [ ] pending: every H3 item in this section reported and recorded.
- [ ] pending: the LICENSE decision made (see `docs/RELEASING.md`).
- [ ] pending: the `dfuOverBleEnabled` default decided from the H2/H3 BLE
      results.
- [ ] pending: the vendored `usb_serial` override re-checked against
      upstream.
- [ ] pending: the release workflow green on the `v1.0.0-rc.1` tag with
      every artifact attached.
```

- [ ] **Step 5: Run test to verify it passes**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart test test/release_docs_test.dart
```

Expected: 10 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add docs/RELEASING.md docs/hardware-checklist.md test/release_docs_test.dart
git commit -m "docs(release): add the release runbook and the H3 checklist

H3 is run against the RC artifacts rather than a debug build, because the
point of the gate is that the shipped thing works."
```

---

### Task 11: Close out Phase 10 and tag `v1.0.0-rc.1`

**Files:**
- Modify: `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md`,
  `AGENTS.md`, `docs/research/DECISIONS.md`, `tasks/lessons.md`

**Interfaces:**
- Consumes: everything from Tasks 1-10.
- Produces: an annotated `v1.0.0-rc.1` tag and a green release run. Produces
  **no** `v1.0.0` tag.

- [ ] **Step 1: Prove the whole gate is green**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
dart run melos run check:all
dart run melos run check:release
git push
gh run watch "$(gh run list --workflow ci.yml --branch bobbyrc/chinook --limit 1 --json databaseId -q '.[0].databaseId')"
```

Expected: `check:all` green, `check_release: ok (1.0.0-rc.1)`, and the `ci`
workflow green on the branch. Do not proceed on a red run.

- [ ] **Step 2: Tick the roadmap**

In `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md`, in the Phase
status list, change `- [ ] Phase 10` to `- [x] Phase 10`. In the phase
table, change the Phase 10 row's Plan cell from `write from spec 10` to
`` `2026-09-03-phase-10-release.md` (done) ``.

- [ ] **Step 3: Update `AGENTS.md`**

Replace the "Next:" paragraph of the "Current status" section with:

```markdown
Phase 10 (release) is complete (2026-09-03): `.github/workflows/release.yml`
builds and publishes artifacts for all five platforms (macOS `.dmg`,
Windows installer plus zip, Linux AppImage plus tarball, Android `.apk` and
`.aab`, an unsigned iOS `.ipa`), calling `ci.yml` through its new
`workflow_call` trigger so a release can never ship a tree that fails CI.
Every signing step lives in a script under `tool/package/` and degrades to
an unsigned or ad-hoc artifact when its secret is absent, so a fork build
produces the same file list. `tool/check_release.dart` reconciles the tag
with `app/pubspec.yaml` and `CHANGELOG.md` and reports the LICENSE TODO as
a warning only. Runbook: `docs/RELEASING.md`.

Next: the user runs the H3 section of `docs/hardware-checklist.md` against
the `v1.0.0-rc.1` artifacts. `v1.0.0` is tagged only after that report and
the sign-off list at the end of H3 — no agent tags it.
```

Add to the "Decisions made overnight" list:

```markdown
- Release artifacts are unsigned-by-default: signing is a script-level
  decision keyed on the presence of a secret, never a workflow `if:`, so a
  fork or a secretless rehearsal still produces every artifact.
- Apple targets build with the version core only (`1.0.0`), because
  `CFBundleShortVersionString` rejects a pre-release suffix; the RC identity
  lives in the tag and the artifact names.
- The iOS artifact is an unsigned `.ipa`. There is no Apple team id in the
  repo; the TestFlight route is written down in `docs/RELEASING.md` instead
  of automated.
- A release candidate gets no changelog entry of its own; it is validated
  against the entry it is a candidate for.
```

- [ ] **Step 4: Record the decisions**

Append to `docs/research/DECISIONS.md`, after the Phase 5 section (or after
whatever the newest phase section is when this runs):

```markdown
## Phase 10 decisions (2026-09-03)

- **Signing degrades in the script, not in the workflow.** GitHub's `secrets`
  context is awkward to test in a step `if:`, and gating there would mean a
  fork's release run produces a *different* file list from the maintainer's.
  Each packaging script reads the secret from its environment and picks
  signed or ad-hoc itself, printing which. The artifact always exists.
- **`release.yml` calls `ci.yml` rather than restating it.** A second copy of
  the `check` job would drift. `workflow_call` was added to `ci.yml` and
  nothing else changed; under it the `integration` job's
  `if: github.event_name != 'pull_request'` sees the caller's event, so the
  release inherits the macOS emulator-mode integration run for free.
- **Apple builds get the version core.** `CFBundleShortVersionString` must be
  three dotted numbers, so `ReleaseVersion.appleBuildName` strips the
  pre-release. Everything else builds `1.0.0-rc.1`.
- **No `.deb`.** Spec 10 asks for an AppImage; the extra tarball covers the
  "give me the files" case, and a `.deb` would need a maintained dependency
  list nobody is going to keep current.
- **The `.ipa` is unsigned.** Spec 10 defers the mobile stores; without a
  team id every committed `ExportOptions.plist` would be a placeholder.
- **The LICENSE TODO warns, never fails.** Choosing a licence is the user's
  call (AGENTS.md); a release can be rehearsed and an RC cut before it is
  made, and `docs/RELEASING.md` blocks a public v1.0.0 on it.
- **A release candidate gets no changelog entry.** `v1.0.0-rc.1` is checked
  against the `1.0.0` entry, so an RC cannot be cut for a release that has
  not been written up.
```

- [ ] **Step 5: Add the lessons**

Append to `tasks/lessons.md`:

```markdown
## Phase 10 (release)

- **Package with scripts, call them from the workflow.** Every packaging
  decision that lives in a `.yml` is untestable and unrunnable locally. The
  scripts under `tool/package/` are asserted on by `test/packaging_test.dart`
  and can be run by hand on the same inputs CI uses.
- **A secret-gated `if:` in a workflow is a fork trap.** It makes the
  maintainer's run and a contributor's run produce different artifacts, and
  the difference only shows up on a release day. Push the decision into the
  script and let it degrade.
- **`workflow_call` beats copying a job.** Adding one trigger line to
  `ci.yml` gave the release the whole check matrix and the macOS integration
  run without a second copy to keep in sync.
- **Rehearse a release with `workflow_dispatch` before the tag exists.** The
  tag is immutable-ish and a failed release run against one is noisy; the
  dispatch input builds the same thing off a branch.
```

- [ ] **Step 6: Commit the close-out**

```bash
git add docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md AGENTS.md \
  docs/research/DECISIONS.md tasks/lessons.md
git commit -m "docs: close out Phase 10

Records the release decisions and points the next session at the H3
hardware pass, which is the only thing between the RC and v1.0.0."
```

- [ ] **Step 7: Tag the release candidate**

Only after Step 1's CI run is green and the commits above are pushed:

```bash
git push
gh run watch "$(gh run list --workflow ci.yml --branch bobbyrc/chinook --limit 1 --json databaseId -q '.[0].databaseId')"
git tag -a v1.0.0-rc.1 -m "Spectra 1.0.0-rc.1

The first release candidate. Artifacts for all five platforms are attached
to the release; the hardware pass (H3 in docs/hardware-checklist.md) is
what stands between this and v1.0.0."
git push origin v1.0.0-rc.1
gh run watch "$(gh run list --workflow release.yml --limit 1 --json databaseId -q '.[0].databaseId')"
```

Expected: the release workflow runs to green and creates a **draft
pre-release** `v1.0.0-rc.1` with every artifact attached. Verify with:

```bash
gh release view v1.0.0-rc.1
```

- [ ] **Step 8: Stop. Do not tag `v1.0.0`.**

Report to the user:

- the release page URL and the artifact list,
- that `docs/hardware-checklist.md` section H3 is waiting for them,
- that `v1.0.0` is deliberately untagged until they report H3 passing and
  the sign-off list at the end of H3 is complete,
- the two decisions only they can make: the LICENSE and the app icons.

---

## Self-review

**Spec coverage (section 10, release half).**

| Spec requirement | Task |
|---|---|
| "Tagged builds produce release artifacts" | 9 |
| "Signing and notarization are added at the first release" | 4 (macOS), 5 (Windows), 7 (Android) |
| "Desktop ships as a signed installer per platform" | 4, 5, 6 |
| "Linux as an AppImage" | 6 |
| "Mobile stores are a later step" | 7 (apk/aab on the release page), 8 + 10 (iOS unsigned, TestFlight documented) |
| "Semantic versions" | 1, 3 |
| "a changelog" | 2 |
| "Hardware checklist … run before every release … connect, pairing, slot round trip, HF and LF scan, USB DFU, BLE DFU, recovery from interrupted DFU. This gate is not optional." | 10 (every item present), 11 (sign-off gates `v1.0.0`) |
| CI shape unchanged, release-mode builds, integration on macOS | 9 (`ci.yml` gains only `workflow_call`; each platform job builds `--release`; the called `ci.yml` runs `flutter test integration_test -d macos`) |
| Spec 5.7 platform files a release build needs | 4 (macOS `Release.entitlements` used for signing), 7 (Android release signing); the manifests and plists themselves are already landed and asserted by `test/platform_setup_test.dart` |

Roadmap gate: CI green (Task 11 Step 1), artifacts built (Task 9 Step 6 and
Task 11 Step 7), H3 section written (Task 10), `v1.0.0` waits (Task 11 Step 8).

**Placeholder scan.** No "TBD", no "similar to Task N", no "add error
handling". The one literal `TODO` string in the plan is the *existing*
LICENSE template text, quoted deliberately and asserted on. Every code step
carries the full file contents.

**Type and name consistency.** `ReleaseVersion` (Task 1) is used by name in
Task 3's CLI and by its `outputs` keys in Task 9's workflow outputs and
tests. `ChangelogEntry`/`latestReleasedEntry` (Task 2) are used unchanged in
Task 3. `LicenseState`/`licenseStates` (Task 3) match their test. Artifact
names use `slug` = `spectra-<build_name>` consistently across Tasks 4-6, 8,
9 and 10. `test/packaging_test.dart` is created in Task 4 and extended (never
recreated) in Tasks 5, 6, 7 and 8; the running test count is stated at each
step. Build-output paths, the binary name `spectra`, the bundle id
`dev.spectra.spectra` and `app/macos/Runner/Release.entitlements` are all
quoted from the landed files listed in "Landed facts".

**Consistency with the landed workflows.** `release.yml` reuses `ci.yml`'s
`env.FLUTTER_VERSION: 3.47.2`, its `actions/checkout@v4` +
`subosito/flutter-action@v2` (`channel: stable`, `cache: true`) setup, its
`apt-get` line for Linux, its `actions/setup-java@v4` `temurin`/`17` for
Android, per-job `timeout-minutes`, and a `concurrency` group in the same
shape (with `cancel-in-progress: false`, since a release must not be
cancelled). The only edit to `ci.yml` is the added `workflow_call:` trigger,
which Task 9's test pins alongside every existing trigger and job.
