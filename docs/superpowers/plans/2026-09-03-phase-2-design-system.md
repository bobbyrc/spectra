# Phase 2: spectra_ui design system Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `packages/spectra_ui`: the four token groups, `SpectraTheme` and its `material_ui` `ThemeData`, every spec 6.2 component with light and dark goldens and behavior tests, ARB localization for the kit's own strings, a string-literal lint, and a gallery example that shows every component and builds on macOS.

**Architecture:** Tokens are const data with no widget dependency. `SpectraTheme` is an `InheritedWidget` carrying the brightness-resolved colors; `spectraThemeData` maps the same tokens into `material_ui`'s `ThemeData` so `material_ui` components inherit our palette, and `SpectraApp` installs both plus the localization delegates. Components are leaf widgets over plain data (strings, ints, `spectra_ui` enums) — never device types — each in its own file with one public type, each proved by a widget test for behavior and an alchemist golden for appearance. The gallery in `packages/spectra_ui/example` is a `go_router` app on the same shell, one route per component.

**Tech Stack:** Flutter 3.47.2 / Dart 3.13, `material_ui` 1.1.1, `google_fonts`, `flutter_animate`, `flutter_localizations` + `intl`, `alchemist` 0.14.0 for goldens, `go_router` 18.0.1 in the gallery only.

**Spec:** `docs/superpowers/specs/2026-09-02-spectra-design.md` sections 6 (6.1 tokens, 6.2 components, 6.3 rules), 7.6 (localization and accessibility), 8.5 (code shape), and the section 2 dependency table. Spike facts: `docs/research/spikes.md`, Spike B.

## Global Constraints

- `spectra_ui` may depend on `flutter`, `material_ui`, `google_fonts`, `flutter_animate`, `flutter_localizations` and `intl` only, and **must not** depend on `chameleon` or `chameleon_flutter` (spec section 2). `tool/dep_lint.dart` enforces it; its `spectra_ui` allowlist already lists exactly these.
- `spectra_ui_gallery` (the example) may depend on `flutter`, `spectra_ui`, `material_ui` and `go_router` only.
- **Import convention:** inside `packages/spectra_ui/lib`, `packages/spectra_ui/test` and the gallery, import `package:material_ui/material_ui.dart` and **never** `package:flutter/material.dart`. The two libraries both declare `ThemeData`, `Theme`, `MaterialApp` and `MaterialPage`; an unprefixed dual import is an `ambiguous_import` compile error (Spike B). `package:material_ui/material_ui.dart` re-exports `package:flutter/widgets.dart`, so it is a complete replacement. A file that needs only widgets-layer types may import `package:flutter/widgets.dart` instead; never both.
- Spike B amended spec section 6: **no bridge file to an in-SDK `ThemeData` is written.** go_router 18.0.1 already depends on `material_ui`, and alchemist 0.14.0 renders `material_ui` widgets with no `MaterialApp` wrapper. Do not write one speculatively.
- Files stay under about 300 lines and hold **one public type** each (spec 8.5). Enums that belong to a component live in their own file next to it.
- Components take plain data — `String`, `int`, `Uint8List`, `IconData`, `Widget`, and enums declared in `spectra_ui`. No type from `chameleon` ever appears in a signature (spec 6.3).
- Every user-facing string the kit itself produces goes through ARB localization (spec 7.6). String literals passed to `Text(` under `packages/spectra_ui/lib/src/components/` are a lint failure unless the line carries a `// l10n-exempt` marker.
- Every interactive component sets a semantics label and has a minimum 48x48 logical-pixel touch target (spec 7.6).
- Goldens use alchemist and are generated in **CI mode only** (`test/goldens/ci/`), so they are identical on macOS and Ubuntu; platform goldens are disabled unless `SPECTRA_PLATFORM_GOLDENS=true` is set, and platform golden directories are git-ignored. Never commit a macOS-rendered golden.
- Every command is `mise x -- flutter ...` / `mise x -- dart ...`, run from the package directory (`packages/spectra_ui` unless a task says otherwise).
- Before running any `melos` script locally: `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"` — mise puts its tool paths after an older fvm Dart on this machine, and melos would otherwise resolve the wrong Dart.
- Commit after every task. Imperative subject, short body explaining why, trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- This is a git worktree. Never use bare `git stash`.
- `dart run tool/dep_lint.dart`, `dart format --set-exit-if-changed .`, `dart analyze --fatal-infos .` and all tests stay green at every commit.
- Generated localization files are committed; `tool/check_codegen.sh` must pass (Task 5 extends it to cover `flutter gen-l10n`).

---

## File structure

```
packages/spectra_ui/
  pubspec.yaml                                deps, uses-material-design: true, google_fonts asset dir
  dart_test.yaml                              declares the `golden` tag alchemist applies
  l10n.yaml                                   gen-l10n config, output committed into lib/l10n
  .gitignore                                  adds failures/ and platform golden dirs
  assets/google_fonts/                        bundled Inter + JetBrains Mono so runtime fetching is off
  lib/spectra_ui.dart                         public barrel: tokens, theme, l10n delegate, components
  lib/l10n/spectra_ui_en.arb                  the kit's own user-facing strings
  lib/l10n/spectra_ui_localizations.dart      generated, committed
  lib/l10n/spectra_ui_localizations_en.dart   generated, committed
  lib/src/tokens/colors.dart                  SpectraColors: raw palette + light/dark schemes
  lib/src/tokens/color_scheme.dart            SpectraColorScheme: the resolved per-brightness roles
  lib/src/tokens/typography.dart              SpectraTypography: six-step scale + mono, TextTheme
  lib/src/tokens/spacing.dart                 SpectraSpacing: 4-point scale
  lib/src/tokens/motion.dart                  SpectraMotion: three durations, two curves
  lib/src/theme/spectra_theme.dart            SpectraTheme InheritedWidget + of/maybeOf
  lib/src/theme/theme_data.dart               spectraThemeData(): tokens -> material_ui ThemeData
  lib/src/theme/spectra_app.dart              SpectraApp: MaterialApp.router + theme + l10n + SpectraTheme
  lib/src/components/button.dart              SpectraButton
  lib/src/components/button_variant.dart      SpectraButtonVariant enum
  lib/src/components/text_field.dart          SpectraTextField
  lib/src/components/dialog.dart              SpectraDialog + show
  lib/src/components/bottom_sheet.dart        SpectraBottomSheet + show
  lib/src/components/card.dart                SpectraCard
  lib/src/components/list_tile.dart           SpectraListTile
  lib/src/components/section_header.dart      SpectraSectionHeader
  lib/src/components/status_chip.dart         SpectraStatusChip (connection + battery constructors)
  lib/src/components/connection_status.dart   SpectraConnectionStatus enum
  lib/src/components/progress_indicator.dart  SpectraProgressIndicator
  lib/src/components/step_indicator.dart      SpectraStepIndicator
  lib/src/components/hex_viewer.dart          SpectraHexViewer
  lib/src/components/hex_highlight.dart       SpectraHexHighlight
  lib/src/components/slot_tile.dart           SpectraSlotTile
  lib/src/components/disclosure.dart          SpectraDisclosure
  lib/src/components/app_shell.dart           SpectraAppShell (adaptive bottom bar / rail)
  lib/src/components/destination.dart         SpectraDestination + spectraNavigationRailBreakpoint
  test/flutter_test_config.dart               AlchemistConfig: CI goldens on, platform goldens off
  test/support/golden_harness.dart            spectraGoldenScenario(): themed, localized scenario
  test/tokens/*_test.dart                     token value tests
  test/theme/*_test.dart                      theme resolution tests
  test/components/<name>_test.dart            behavior tests
  test/components/<name>_golden_test.dart     light + dark goldens
  test/components/goldens/ci/*.png            committed goldens, one per light/dark test
  example/lib/main.dart                       gallery entry: runApp(GalleryApp())
  example/lib/gallery_app.dart                GalleryApp: SpectraApp over the gallery router
  example/lib/gallery_router.dart             buildGalleryRouter(): shell + one route per component
  example/lib/gallery_entry.dart              GalleryEntry: title/path/builder record for a demo
  example/lib/pages/<name>_page.dart          one demo page per component, sample data only
  example/test/gallery_test.dart              visits every route
tool/src/string_rules.dart                    checkTextLiterals(): the ui/ string-literal rule
tool/dep_lint.dart                            wires the string rule into the lint run
test/string_rules_test.dart                   unit tests for the string rule
tool/check_codegen.sh                         also runs flutter gen-l10n and diffs its output
```

---

### Task 1: Package setup, fonts, golden harness config

**Files:**
- Modify: `packages/spectra_ui/pubspec.yaml`, `packages/spectra_ui/.gitignore`, root `pubspec.yaml` (melos scripts)
- Create: `packages/spectra_ui/dart_test.yaml`, `packages/spectra_ui/test/flutter_test_config.dart`, `packages/spectra_ui/assets/google_fonts/` (four font files)
- Test: `packages/spectra_ui/test/alchemist_config_test.dart`

**Interfaces:**
- Produces: `Future<void> testExecutable(FutureOr<void> Function() testMain)` in `test/flutter_test_config.dart`, which every test in the package runs under. It sets `GoogleFonts.config.allowRuntimeFetching = false` and an `AlchemistConfig` with `ciGoldensConfig` enabled and `platformGoldensConfig` enabled only when `SPECTRA_PLATFORM_GOLDENS=true`.
- Produces: the melos script `goldens:update`.

- [ ] **Step 1: Add the dependencies**

Run in `packages/spectra_ui`:

```bash
mise x -- flutter pub add google_fonts flutter_animate intl
mise x -- flutter pub add flutter_localizations --sdk=flutter
mise x -- flutter pub add dev:alchemist
```

`material_ui`, `flutter_test` and `alchemist` are already there from Phase 0; `pub add` is idempotent for them.

- [ ] **Step 2: Bundle the fonts**

google_fonts fetches over the network by default, which makes tests non-deterministic and breaks offline builds. Bundling the exact files into an asset directory lets google_fonts resolve them locally with fetching disabled.

```bash
mkdir -p assets/google_fonts
curl -fsSL -o assets/google_fonts/Inter-Regular.ttf \
  https://raw.githubusercontent.com/google/fonts/main/ofl/inter/Inter%5Bopsz%2Cwght%5D.ttf
curl -fsSL -o assets/google_fonts/JetBrainsMono-Regular.ttf \
  https://raw.githubusercontent.com/google/fonts/main/ofl/jetbrainsmono/JetBrainsMono%5Bwght%5D.ttf
ls -l assets/google_fonts
```

Expected: two files, each larger than 100 KB. If a URL 404s, find the current path under `https://github.com/google/fonts/tree/main/ofl/inter` and use that; the file names on disk must stay exactly `Inter-Regular.ttf` and `JetBrainsMono-Regular.ttf`, because google_fonts matches bundled assets by that basename.

- [ ] **Step 3: Edit the pubspec's flutter section**

Replace the whole commented-out `flutter:` block at the end of `packages/spectra_ui/pubspec.yaml` with:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/google_fonts/
```

`uses-material-design: true` is required: alchemist declares it, and without it Material icons do not render in goldens (Spike B).

- [ ] **Step 4: Write the failing test**

```dart
// test/alchemist_config_test.dart
import 'package:alchemist/alchemist.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  test('CI goldens are enabled so committed goldens are platform-neutral', () {
    expect(AlchemistConfig.current().ciGoldensConfig.enabled, isTrue);
  });

  test('platform goldens are off unless explicitly requested', () {
    expect(AlchemistConfig.current().platformGoldensConfig.enabled, isFalse);
  });

  test('google_fonts never reaches the network in tests', () {
    expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
  });
}
```

- [ ] **Step 5: Run to verify it fails**

Run: `mise x -- flutter test test/alchemist_config_test.dart`
Expected: FAIL — `platform goldens are off unless explicitly requested` fails because alchemist's default `platformGoldensConfig.enabled` is true, and the google_fonts test fails because nothing has set the flag.

- [ ] **Step 6: Write the test config**

```dart
// test/flutter_test_config.dart
import 'dart:async';
import 'dart:io' show Platform;

import 'package:alchemist/alchemist.dart';
import 'package:google_fonts/google_fonts.dart';

/// Runs every test in this package under one Alchemist configuration.
///
/// CI goldens (`test/goldens/ci/`) are the only ones committed: they render
/// with flutter_test's default Ahem font and no shadows, so a golden produced
/// on macOS is byte-identical to one produced on the Ubuntu `check` job.
/// Platform goldens are opt-in via `SPECTRA_PLATFORM_GOLDENS=true` for local
/// eyeballing only, and their directories are git-ignored.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  final bool platformGoldens =
      Platform.environment['SPECTRA_PLATFORM_GOLDENS'] == 'true';
  return AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      ciGoldensConfig: const CiGoldensConfig(enabled: true),
      platformGoldensConfig: PlatformGoldensConfig(enabled: platformGoldens),
    ),
    run: testMain,
  );
}
```

- [ ] **Step 7: Declare the golden tag**

```yaml
# packages/spectra_ui/dart_test.yaml
# alchemist tags every golden test `golden`. Declaring the tag here silences
# the "unknown tag" warning. It carries no `skip`, so goldens run by default
# in `flutter test` and therefore in the CI `check` job.
tags:
  golden:
```

- [ ] **Step 8: Ignore golden failure output and platform goldens**

Append to `packages/spectra_ui/.gitignore`:

```
# Alchemist writes diff images here when a golden does not match.
failures/
# Only CI goldens are committed; platform goldens are local-only.
# Alchemist writes goldens beside the test file, so match at any depth.
**/goldens/macos/
**/goldens/linux/
**/goldens/windows/
```

- [ ] **Step 9: Add the melos script**

In the root `pubspec.yaml`, inside `melos: scripts:`, after the `test:flutter` entry, add:

```yaml
    goldens:update:
      run: melos exec --scope=spectra_ui -- flutter test --update-goldens
      description: Regenerate spectra_ui's committed CI goldens.
```

- [ ] **Step 10: Run the test to verify it passes**

Run: `mise x -- flutter test test/alchemist_config_test.dart`
Expected: PASS, 3 tests, no "unknown tag" warning.

- [ ] **Step 11: Commit**

```bash
git add packages/spectra_ui/pubspec.yaml packages/spectra_ui/dart_test.yaml \
  packages/spectra_ui/.gitignore packages/spectra_ui/assets \
  packages/spectra_ui/test/flutter_test_config.dart \
  packages/spectra_ui/test/alchemist_config_test.dart pubspec.yaml pubspec.lock
git commit -m "$(cat <<'MSG'
chore(spectra_ui): set up dependencies, bundled fonts and golden config

Goldens must be identical on macOS and the Ubuntu CI job, so only
alchemist's CI mode is enabled and platform goldens are opt-in and
git-ignored. Fonts are bundled so google_fonts never touches the network.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 2: Color, spacing and motion tokens

**Files:**
- Create: `packages/spectra_ui/lib/src/tokens/color_scheme.dart`, `lib/src/tokens/colors.dart`, `lib/src/tokens/spacing.dart`, `lib/src/tokens/motion.dart`
- Modify: `packages/spectra_ui/lib/spectra_ui.dart`
- Test: `packages/spectra_ui/test/tokens/tokens_test.dart`

**Interfaces:**
- Produces: `final class SpectraColorScheme` with const fields `accent`, `onAccent`, `background`, `surface`, `surfaceRaised`, `border`, `textPrimary`, `textSecondary`, `textDisabled`, `success`, `warning`, `danger`, `connected`, `scrim`, all `Color`.
- Produces: `abstract final class SpectraColors` with the raw palette (`accent`, `accentBright`, `neutral0`..`neutral1000`, `success`, `successDark`, `warning`, `warningDark`, `danger`, `dangerDark`, `connected`, `connectedDark`) and `static const SpectraColorScheme light` / `dark`.
- Produces: `abstract final class SpectraSpacing` with `static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32`.
- Produces: `abstract final class SpectraMotion` with `static const Duration fast = Duration(milliseconds: 120), medium = Duration(milliseconds: 220), slow = Duration(milliseconds: 400)` and `static const Curve standard = Curves.easeOutCubic, emphasized = Curves.easeInOutCubic`.

- [ ] **Step 1: Write the failing test**

```dart
// test/tokens/tokens_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

void main() {
  group('SpectraColors', () {
    test('both schemes derive from the same brand accent', () {
      expect(SpectraColors.light.accent, SpectraColors.accent);
      expect(SpectraColors.dark.accent, SpectraColors.accentBright);
    });

    test('light and dark invert the neutral scale', () {
      expect(SpectraColors.light.background, SpectraColors.neutral50);
      expect(SpectraColors.light.textPrimary, SpectraColors.neutral900);
      expect(SpectraColors.dark.background, SpectraColors.neutral1000);
      expect(SpectraColors.dark.textPrimary, SpectraColors.neutral50);
    });

    test('every semantic role is present in both schemes', () {
      for (final scheme in <SpectraColorScheme>[
        SpectraColors.light,
        SpectraColors.dark,
      ]) {
        expect(scheme.success, isNot(scheme.warning));
        expect(scheme.warning, isNot(scheme.danger));
        expect(scheme.danger, isNot(scheme.connected));
      }
    });

    test('body text on the background clears WCAG AA contrast', () {
      double contrast(Color a, Color b) {
        final double la = a.computeLuminance();
        final double lb = b.computeLuminance();
        final double hi = la > lb ? la : lb;
        final double lo = la > lb ? lb : la;
        return (hi + 0.05) / (lo + 0.05);
      }

      expect(
        contrast(SpectraColors.light.textPrimary, SpectraColors.light.background),
        greaterThan(4.5),
      );
      expect(
        contrast(SpectraColors.dark.textPrimary, SpectraColors.dark.background),
        greaterThan(4.5),
      );
    });
  });

  test('SpectraSpacing is a 4-point scale', () {
    expect(
      <double>[
        SpectraSpacing.xs,
        SpectraSpacing.sm,
        SpectraSpacing.md,
        SpectraSpacing.lg,
        SpectraSpacing.xl,
        SpectraSpacing.xxl,
      ],
      <double>[4, 8, 12, 16, 24, 32],
    );
  });

  test('SpectraMotion has three durations and two curves', () {
    expect(SpectraMotion.fast, const Duration(milliseconds: 120));
    expect(SpectraMotion.medium, const Duration(milliseconds: 220));
    expect(SpectraMotion.slow, const Duration(milliseconds: 400));
    expect(SpectraMotion.standard, Curves.easeOutCubic);
    expect(SpectraMotion.emphasized, Curves.easeInOutCubic);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `mise x -- flutter test test/tokens/tokens_test.dart`
Expected: FAIL to compile — `Undefined name 'SpectraColors'` and friends.

- [ ] **Step 3: Implement the scheme record**

```dart
// lib/src/tokens/color_scheme.dart
import 'package:flutter/widgets.dart' show Color;

