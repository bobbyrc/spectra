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
