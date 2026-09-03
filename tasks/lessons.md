# Lessons

Rules for future sessions, captured from corrections and dead ends. Add a
dated entry per lesson; keep each one actionable.

## 2026-09-03 (Phase 0 foundation)

- **mise vs fvm PATH ordering on this Mac.** `mise x -- <cmd>` does not put
  mise's tool paths first — it lets an older fvm-installed Dart win, and
  anything spawned through `melos exec` (which resolves `dart`/`flutter` off
  `PATH`) then picks up the wrong SDK. Before running melos scripts, run in
  the same shell command:
  `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"` — then
  invoke `dart`/`flutter` directly, not through `mise x --`.
- **`melos exec` needs the `melos` binary itself on `PATH`.** Activate it
  globally (`dart pub global activate melos`) so it lands in
  `~/.pub-cache/bin`; CI does this in a setup step. Without it, `melos`-based
  scripts fail before they even get to the PATH-ordering issue above.
- **`flutter create` leaves stale defaults behind.** Its templates set
  `uses-material-design: true` and add `cupertino_icons` to `pubspec.yaml`
  even for packages that don't want Cupertino/Material assets yet (e.g. a
  pure design-system package before its gallery exists). Strip both after
  scaffolding unless the package actually needs them.
- **A pub workspace has one root `pubspec.lock`.** Don't expect or maintain
  per-package lockfiles once a package joins the `workspace:` list in the
  root `pubspec.yaml`; resolution happens once at the root.
- **`flutter create --template=package` starts at version `0.0.1`.** If
  another package in the workspace depends on it with a `^0.1.0` constraint,
  bump the new package to `0.1.0` immediately — `0.0.1` does not satisfy
  `^0.1.0`.
- **`lints` resolves to `^6` on Dart 3.13.** The commonly-remembered `^5`
  constraint fails version solving; use `^6` in `analysis_options`-adjacent
  `pubspec.yaml` dev_dependencies.
- **`material_ui` and `package:flutter/material.dart` collide unprefixed.**
  Both declare their own `ThemeData`, `Theme`, `MaterialApp`, etc. Importing
  both unprefixed into the same file is an `ambiguous_import` analyzer error.
  Import `package:material_ui/material_ui.dart` (never the in-SDK Material)
  in `spectra_ui`, its gallery, and app features; if in-SDK Material is ever
  needed elsewhere, import it with a prefix (e.g. `as legacy`).
- **Poll CI with `gh run watch`, not long blind waits.** For draft-PR CI
  verification, `gh run watch <run-id>` (or `gh run list` before it) gives
  timely status without a TaskOutput-style long sleep.

## 2026-09-03 (Phase 2: spectra_ui)

- **`material_ui` vs `package:flutter/material.dart` import clash.** Both
  declare `ThemeData`, `Theme`, `MaterialApp`, `MaterialPage`, etc.
  unprefixed. Import `package:material_ui/material_ui.dart` everywhere in
  `spectra_ui`, its gallery and `app/lib/features`; never the in-SDK
  Material import. Drop to `package:flutter/widgets.dart` when only
  widgets-layer types are needed.
- **Alchemist CI goldens obscure text.** CI-mode goldens render text as
  block glyphs so they render identically on macOS and Ubuntu; they verify
  layout, colour and shape, not typography. Cover typography with token
  unit tests instead, and generate/update goldens only with
  `melos run goldens:update` (alchemist's CI mode), never a platform run.
- **`AlchemistConfig.current()` must be captured in `main()`, not inside a
  test body.** Calling it per-test re-reads ambient state race-prone across
  parallel test isolates; set it once at suite startup.
- **`flutter_animate` indeterminate/looping animations break
  `pumpAndSettle`.** A widget with a repeating animation never settles.
  Use a bounded `pump(duration)` sequence, or drive the widget with
  `initiallyExpanded: true` so the test never has to pump through the
  animation.
- **`Semantics` merging needs `container: true`/`explicitChildNodes` for
  separate nodes.** Without one of these, a wrapping `Semantics` merges
  into its child's node instead of producing its own, and semantics
  assertions silently pass or fail on the wrong node.
- **Use `HitTestBehavior.opaque` for tappable rows.** A `GestureDetector`
  wrapping a row with transparent gaps (e.g. padding, spacers) misses taps
  in those gaps under the default `HitTestBehavior.deferToChild`; opaque
  behavior makes the whole row's bounds tappable, which is what a tap test
  and a real user both expect.
- **`dart format` only your own package when working concurrently.** A
  repo-wide `dart format .` reformats a concurrent implementer's
  in-progress, uncommitted files in another package and manufactures merge
  noise. Format only the directory you are actually changing.
- **`git add --intent-to-add` per pattern, not per file.** When staging
  generated files whose paths aren't known ahead of time (`*.g.dart`,
  `*_localizations*.dart`), add `--intent-to-add` per glob pattern so a
  plain `git diff` (which ignores untracked files) still catches newly
  generated, never-before-committed output as stale.
- **Alchemist's `obscureText` does not make CI goldens byte-identical across
  host platforms.** Non-text anti-aliasing (borders, rounded corners, icons)
  still differs by a fraction of a percent of pixels between the macOS host
  goldens were authored on and the Ubuntu `check` runner. Set
  `CiGoldensConfig(diffThreshold: 0.01)` (or similar) in
  `flutter_test_config.dart` so a real Ubuntu CI run doesn't fail on this
  noise; verify the actual diff percentages from a CI log before picking a
  number, rather than guessing.
- **`mise x --` can race on this Mac.** It sometimes resolves the fvm Dart
  (3.8.1) instead of mise's pinned Flutter Dart (3.13.2) when invoked
  repeatedly in the same session, especially under concurrent shell
  activity. Prefer exporting
  `PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"` and setting
  `MISE_X=""` for `tool/check_codegen.sh` so it uses the exported `PATH`
  directly instead of re-resolving through `mise x --`; this is what CI
  already does.