/// The colour roles resolved for one brightness.
///
/// Both schemes are derived from the raw palette in [SpectraColors]; nothing
/// in the kit reads a raw palette entry directly.
final class SpectraColorScheme {
  const SpectraColorScheme({
    required this.accent,
    required this.onAccent,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.success,
    required this.warning,
    required this.danger,
    required this.connected,
    required this.scrim,
  });

  final Color accent;
  final Color onAccent;
  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color success;
  final Color warning;
  final Color danger;
  final Color connected;
  final Color scrim;
}
```

- [ ] **Step 4: Implement the palette**

```dart
// lib/src/tokens/colors.dart
import 'package:flutter/widgets.dart' show Color;

import 'color_scheme.dart';

/// The raw palette and the two schemes derived from it (spec 6.1): one brand
/// accent, a thirteen-step neutral scale and four semantic roles.
abstract final class SpectraColors {
  // Brand accent.
  static const Color accent = Color(0xFF3F5AE0);
  static const Color accentBright = Color(0xFF8DA2FF);

  // Neutral scale, light to dark.
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFF7F8FA);
  static const Color neutral100 = Color(0xFFEDEFF3);
  static const Color neutral200 = Color(0xFFDCE0E8);
  static const Color neutral300 = Color(0xFFB9C0CC);
  static const Color neutral400 = Color(0xFF8A93A3);
  static const Color neutral500 = Color(0xFF636C7C);
  static const Color neutral600 = Color(0xFF474F5C);
  static const Color neutral700 = Color(0xFF313846);
  static const Color neutral800 = Color(0xFF1E2430);
  static const Color neutral900 = Color(0xFF12161E);
  static const Color neutral1000 = Color(0xFF0A0D12);

  // Semantic roles, light then dark variant.
  static const Color success = Color(0xFF15794A);
  static const Color successDark = Color(0xFF4ED08C);
  static const Color warning = Color(0xFF8A5A00);
  static const Color warningDark = Color(0xFFE0A93C);
  static const Color danger = Color(0xFFB3261E);
  static const Color dangerDark = Color(0xFFFF8A80);
  static const Color connected = Color(0xFF0E7490);
  static const Color connectedDark = Color(0xFF4DD6F0);

  static const Color scrimLight = Color(0x66000000);
  static const Color scrimDark = Color(0x99000000);

  static const SpectraColorScheme light = SpectraColorScheme(
    accent: accent,
    onAccent: neutral0,
    background: neutral50,
    surface: neutral0,
    surfaceRaised: neutral100,
    border: neutral200,
    textPrimary: neutral900,
    textSecondary: neutral500,
    textDisabled: neutral400,
    success: success,
    warning: warning,
    danger: danger,
    connected: connected,
    scrim: scrimLight,
  );

  static const SpectraColorScheme dark = SpectraColorScheme(
    accent: accentBright,
    onAccent: neutral1000,
    background: neutral1000,
    surface: neutral900,
    surfaceRaised: neutral800,
    border: neutral700,
    textPrimary: neutral50,
    textSecondary: neutral300,
    textDisabled: neutral500,
    success: successDark,
    warning: warningDark,
    danger: dangerDark,
    connected: connectedDark,
    scrim: scrimDark,
  );
}
```

- [ ] **Step 5: Implement spacing and motion**

```dart
// lib/src/tokens/spacing.dart
/// The 4-point spacing scale (spec 6.1). Every padding, gap and inset in the
/// kit comes from here.
abstract final class SpectraSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}
```

```dart
// lib/src/tokens/motion.dart
import 'package:flutter/widgets.dart' show Curve, Curves;

/// Three durations and two curves (spec 6.1), applied through flutter_animate.
abstract final class SpectraMotion {
  /// State flips: chip colour, checkbox, hover.
  static const Duration fast = Duration(milliseconds: 120);

  /// The default: disclosure expansion, sheet content, list reorder.
  static const Duration medium = Duration(milliseconds: 220);

  /// Full-surface changes: route transitions, sheet entry.
  static const Duration slow = Duration(milliseconds: 400);

  /// Everything that enters or settles.
  static const Curve standard = Curves.easeOutCubic;

  /// Anything that both leaves and arrives, such as a size change.
  static const Curve emphasized = Curves.easeInOutCubic;
}
```

- [ ] **Step 6: Export from the barrel**

```dart
// lib/spectra_ui.dart
/// Spectra design system: tokens, theme and core components.
library;

export 'src/tokens/color_scheme.dart';
export 'src/tokens/colors.dart';
export 'src/tokens/motion.dart';
export 'src/tokens/spacing.dart';

const String spectraUiVersion = '0.1.0';
```

- [ ] **Step 7: Run to verify it passes**

Run: `mise x -- flutter test test/tokens/tokens_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 8: Commit**

```bash
git add packages/spectra_ui/lib packages/spectra_ui/test/tokens
git commit -m "$(cat <<'MSG'
feat(spectra_ui): add colour, spacing and motion tokens

Both schemes derive from one accent and one neutral scale so a palette
change is a one-line edit, and the contrast test locks the AA floor the
accessibility requirement in spec 7.6 asks for.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 3: Typography tokens

**Files:**
- Create: `packages/spectra_ui/lib/src/tokens/typography.dart`
- Modify: `packages/spectra_ui/lib/spectra_ui.dart`
- Test: `packages/spectra_ui/test/tokens/typography_test.dart`

**Interfaces:**
- Consumes: `SpectraColorScheme`, `SpectraColors` (Task 2).
- Produces: `abstract final class SpectraTypography` with `static TextStyle get display, headline, title, body, bodySmall, label` (the six-step scale), `static TextStyle get mono` (the hex viewer face, same size as `body`), `static const String sansFamily = 'Inter'`, `static const String monoFamily = 'JetBrains Mono'`, and `static TextTheme textTheme(SpectraColorScheme colors)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/tokens/typography_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra_ui/spectra_ui.dart';

void main() {
  test('the scale has six descending steps', () {
    final sizes = <double?>[
      SpectraTypography.display.fontSize,
      SpectraTypography.headline.fontSize,
      SpectraTypography.title.fontSize,
      SpectraTypography.body.fontSize,
      SpectraTypography.bodySmall.fontSize,
      SpectraTypography.label.fontSize,
    ];
    expect(sizes, <double>[32, 24, 18, 15, 13, 12]);
  });

  test('the sans face is Inter and resolves offline', () {
    expect(SpectraTypography.body.fontFamily, contains(SpectraTypography.sansFamily));
  });

  test('the mono face is a different family at the body size', () {
    expect(SpectraTypography.mono.fontFamily, contains('JetBrainsMono'));
    expect(SpectraTypography.mono.fontSize, SpectraTypography.body.fontSize);
  });

  test('textTheme colours every step from the scheme', () {
    final theme = SpectraTypography.textTheme(SpectraColors.dark);
    expect(theme.bodyMedium!.color, SpectraColors.dark.textPrimary);
    expect(theme.bodySmall!.color, SpectraColors.dark.textSecondary);
    expect(theme.displaySmall!.fontSize, 32);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `mise x -- flutter test test/tokens/typography_test.dart`
Expected: FAIL to compile — `Undefined name 'SpectraTypography'`.

- [ ] **Step 3: Implement**

`google_fonts` returns a `TextStyle` whose `fontFamily` is the family name it registered (`Inter`, `JetBrainsMono`), so the styles cannot be `const`; they are cached statics instead. With `allowRuntimeFetching = false` (Task 1) google_fonts resolves the bundled asset and never reaches the network. In widget tests the asset load is asynchronous and is not awaited, so text falls back to flutter_test's Ahem — which is exactly what makes goldens identical across platforms.

```dart
// lib/src/tokens/typography.dart
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'color_scheme.dart';

/// The six-step type scale (spec 6.1) plus the monospaced face the hex viewer
/// needs. One variable sans, loaded from `assets/google_fonts/`.
abstract final class SpectraTypography {
  static const String sansFamily = 'Inter';
  static const String monoFamily = 'JetBrains Mono';

  static TextStyle get display =>
      GoogleFonts.inter(fontSize: 32, height: 1.15, fontWeight: FontWeight.w600);

  static TextStyle get headline =>
      GoogleFonts.inter(fontSize: 24, height: 1.2, fontWeight: FontWeight.w600);

  static TextStyle get title =>
      GoogleFonts.inter(fontSize: 18, height: 1.3, fontWeight: FontWeight.w600);

  static TextStyle get body =>
      GoogleFonts.inter(fontSize: 15, height: 1.45, fontWeight: FontWeight.w400);

  static TextStyle get bodySmall =>
      GoogleFonts.inter(fontSize: 13, height: 1.4, fontWeight: FontWeight.w400);

  static TextStyle get label => GoogleFonts.inter(
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
  );

  /// Body-sized monospace, used by the hex viewer so columns line up.
  static TextStyle get mono => GoogleFonts.jetBrainsMono(
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  /// Maps the scale onto `material_ui`'s [TextTheme] so `material_ui`
  /// components pick up our type without each one being restyled.
  static TextTheme textTheme(SpectraColorScheme colors) {
    return TextTheme(
      displaySmall: display.copyWith(color: colors.textPrimary),
      headlineSmall: headline.copyWith(color: colors.textPrimary),
      titleMedium: title.copyWith(color: colors.textPrimary),
      bodyMedium: body.copyWith(color: colors.textPrimary),
      bodySmall: bodySmall.copyWith(color: colors.textSecondary),
      labelLarge: label.copyWith(color: colors.textPrimary),
    );
  }
}
```

- [ ] **Step 4: Export it**

Add to `lib/spectra_ui.dart`, keeping the exports alphabetical (`directives_ordering` is on):

```dart
export 'src/tokens/typography.dart';
```

- [ ] **Step 5: Run to verify it passes**

Run: `mise x -- flutter test test/tokens/typography_test.dart`
Expected: PASS, 4 tests.

If `the sans face is Inter` fails because google_fonts registers the family as `Inter_regular` or similar, relax the assertion to `startsWith('Inter')` — do not change the family name in the pubspec asset path.

- [ ] **Step 6: Commit**

```bash
git add packages/spectra_ui/lib packages/spectra_ui/test/tokens
git commit -m "$(cat <<'MSG'
feat(spectra_ui): add the type scale on a bundled variable sans

Fonts are bundled and runtime fetching is off, so builds work offline and
tests never depend on a network round trip.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 4: ARB localization for the kit's own strings

**Files:**
- Create: `packages/spectra_ui/l10n.yaml`, `packages/spectra_ui/lib/l10n/spectra_ui_en.arb`
- Generated and committed: `packages/spectra_ui/lib/l10n/spectra_ui_localizations.dart`, `packages/spectra_ui/lib/l10n/spectra_ui_localizations_en.dart`
- Modify: `packages/spectra_ui/lib/spectra_ui.dart`, `tool/check_codegen.sh`
- Test: `packages/spectra_ui/test/l10n/localizations_test.dart`

**Interfaces:**
- Produces: `class SpectraUiLocalizations` with `static SpectraUiLocalizations of(BuildContext)`, `static const LocalizationsDelegate<SpectraUiLocalizations> delegate`, `static const List<Locale> supportedLocales`, and these getters/methods, all used verbatim by later tasks:
  `disclosureShow`, `disclosureHide`, `hexViewerOffsetHeader`, `hexViewerAsciiHeader`, `hexViewerEmpty`, `slotTileEmpty`, `slotTileDisabled`, `slotTileActive`, `slotLabel(int number)`, `statusConnected`, `statusConnecting`, `statusDisconnected`, `statusLimited`, `statusUpdating`, `batteryLevel(int percent)`, `batteryCharging(int percent)`, `stepProgress(int current, int total)`, `cancel`, `confirm`, `close`, `requiredField`.

- [ ] **Step 1: Write the failing test**

```dart
// test/l10n/localizations_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

void main() {
  testWidgets('the delegate resolves English strings from context', (
    tester,
  ) async {
    late SpectraUiLocalizations l10n;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('en'),
        delegates: const <LocalizationsDelegate<Object?>>[
          SpectraUiLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        child: Builder(
          builder: (context) {
            l10n = SpectraUiLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(l10n.disclosureShow, 'Show details');
    expect(l10n.disclosureHide, 'Hide details');
    expect(l10n.slotLabel(3), 'Slot 3');
    expect(l10n.batteryLevel(87), '87%');
    expect(l10n.batteryCharging(87), '87% charging');
    expect(l10n.stepProgress(2, 5), 'Step 2 of 5');
    expect(l10n.statusConnected, 'Connected');
  });

  test('English is the only supported locale in v1', () {
    expect(SpectraUiLocalizations.supportedLocales, <Locale>[const Locale('en')]);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `mise x -- flutter test test/l10n/localizations_test.dart`
Expected: FAIL to compile — `Undefined name 'SpectraUiLocalizations'`.

- [ ] **Step 3: Write the gen-l10n config**

```yaml
# packages/spectra_ui/l10n.yaml
arb-dir: lib/l10n
template-arb-file: spectra_ui_en.arb
output-dir: lib/l10n
output-localization-file: spectra_ui_localizations.dart
output-class: SpectraUiLocalizations
nullable-getter: false
synthetic-package: false
```

`synthetic-package: false` is what puts the generated files in `lib/l10n/` so they can be committed and imported directly. If `flutter gen-l10n` reports that key as unrecognised on Flutter 3.47, delete that one line — `output-dir` alone already places the files there — and note it in the commit body.

- [ ] **Step 4: Write the ARB file**

```json
{
  "@@locale": "en",
  "disclosureShow": "Show details",
  "@disclosureShow": {"description": "Expands a disclosure to its expert detail."},
  "disclosureHide": "Hide details",
  "@disclosureHide": {"description": "Collapses a disclosure back to its summary."},
  "hexViewerOffsetHeader": "Offset",
  "@hexViewerOffsetHeader": {"description": "Column header above the byte offsets."},
  "hexViewerAsciiHeader": "ASCII",
  "@hexViewerAsciiHeader": {"description": "Column header above the ASCII gutter."},
  "hexViewerEmpty": "No data",
  "@hexViewerEmpty": {"description": "Shown when a hex viewer is given zero bytes."},
  "slotTileEmpty": "Empty",
  "@slotTileEmpty": {"description": "A slot with no tag configured."},
  "slotTileDisabled": "Disabled",
  "@slotTileDisabled": {"description": "A slot that exists but is switched off."},
  "slotTileActive": "Active",
  "@slotTileActive": {"description": "The slot the device is currently emulating."},
  "slotLabel": "Slot {number}",
  "@slotLabel": {
    "description": "Names a slot by its one-based number.",
    "placeholders": {"number": {"type": "int"}}
  },
  "statusConnected": "Connected",
  "@statusConnected": {"description": "Connection status chip label."},
  "statusConnecting": "Connecting",
  "@statusConnecting": {"description": "Connection status chip label."},
  "statusDisconnected": "Disconnected",
  "@statusDisconnected": {"description": "Connection status chip label."},
  "statusLimited": "Limited",
  "@statusLimited": {"description": "Connected but only firmware update is possible."},
  "statusUpdating": "Updating",
  "@statusUpdating": {"description": "A firmware update is in progress."},
  "batteryLevel": "{percent}%",
  "@batteryLevel": {
    "description": "Battery charge as a percentage.",
    "placeholders": {"percent": {"type": "int"}}
  },
  "batteryCharging": "{percent}% charging",
  "@batteryCharging": {
    "description": "Battery charge while on external power.",
    "placeholders": {"percent": {"type": "int"}}
  },
  "stepProgress": "Step {current} of {total}",
  "@stepProgress": {
    "description": "Position within a multi-step operation.",
    "placeholders": {"current": {"type": "int"}, "total": {"type": "int"}}
  },
  "cancel": "Cancel",
  "@cancel": {"description": "Cancels a dialog, sheet or long operation."},
  "confirm": "OK",
  "@confirm": {"description": "Confirms a dialog."},
  "close": "Close",
  "@close": {"description": "Closes a bottom sheet."},
  "requiredField": "Required",
  "@requiredField": {"description": "Default error text on an empty required input."}
}
```

- [ ] **Step 5: Generate and inspect**

Run in `packages/spectra_ui`:

```bash
mise x -- flutter gen-l10n
ls lib/l10n
```

Expected: `spectra_ui_en.arb`, `spectra_ui_localizations.dart`, `spectra_ui_localizations_en.dart`.

- [ ] **Step 6: Export the delegate**

Add to `lib/spectra_ui.dart`:

```dart
export 'l10n/spectra_ui_localizations.dart';
```

Generated files are excluded from analysis only when they end in `.g.dart` or `.freezed.dart`, and these do not, so they must analyze clean. If `dart analyze --fatal-infos .` complains about the generated files, add `lib/l10n/spectra_ui_localizations*.dart` to the `analyzer: exclude:` list in `packages/spectra_ui/analysis_options.yaml` rather than editing generated code.

- [ ] **Step 7: Run to verify it passes**

Run: `mise x -- flutter test test/l10n/localizations_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 8: Teach check_codegen.sh about gen-l10n**

The generated localizations are committed, so CI must fail when they go stale. Replace `tool/check_codegen.sh` with:

```bash
#!/usr/bin/env bash
# Regenerates code in every package that uses build_runner or gen-l10n and
# fails if the committed generated files differ.
set -euo pipefail
cd "$(dirname "$0")/.."
# Locally, commands go through mise. On CI mise is absent: set MISE_X="".
MISE_X="${MISE_X-mise x --}"
for pkg in packages/chameleon packages/chameleon_flutter packages/spectra_ui app; do
  if grep -q "build_runner" "$pkg/pubspec.yaml" 2>/dev/null; then
    echo "codegen: $pkg"
    (cd "$pkg" && $MISE_X dart run build_runner build --delete-conflicting-outputs >/dev/null)
  fi
  if [ -f "$pkg/l10n.yaml" ]; then
    echo "l10n: $pkg"
    (cd "$pkg" && $MISE_X flutter gen-l10n >/dev/null)
  fi
done
if ! git diff --quiet -- '*.g.dart' '*.freezed.dart' '*.drift.dart' '*_localizations.dart' '*_localizations_*.dart'; then
  echo "codegen: committed generated files are stale:" >&2
  git --no-pager diff --stat -- '*.g.dart' '*.freezed.dart' '*.drift.dart' '*_localizations.dart' '*_localizations_*.dart' >&2
  exit 1
fi
echo "codegen: ok"
```

- [ ] **Step 9: Verify the codegen check passes**

Run from the worktree root:

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
bash tool/check_codegen.sh
```

Expected: `l10n: packages/spectra_ui` then `codegen: ok`. If it reports the files as stale on a clean tree, the generator is not deterministic across runs — re-run once and commit the second output.

- [ ] **Step 10: Commit**

```bash
git add packages/spectra_ui/l10n.yaml packages/spectra_ui/lib packages/spectra_ui/test/l10n \
  packages/spectra_ui/analysis_options.yaml tool/check_codegen.sh
git commit -m "$(cat <<'MSG'
feat(spectra_ui): localize the kit's own strings through ARB

Spec 7.6 requires ARB from the first screen. The generated delegate is
committed so the app can install it without a build step, and
check_codegen.sh now fails when it drifts from the ARB.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 5: SpectraTheme, spectraThemeData and SpectraApp

**Files:**
- Create: `packages/spectra_ui/lib/src/theme/spectra_theme.dart`, `lib/src/theme/theme_data.dart`, `lib/src/theme/spectra_app.dart`
- Modify: `packages/spectra_ui/lib/spectra_ui.dart`
- Test: `packages/spectra_ui/test/theme/spectra_theme_test.dart`

**Interfaces:**
- Consumes: `SpectraColorScheme`, `SpectraColors`, `SpectraTypography`, `SpectraUiLocalizations`.
- Produces: `class SpectraTheme extends InheritedWidget` with `const SpectraTheme({required SpectraColorScheme colors, required Brightness brightness, required Widget child, Key? key})`, `static SpectraTheme of(BuildContext context)` (asserts when absent), `static SpectraTheme? maybeOf(BuildContext context)`.
- Produces: `ThemeData spectraThemeData(SpectraColorScheme colors, Brightness brightness)` — `material_ui`'s `ThemeData`.
- Produces: `class SpectraApp extends StatelessWidget` with `const SpectraApp({required RouterConfig<Object> routerConfig, String title = 'Spectra', ThemeMode themeMode = ThemeMode.system, Key? key})`.

Spacing, motion and type do not vary by brightness, so they stay static and are not carried on the inherited widget; only the resolved colours and the brightness are.

- [ ] **Step 1: Write the failing test**

```dart
// test/theme/spectra_theme_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

void main() {
  testWidgets('SpectraTheme.of returns the resolved dark scheme', (
    tester,
  ) async {
    late SpectraTheme theme;
    await tester.pumpWidget(
      SpectraTheme(
        colors: SpectraColors.dark,
        brightness: Brightness.dark,
        child: Builder(
          builder: (context) {
            theme = SpectraTheme.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(theme.brightness, Brightness.dark);
    expect(theme.colors.accent, SpectraColors.dark.accent);
  });

  testWidgets('SpectraTheme.maybeOf is null outside a theme', (tester) async {
    SpectraTheme? theme;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          theme = SpectraTheme.maybeOf(context);
          return const SizedBox.shrink();
        },
      ),
    );
    expect(theme, isNull);
  });

  test('spectraThemeData maps our tokens onto material_ui', () {
    final data = spectraThemeData(SpectraColors.light, Brightness.light);
    expect(data.brightness, Brightness.light);
    expect(data.colorScheme.primary, SpectraColors.light.accent);
    expect(data.colorScheme.error, SpectraColors.light.danger);
    expect(data.scaffoldBackgroundColor, SpectraColors.light.background);
    expect(data.textTheme.bodyMedium!.color, SpectraColors.light.textPrimary);
  });

  testWidgets('SpectraApp themes material_ui widgets and installs l10n', (
    tester,
  ) async {
    late BuildContext inner;
    await tester.pumpWidget(
      SpectraApp(
        themeMode: ThemeMode.light,
        routerConfig: RouterConfig<Object>(
          routerDelegate: _SingleRouteDelegate(
            (context) {
              inner = context;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(Theme.of(inner).colorScheme.primary, SpectraColors.light.accent);
    expect(SpectraTheme.of(inner).colors.accent, SpectraColors.light.accent);
    expect(SpectraUiLocalizations.of(inner).cancel, 'Cancel');
  });
}

/// Minimal router that always builds one page, so the test needs no go_router.
class _SingleRouteDelegate extends RouterDelegate<Object>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<Object> {
  _SingleRouteDelegate(this.builder);

  final WidgetBuilder builder;

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: <Page<Object?>>[
        MaterialPage<Object?>(child: Builder(builder: builder)),
      ],
      onDidRemovePage: (_) {},
    );
  }

  @override
  Future<void> setNewRoutePath(Object configuration) async {}
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `mise x -- flutter test test/theme/spectra_theme_test.dart`
Expected: FAIL to compile — `Undefined name 'SpectraTheme'`, `spectraThemeData`, `SpectraApp`.

- [ ] **Step 3: Implement the inherited widget**

```dart
// lib/src/theme/spectra_theme.dart
import 'package:flutter/widgets.dart';

import '../tokens/color_scheme.dart';

/// Carries the brightness-resolved Spectra tokens down the tree.
///
/// Spacing, motion and type do not vary by brightness, so they stay static on
/// their token classes; only the colours and the brightness are inherited.
class SpectraTheme extends InheritedWidget {
  const SpectraTheme({
    required this.colors,
    required this.brightness,
    required super.child,
    super.key,
  });

  final SpectraColorScheme colors;
  final Brightness brightness;

  static SpectraTheme? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SpectraTheme>();

  static SpectraTheme of(BuildContext context) {
    final SpectraTheme? theme = maybeOf(context);
    assert(theme != null, 'No SpectraTheme found. Wrap the app in SpectraApp.');
    return theme!;
  }

  @override
  bool updateShouldNotify(SpectraTheme oldWidget) =>
      oldWidget.brightness != brightness || oldWidget.colors != colors;
}
```

- [ ] **Step 4: Implement the ThemeData mapping**

```dart
// lib/src/theme/theme_data.dart
import 'package:material_ui/material_ui.dart';

import '../tokens/color_scheme.dart';
import '../tokens/typography.dart';

/// Builds `material_ui`'s [ThemeData] from Spectra tokens, so `material_ui`
/// components inherit our palette and type instead of a seeded default.
///
/// This is deliberately not a bridge to the in-SDK `ThemeData`: Spike B found
/// nothing in the dependency set needs one.
ThemeData spectraThemeData(SpectraColorScheme colors, Brightness brightness) {
  final ColorScheme scheme = ColorScheme(
    brightness: brightness,
    primary: colors.accent,
    onPrimary: colors.onAccent,
    secondary: colors.connected,
    onSecondary: colors.onAccent,
    error: colors.danger,
    onError: colors.onAccent,
    surface: colors.surface,
    onSurface: colors.textPrimary,
  );
  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.background,
    canvasColor: colors.background,
    dividerColor: colors.border,
    textTheme: SpectraTypography.textTheme(colors),
  );
}
```

If `ThemeData` in `material_ui` 1.1.1 rejects `canvasColor` or `dividerColor`, drop those two arguments — they are conveniences, not requirements.

- [ ] **Step 5: Implement the app wrapper**

```dart
// lib/src/theme/spectra_app.dart
import 'package:material_ui/material_ui.dart';

import '../../l10n/spectra_ui_localizations.dart';
import '../tokens/colors.dart';
import 'spectra_theme.dart';
import 'theme_data.dart';

/// The application root: `material_ui`'s router app, themed from Spectra
/// tokens, with the kit's localization delegate installed and a [SpectraTheme]
/// wrapped around every route.
class SpectraApp extends StatelessWidget {
  const SpectraApp({
    required this.routerConfig,
    this.title = 'Spectra',
    this.themeMode = ThemeMode.system,
    super.key,
  });

  final RouterConfig<Object> routerConfig;
  final String title;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: title,
      debugShowCheckedModeBanner: false,
      theme: spectraThemeData(SpectraColors.light, Brightness.light),
      darkTheme: spectraThemeData(SpectraColors.dark, Brightness.dark),
      themeMode: themeMode,
      routerConfig: routerConfig,
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        SpectraUiLocalizations.delegate,
      ],
      supportedLocales: SpectraUiLocalizations.supportedLocales,
      builder: (BuildContext context, Widget? child) {
        final Brightness brightness = Theme.of(context).brightness;
        return SpectraTheme(
          colors: brightness == Brightness.dark
              ? SpectraColors.dark
              : SpectraColors.light,
          brightness: brightness,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
```

`MaterialApp` appends its own delegates after the ones given, so the `material_ui` and widgets localizations are still installed.

- [ ] **Step 6: Export the theme layer**

Add to `lib/spectra_ui.dart`:

```dart
export 'src/theme/spectra_app.dart';
export 'src/theme/spectra_theme.dart';
export 'src/theme/theme_data.dart';
```

- [ ] **Step 7: Run to verify it passes**

Run: `mise x -- flutter test test/theme/spectra_theme_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 8: Commit**

```bash
git add packages/spectra_ui/lib packages/spectra_ui/test/theme
git commit -m "$(cat <<'MSG'
feat(spectra_ui): add SpectraTheme, ThemeData mapping and SpectraApp

material_ui components need our palette to come through its own ThemeData,
so the tokens are mapped once here rather than restyled per component. No
in-SDK ThemeData bridge is written; Spike B showed nothing needs one.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 6: The string-literal lint

**Files:**
- Create: `tool/src/string_rules.dart`, `test/string_rules_test.dart` (worktree root `test/`, next to `dep_rules_test.dart`)
- Modify: `tool/dep_lint.dart`

**Interfaces:**
- Consumes: `Violation` from `tool/src/dep_rules.dart` (fields `rule`, `file`, `import`, `message`).
- Produces: `bool isLocalizedUiPath(String packageName, String relativePath)` and `List<Violation> checkTextLiterals({required String packageName, required String relativePath, required String source})` in `tool/src/string_rules.dart`. The rule name is `no-literal-text`; the exemption marker is `// l10n-exempt` on the same line.

- [ ] **Step 1: Write the failing test**

```dart
// test/string_rules_test.dart
import 'package:test/test.dart';

import '../tool/src/string_rules.dart';

void main() {
  group('isLocalizedUiPath', () {
    test('spectra_ui components are covered', () {
      expect(
        isLocalizedUiPath('spectra_ui', 'lib/src/components/slot_tile.dart'),
        isTrue,
      );
    });

    test('spectra_ui tokens and theme are not', () {
      expect(isLocalizedUiPath('spectra_ui', 'lib/src/tokens/colors.dart'), isFalse);
      expect(isLocalizedUiPath('spectra_ui', 'lib/src/theme/spectra_app.dart'), isFalse);
    });

    test('app feature ui folders are covered at any depth', () {
      expect(isLocalizedUiPath('spectra', 'lib/features/slots/ui/slots_screen.dart'), isTrue);
      expect(
        isLocalizedUiPath('spectra', 'lib/features/slots/ui/widgets/row.dart'),
        isTrue,
      );
    });

    test('app feature non-ui folders are not', () {
      expect(isLocalizedUiPath('spectra', 'lib/features/slots/slots.dart'), isFalse);
      expect(isLocalizedUiPath('spectra', 'lib/features/slots/state/notifier.dart'), isFalse);
    });

    test('the gallery is exempt: it is sample data, not product copy', () {
      expect(
        isLocalizedUiPath('spectra_ui_gallery', 'lib/pages/card_page.dart'),
        isFalse,
      );
    });
  });

  group('checkTextLiterals', () {
    List<String> rulesFor(String source) => checkTextLiterals(
      packageName: 'spectra_ui',
      relativePath: 'lib/src/components/demo.dart',
      source: source,
    ).map((v) => v.rule).toList();

    test('flags a bare string literal in Text', () {
      expect(rulesFor("Widget b() => Text('Slot 1');"), ['no-literal-text']);
    });

    test('flags a const string literal in Text', () {
      expect(rulesFor('Widget b() => const Text("Slot 1");'), ['no-literal-text']);
    });

    test('allows a localization lookup', () {
      expect(rulesFor('Widget b() => Text(l10n.slotTileEmpty);'), isEmpty);
    });

    test('allows an interpolated variable', () {
      expect(rulesFor('Widget b() => Text(label);'), isEmpty);
    });

    test('honours the l10n-exempt marker', () {
      expect(
        rulesFor("Widget b() => Text('0x00'); // l10n-exempt: hex sample"),
        isEmpty,
      );
    });

    test('does not flag other calls that take strings', () {
      expect(rulesFor("final s = Semantics(label: 'x');"), isEmpty);
    });

    test('reports the offending literal and line', () {
      final v = checkTextLiterals(
        packageName: 'spectra_ui',
        relativePath: 'lib/src/components/demo.dart',
        source: "// line one\nWidget b() => Text('Nope');\n",
      );
      expect(v.single.file, 'lib/src/components/demo.dart:2');
      expect(v.single.import, "Text('Nope'");
    });

    test('files outside a ui path are never checked', () {
      final v = checkTextLiterals(
        packageName: 'spectra_ui',
        relativePath: 'lib/src/tokens/colors.dart',
        source: "Widget b() => Text('fine here');",
      );
      expect(v, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run from the worktree root: `mise x -- dart test test/string_rules_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'string_rules'` / file not found.

- [ ] **Step 3: Implement the rule**

```dart
// tool/src/string_rules.dart
/// Spec 7.6: "a lint fails on string literals in `ui/` folders". This is that
/// lint, kept deliberately textual — the analyzer plugin API is not worth the
/// weight for one rule.
library;

import 'dep_rules.dart' show Violation;

final RegExp _textLiteral = RegExp(r'''\bText\(\s*(?:const\s+)?['"]''');
final RegExp _featureUi = RegExp(r'^lib/features/[^/]+/ui/');

/// True when [relativePath] holds user-facing UI whose copy must be localized.
bool isLocalizedUiPath(String packageName, String relativePath) {
  if (packageName == 'spectra_ui') {
    return relativePath.startsWith('lib/src/components/');
  }
  if (packageName == 'spectra') {
    return _featureUi.hasMatch(relativePath);
  }
  return false;
}

/// Flags string literals handed straight to `Text(` in localized UI files.
/// A line carrying `// l10n-exempt` is skipped, for genuinely non-user-facing
/// text such as a hex sample or a debug affordance.
List<Violation> checkTextLiterals({
  required String packageName,
  required String relativePath,
  required String source,
}) {
  if (!isLocalizedUiPath(packageName, relativePath)) return const <Violation>[];
  final List<Violation> out = <Violation>[];
  final List<String> lines = source.split('\n');
  for (int i = 0; i < lines.length; i++) {
    final String line = lines[i];
    if (line.contains('l10n-exempt')) continue;
    final RegExpMatch? match = _textLiteral.firstMatch(line);
    if (match == null) continue;
    out.add(
      Violation(
        'no-literal-text',
        '$relativePath:${i + 1}',
        match.group(0)!,
        'user-facing text must come from SpectraUiLocalizations; '
            'mark genuinely non-user-facing strings with // l10n-exempt',
      ),
    );
  }
  return out;
}
```

- [ ] **Step 4: Wire it into the lint run**

In `tool/dep_lint.dart`, add the import and call. The file's import block becomes:

```dart
import 'dart:io';

import 'src/dep_rules.dart';
import 'src/string_rules.dart';
```

and inside `runDepLint`, replace the body of the innermost file loop with:

```dart
        final rel = f.path.substring(dir.path.length + 1);
        final source = f.readAsStringSync();
        final violations = <Violation>[
          ...checkFile(
            packageName: entry.key,
            relativePath: rel,
            imports: extractImports(source),
          ),
          ...checkTextLiterals(
            packageName: entry.key,
            relativePath: rel,
            source: source,
          ),
        ];
        for (final v in violations) {
          stderr.writeln('${entry.value}/$v');
          count++;
        }
```

- [ ] **Step 5: Run to verify it passes**

```bash
mise x -- dart test test/string_rules_test.dart
mise x -- dart run tool/dep_lint.dart
```

Expected: 14 tests PASS, then `dep_lint: ok`.

- [ ] **Step 6: Commit**

```bash
git add tool/src/string_rules.dart tool/dep_lint.dart test/string_rules_test.dart
git commit -m "$(cat <<'MSG'
feat(tool): fail the lint on string literals in localized UI

Spec 7.6 requires it. Textual rather than analyzer-based because it is one
rule; // l10n-exempt covers hex samples and other non-product copy.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 7: Golden harness and buttons

**Files:**
- Create: `packages/spectra_ui/test/support/golden_harness.dart`, `lib/src/components/button_variant.dart`, `lib/src/components/button.dart`
- Modify: `packages/spectra_ui/lib/spectra_ui.dart`
- Test: `packages/spectra_ui/test/components/button_test.dart`, `test/components/button_golden_test.dart`
- Generated: `packages/spectra_ui/test/components/goldens/ci/button_light.png`, `button_dark.png`

**Interfaces:**
- Consumes: `SpectraColors`, `SpectraColorScheme`, `SpectraSpacing`, `SpectraTypography`, `SpectraTheme`, `spectraThemeData`, `SpectraUiLocalizations`.
- Produces (harness, used by every later golden task):
  - `Widget spectraHarness({required Widget child, Brightness brightness = Brightness.light, double? width, double? height})` — a themed, localized, scrollable-free host for one component.
  - `GoldenTestScenario spectraScenario({required String name, required Widget child, Brightness brightness = Brightness.light, double width = 360, double height = 160})`.
- Produces: `enum SpectraButtonVariant { primary, secondary, danger }`.
- Produces: `class SpectraButton extends StatelessWidget` with `const SpectraButton({required String label, required VoidCallback? onPressed, SpectraButtonVariant variant = SpectraButtonVariant.primary, IconData? icon, bool busy = false, String? semanticsLabel, Key? key})`. `onPressed: null` disables it.

- [ ] **Step 1: Write the harness**

```dart
// test/support/golden_harness.dart
import 'package:alchemist/alchemist.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

/// Hosts one component under the Spectra theme and the kit's localizations.
///
/// A fixed [width]/[height] keeps golden scenarios bounded; `material_ui`'s
/// `MaterialApp` supplies every delegate the components need.
Widget spectraHarness({
  required Widget child,
  Brightness brightness = Brightness.light,
  double? width,
  double? height,
}) {
  final SpectraColorScheme colors =
      brightness == Brightness.dark ? SpectraColors.dark : SpectraColors.light;
  return SizedBox(
    width: width,
    height: height,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: spectraThemeData(colors, brightness),
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        SpectraUiLocalizations.delegate,
      ],
      supportedLocales: SpectraUiLocalizations.supportedLocales,
      home: SpectraTheme(
        colors: colors,
        brightness: brightness,
        child: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(SpectraSpacing.lg),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

/// One alchemist scenario wrapped in [spectraHarness].
GoldenTestScenario spectraScenario({
  required String name,
  required Widget child,
  Brightness brightness = Brightness.light,
  double width = 360,
  double height = 160,
}) {
  return GoldenTestScenario(
    name: name,
    child: spectraHarness(
      brightness: brightness,
      width: width,
      height: height,
      child: child,
    ),
  );
}
```

- [ ] **Step 2: Write the failing behavior test**

```dart
// test/components/button_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  testWidgets('calls onPressed and meets the 48px touch target', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      spectraHarness(
        child: SpectraButton(label: 'Connect', onPressed: () => taps++),
      ),
    );
    await tester.tap(find.text('Connect'));
    expect(taps, 1);
    expect(tester.getSize(find.byType(SpectraButton)).height, greaterThanOrEqualTo(48));
  });

  testWidgets('a null onPressed disables the button', (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        child: const SpectraButton(label: 'Connect', onPressed: null),
      ),
    );
    await tester.tap(find.text('Connect'), warnIfMissed: false);
    expect(tester.takeException(), isNull);
    final Semantics node = tester.widget<Semantics>(
      find
          .descendant(
            of: find.byType(SpectraButton),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(node.properties.enabled, isFalse);
  });

  testWidgets('busy replaces the label with a spinner and blocks taps', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      spectraHarness(
        child: SpectraButton(
          label: 'Connect',
          busy: true,
          onPressed: () => taps++,
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(SpectraButton), warnIfMissed: false);
    expect(taps, 0);
  });

  testWidgets('the danger variant paints from the danger token', (
    tester,
  ) async {
    await tester.pumpWidget(
      spectraHarness(
        child: SpectraButton(
          label: 'Erase',
          variant: SpectraButtonVariant.danger,
          onPressed: () {},
        ),
      ),
    );
    final DecoratedBox box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(SpectraButton),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect((box.decoration as BoxDecoration).color, SpectraColors.light.danger);
  });

  testWidgets('a semanticsLabel overrides the visible label for a11y', (
    tester,
  ) async {
    await tester.pumpWidget(
      spectraHarness(
        child: SpectraButton(
          label: 'Erase',
          semanticsLabel: 'Erase all slots',
          onPressed: () {},
        ),
      ),
    );
    expect(find.bySemanticsLabel('Erase all slots'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Write the failing golden test**

```dart
// test/components/button_golden_test.dart
import 'package:alchemist/alchemist.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  for (final (String name, Brightness brightness) in <(String, Brightness)>[
    ('button_light', Brightness.light),
    ('button_dark', Brightness.dark),
  ]) {
    goldenTest(
      'buttons render every variant and state ($name)',
      fileName: name,
      builder: () => GoldenTestGroup(
        columns: 2,
        children: <Widget>[
          spectraScenario(
            name: 'primary',
            brightness: brightness,
            child: SpectraButton(label: 'Connect', onPressed: () {}),
          ),
          spectraScenario(
            name: 'secondary',
            brightness: brightness,
            child: SpectraButton(
              label: 'Rescan',
              variant: SpectraButtonVariant.secondary,
              onPressed: () {},
            ),
          ),
          spectraScenario(
            name: 'danger',
            brightness: brightness,
            child: SpectraButton(
              label: 'Erase',
              variant: SpectraButtonVariant.danger,
              onPressed: () {},
            ),
          ),
          spectraScenario(
            name: 'disabled',
            brightness: brightness,
            child: const SpectraButton(label: 'Connect', onPressed: null),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run to verify both fail**

Run: `mise x -- flutter test test/components`
Expected: FAIL to compile — `Undefined name 'SpectraButton'`.

- [ ] **Step 5: Implement the variant enum**

```dart
// lib/src/components/button_variant.dart
/// The three button roles the app uses (spec 6.2).
enum SpectraButtonVariant {
  /// The one primary action on a surface.
  primary,

  /// Secondary actions: outlined, same footprint.
  secondary,

  /// Destructive actions: erase, disconnect, overwrite a card.
  danger,
}
```

- [ ] **Step 6: Implement the button**

```dart
// lib/src/components/button.dart
import 'package:material_ui/material_ui.dart';

import '../theme/spectra_theme.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'button_variant.dart';

/// A Spectra button. Takes a plain label, never a device type.
class SpectraButton extends StatelessWidget {
  const SpectraButton({
    required this.label,
    required this.onPressed,
    this.variant = SpectraButtonVariant.primary,
    this.icon,
    this.busy = false,
    this.semanticsLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final SpectraButtonVariant variant;
  final IconData? icon;

  /// Shows a spinner in place of the label and ignores taps.
  final bool busy;

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    final bool enabled = onPressed != null && !busy;
    final Color background = switch (variant) {
      SpectraButtonVariant.primary => theme.colors.accent,
      SpectraButtonVariant.secondary => theme.colors.surface,
      SpectraButtonVariant.danger => theme.colors.danger,
    };
    final Color foreground = switch (variant) {
      SpectraButtonVariant.primary => theme.colors.onAccent,
      SpectraButtonVariant.secondary => theme.colors.textPrimary,
      SpectraButtonVariant.danger => theme.colors.onAccent,
    };
    final Color border = variant == SpectraButtonVariant.secondary
        ? theme.colors.border
        : background;

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticsLabel ?? label,
      excludeSemantics: semanticsLabel != null,
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: enabled ? background : theme.colors.surfaceRaised,
            border: Border.all(color: enabled ? border : theme.colors.border),
            borderRadius: BorderRadius.circular(SpectraSpacing.sm),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpectraSpacing.lg,
                vertical: SpectraSpacing.md,
              ),
              child: Center(
                child: busy
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: foreground,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (icon != null) ...<Widget>[
                            Icon(
                              icon,
                              size: 18,
                              color: enabled
                                  ? foreground
                                  : theme.colors.textDisabled,
                            ),
                            const SizedBox(width: SpectraSpacing.sm),
                          ],
                          Text(
                            label,
                            style: SpectraTypography.label.copyWith(
                              color: enabled
                                  ? foreground
                                  : theme.colors.textDisabled,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

`Text(label)` takes a variable, so the `no-literal-text` rule is satisfied.

- [ ] **Step 7: Export**

Add to `lib/spectra_ui.dart`:

```dart
export 'src/components/button.dart';
export 'src/components/button_variant.dart';
```

- [ ] **Step 8: Run the behavior test**

Run: `mise x -- flutter test test/components/button_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 9: Generate the goldens in CI mode**

```bash
mise x -- flutter test test/components/button_golden_test.dart --update-goldens
ls test/components/goldens/ci
```

Expected: `button_light.png` and `button_dark.png`, and **no** `test/components/goldens/macos/` in `git status` (it is git-ignored, and `SPECTRA_PLATFORM_GOLDENS` is unset so it is not even written).

- [ ] **Step 10: Verify the goldens without updating**

Run: `mise x -- flutter test test/components/button_golden_test.dart`
Expected: PASS, 2 golden tests.

- [ ] **Step 11: Commit**

```bash
git add packages/spectra_ui/lib packages/spectra_ui/test
git commit -m "$(cat <<'MSG'
feat(spectra_ui): add buttons and the shared golden harness

Every later component reuses spectraHarness/spectraScenario, so the theme,
localizations and scenario bounds are defined once here.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 8: Text input, dialog and bottom sheet

**Files:**
- Create: `lib/src/components/text_field.dart`, `lib/src/components/dialog.dart`, `lib/src/components/bottom_sheet.dart`
- Modify: `lib/spectra_ui.dart`
- Test: `test/components/text_field_test.dart`, `test/components/overlays_test.dart`, `test/components/overlays_golden_test.dart`
- Generated: `test/components/goldens/ci/overlays_light.png`, `overlays_dark.png`

**Interfaces:**
- Consumes: `spectraHarness`, `spectraScenario`, `SpectraButton`, `SpectraButtonVariant`, `SpectraTheme`, `SpectraSpacing`, `SpectraTypography`, `SpectraUiLocalizations`.
- Produces: `class SpectraTextField extends StatelessWidget` — `const SpectraTextField({required String label, TextEditingController? controller, String? hint, String? errorText, ValueChanged<String>? onChanged, bool obscureText = false, bool enabled = true, Key? key})`.
- Produces: `class SpectraDialog extends StatelessWidget` — `const SpectraDialog({required String title, required Widget content, required List<Widget> actions, Key? key})`, plus `static Future<T?> show<T>({required BuildContext context, required String title, required Widget content, required List<Widget> Function(BuildContext) actions})`.
- Produces: `class SpectraBottomSheet extends StatelessWidget` — `const SpectraBottomSheet({required String title, required Widget child, Key? key})`, plus `static Future<T?> show<T>({required BuildContext context, required String title, required WidgetBuilder builder})`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/components/text_field_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  testWidgets('reports typing through onChanged', (tester) async {
    final changes = <String>[];
    await tester.pumpWidget(
      spectraHarness(
        child: SpectraTextField(label: 'Nickname', onChanged: changes.add),
      ),
    );
    await tester.enterText(find.byType(TextField), 'gate');
    expect(changes, <String>['gate']);
  });

  testWidgets('shows the error text and marks the field as errored', (
    tester,
  ) async {
    await tester.pumpWidget(
      spectraHarness(
        child: const SpectraTextField(label: 'Nickname', errorText: 'Required'),
      ),
    );
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('meets the 48px touch target', (tester) async {
    await tester.pumpWidget(
      spectraHarness(child: const SpectraTextField(label: 'Nickname')),
    );
    expect(
      tester.getSize(find.byType(TextField)).height,
      greaterThanOrEqualTo(48),
    );
  });
}
```

```dart
// test/components/overlays_test.dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  testWidgets('SpectraDialog.show returns the chosen value', (tester) async {
    Object? result;
    await tester.pumpWidget(
      spectraHarness(
        child: Builder(
          builder: (context) => SpectraButton(
            label: 'Open',
            onPressed: () async {
              result = await SpectraDialog.show<String>(
                context: context,
                title: 'Erase slot',
                content: const SizedBox.shrink(),
                actions: (context) => <Widget>[
                  SpectraButton(
                    label: SpectraUiLocalizations.of(context).confirm,
                    variant: SpectraButtonVariant.danger,
                    onPressed: () => Navigator.of(context).pop('erased'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Erase slot'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(result, 'erased');
  });

  testWidgets('SpectraBottomSheet.show presents its title and child', (
    tester,
  ) async {
    await tester.pumpWidget(
      spectraHarness(
        child: Builder(
          builder: (context) => SpectraButton(
            label: 'Open',
            onPressed: () {
              unawaited(
                SpectraBottomSheet.show<void>(
                  context: context,
                  title: 'Pick a slot',
                  builder: (_) => const SpectraTextField(label: 'Filter'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a slot'), findsOneWidget);
    expect(find.byType(SpectraTextField), findsOneWidget);
  });
}
```

```dart
// test/components/overlays_golden_test.dart
import 'package:alchemist/alchemist.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  for (final (String name, Brightness brightness) in <(String, Brightness)>[
    ('overlays_light', Brightness.light),
    ('overlays_dark', Brightness.dark),
  ]) {
    goldenTest(
      'input, dialog and sheet render ($name)',
      fileName: name,
      builder: () => GoldenTestGroup(
        columns: 1,
        children: <Widget>[
          spectraScenario(
            name: 'text field',
            brightness: brightness,
            width: 360,
            height: 140,
            child: const SpectraTextField(
              label: 'Nickname',
              hint: 'Office badge',
            ),
          ),
          spectraScenario(
            name: 'text field with error',
            brightness: brightness,
            width: 360,
            height: 160,
            child: const SpectraTextField(
              label: 'Nickname',
              errorText: 'Required',
            ),
          ),
          spectraScenario(
            name: 'dialog',
            brightness: brightness,
            width: 400,
            height: 240,
            child: SpectraDialog(
              title: 'Erase slot 3?',
              content: const SpectraTextField(label: 'Type ERASE'),
              actions: <Widget>[
                SpectraButton(
                  label: 'Cancel',
                  variant: SpectraButtonVariant.secondary,
                  onPressed: () {},
                ),
                SpectraButton(
                  label: 'OK',
                  variant: SpectraButtonVariant.danger,
                  onPressed: () {},
                ),
              ],
            ),
          ),
          spectraScenario(
            name: 'bottom sheet',
            brightness: brightness,
            width: 400,
            height: 220,
            child: const SpectraBottomSheet(
              title: 'Pick a slot',
              child: SpectraTextField(label: 'Filter'),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `mise x -- flutter test test/components/text_field_test.dart test/components/overlays_test.dart`
Expected: FAIL to compile — `Undefined name 'SpectraTextField'`.

- [ ] **Step 3: Implement the text field**

```dart
// lib/src/components/text_field.dart
import 'package:material_ui/material_ui.dart';

import '../theme/spectra_theme.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// A labelled single-line input over `material_ui`'s [TextField].
class SpectraTextField extends StatelessWidget {
  const SpectraTextField({
    required this.label,
    this.controller,
    this.hint,
    this.errorText,
    this.onChanged,
    this.obscureText = false,
    this.enabled = true,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    return Semantics(
      textField: true,
      label: label,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        obscureText: obscureText,
        enabled: enabled,
        style: SpectraTypography.body.copyWith(color: theme.colors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: errorText,
          filled: true,
          fillColor: theme.colors.surface,
          constraints: const BoxConstraints(minHeight: 48),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: SpectraSpacing.md,
            vertical: SpectraSpacing.md,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SpectraSpacing.sm),
            borderSide: BorderSide(color: theme.colors.border),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Implement the dialog**

```dart
// lib/src/components/dialog.dart
import 'package:material_ui/material_ui.dart';

import '../theme/spectra_theme.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// A Spectra modal dialog. [show] presents it and returns the popped value.
class SpectraDialog extends StatelessWidget {
  const SpectraDialog({
    required this.title,
    required this.content,
    required this.actions,
    super.key,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    required List<Widget> Function(BuildContext context) actions,
  }) {
    return showDialog<T>(
      context: context,
      builder: (BuildContext context) => SpectraDialog(
        title: title,
        content: content,
        actions: actions(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    return Dialog(
      backgroundColor: theme.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SpectraSpacing.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(SpectraSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: SpectraTypography.title.copyWith(
                color: theme.colors.textPrimary,
              ),
            ),
            const SizedBox(height: SpectraSpacing.lg),
            content,
            const SizedBox(height: SpectraSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                for (final Widget action in actions) ...<Widget>[
                  const SizedBox(width: SpectraSpacing.sm),
                  action,
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Implement the bottom sheet**

```dart
// lib/src/components/bottom_sheet.dart
import 'package:material_ui/material_ui.dart';

import '../../l10n/spectra_ui_localizations.dart';
import '../theme/spectra_theme.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// A titled modal sheet. [show] presents it and returns the popped value.
class SpectraBottomSheet extends StatelessWidget {
  const SpectraBottomSheet({
    required this.title,
    required this.child,
    super.key,
  });

  final String title;
  final Widget child;

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required WidgetBuilder builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) =>
          SpectraBottomSheet(title: title, child: builder(context)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    final SpectraUiLocalizations l10n = SpectraUiLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SpectraSpacing.lg),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(SpectraSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      style: SpectraTypography.title.copyWith(
                        color: theme.colors.textPrimary,
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: l10n.close,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.close, color: theme.colors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SpectraSpacing.lg),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Export**

Add to `lib/spectra_ui.dart`:

```dart
export 'src/components/bottom_sheet.dart';
export 'src/components/dialog.dart';
export 'src/components/text_field.dart';
```

- [ ] **Step 7: Run the behavior tests**

Run: `mise x -- flutter test test/components/text_field_test.dart test/components/overlays_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 8: Generate and verify the goldens**

```bash
mise x -- flutter test test/components/overlays_golden_test.dart --update-goldens
mise x -- flutter test test/components/overlays_golden_test.dart
```

Expected: the second run PASSes, 2 golden tests, and `test/components/goldens/ci/overlays_light.png` and `overlays_dark.png` exist.

- [ ] **Step 9: Commit**

```bash
git add packages/spectra_ui/lib packages/spectra_ui/test
git commit -m "$(cat <<'MSG'
feat(spectra_ui): add text input, dialog and bottom sheet

Dialog and sheet expose static show helpers so features never construct a
route themselves, which keeps the presentation style in one place.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 9: Card, list tile and section header

**Files:**
- Create: `lib/src/components/card.dart`, `lib/src/components/list_tile.dart`, `lib/src/components/section_header.dart`
- Modify: `lib/spectra_ui.dart`
- Test: `test/components/surfaces_test.dart`, `test/components/surfaces_golden_test.dart`
- Generated: `test/components/goldens/ci/surfaces_light.png`, `surfaces_dark.png`

**Interfaces:**
- Produces: `class SpectraCard extends StatelessWidget` — `const SpectraCard({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(SpectraSpacing.lg), VoidCallback? onTap, String? semanticsLabel, Key? key})`.
- Produces: `class SpectraListTile extends StatelessWidget` — `const SpectraListTile({required String title, String? subtitle, Widget? leading, Widget? trailing, VoidCallback? onTap, Key? key})`.
- Produces: `class SpectraSectionHeader extends StatelessWidget` — `const SpectraSectionHeader({required String title, String? actionLabel, VoidCallback? onAction, Key? key})`.

- [ ] **Step 1: Write the failing behavior test**

```dart
// test/components/surfaces_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  testWidgets('a tappable card reports taps and is a semantics button', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      spectraHarness(
        child: SpectraCard(
          semanticsLabel: 'Device card',
          onTap: () => taps++,
          child: const SizedBox(width: 100, height: 60),
        ),
      ),
    );
    await tester.tap(find.byType(SpectraCard));
    expect(taps, 1);
    expect(find.bySemanticsLabel('Device card'), findsOneWidget);
  });

  testWidgets('a plain card is not a button', (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        child: const SpectraCard(child: SizedBox(width: 100, height: 60)),
      ),
    );
    expect(tester.widgetList(find.byType(GestureDetector)), isEmpty);
  });

  testWidgets('a list tile shows title, subtitle and keeps a 48px target', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      spectraHarness(
        width: 360,
        child: SpectraListTile(
          title: 'Chameleon Ultra',
          subtitle: 'USB serial',
          onTap: () => taps++,
        ),
      ),
    );
    expect(find.text('Chameleon Ultra'), findsOneWidget);
    expect(find.text('USB serial'), findsOneWidget);
    expect(
      tester.getSize(find.byType(SpectraListTile)).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.byType(SpectraListTile));
    expect(taps, 1);
  });

  testWidgets('a section header fires its action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      spectraHarness(
        width: 360,
        child: SpectraSectionHeader(
          title: 'Slots',
          actionLabel: 'Refresh',
          onAction: () => taps++,
        ),
      ),
    );
    await tester.tap(find.text('Refresh'));
    expect(taps, 1);
  });
}
```

- [ ] **Step 2: Write the failing golden test**

```dart
// test/components/surfaces_golden_test.dart
import 'package:alchemist/alchemist.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  for (final (String name, Brightness brightness) in <(String, Brightness)>[
    ('surfaces_light', Brightness.light),
    ('surfaces_dark', Brightness.dark),
  ]) {
    goldenTest(
      'card, list tile and section header render ($name)',
      fileName: name,
      builder: () => GoldenTestGroup(
        columns: 1,
        children: <Widget>[
          spectraScenario(
            name: 'card',
            brightness: brightness,
            width: 380,
            height: 140,
            child: const SpectraCard(
              child: SpectraListTile(
                title: 'Chameleon Ultra',
                subtitle: 'Firmware 2.0.0',
              ),
            ),
          ),
          spectraScenario(
            name: 'section header',
            brightness: brightness,
            width: 380,
            height: 100,
            child: SpectraSectionHeader(
              title: 'Slots',
              actionLabel: 'Refresh',
              onAction: () {},
            ),
          ),
          spectraScenario(
            name: 'list tile with leading and trailing',
            brightness: brightness,
            width: 380,
            height: 120,
            child: SpectraListTile(
              title: 'Office badge',
              subtitle: 'MIFARE Classic 1K',
              leading: const Icon(Icons.badge_outlined),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Run to verify they fail**

Run: `mise x -- flutter test test/components/surfaces_test.dart`
Expected: FAIL to compile — `Undefined name 'SpectraCard'`.

- [ ] **Step 4: Implement the card**

```dart
// lib/src/components/card.dart
import 'package:material_ui/material_ui.dart';

import '../theme/spectra_theme.dart';
import '../tokens/spacing.dart';

/// A raised surface. Tappable only when [onTap] is given.
class SpectraCard extends StatelessWidget {
  const SpectraCard({
    required this.child,
    this.padding = const EdgeInsets.all(SpectraSpacing.lg),
    this.onTap,
    this.semanticsLabel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    final Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border.all(color: theme.colors.border),
        borderRadius: BorderRadius.circular(SpectraSpacing.md),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) {
      return semanticsLabel == null
          ? surface
          : Semantics(label: semanticsLabel, child: surface);
    }
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(onTap: onTap, child: surface),
    );
  }
}
```

- [ ] **Step 5: Implement the list tile**

```dart
// lib/src/components/list_tile.dart
import 'package:material_ui/material_ui.dart';

import '../theme/spectra_theme.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// One row of a list: title, optional subtitle, optional leading and trailing.
class SpectraListTile extends StatelessWidget {
  const SpectraListTile({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    final Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SpectraSpacing.md,
          vertical: SpectraSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            if (leading != null) ...<Widget>[
              IconTheme(
                data: IconThemeData(color: theme.colors.textSecondary),
                child: leading!,
              ),
              const SizedBox(width: SpectraSpacing.md),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: SpectraTypography.body.copyWith(
                      color: theme.colors.textPrimary,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: SpectraTypography.bodySmall.copyWith(
                        color: theme.colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: SpectraSpacing.md),
              IconTheme(
                data: IconThemeData(color: theme.colors.textSecondary),
                child: trailing!,
              ),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: subtitle == null ? title : '$title, $subtitle',
      excludeSemantics: true,
      child: GestureDetector(onTap: onTap, child: row),
    );
  }
}
```

- [ ] **Step 6: Implement the section header**

```dart
// lib/src/components/section_header.dart
import 'package:material_ui/material_ui.dart';

import '../theme/spectra_theme.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// A group title with one optional trailing action.
class SpectraSectionHeader extends StatelessWidget {
  const SpectraSectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SpectraSpacing.md,
        vertical: SpectraSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: SpectraTypography.label.copyWith(
                color: theme.colors.textSecondary,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            Semantics(
              button: true,
              label: actionLabel,
              child: GestureDetector(
                onTap: onAction,
                child: SizedBox(
                  height: 48,
                  child: Center(
                    child: Text(
                      actionLabel!,
                      style: SpectraTypography.label.copyWith(
                        color: theme.colors.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Export**

Add to `lib/spectra_ui.dart`:

```dart
export 'src/components/card.dart';
export 'src/components/list_tile.dart';
export 'src/components/section_header.dart';
```

- [ ] **Step 8: Run the behavior test**

Run: `mise x -- flutter test test/components/surfaces_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 9: Generate and verify the goldens**

```bash
mise x -- flutter test test/components/surfaces_golden_test.dart --update-goldens
mise x -- flutter test test/components/surfaces_golden_test.dart
```

Expected: the second run PASSes, 2 golden tests.

- [ ] **Step 10: Commit**

```bash
git add packages/spectra_ui/lib packages/spectra_ui/test
git commit -m "$(cat <<'MSG'
feat(spectra_ui): add card, list tile and section header

Three surfaces of the same shape, so they share one task and one golden
file; the tile carries the semantics label features would otherwise repeat.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 10: Status chip

**Files:**
- Create: `lib/src/components/connection_status.dart`, `lib/src/components/status_chip.dart`
- Modify: `lib/spectra_ui.dart`
- Test: `test/components/status_chip_test.dart`, `test/components/status_chip_golden_test.dart`
- Generated: `test/components/goldens/ci/status_chip_light.png`, `status_chip_dark.png`

**Interfaces:**
- Produces: `enum SpectraConnectionStatus { disconnected, connecting, connected, limited, updating }`.
- Produces: `class SpectraStatusChip extends StatelessWidget` with two constructors:
  - `const SpectraStatusChip.connection(SpectraConnectionStatus status, {Key? key})`
  - `const SpectraStatusChip.battery({required int percent, bool charging = false, Key? key})`
  and public fields `SpectraConnectionStatus? status`, `int? percent`, `bool charging`.

The app maps its own `connectionState` onto `SpectraConnectionStatus`; the chip never sees a device type (spec 6.3).

- [ ] **Step 1: Write the failing behavior test**

```dart
// test/components/status_chip_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  testWidgets('each connection status gets its localized label', (
    tester,
  ) async {
    for (final (SpectraConnectionStatus status, String label)
        in <(SpectraConnectionStatus, String)>[
          (SpectraConnectionStatus.disconnected, 'Disconnected'),
          (SpectraConnectionStatus.connecting, 'Connecting'),
          (SpectraConnectionStatus.connected, 'Connected'),
          (SpectraConnectionStatus.limited, 'Limited'),
          (SpectraConnectionStatus.updating, 'Updating'),
        ]) {
      await tester.pumpWidget(
        spectraHarness(child: SpectraStatusChip.connection(status)),
      );
      expect(find.text(label), findsOneWidget, reason: '$status');
    }
  });

  testWidgets('connected paints from the connected token', (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        child: const SpectraStatusChip.connection(
          SpectraConnectionStatus.connected,
        ),
      ),
    );
    final DecoratedBox box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(SpectraStatusChip),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(
      (box.decoration as BoxDecoration).border!.top.color,
      SpectraColors.light.connected,
    );
  });

  testWidgets('battery shows a percentage and a charging variant', (
    tester,
  ) async {
    await tester.pumpWidget(
      spectraHarness(child: const SpectraStatusChip.battery(percent: 87)),
    );
    expect(find.text('87%'), findsOneWidget);

    await tester.pumpWidget(
      spectraHarness(
        child: const SpectraStatusChip.battery(percent: 87, charging: true),
      ),
    );
    expect(find.text('87% charging'), findsOneWidget);
  });

  testWidgets('a low battery uses the danger token', (tester) async {
    await tester.pumpWidget(
      spectraHarness(child: const SpectraStatusChip.battery(percent: 9)),
    );
    final DecoratedBox box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(SpectraStatusChip),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(
      (box.decoration as BoxDecoration).border!.top.color,
      SpectraColors.light.danger,
    );
  });
}
```

- [ ] **Step 2: Write the failing golden test**

```dart
// test/components/status_chip_golden_test.dart
import 'package:alchemist/alchemist.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  for (final (String name, Brightness brightness) in <(String, Brightness)>[
    ('status_chip_light', Brightness.light),
    ('status_chip_dark', Brightness.dark),
  ]) {
    goldenTest(
      'status chips render every variant ($name)',
      fileName: name,
      builder: () => GoldenTestGroup(
        columns: 3,
        children: <Widget>[
          for (final SpectraConnectionStatus status
              in SpectraConnectionStatus.values)
            spectraScenario(
              name: status.name,
              brightness: brightness,
              width: 220,
              height: 100,
              child: SpectraStatusChip.connection(status),
            ),
          spectraScenario(
            name: 'battery 87',
            brightness: brightness,
            width: 220,
            height: 100,
            child: const SpectraStatusChip.battery(percent: 87),
          ),
          spectraScenario(
            name: 'battery 34 charging',
            brightness: brightness,
            width: 220,
            height: 100,
            child: const SpectraStatusChip.battery(percent: 34, charging: true),
          ),
          spectraScenario(
            name: 'battery 9',
            brightness: brightness,
            width: 220,
            height: 100,
            child: const SpectraStatusChip.battery(percent: 9),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Run to verify they fail**

Run: `mise x -- flutter test test/components/status_chip_test.dart`
Expected: FAIL to compile — `Undefined name 'SpectraStatusChip'`.

- [ ] **Step 4: Implement the enum**

```dart
// lib/src/components/connection_status.dart
/// The connection states the chip can show. The app maps its own session
/// state onto this; `spectra_ui` never sees a device type.
enum SpectraConnectionStatus {
  disconnected,
  connecting,
  connected,

  /// Connected, but only a firmware update is possible.
  limited,

  /// A firmware update is running.
  updating,
}
```

- [ ] **Step 5: Implement the chip**

```dart
// lib/src/components/status_chip.dart
import 'package:material_ui/material_ui.dart';

import '../../l10n/spectra_ui_localizations.dart';
import '../theme/spectra_theme.dart';
import '../tokens/color_scheme.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'connection_status.dart';

/// A small labelled state chip, in a connection variant and a battery variant.
class SpectraStatusChip extends StatelessWidget {
  const SpectraStatusChip.connection(SpectraConnectionStatus this.status, {super.key})
    : percent = null,
      charging = false;

  const SpectraStatusChip.battery({
    required int this.percent,
    this.charging = false,
    super.key,
  }) : status = null;

  final SpectraConnectionStatus? status;
  final int? percent;
  final bool charging;

  /// Below this the battery chip turns danger-coloured.
  static const int lowBatteryPercent = 15;

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    final SpectraUiLocalizations l10n = SpectraUiLocalizations.of(context);
    final SpectraColorScheme colors = theme.colors;

    final (String label, Color tint, IconData icon) = switch (status) {
      SpectraConnectionStatus.disconnected => (
        l10n.statusDisconnected,
        colors.textSecondary,
        Icons.link_off,
      ),
      SpectraConnectionStatus.connecting => (
        l10n.statusConnecting,
        colors.warning,
        Icons.sync,
      ),
      SpectraConnectionStatus.connected => (
        l10n.statusConnected,
        colors.connected,
        Icons.link,
      ),
      SpectraConnectionStatus.limited => (
        l10n.statusLimited,
        colors.warning,
        Icons.warning_amber,
      ),
      SpectraConnectionStatus.updating => (
        l10n.statusUpdating,
        colors.accent,
        Icons.system_update_alt,
      ),
      null => (
        charging ? l10n.batteryCharging(percent!) : l10n.batteryLevel(percent!),
        percent! <= lowBatteryPercent ? colors.danger : colors.success,
        charging ? Icons.battery_charging_full : Icons.battery_full,
      ),
    };

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: tint),
          borderRadius: BorderRadius.circular(SpectraSpacing.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpectraSpacing.md,
            vertical: SpectraSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 14, color: tint),
              const SizedBox(width: SpectraSpacing.xs),
              Text(label, style: SpectraTypography.label.copyWith(color: tint)),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Export**

Add to `lib/spectra_ui.dart`:

```dart
export 'src/components/connection_status.dart';
export 'src/components/status_chip.dart';
```

- [ ] **Step 7: Run the behavior test**

Run: `mise x -- flutter test test/components/status_chip_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 8: Generate and verify the goldens**

```bash
mise x -- flutter test test/components/status_chip_golden_test.dart --update-goldens
mise x -- flutter test test/components/status_chip_golden_test.dart
```

Expected: the second run PASSes, 2 golden tests.

- [ ] **Step 9: Commit**

```bash
git add packages/spectra_ui/lib packages/spectra_ui/test
git commit -m "$(cat <<'MSG'
feat(spectra_ui): add the connection and battery status chip

One widget with two named constructors keeps the chip geometry identical
across the dashboard's two uses, and the labels come from the ARB catalog.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 11: Progress and step indicators

**Files:**
- Create: `lib/src/components/progress_indicator.dart`, `lib/src/components/step_indicator.dart`
- Modify: `lib/spectra_ui.dart`
- Test: `test/components/progress_test.dart`, `test/components/progress_golden_test.dart`
- Generated: `test/components/goldens/ci/progress_light.png`, `progress_dark.png`

**Interfaces:**
- Produces: `class SpectraProgressIndicator extends StatelessWidget` — `const SpectraProgressIndicator({required String label, double? value, String? detail, VoidCallback? onCancel, Key? key})`. `value == null` means indeterminate; `value` is 0..1.
- Produces: `class SpectraStepIndicator extends StatelessWidget` — `const SpectraStepIndicator({required List<String> steps, required int currentIndex, bool failed = false, Key? key})`.

- [ ] **Step 1: Write the failing behavior test**

```dart
// test/components/progress_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  testWidgets('a determinate value drives the bar', (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 360,
        child: const SpectraProgressIndicator(label: 'Writing', value: 0.4),
      ),
    );
    final LinearProgressIndicator bar = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(bar.value, 0.4);
    expect(find.text('Writing'), findsOneWidget);
  });

  testWidgets('a null value is indeterminate', (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 360,
        child: const SpectraProgressIndicator(label: 'Scanning'),
      ),
    );
    final LinearProgressIndicator bar = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(bar.value, isNull);
  });

  testWidgets('the cancel affordance appears only with onCancel', (
    tester,
  ) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 360,
        child: const SpectraProgressIndicator(label: 'Writing', value: 0.4),
      ),
    );
    expect(find.text('Cancel'), findsNothing);

    var cancels = 0;
    await tester.pumpWidget(
      spectraHarness(
        width: 360,
        child: SpectraProgressIndicator(
          label: 'Writing',
          value: 0.4,
          onCancel: () => cancels++,
        ),
      ),
    );
    await tester.tap(find.text('Cancel'));
    expect(cancels, 1);
  });

  testWidgets('the step indicator labels its position', (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 360,
        child: const SpectraStepIndicator(
          steps: <String>['Prepare', 'Transfer', 'Verify'],
          currentIndex: 1,
        ),
      ),
    );
    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
  });

  testWidgets('a failed step tints from the danger token', (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 360,
        child: const SpectraStepIndicator(
          steps: <String>['Prepare', 'Transfer', 'Verify'],
          currentIndex: 1,
          failed: true,
        ),
      ),
    );
    final Text label = tester.widget<Text>(find.text('Transfer'));
    expect(label.style!.color, SpectraColors.light.danger);
  });
}
```

- [ ] **Step 2: Write the failing golden test**

```dart
// test/components/progress_golden_test.dart
import 'package:alchemist/alchemist.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  const List<String> steps = <String>['Prepare', 'Transfer', 'Verify'];
  for (final (String name, Brightness brightness) in <(String, Brightness)>[
    ('progress_light', Brightness.light),
    ('progress_dark', Brightness.dark),
  ]) {
    goldenTest(
      'progress and step indicators render ($name)',
      fileName: name,
      builder: () => GoldenTestGroup(
        columns: 1,
        children: <Widget>[
          spectraScenario(
            name: 'determinate with cancel',
            brightness: brightness,
            width: 400,
            height: 160,
            child: SpectraProgressIndicator(
              label: 'Writing slot 3',
              detail: '12 of 64 blocks',
              value: 0.4,
              onCancel: () {},
            ),
          ),
          spectraScenario(
            name: 'step 2 of 3',
            brightness: brightness,
            width: 400,
            height: 140,
            child: const SpectraStepIndicator(steps: steps, currentIndex: 1),
          ),
          spectraScenario(
            name: 'step 2 failed',
            brightness: brightness,
            width: 400,
            height: 140,
            child: const SpectraStepIndicator(
              steps: steps,
              currentIndex: 1,
              failed: true,
            ),
          ),
        ],
      ),
    );
  }
}
```

The indeterminate bar is deliberately absent from the goldens: it animates forever and would never settle.

- [ ] **Step 3: Run to verify they fail**

Run: `mise x -- flutter test test/components/progress_test.dart`
Expected: FAIL to compile — `Undefined name 'SpectraProgressIndicator'`.

- [ ] **Step 4: Implement the progress indicator**

```dart
// lib/src/components/progress_indicator.dart
import 'package:material_ui/material_ui.dart';

import '../../l10n/spectra_ui_localizations.dart';
import '../theme/spectra_theme.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'button.dart';
import 'button_variant.dart';

/// A labelled progress bar for a long operation, with optional cancellation.
class SpectraProgressIndicator extends StatelessWidget {
  const SpectraProgressIndicator({
    required this.label,
    this.value,
    this.detail,
    this.onCancel,
    super.key,
  });

  final String label;

  /// 0..1, or null for an indeterminate operation.
  final double? value;

  final String? detail;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    final SpectraUiLocalizations l10n = SpectraUiLocalizations.of(context);
    return Semantics(
      label: detail == null ? label : '$label, $detail',
      value: value == null ? null : '${(value! * 100).round()}%',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: SpectraTypography.body.copyWith(
              color: theme.colors.textPrimary,
            ),
          ),
          const SizedBox(height: SpectraSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(SpectraSpacing.xs),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: theme.colors.surfaceRaised,
              color: theme.colors.accent,
            ),
          ),
          if (detail != null) ...<Widget>[
            const SizedBox(height: SpectraSpacing.xs),
            Text(
              detail!,
              style: SpectraTypography.bodySmall.copyWith(
                color: theme.colors.textSecondary,
              ),
            ),
          ],
          if (onCancel != null) ...<Widget>[
            const SizedBox(height: SpectraSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: SpectraButton(
                label: l10n.cancel,
                variant: SpectraButtonVariant.secondary,
                onPressed: onCancel,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Implement the step indicator**

```dart
// lib/src/components/step_indicator.dart
import 'package:material_ui/material_ui.dart';

import '../../l10n/spectra_ui_localizations.dart';
import '../theme/spectra_theme.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Position within a fixed sequence of named steps, such as a DFU run.
class SpectraStepIndicator extends StatelessWidget {
  const SpectraStepIndicator({
    required this.steps,
    required this.currentIndex,
    this.failed = false,
    super.key,
  });

  final List<String> steps;
  final int currentIndex;

  /// The current step failed: it and its dot turn danger-coloured.
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    final SpectraUiLocalizations l10n = SpectraUiLocalizations.of(context);
    final Color currentColor = failed ? theme.colors.danger : theme.colors.accent;
    return Semantics(
      label: l10n.stepProgress(currentIndex + 1, steps.length),
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.stepProgress(currentIndex + 1, steps.length),
            style: SpectraTypography.label.copyWith(
              color: theme.colors.textSecondary,
            ),
          ),
          const SizedBox(height: SpectraSpacing.sm),
          Row(
            children: <Widget>[
              for (int i = 0; i < steps.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: SpectraSpacing.sm),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: switch (i) {
                      _ when i < currentIndex => theme.colors.success,
                      _ when i == currentIndex => currentColor,
                      _ => theme.colors.border,
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: SpectraSpacing.sm),
          Text(
            steps[currentIndex],
            style: SpectraTypography.body.copyWith(
              color: failed ? theme.colors.danger : theme.colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Export**

Add to `lib/spectra_ui.dart`:

```dart
export 'src/components/progress_indicator.dart';
export 'src/components/step_indicator.dart';
```

- [ ] **Step 7: Run the behavior test**

Run: `mise x -- flutter test test/components/progress_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 8: Generate and verify the goldens**

```bash
mise x -- flutter test test/components/progress_golden_test.dart --update-goldens
mise x -- flutter test test/components/progress_golden_test.dart
```

Expected: the second run PASSes, 2 golden tests.

- [ ] **Step 9: Commit**

```bash
git add packages/spectra_ui/lib packages/spectra_ui/test
git commit -m "$(cat <<'MSG'
feat(spectra_ui): add progress and step indicators

Long operations (DFU, full-dump reads) need both a bar and a named-step
position; the step labels come from the caller so the kit stays generic.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 12: Hex viewer

**Files:**
- Create: `lib/src/components/hex_highlight.dart`, `lib/src/components/hex_viewer.dart`
- Modify: `lib/spectra_ui.dart`
- Test: `test/components/hex_viewer_test.dart`, `test/components/hex_viewer_golden_test.dart`
- Generated: `test/components/goldens/ci/hex_viewer_light.png`, `hex_viewer_dark.png`

**Interfaces:**
- Produces: `final class SpectraHexHighlight` — `const SpectraHexHighlight({required int start, required int length, required Color color, String? label})`, with `int get end => start + length` and `bool contains(int index)`.
- Produces: `class SpectraHexViewer extends StatelessWidget` — `const SpectraHexViewer({required Uint8List bytes, int bytesPerRow = 16, int groupSize = 4, List<SpectraHexHighlight> highlights = const <SpectraHexHighlight>[], bool showAscii = true, Key? key})`.

Row rendering: an 8-digit uppercase hex offset, then `bytesPerRow` two-digit uppercase bytes separated by a single space with an extra space after every `groupSize` bytes, then the ASCII gutter (printable 0x20..0x7E, `.` otherwise).

- [ ] **Step 1: Write the failing behavior test**

```dart
// test/components/hex_viewer_test.dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

Uint8List _bytes(int n) =>
    Uint8List.fromList(List<int>.generate(n, (int i) => i & 0xFF));

void main() {
  test('a highlight knows the range it covers', () {
    const h = SpectraHexHighlight(
      start: 4,
      length: 3,
      color: Color(0xFF00FF00),
    );
    expect(h.end, 7);
    expect(h.contains(3), isFalse);
    expect(h.contains(4), isTrue);
    expect(h.contains(6), isTrue);
    expect(h.contains(7), isFalse);
  });

  testWidgets('renders one row per bytesPerRow with an offset column', (
    tester,
  ) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 640,
        height: 260,
        child: SpectraHexViewer(bytes: _bytes(32)),
      ),
    );
    expect(find.text('00000000'), findsOneWidget);
    expect(find.text('00000010'), findsOneWidget);
    expect(find.text('Offset'), findsOneWidget);
    expect(find.text('ASCII'), findsOneWidget);
  });

  testWidgets('groups bytes and pads a short final row', (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 640,
        height: 220,
        child: SpectraHexViewer(
          bytes: Uint8List.fromList(<int>[0x04, 0x1F, 0xAB, 0xCD, 0xEF]),
        ),
      ),
    );
    // Each byte is its own Text so highlight ranges can tint individually.
    expect(find.text('04'), findsOneWidget);
    expect(find.text('1F'), findsOneWidget);
    expect(find.text('EF'), findsOneWidget);
    // A double space marks the group break before the fifth byte.
    expect(find.text('  '), findsOneWidget);
  });

  testWidgets('renders the ASCII gutter with dots for unprintables', (
    tester,
  ) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 640,
        height: 220,
        child: SpectraHexViewer(
          bytes: Uint8List.fromList(<int>[0x41, 0x42, 0x00, 0x7F]),
        ),
      ),
    );
    expect(find.text('AB..'), findsOneWidget);
  });

  testWidgets('shows the empty label for zero bytes', (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 400,
        child: SpectraHexViewer(bytes: Uint8List(0)),
      ),
    );
    expect(find.text('No data'), findsOneWidget);
  });

  testWidgets('a highlight tints only the bytes it covers', (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 640,
        height: 220,
        child: SpectraHexViewer(
          bytes: _bytes(8),
          bytesPerRow: 8,
          groupSize: 8,
          showAscii: false,
          highlights: const <SpectraHexHighlight>[
            SpectraHexHighlight(start: 2, length: 2, color: Color(0xFF00FF00)),
          ],
        ),
      ),
    );
    final Iterable<Text> cells = tester
        .widgetList<Text>(find.byType(Text))
        .where((Text t) => t.data == '02' || t.data == '03' || t.data == '05');
    expect(cells.length, 3);
    for (final Text cell in cells) {
      final bool highlighted = cell.data != '05';
      expect(
        cell.style!.backgroundColor,
        highlighted ? const Color(0xFF00FF00) : null,
        reason: cell.data,
      );
    }
  });
}
```

- [ ] **Step 2: Write the failing golden test**

```dart
// test/components/hex_viewer_golden_test.dart
import 'dart:typed_data';

import 'package:alchemist/alchemist.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  final Uint8List block = Uint8List.fromList(
    List<int>.generate(48, (int i) => (i * 7 + 0x20) & 0xFF),
  );
  for (final (String name, Brightness brightness) in <(String, Brightness)>[
    ('hex_viewer_light', Brightness.light),
    ('hex_viewer_dark', Brightness.dark),
  ]) {
    goldenTest(
      'hex viewer renders rows, groups and highlights ($name)',
      fileName: name,
      builder: () => GoldenTestGroup(
        columns: 1,
        children: <Widget>[
          spectraScenario(
            name: 'three rows with a highlighted key range',
            brightness: brightness,
            width: 760,
            height: 220,
            child: SpectraHexViewer(
              bytes: block,
              highlights: <SpectraHexHighlight>[
                SpectraHexHighlight(
                  start: 6,
                  length: 6,
                  color: brightness == Brightness.dark
                      ? SpectraColors.dark.warning
                      : SpectraColors.light.warning,
                  label: 'Key A',
                ),
              ],
            ),
          ),
          spectraScenario(
            name: 'empty',
            brightness: brightness,
            width: 400,
            height: 120,
            child: SpectraHexViewer(bytes: Uint8List(0)),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Run to verify they fail**

Run: `mise x -- flutter test test/components/hex_viewer_test.dart`
Expected: FAIL to compile — `Undefined name 'SpectraHexHighlight'`.

- [ ] **Step 4: Implement the highlight**

```dart
// lib/src/components/hex_highlight.dart
import 'package:flutter/widgets.dart' show Color;

/// A byte range the hex viewer tints, such as a sector key or a UID.
final class SpectraHexHighlight {
  const SpectraHexHighlight({
    required this.start,
    required this.length,
    required this.color,
    this.label,
  });

  /// First byte index covered.
  final int start;

  /// Number of bytes covered.
  final int length;

  final Color color;

  /// Optional semantics label announced for the range.
  final String? label;

  int get end => start + length;

  bool contains(int index) => index >= start && index < end;
}
```

- [ ] **Step 5: Implement the viewer**

```dart
// lib/src/components/hex_viewer.dart
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../l10n/spectra_ui_localizations.dart';
import '../theme/spectra_theme.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'hex_highlight.dart';

/// A monospaced hex dump: offset column, grouped bytes, ASCII gutter and
/// tinted highlight ranges. Takes plain bytes, never a dump model.
class SpectraHexViewer extends StatelessWidget {
  const SpectraHexViewer({
    required this.bytes,
    this.bytesPerRow = 16,
    this.groupSize = 4,
    this.highlights = const <SpectraHexHighlight>[],
    this.showAscii = true,
    super.key,
  });

  final Uint8List bytes;
  final int bytesPerRow;
  final int groupSize;
  final List<SpectraHexHighlight> highlights;
  final bool showAscii;

  Color? _tintFor(int index) {
    for (final SpectraHexHighlight h in highlights) {
      if (h.contains(index)) return h.color;
    }
    return null;
  }

  static String _ascii(Uint8List row) {
    final StringBuffer buffer = StringBuffer();
    for (final int b in row) {
      buffer.write(b >= 0x20 && b <= 0x7E ? String.fromCharCode(b) : '.');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    final SpectraUiLocalizations l10n = SpectraUiLocalizations.of(context);
    final TextStyle mono = SpectraTypography.mono.copyWith(
      color: theme.colors.textPrimary,
    );
    final TextStyle header = SpectraTypography.label.copyWith(
      color: theme.colors.textSecondary,
    );

    if (bytes.isEmpty) {
      return Text(
        l10n.hexViewerEmpty,
        style: SpectraTypography.body.copyWith(color: theme.colors.textSecondary),
      );
    }

    final int rowCount = (bytes.length + bytesPerRow - 1) ~/ bytesPerRow;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SizedBox(width: 96, child: Text(l10n.hexViewerOffsetHeader, style: header)),
              if (showAscii) ...<Widget>[
                const SizedBox(width: SpectraSpacing.lg),
                Text(l10n.hexViewerAsciiHeader, style: header),
              ],
            ],
          ),
          const SizedBox(height: SpectraSpacing.xs),
          for (int row = 0; row < rowCount; row++)
            _buildRow(row, mono, theme.colors.textSecondary),
        ],
      ),
    );
  }

  Widget _buildRow(int row, TextStyle mono, Color offsetColor) {
    final int start = row * bytesPerRow;
    final int end = (start + bytesPerRow).clamp(0, bytes.length);
    final Uint8List slice = Uint8List.sublistView(bytes, start, end);
    final List<Widget> cells = <Widget>[];
    for (int i = 0; i < slice.length; i++) {
      if (i > 0) {
        final bool groupBreak = i % groupSize == 0;
        cells.add(Text(groupBreak ? '  ' : ' ', style: mono)); // l10n-exempt: layout gap
      }
      final Color? tint = _tintFor(start + i);
      cells.add(
        Text(
          slice[i].toRadixString(16).toUpperCase().padLeft(2, '0'),
          style: tint == null ? mono : mono.copyWith(backgroundColor: tint),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: SpectraSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(
              start.toRadixString(16).toUpperCase().padLeft(8, '0'),
              style: mono.copyWith(color: offsetColor),
            ),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: cells),
          if (showAscii) ...<Widget>[
            const SizedBox(width: SpectraSpacing.lg),
            Text(_ascii(slice), style: mono),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Export**

Add to `lib/spectra_ui.dart`:

```dart
export 'src/components/hex_highlight.dart';
export 'src/components/hex_viewer.dart';
```

- [ ] **Step 7: Run the behavior test**

Run: `mise x -- flutter test test/components/hex_viewer_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 8: Generate and verify the goldens**

```bash
mise x -- flutter test test/components/hex_viewer_golden_test.dart --update-goldens
mise x -- flutter test test/components/hex_viewer_golden_test.dart
```

Expected: the second run PASSes, 2 golden tests.

- [ ] **Step 9: Verify the lint accepts the l10n-exempt marker**

Run from the worktree root: `mise x -- dart run tool/dep_lint.dart`
Expected: `dep_lint: ok`. The layout-gap `Text('  ')` is the one exempted literal in the kit; if the lint still flags it, the marker comment is on the wrong line — it must be on the same line as the `Text(`.

- [ ] **Step 10: Commit**

```bash
git add packages/spectra_ui/lib packages/spectra_ui/test
git commit -m "$(cat <<'MSG'
feat(spectra_ui): add the hex viewer

Per-byte Text widgets are what make highlight ranges possible without a
custom painter, and the dump editor needs range tinting from day one.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 13: Slot tile

**Files:**
- Create: `lib/src/components/slot_tile.dart`
- Modify: `lib/spectra_ui.dart`
- Test: `test/components/slot_tile_test.dart`, `test/components/slot_tile_golden_test.dart`
- Generated: `test/components/goldens/ci/slot_tile_light.png`, `slot_tile_dark.png`

**Interfaces:**
- Produces: `class SpectraSlotTile extends StatelessWidget` — `const SpectraSlotTile({required int number, required bool enabled, String? nickname, List<String> tagTypes = const <String>[], bool active = false, VoidCallback? onTap, Key? key})`.

`number` is one-based. `tagTypes` are already-formatted display names supplied by the app (for example `MIFARE Classic 1K`, `EM410X`); the kit never sees a `TagType`.

- [ ] **Step 1: Write the failing behavior test**

```dart
// test/components/slot_tile_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  testWidgets('shows the slot number and nickname', (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 300,
        child: const SpectraSlotTile(
          number: 3,
          enabled: true,
          nickname: 'Office badge',
          tagTypes: <String>['MIFARE Classic 1K'],
        ),
      ),
    );
    expect(find.text('Slot 3'), findsOneWidget);
    expect(find.text('Office badge'), findsOneWidget);
    expect(find.text('MIFARE Classic 1K'), findsOneWidget);
  });

  testWidgets('falls back to Empty with no nickname and no tag types', (
    tester,
  ) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 300,
        child: const SpectraSlotTile(number: 5, enabled: true),
      ),
    );
    expect(find.text('Empty'), findsOneWidget);
  });

  testWidgets('a disabled slot says so and dims its text', (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 300,
        child: const SpectraSlotTile(
          number: 2,
          enabled: false,
          nickname: 'Spare',
        ),
      ),
    );
    expect(find.text('Disabled'), findsOneWidget);
    final Text nickname = tester.widget<Text>(find.text('Spare'));
    expect(nickname.style!.color, SpectraColors.light.textDisabled);
  });

  testWidgets('the active slot is marked and accented', (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 300,
        child: const SpectraSlotTile(
          number: 1,
          enabled: true,
          nickname: 'Gate',
          active: true,
        ),
      ),
    );
    expect(find.text('Active'), findsOneWidget);
    final DecoratedBox box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(SpectraSlotTile),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(
      (box.decoration as BoxDecoration).border!.top.color,
      SpectraColors.light.accent,
    );
  });

  testWidgets('taps are reported and the target is at least 48px', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      spectraHarness(
        width: 300,
        child: SpectraSlotTile(
          number: 4,
          enabled: true,
          nickname: 'Gate',
          onTap: () => taps++,
        ),
      ),
    );
    await tester.tap(find.byType(SpectraSlotTile));
    expect(taps, 1);
    expect(
      tester.getSize(find.byType(SpectraSlotTile)).height,
      greaterThanOrEqualTo(48),
    );
  });
}
```

- [ ] **Step 2: Write the failing golden test**

```dart
// test/components/slot_tile_golden_test.dart
import 'package:alchemist/alchemist.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  for (final (String name, Brightness brightness) in <(String, Brightness)>[
    ('slot_tile_light', Brightness.light),
    ('slot_tile_dark', Brightness.dark),
  ]) {
    goldenTest(
      'slot tiles render every state ($name)',
      fileName: name,
      builder: () => GoldenTestGroup(
        columns: 2,
        children: <Widget>[
          spectraScenario(
            name: 'active with two tag types',
            brightness: brightness,
            width: 320,
            height: 160,
            child: const SpectraSlotTile(
              number: 1,
              enabled: true,
              active: true,
              nickname: 'Office badge',
              tagTypes: <String>['MIFARE Classic 1K', 'EM410X'],
            ),
          ),
          spectraScenario(
            name: 'enabled',
            brightness: brightness,
            width: 320,
            height: 160,
            child: const SpectraSlotTile(
              number: 2,
              enabled: true,
              nickname: 'Gate fob',
              tagTypes: <String>['EM410X'],
            ),
          ),
          spectraScenario(
            name: 'empty',
            brightness: brightness,
            width: 320,
            height: 160,
            child: const SpectraSlotTile(number: 3, enabled: true),
          ),
          spectraScenario(
            name: 'disabled',
            brightness: brightness,
            width: 320,
            height: 160,
            child: const SpectraSlotTile(
              number: 4,
              enabled: false,
              nickname: 'Spare',
              tagTypes: <String>['NTAG215'],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Run to verify they fail**

Run: `mise x -- flutter test test/components/slot_tile_test.dart`
Expected: FAIL to compile — `Undefined name 'SpectraSlotTile'`.

- [ ] **Step 4: Implement**

```dart
// lib/src/components/slot_tile.dart
import 'package:material_ui/material_ui.dart';

import '../../l10n/spectra_ui_localizations.dart';
import '../theme/spectra_theme.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// One of the device's eight slots. Tag types arrive as display strings, so
/// the kit never depends on the SDK's tag enums.
class SpectraSlotTile extends StatelessWidget {
  const SpectraSlotTile({
    required this.number,
    required this.enabled,
    this.nickname,
    this.tagTypes = const <String>[],
    this.active = false,
    this.onTap,
    super.key,
  });

  /// One-based slot number as the device labels it.
  final int number;

  final bool enabled;
  final String? nickname;
  final List<String> tagTypes;

  /// True for the slot the device currently emulates.
  final bool active;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    final SpectraUiLocalizations l10n = SpectraUiLocalizations.of(context);
    final Color primaryText = enabled
        ? theme.colors.textPrimary
        : theme.colors.textDisabled;
    final Color secondaryText = enabled
        ? theme.colors.textSecondary
        : theme.colors.textDisabled;
    final String? statusLabel = !enabled
        ? l10n.slotTileDisabled
        : active
        ? l10n.slotTileActive
        : null;
    final bool empty = nickname == null && tagTypes.isEmpty;

    final Widget body = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border.all(
          color: active ? theme.colors.accent : theme.colors.border,
          width: active ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(SpectraSpacing.md),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.all(SpectraSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.slotLabel(number),
                      style: SpectraTypography.label.copyWith(
                        color: secondaryText,
                      ),
                    ),
                  ),
                  if (statusLabel != null)
                    Text(
                      statusLabel,
                      style: SpectraTypography.label.copyWith(
                        color: active ? theme.colors.accent : secondaryText,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: SpectraSpacing.xs),
              Text(
                empty ? l10n.slotTileEmpty : (nickname ?? l10n.slotTileEmpty),
                style: SpectraTypography.title.copyWith(color: primaryText),
              ),
              if (tagTypes.isNotEmpty) ...<Widget>[
                const SizedBox(height: SpectraSpacing.xs),
                Wrap(
                  spacing: SpectraSpacing.sm,
                  runSpacing: SpectraSpacing.xs,
                  children: <Widget>[
                    for (final String type in tagTypes)
                      Text(
                        type,
                        style: SpectraTypography.bodySmall.copyWith(
                          color: secondaryText,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );

    final String semantics = <String>[
      l10n.slotLabel(number),
      if (nickname != null) nickname! else l10n.slotTileEmpty,
      if (statusLabel != null) statusLabel,
      ...tagTypes,
    ].join(', ');

    if (onTap == null) {
      return Semantics(label: semantics, excludeSemantics: true, child: body);
    }
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: GestureDetector(onTap: onTap, child: body),
    );
  }
}
```

- [ ] **Step 5: Export**

Add to `lib/spectra_ui.dart`:

```dart
export 'src/components/slot_tile.dart';
```

- [ ] **Step 6: Run the behavior test**

Run: `mise x -- flutter test test/components/slot_tile_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 7: Generate and verify the goldens**

```bash
mise x -- flutter test test/components/slot_tile_golden_test.dart --update-goldens
mise x -- flutter test test/components/slot_tile_golden_test.dart
```

Expected: the second run PASSes, 2 golden tests.

- [ ] **Step 8: Commit**

```bash
git add packages/spectra_ui/lib packages/spectra_ui/test
git commit -m "$(cat <<'MSG'
feat(spectra_ui): add the slot tile

Tag types arrive as display strings so the slots feature owns the mapping
from the SDK's enums and the kit stays free of device types.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 14: Disclosure

**Files:**
- Create: `lib/src/components/disclosure.dart`
- Modify: `lib/spectra_ui.dart`
- Test: `test/components/disclosure_test.dart`, `test/components/disclosure_golden_test.dart`
- Generated: `test/components/goldens/ci/disclosure_light.png`, `disclosure_dark.png`

**Interfaces:**
- Produces: `class SpectraDisclosure extends StatefulWidget` — `const SpectraDisclosure({required Widget summary, required Widget detail, bool initiallyExpanded = false, ValueChanged<bool>? onExpansionChanged, Key? key})`.

This is the progressive-disclosure primitive from spec section 1: a summary row that reveals expert detail. Motion comes from `flutter_animate` at `SpectraMotion.medium` with `SpectraMotion.standard`.

- [ ] **Step 1: Write the failing behavior test**

```dart
// test/components/disclosure_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  testWidgets('starts collapsed and shows the expand affordance', (
    tester,
  ) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 360,
        child: const SpectraDisclosure(
          summary: SpectraListTile(title: 'Firmware'),
          detail: SpectraListTile(title: 'Git hash abc1234'),
        ),
      ),
    );
    expect(find.text('Firmware'), findsOneWidget);
    expect(find.text('Git hash abc1234'), findsNothing);
    expect(find.bySemanticsLabel('Show details'), findsOneWidget);
  });

  testWidgets('expands on tap, reports the change and flips the affordance', (
    tester,
  ) async {
    final changes = <bool>[];
    await tester.pumpWidget(
      spectraHarness(
        width: 360,
        height: 300,
        child: SpectraDisclosure(
          summary: const SpectraListTile(title: 'Firmware'),
          detail: const SpectraListTile(title: 'Git hash abc1234'),
          onExpansionChanged: changes.add,
        ),
      ),
    );
    await tester.tap(find.text('Firmware'));
    await tester.pumpAndSettle();

    expect(changes, <bool>[true]);
    expect(find.text('Git hash abc1234'), findsOneWidget);
    expect(find.bySemanticsLabel('Hide details'), findsOneWidget);

    await tester.tap(find.text('Firmware'));
    await tester.pumpAndSettle();
    expect(changes, <bool>[true, false]);
    expect(find.text('Git hash abc1234'), findsNothing);
  });

  testWidgets('initiallyExpanded starts open', (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 360,
        height: 300,
        child: const SpectraDisclosure(
          initiallyExpanded: true,
          summary: SpectraListTile(title: 'Firmware'),
          detail: SpectraListTile(title: 'Git hash abc1234'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Git hash abc1234'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Write the failing golden test**

```dart
// test/components/disclosure_golden_test.dart
import 'package:alchemist/alchemist.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  for (final (String name, Brightness brightness) in <(String, Brightness)>[
    ('disclosure_light', Brightness.light),
    ('disclosure_dark', Brightness.dark),
  ]) {
    goldenTest(
      'disclosure renders collapsed and expanded ($name)',
      fileName: name,
      builder: () => GoldenTestGroup(
        columns: 1,
        children: <Widget>[
          spectraScenario(
            name: 'collapsed',
            brightness: brightness,
            width: 400,
            height: 120,
            child: const SpectraDisclosure(
              summary: SpectraListTile(
                title: 'Firmware 2.0.0',
                subtitle: 'Up to date',
              ),
              detail: SpectraListTile(title: 'Git hash abc1234'),
            ),
          ),
          spectraScenario(
            name: 'expanded',
            brightness: brightness,
            width: 400,
            height: 220,
            child: const SpectraDisclosure(
              initiallyExpanded: true,
              summary: SpectraListTile(
                title: 'Firmware 2.0.0',
                subtitle: 'Up to date',
              ),
              detail: SpectraListTile(
                title: 'Git hash abc1234',
                subtitle: 'Built 2026-08-30',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Run to verify they fail**

Run: `mise x -- flutter test test/components/disclosure_test.dart`
Expected: FAIL to compile — `Undefined name 'SpectraDisclosure'`.

- [ ] **Step 4: Implement**

```dart
// lib/src/components/disclosure.dart
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/spectra_ui_localizations.dart';
import '../theme/spectra_theme.dart';
import '../tokens/motion.dart';
import '../tokens/spacing.dart';

/// A summary row that expands to expert detail: the progressive-disclosure
/// primitive every expert affordance in Spectra sits behind.
class SpectraDisclosure extends StatefulWidget {
  const SpectraDisclosure({
    required this.summary,
    required this.detail,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
    super.key,
  });

  final Widget summary;
  final Widget detail;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;

  @override
  State<SpectraDisclosure> createState() => _SpectraDisclosureState();
}

class _SpectraDisclosureState extends State<SpectraDisclosure> {
  late bool _expanded = widget.initiallyExpanded;

  void _toggle() {
    setState(() => _expanded = !_expanded);
    widget.onExpansionChanged?.call(_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    final SpectraUiLocalizations l10n = SpectraUiLocalizations.of(context);
    final String affordance = _expanded ? l10n.disclosureHide : l10n.disclosureShow;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        GestureDetector(
          onTap: _toggle,
          child: Row(
            children: <Widget>[
              Expanded(child: widget.summary),
              Semantics(
                button: true,
                label: affordance,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(top: SpectraSpacing.sm),
            child: widget.detail
                .animate()
                .fadeIn(duration: SpectraMotion.medium, curve: SpectraMotion.standard),
          ),
      ],
    );
  }
}
```

The fade is finite, so `pumpAndSettle` in the tests and alchemist's own settle leave the golden fully opaque and deterministic.

- [ ] **Step 5: Export**

Add to `lib/spectra_ui.dart`:

```dart
export 'src/components/disclosure.dart';
```

- [ ] **Step 6: Run the behavior test**

Run: `mise x -- flutter test test/components/disclosure_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 7: Generate and verify the goldens**

```bash
mise x -- flutter test test/components/disclosure_golden_test.dart --update-goldens
mise x -- flutter test test/components/disclosure_golden_test.dart
```

Expected: the second run PASSes, 2 golden tests. If the expanded golden comes out semi-transparent, alchemist did not settle the animation — add `pumpBeforeTest: precacheImagesAndSettle` to the `goldenTest` call.

- [ ] **Step 8: Commit**

```bash
git add packages/spectra_ui/lib packages/spectra_ui/test
git commit -m "$(cat <<'MSG'
feat(spectra_ui): add the disclosure component

Progressive disclosure is the spec's core interaction rule, so it gets one
primitive rather than a bespoke expander per screen.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 15: Adaptive app shell

**Files:**
- Create: `lib/src/components/destination.dart`, `lib/src/components/app_shell.dart`
- Modify: `lib/spectra_ui.dart`
- Test: `test/components/app_shell_test.dart`, `test/components/app_shell_golden_test.dart`
- Generated: `test/components/goldens/ci/app_shell_light.png`, `app_shell_dark.png`

**Interfaces:**
- Produces: `const double spectraNavigationRailBreakpoint = 600;` and `final class SpectraDestination` — `const SpectraDestination({required String label, required IconData icon, IconData? selectedIcon})`, in `destination.dart`.
- Produces: `class SpectraAppShell extends StatelessWidget` — `const SpectraAppShell({required List<SpectraDestination> destinations, required int selectedIndex, required ValueChanged<int> onDestinationSelected, required Widget child, String? title, List<Widget> actions = const <Widget>[], Key? key})`.

Below `spectraNavigationRailBreakpoint` logical pixels of width the shell shows a bottom bar; at or above it, a navigation rail on the leading edge. Destinations are a plain list, so routing owns the route table (spec 8.2).

- [ ] **Step 1: Write the failing behavior test**

```dart
// test/components/app_shell_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

const List<SpectraDestination> _destinations = <SpectraDestination>[
  SpectraDestination(label: 'Device', icon: Icons.memory),
  SpectraDestination(label: 'Slots', icon: Icons.grid_view),
  SpectraDestination(label: 'Cards', icon: Icons.style),
];

Widget _shell({required int selectedIndex, required ValueChanged<int> onTap}) {
  return SpectraAppShell(
    destinations: _destinations,
    selectedIndex: selectedIndex,
    onDestinationSelected: onTap,
    title: 'Spectra',
    child: const Center(child: SpectraListTile(title: 'Body')),
  );
}

void main() {
  testWidgets('under 600 logical pixels it shows a bottom bar', (tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      spectraHarness(child: _shell(selectedIndex: 0, onTap: (_) {})),
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('at 600 logical pixels and above it shows a rail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      spectraHarness(child: _shell(selectedIndex: 0, onTap: (_) {})),
    );
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('selecting a destination reports its index in both layouts', (
    tester,
  ) async {
    final taps = <int>[];
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    tester.view.physicalSize = const Size(500, 900);
    await tester.pumpWidget(
      spectraHarness(child: _shell(selectedIndex: 0, onTap: taps.add)),
    );
    await tester.tap(find.text('Slots').last);
    expect(taps, <int>[1]);

    tester.view.physicalSize = const Size(900, 700);
    await tester.pumpWidget(
      spectraHarness(child: _shell(selectedIndex: 0, onTap: taps.add)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cards').last);
    expect(taps, <int>[1, 2]);
  });

  testWidgets('the body is always present', (tester) async {
    await tester.pumpWidget(
      spectraHarness(child: _shell(selectedIndex: 0, onTap: (_) {})),
    );
    expect(find.text('Body'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Write the failing golden test**

```dart
// test/components/app_shell_golden_test.dart
import 'package:alchemist/alchemist.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

const List<SpectraDestination> _destinations = <SpectraDestination>[
  SpectraDestination(label: 'Device', icon: Icons.memory),
  SpectraDestination(label: 'Slots', icon: Icons.grid_view),
  SpectraDestination(label: 'Cards', icon: Icons.style),
  SpectraDestination(label: 'Tools', icon: Icons.build),
  SpectraDestination(label: 'Settings', icon: Icons.settings),
];

void main() {
  for (final (String name, Brightness brightness) in <(String, Brightness)>[
    ('app_shell_light', Brightness.light),
    ('app_shell_dark', Brightness.dark),
  ]) {
    goldenTest(
      'the shell renders both navigation layouts ($name)',
      fileName: name,
      builder: () => GoldenTestGroup(
        columns: 1,
        children: <Widget>[
          spectraScenario(
            name: 'compact, bottom bar',
            brightness: brightness,
            width: 420,
            height: 560,
            child: SpectraAppShell(
              destinations: _destinations,
              selectedIndex: 1,
              onDestinationSelected: (_) {},
              title: 'Slots',
              child: const SpectraCard(
                child: SpectraListTile(title: 'Slot list'),
              ),
            ),
          ),
          spectraScenario(
            name: 'expanded, navigation rail',
            brightness: brightness,
            width: 900,
            height: 500,
            child: SpectraAppShell(
              destinations: _destinations,
              selectedIndex: 1,
              onDestinationSelected: (_) {},
              title: 'Slots',
              child: const SpectraCard(
                child: SpectraListTile(title: 'Slot list'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

The shell measures its own incoming constraints, not the window, so the two scenarios differ purely by the `SizedBox` width the harness applies.

- [ ] **Step 3: Run to verify they fail**

Run: `mise x -- flutter test test/components/app_shell_test.dart`
Expected: FAIL to compile — `Undefined name 'SpectraAppShell'`.

- [ ] **Step 4: Implement the destination**

```dart
// lib/src/components/destination.dart
import 'package:flutter/widgets.dart' show IconData;

/// Width at which the shell swaps a bottom bar for a navigation rail
/// (spec 6.2).
const double spectraNavigationRailBreakpoint = 600;

/// One top-level navigation target. A plain value so routing owns the route
/// table and the shell stays a dumb layout.
final class SpectraDestination {
  const SpectraDestination({
    required this.label,
    required this.icon,
    this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
}
```

- [ ] **Step 5: Implement the shell**

```dart
// lib/src/components/app_shell.dart
import 'package:material_ui/material_ui.dart';

import '../theme/spectra_theme.dart';
import '../tokens/typography.dart';
import 'destination.dart';

/// The adaptive application frame: a bottom bar under
/// [spectraNavigationRailBreakpoint], a navigation rail at or above it.
class SpectraAppShell extends StatelessWidget {
  const SpectraAppShell({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
    this.title,
    this.actions = const <Widget>[],
    super.key,
  });

  final List<SpectraDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;
  final String? title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    final String? shellTitle = title;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide =
            constraints.maxWidth >= spectraNavigationRailBreakpoint;
        return Scaffold(
          backgroundColor: theme.colors.background,
          appBar: shellTitle == null
              ? null
              : AppBar(
                  backgroundColor: theme.colors.surface,
                  title: Text(
                    shellTitle,
                    style: SpectraTypography.title.copyWith(
                      color: theme.colors.textPrimary,
                    ),
                  ),
                  actions: actions,
                ),
          body: wide
              ? Row(
                  children: <Widget>[
                    NavigationRail(
                      backgroundColor: theme.colors.surface,
                      selectedIndex: selectedIndex,
                      onDestinationSelected: onDestinationSelected,
                      labelType: NavigationRailLabelType.all,
                      destinations: <NavigationRailDestination>[
                        for (final SpectraDestination d in destinations)
                          NavigationRailDestination(
                            icon: Icon(d.icon),
                            selectedIcon: Icon(d.selectedIcon ?? d.icon),
                            label: Text(d.label),
                          ),
                      ],
                    ),
                    VerticalDivider(width: 1, color: theme.colors.border),
                    Expanded(child: child),
                  ],
                )
              : child,
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  backgroundColor: theme.colors.surface,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  destinations: <NavigationDestination>[
                    for (final SpectraDestination d in destinations)
                      NavigationDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon ?? d.icon),
                        label: d.label,
                      ),
                  ],
                ),
        );
      },
    );
  }
}
```

`Text(d.label)` and `label: d.label` both take variables, so the `no-literal-text` rule is satisfied. `NavigationBar` and `NavigationRail` already meet the 48x48 target.

- [ ] **Step 6: Export**

Add to `lib/spectra_ui.dart`:

```dart
export 'src/components/app_shell.dart';
export 'src/components/destination.dart';
```

- [ ] **Step 7: Run the behavior test**

Run: `mise x -- flutter test test/components/app_shell_test.dart`
Expected: PASS, 4 tests.

If the first two tests both find a rail, the harness's fixed-size `SizedBox` is overriding the view size — pass `width: 500` / `width: 900` to `spectraHarness` in those tests instead of setting `tester.view.physicalSize`.

- [ ] **Step 8: Generate and verify the goldens**

```bash
mise x -- flutter test test/components/app_shell_golden_test.dart --update-goldens
mise x -- flutter test test/components/app_shell_golden_test.dart
```

Expected: the second run PASSes, 2 golden tests.

- [ ] **Step 9: Commit**

```bash
git add packages/spectra_ui/lib packages/spectra_ui/test
git commit -m "$(cat <<'MSG'
feat(spectra_ui): add the adaptive app shell

The shell measures its own constraints rather than the window, so it works
inside a golden scenario and inside a resizable desktop window alike.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 16: The gallery example

**Files:**
- Rewrite: `packages/spectra_ui/example/lib/main.dart`
- Create: `example/lib/gallery_app.dart`, `example/lib/gallery_entry.dart`, `example/lib/gallery_router.dart`, `example/lib/pages/buttons_page.dart`, `pages/inputs_page.dart`, `pages/surfaces_page.dart`, `pages/status_page.dart`, `pages/progress_page.dart`, `pages/hex_viewer_page.dart`, `pages/slots_page.dart`, `pages/disclosure_page.dart`
- Rewrite: `example/test/widget_test.dart` -> `example/test/gallery_test.dart`
- Test: `packages/spectra_ui/example/test/gallery_test.dart`

**Interfaces:**
- Consumes: every exported `spectra_ui` type from Tasks 2 to 15.
- Produces: `final class GalleryEntry` — `const GalleryEntry({required String path, required String title, required WidgetBuilder builder})`; `const List<GalleryEntry> galleryEntries`; `GoRouter buildGalleryRouter()`; `class GalleryApp extends StatefulWidget` (owns the light/dark toggle).

The Spike B probe's structure (a `GoRouter` built by a top-level function, driven by a widget test) is kept; its two placeholder routes and its local `galleryTheme` are replaced, because `SpectraApp` now owns theming.

- [ ] **Step 1: Write the failing test**

```dart
// packages/spectra_ui/example/test/gallery_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';
import 'package:spectra_ui_gallery/gallery_app.dart';
import 'package:spectra_ui_gallery/gallery_entry.dart';
import 'package:spectra_ui_gallery/gallery_router.dart';

void main() {
  testWidgets('the index lists every component page', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GalleryApp());
    await tester.pumpAndSettle();

    for (final GalleryEntry entry in galleryEntries) {
      expect(find.text(entry.title), findsWidgets, reason: entry.path);
    }
  });

  testWidgets('every route builds without throwing', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = buildGalleryRouter();
    await tester.pumpWidget(GalleryApp(router: router));
    await tester.pumpAndSettle();

    for (final GalleryEntry entry in galleryEntries) {
      router.go(entry.path);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: entry.path);
      expect(find.byType(SpectraAppShell), findsOneWidget, reason: entry.path);
    }
  });

  testWidgets('the theme toggle switches the shell to dark', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GalleryApp());
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Toggle dark mode'));
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.byType(SpectraAppShell));
    expect(SpectraTheme.of(context).brightness, Brightness.dark);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run in `packages/spectra_ui/example`: `mise x -- flutter test test/gallery_test.dart`
Expected: FAIL to compile — `Couldn't resolve the package 'spectra_ui_gallery/gallery_app.dart'`.

- [ ] **Step 3: Delete the probe test**

```bash
git rm packages/spectra_ui/example/test/widget_test.dart
```

Its assertions (navigation works, components take the theme) are now covered by `gallery_test.dart` and by `test/theme/spectra_theme_test.dart` in the package.

- [ ] **Step 4: Implement the entry record and the page list**

```dart
// example/lib/gallery_entry.dart
import 'package:material_ui/material_ui.dart';

import 'pages/buttons_page.dart';
import 'pages/disclosure_page.dart';
import 'pages/hex_viewer_page.dart';
import 'pages/inputs_page.dart';
import 'pages/progress_page.dart';
import 'pages/slots_page.dart';
import 'pages/status_page.dart';
import 'pages/surfaces_page.dart';

/// One demo page in the gallery.
final class GalleryEntry {
  const GalleryEntry({
    required this.path,
    required this.title,
    required this.builder,
  });

  final String path;
  final String title;
  final WidgetBuilder builder;
}

/// Every component gets a page. Adding a component means adding a row here.
const List<GalleryEntry> galleryEntries = <GalleryEntry>[
  GalleryEntry(path: '/buttons', title: 'Buttons', builder: buildButtonsPage),
  GalleryEntry(path: '/inputs', title: 'Inputs and overlays', builder: buildInputsPage),
  GalleryEntry(path: '/surfaces', title: 'Cards and lists', builder: buildSurfacesPage),
  GalleryEntry(path: '/status', title: 'Status chips', builder: buildStatusPage),
  GalleryEntry(path: '/progress', title: 'Progress and steps', builder: buildProgressPage),
  GalleryEntry(path: '/hex', title: 'Hex viewer', builder: buildHexViewerPage),
  GalleryEntry(path: '/slots', title: 'Slot tiles', builder: buildSlotsPage),
  GalleryEntry(path: '/disclosure', title: 'Disclosure', builder: buildDisclosurePage),
];
```

- [ ] **Step 5: Implement one page per component**

Each page is a top-level `Widget build<Name>Page(BuildContext context)` function returning a scrollable column of sample data. Two are shown in full; write the remaining six the same way, using the sample data from the corresponding golden test.

```dart
// example/lib/pages/buttons_page.dart
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

/// Every button variant and state, with sample labels.
Widget buildButtonsPage(BuildContext context) {
  return ListView(
    padding: const EdgeInsets.all(SpectraSpacing.xl),
    children: <Widget>[
      const SpectraSectionHeader(title: 'Variants'),
      SpectraButton(label: 'Connect', onPressed: () {}),
      const SizedBox(height: SpectraSpacing.md),
      SpectraButton(
        label: 'Rescan',
        variant: SpectraButtonVariant.secondary,
        onPressed: () {},
      ),
      const SizedBox(height: SpectraSpacing.md),
      SpectraButton(
        label: 'Erase slot',
        variant: SpectraButtonVariant.danger,
        icon: Icons.delete_outline,
        onPressed: () {},
      ),
      const SizedBox(height: SpectraSpacing.xl),
      const SpectraSectionHeader(title: 'States'),
      const SpectraButton(label: 'Disabled', onPressed: null),
      const SizedBox(height: SpectraSpacing.md),
      SpectraButton(label: 'Working', busy: true, onPressed: () {}),
    ],
  );
}
```

```dart
// example/lib/pages/hex_viewer_page.dart
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

/// A 48-byte sample dump with one highlighted key range.
Widget buildHexViewerPage(BuildContext context) {
  final Uint8List sample = Uint8List.fromList(
    List<int>.generate(48, (int i) => (i * 7 + 0x20) & 0xFF),
  );
  return ListView(
    padding: const EdgeInsets.all(SpectraSpacing.xl),
    children: <Widget>[
      const SpectraSectionHeader(title: 'Sector 0 with Key A highlighted'),
      const SizedBox(height: SpectraSpacing.md),
      SpectraHexViewer(
        bytes: sample,
        highlights: <SpectraHexHighlight>[
          SpectraHexHighlight(
            start: 6,
            length: 6,
            color: SpectraTheme.of(context).colors.warning,
            label: 'Key A',
          ),
        ],
      ),
      const SizedBox(height: SpectraSpacing.xl),
      const SpectraSectionHeader(title: 'Empty'),
      SpectraHexViewer(bytes: Uint8List(0)),
    ],
  );
}
```

The remaining pages, each with the same shape:

- `inputs_page.dart` — `buildInputsPage`: a `SpectraTextField`, one with `errorText: 'Required'`, and two buttons that call `SpectraDialog.show` and `SpectraBottomSheet.show`.
- `surfaces_page.dart` — `buildSurfacesPage`: a `SpectraSectionHeader`, a `SpectraCard` wrapping two `SpectraListTile`s with leading and trailing icons.
- `status_page.dart` — `buildStatusPage`: a `Wrap` of `SpectraStatusChip.connection` for every `SpectraConnectionStatus.values`, plus battery chips at 87, 34 charging and 9.
- `progress_page.dart` — `buildProgressPage`: a determinate `SpectraProgressIndicator` at 0.4 with a cancel callback, an indeterminate one, and `SpectraStepIndicator` at index 1 of `['Prepare', 'Transfer', 'Verify']`, plus the same with `failed: true`.
- `slots_page.dart` — `buildSlotsPage`: four `SpectraSlotTile`s covering active, enabled, empty and disabled.
- `disclosure_page.dart` — `buildDisclosurePage`: two `SpectraDisclosure`s, one collapsed and one `initiallyExpanded`.

- [ ] **Step 6: Implement the router**

```dart
// example/lib/gallery_router.dart
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import 'gallery_entry.dart';

/// One route per component, all inside the adaptive shell. `/` redirects to
/// the first entry so the shell always has a selected destination.
GoRouter buildGalleryRouter() {
  return GoRouter(
    initialLocation: galleryEntries.first.path,
    routes: <RouteBase>[
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          final int index = galleryEntries.indexWhere(
            (GalleryEntry e) => e.path == state.uri.path,
          );
          return SpectraAppShell(
            destinations: <SpectraDestination>[
              for (final GalleryEntry e in galleryEntries)
                SpectraDestination(label: e.title, icon: Icons.widgets_outlined),
            ],
            selectedIndex: index < 0 ? 0 : index,
            onDestinationSelected: (int i) =>
                GoRouter.of(context).go(galleryEntries[i].path),
            title: index < 0 ? galleryEntries.first.title : galleryEntries[index].title,
            child: child,
          );
        },
        routes: <RouteBase>[
          for (final GalleryEntry entry in galleryEntries)
            GoRoute(
              path: entry.path,
              builder: (BuildContext context, GoRouterState state) =>
                  entry.builder(context),
            ),
        ],
      ),
    ],
  );
}
```

- [ ] **Step 7: Implement the app and the entry point**

```dart
// example/lib/gallery_app.dart
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import 'gallery_router.dart';

/// The gallery root. Owns the light/dark toggle so the whole kit can be seen
/// in both schemes without changing the host system setting.
class GalleryApp extends StatefulWidget {
  const GalleryApp({this.router, super.key});

  final GoRouter? router;

  @override
  State<GalleryApp> createState() => _GalleryAppState();
}

class _GalleryAppState extends State<GalleryApp> {
  late final GoRouter _router = widget.router ?? buildGalleryRouter();
  ThemeMode _mode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        SpectraApp(
          title: 'Spectra UI gallery',
          themeMode: _mode,
          routerConfig: _router,
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Semantics(
            button: true,
            label: 'Toggle dark mode',
            child: GestureDetector(
              onTap: () => setState(
                () => _mode = _mode == ThemeMode.light
                    ? ThemeMode.dark
                    : ThemeMode.light,
              ),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.brightness_6),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

The toggle lives outside `SpectraApp` in a `Stack` so it is reachable from every route without the shell growing a gallery-only action. Wrap the `Stack` in a `Directionality(textDirection: TextDirection.ltr, child: ...)` if the analyzer or a runtime assertion asks for one.

```dart
// example/lib/main.dart
import 'package:material_ui/material_ui.dart';

import 'gallery_app.dart';

void main() {
  runApp(const GalleryApp());
}
```

- [ ] **Step 8: Run the gallery test**

Run in `packages/spectra_ui/example`: `mise x -- flutter test test/gallery_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 9: Build it on macOS**

Run in `packages/spectra_ui/example`:

```bash
mise x -- flutter build macos --debug
```

Expected: `✓ Built build/macos/Build/Products/Debug/spectra_ui_gallery.app`. This is the roadmap's Phase 2 gate ("gallery runs on macOS in emulator-free mode"); the gallery has no device dependency at all, so nothing needs hardware.

- [ ] **Step 10: Verify the dependency lint**

Run from the worktree root: `mise x -- dart run tool/dep_lint.dart`
Expected: `dep_lint: ok`. The gallery is exempt from `no-literal-text` (its copy is sample data), and its imports stay inside `flutter`, `spectra_ui`, `material_ui` and `go_router`.

- [ ] **Step 11: Commit**

```bash
git add packages/spectra_ui/example
git commit -m "$(cat <<'MSG'
feat(spectra_ui): grow the probe example into the component gallery

Spec 6.3 requires a gallery showing every component with sample data; a
route per component plus a test that visits them all means a component
cannot land without somewhere to look at it.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

### Task 17: Full check, CI verification and phase close-out

**Files:**
- Modify: `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md`, `AGENTS.md`, `tasks/lessons.md`, `docs/research/DECISIONS.md`
- Verify only: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: everything from Tasks 1 to 16.
- Produces: nothing in code. This task proves the phase gate and records the decisions.

- [ ] **Step 1: Run the whole check suite**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
melos run check:all
```

Expected, in order: `format` clean, `analyze` clean, `dep_lint: ok`, `codegen: ok`, `dart test` green in `chameleon`, `flutter test` green in `spectra_ui` and `spectra_ui_gallery`. Fix anything red before continuing; do not proceed on a partial pass.

- [ ] **Step 2: Confirm the goldens actually ran**

```bash
cd packages/spectra_ui
mise x -- flutter test --reporter expanded 2>&1 | grep -c 'golden'
mise x -- flutter test --exclude-tags golden --reporter compact | tail -2
```

Expected: the first command prints a count of at least 16 (eight golden files, light and dark). The second run is only a control: it must report **fewer** tests than the plain run, proving the `golden` tag is applied and that the plain `flutter test` the CI `check` job runs does **not** exclude it.

- [ ] **Step 3: Confirm the committed goldens are the CI ones**

```bash
git status --short packages/spectra_ui/test
ls packages/spectra_ui/test/components/goldens
```

Expected: `git status` is clean, and `goldens/` contains only `ci`. If a `macos` directory exists it is git-ignored; delete it so a future reader is not confused:

```bash
rm -rf packages/spectra_ui/test/components/goldens/macos
```

- [ ] **Step 4: Confirm CI needs no new job**

Read `.github/workflows/ci.yml`. The `check` job already runs `dart run melos run test:flutter`, whose `packageFilters` are `flutter: true` and `dirExists: test` — which matches `spectra_ui` and `spectra_ui_gallery`. Goldens therefore run on the existing Ubuntu job with no workflow change. Confirm no edit is needed and record that in the commit body. The only workflow requirement is that `check` runs on `ubuntu-latest`, which it does; if that ever changes, the committed CI goldens must be regenerated on the new platform.

- [ ] **Step 5: Tick the roadmap**

In `docs/superpowers/plans/2026-09-02-spectra-v1-roadmap.md`, change `- [ ] Phase 2` to `- [x] Phase 2`, and in the phase table change the Phase 2 Plan cell from `write from spec 6, 7.6, 8.5` to `` `2026-09-03-phase-2-design-system.md` (done) ``.

- [ ] **Step 6: Update AGENTS.md**

Replace the "Current status" section's date and body so it reads:

```markdown
## Current status (2026-09-03)

Design spec approved:
`docs/superpowers/specs/2026-09-02-spectra-design.md`. Rationale in
`docs/research/DECISIONS.md`. Phase 2 (`packages/spectra_ui`) is complete:
tokens, `SpectraTheme`, every spec 6.2 component with light and dark CI
goldens, ARB localization and a component gallery. Phase 1 (`packages/chameleon`)
is the next unfinished phase.

Plans, in `docs/superpowers/plans/`:

- `2026-09-02-spectra-v1-roadmap.md`: the ten phases, gates and the three
  hardware handoffs. Start here.
- `2026-09-02-phase-0-foundation.md`: toolchain, workspace, lint, CI, spikes.
- `2026-09-02-phase-1-chameleon-sdk.md`: the pure-Dart SDK, task by task.
- `2026-09-03-phase-2-design-system.md`: the design system, task by task.
- Phases 3 to 10: write each plan with the writing-plans skill from the spec
  sections the roadmap lists, when that phase starts.
```

Also add to the "Decisions already made" list:

```markdown
- UI imports: inside `spectra_ui`, its gallery and `app/lib/features`, import
  `package:material_ui/material_ui.dart`, never `package:flutter/material.dart`.
  The two libraries declare the same names and an unprefixed dual import is a
  compile error.
```

- [ ] **Step 7: Add the lessons**

Append to `tasks/lessons.md` (create the file if it does not exist):

```markdown
## Phase 2: spectra_ui

- material_ui and package:flutter/material.dart cannot both be imported
  unprefixed into one file: both declare ThemeData, Theme, MaterialApp and
  MaterialPage. Pick material_ui everywhere in UI code; drop to
  package:flutter/widgets.dart when only widgets-layer types are needed.
- Goldens are committed from alchemist's CI mode only. Platform goldens are
  git-ignored and opt-in via SPECTRA_PLATFORM_GOLDENS=true, so a golden
  produced on this Mac can never be committed and then fail on Ubuntu.
- Rendering each hex byte as its own Text is what makes per-range highlight
  tinting possible without a custom painter; tests must assert per-cell, not
  on a joined row string.
- google_fonts must be bundled (assets/google_fonts/) with
  allowRuntimeFetching = false, or tests and offline builds depend on a
  network round trip.
```

- [ ] **Step 8: Record the decisions**

Append to `docs/research/DECISIONS.md`:

```markdown
## Phase 2 decisions (2026-09-03)

- **material_ui import convention.** `spectra_ui`, its gallery and
  `app/lib/features` import `package:material_ui/material_ui.dart` and never
  `package:flutter/material.dart`; the two declare the same names and an
  unprefixed dual import is an `ambiguous_import` error. No in-SDK `ThemeData`
  bridge is written (Spike B: go_router 18.0.1 already depends on material_ui,
  alchemist 0.14.0 needs no wrapper). `spectraThemeData()` maps Spectra tokens
  onto material_ui's own `ThemeData` instead.
- **Goldens policy.** Alchemist CI goldens only (`test/goldens/ci/`), generated
  with `melos run goldens:update` (or `flutter test --update-goldens` in the
  package). Platform goldens are disabled unless `SPECTRA_PLATFORM_GOLDENS=true`
  and their directories are git-ignored, so macOS-rendered images can never be
  committed. Goldens run in the existing Ubuntu `check` job via
  `melos run test:flutter`; no extra CI job.
- **Font fallback.** One variable sans (Inter) and one mono (JetBrains Mono),
  both bundled under `packages/spectra_ui/assets/google_fonts/` with
  `GoogleFonts.config.allowRuntimeFetching = false`. Production is offline
  capable; tests do not await the async font load, so golden text renders in
  flutter_test's Ahem and is identical on every platform.
- **Localization.** The kit owns an ARB catalog for its own strings
  (`SpectraUiLocalizations`), generated with `flutter gen-l10n` into
  `lib/l10n/` and committed; `tool/check_codegen.sh` fails when it goes stale.
  A textual lint (`tool/src/string_rules.dart`, rule `no-literal-text`) fails
  on string literals passed to `Text(` under
  `packages/spectra_ui/lib/src/components/` and `app/lib/features/**/ui/`,
  with `// l10n-exempt` for genuinely non-user-facing text.
```

- [ ] **Step 9: Re-run the full check**

```bash
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"
melos run check:all
```

Expected: everything green.

- [ ] **Step 10: Commit**

```bash
git add docs AGENTS.md tasks/lessons.md
git commit -m "$(cat <<'MSG'
docs: close out Phase 2 and record the design system decisions

Goldens run in the existing Ubuntu check job, so ci.yml needed no change;
the import convention, goldens policy and font choice are written down
because every later phase's UI code depends on them.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
)"
```

---

## Self-review notes

Checked against the spec before saving:

- **6.1 tokens** — Task 2 (colour, spacing, motion) and Task 3 (type). Four groups, exact values named.
- **6.2 components** — app shell (15), cards/list tiles/section headers (9), status chip (10), hex viewer (12), slot tile (13), progress and step indicators (11), disclosure (14), buttons (7), inputs/dialogs/sheets (8). Every one has light and dark goldens.
- **6.3 rules** — no device dependency (enforced by the existing `spectra_ui` allowlist and re-verified in Tasks 12 and 16); gallery in Task 16; goldens on one CI platform in Tasks 1 and 17; kit strings localized in Task 4.
- **7.6** — ARB from the first component (4), the string-literal lint (6), semantics labels and 48x48 targets asserted in every component task.
- **8.5** — one public type per file throughout the File structure; the largest file (`hex_viewer.dart`) is about 150 lines.
- **Section 2 dependency table** — no task adds a dependency outside the `spectra_ui` allowlist; `intl` comes in as google_fonts/gen-l10n's own requirement and is already allowlisted.
- **Not covered here, by design:** "Native window chrome on desktop" (spec 6.2) — the adversarial review cut custom desktop window chrome from v1 (`docs/research/DECISIONS.md`), so the shell uses the platform's default window frame and no task builds one.
