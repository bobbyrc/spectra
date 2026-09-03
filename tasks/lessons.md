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
- **Generate committed goldens on the platform that compares them.** A
  tolerance (`diffThreshold`) buys a green CI run but hides sub-threshold
  regressions forever. The better fix is a `workflow_dispatch` job that runs
  `flutter test --update-goldens` on the CI platform and uploads the images
  as an artifact; download, commit, and tighten the threshold. Say plainly in
  the package README that a local `flutter test` may then disagree.
- **`Semantics(button: true, excludeSemantics: true, child: GestureDetector)`
  is a trap.** It announces a button that has no `SemanticsAction.tap` (put
  `onTap:` on the `Semantics` node itself) and cannot take keyboard focus.
  Exclude the child's semantics *below* the focus widget, not above it, and
  wrap in `MergeSemantics` so the one announced node keeps both the tap
  action and the focusable flag. Assert it with
  `expect(tester.getSemantics(f), matchesSemantics(hasTapAction: true, ...))`
  — a `find.bySemanticsLabel` check passes without either.
- **A `ThemeData` with an under-specified `ColorScheme` looks fine until it
  doesn't.** Unset roles fall back to Material's seeded defaults, so an
  off-palette navigation indicator or a tinted app bar appears only in the
  one screen that uses that widget. Fill every role from a token and assert
  the previously-defaulting ones in a test. Same for `TextTheme`: fill all
  fifteen roles, not just the ones your own scale names.
- **A `const` constructor cannot assert on `list.length`.** `assert(i <
  steps.length)` in a const constructor is a `const_eval_property_access`
  error at every const call site. Keep the const-safe half (`i >= 0`) in the
  constructor and put the bound check plus a clamp at the top of `build`.

## 2026-09-03 (Phase 1: chameleon SDK)

- **`fake_async` and a `FakeDevice` do not mix.** `FakeAsync` only controls
  timers and microtasks created inside its zone; a fake transport that
  answers on a real `Future.delayed`, or any code awaiting a real I/O-shaped
  future, hangs forever inside `fakeAsync`. Use `fake_async` for units whose
  only time source is a `Timer` (the dispatcher's timeout), and short real
  delays for anything that talks to the fake device.
- **`expect(() async => f(), throwsA(...))` cannot catch an async throw.**
  The closure returns a `Future` that completes with the error *after*
  `expect` has returned, so the test passes and then crashes the run as an
  unhandled error. Always `await expectLater(future, throwsA(...))`.
- **A sealed hierarchy needs every subclass in the same library.** Moving one
  variant of a `sealed class` into another file breaks exhaustive switches at
  the seam. Keep the family together (`part` files if the file is getting
  long) — that is the reason `DfuError` lives in `errors.dart` and not in the
  DFU directory.
- **Extensions are the clean way to split a long class.** `extension X on
  Foo` in another file splits behaviour without a subclass — but an extension
  cannot hold state, so the fields stay on the class, and the extension has
  to be imported (or be a `part`) to be visible. `FakeFirmware`'s handlers
  are imported extensions; `DeviceSession`'s handshake and polling are
  `part` files precisely because they touch private state.
- **Read the generation counter at dispatch, not at enqueue.** A command that
  waits in a queue and then gets abandoned must be matched against the
  generation in force when it went on the wire; capturing it when it was
  queued lets a stale response match a fresh command.
- **Say who disposes what, in the doc comment.** A terminal transport close
  releases the dispatcher but deliberately leaves the state streams open (the
  app still wants the last known state), so `close()` is mandatory even for a
  session that is already disconnected. An undocumented split like that is a
  leak or a "stream closed" crash a phase later.
- **`yield*` forwards errors into the stream; a bare `await for` does not.**
  In an `async*` method, forwarding a sub-stream with `yield*` lets its error
  terminate the outer stream — which is what you want when the outer contract
  is "exactly one terminal event". Wrapping the whole body in try/catch and
  yielding a failure event is the other half of that contract.
- **nrfutil stores the image SHA-256 byte-reversed in the init packet.** A
  hash check written from the protobuf schema alone rejects every real
  package. Accept the order the tool actually writes, one order only, and tag
  it for hardware validation rather than accepting both.
- **`mise x -- dart` is not the same as putting mise's Flutter on PATH.** The
  Dart that ships inside the Flutter SDK is the one the workspace resolves
  against; `export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH"`
  first, then run `dart`/`melos` directly. In a pub workspace, note that
  `.dart_tool/package_config.json` lives at the workspace root, so
  `format_coverage --packages=../../.dart_tool/package_config.json`.
- **A drain window is not a timeout.** Waiting for a stray response for as
  long as the command itself was allowed makes one dropped response cost
  every later command a full timeout. Bound the two separately: the timeout
  answers "how long may this command take", the drain "how long is a late
  response still recognisable as stale".
- **A probe needs a probe's timeout.** Commands sent to find out whether the
  device supports them should not pay the catalog's timeout, let alone with
  a retry: the case they exist for is the device that never answers.
- **Refusals should carry their reason.** `SessionNotReady` on a session that
  is limited by old firmware tells the app nothing it can act on;
  `UnsupportedFirmware(reason)` tells it to offer an update. Add the state
  that makes the refusal specific before the UI has to guess.
- **One fake, many knobs.** Three test files had each grown their own
  `Transport` stub for a single misbehaviour (a failing write, a stalled
  write, an out-of-band state). Knobs on the one fake — `failNextWrite`,
  `stallWrites`, `emitState` — kept the fake honest and deleted 100 lines of
  near-duplicate test scaffolding.
- **Make the fake's capability list the fake's handler list.** Advertising
  commands the fake answers NOT_IMPLEMENTED means every test runs against a
  device that lies about itself, and the version matrix stops proving
  anything.
- **Wait for the condition, not for a duration.** `await settle()` after an
  async load is a guess that fails on a slow machine and wastes time on a
  fast one; a helper that polls the state the load produces (and throws when
  it never arrives) says what the test is actually waiting for.
- **Never assume a BLE MTU.** The Chameleon firmware requests 247 but the
  platform decides. Ask with `requestMtu`, use `mtu - 3` for the ATT
  overhead, and fall back to 20 when the platform will not answer.
- **A plugin package cannot own the app's platform files.** Spec 5.7 assigns
  the manifest, plist and entitlements to `chameleon_flutter`, but they can
  only live in `app/` and in the example. A workspace-root test that reads
  the files is the enforcement.
- **`universal_ble` and `usb_serial` cannot be unit-tested directly.** Both
  go through a plugin channel that throws `MissingPluginException` under
  `flutter test`. Wrap them in an interface this repo owns; the wrapper is
  the untestable part, and it is a dozen lines with no logic.
- **A plan's wire-format sketch is not a source.** The Phase 3 plan invented
  a length-prefixed serial DFU write-object frame; the real one (nrfutil's
  `dfu_transport_serial.py`) is opcode plus raw data, no length prefix. Cite
  upstream source lines (file + function) for any byte layout in a plan, or
  the implementer will faithfully build the wrong thing.
- **A `skip:`'d test tag silently makes the documented command a no-op.**
  `dart_test.yaml` skips the `hardware` tag by default, so the "run the
  hardware checks" command as first written (`flutter test --tags
  hardware`) executed nothing and reported success. When a tag is
  `skip:`, document `--run-skipped` right next to the command, not as a
  footnote.
- **Plan sketches of facade/method names drift from the landed API.**
  Names a plan proposes for a later task's consumption (a Phase 1 facade
  method, a barrel export) can be stale by the time that task runs.
  Implementers must read the landed file for the real name, not trust the
  plan's sketch; reviewers must check names against that file too.
- **Parallel implementers in one worktree need disjoint file sets.**
  Touching only the files a task owns, `git commit --only <paths>`, and
  formatting only your own files are not optional courtesies — earlier in
  this project a repo-wide `dart format` by one agent silently discarded
  another agent's uncommitted work.
- **A round trip through a write-through cache proves nothing.** Reading
  back a value the SDK cached on write only confirms the cache wrote what
  it was told; call `slots.refresh()` (or the equivalent device read) to
  prove the device actually has it.
- **`container.read(provider.future)` hangs on an autoDispose provider with
  no listener.** Under riverpod 3, nothing keeps an autoDispose
  stream/async provider alive just because you awaited its `.future`; the
  provider disposes before it resolves and the await never returns. Hold a
  `container.listen(provider, (_, __) {})` (or use a harness that does)
  before awaiting `.future`.
- **A `StreamSubscription.cancel()` future never completes under
  `fakeAsync`.** Awaiting it in a teardown or dispose path hangs the test.
  Fire-and-forget the cancel (`unawaited(sub.cancel())`) in any code path
  that can run under a virtual clock; the SDK's `DeviceSession` and
  `CommandDispatcher` were both fixed this way in Phase 4, and
  `chameleon_flutter` still has the same pattern in `merged_scan`,
  `state_stream` and the DFU channels, unfixed, waiting for a widget test
  that drives them hard enough to hit it.
- **`flutter_test`'s pending-timer check runs before `addTearDown`
  callbacks fire.** A test that leaves a live stream or timer mounted must
  settle it inline (or in a `finally` around the test body), not by
  registering a teardown — by the time `addTearDown` runs, the pending-timer
  assertion has already failed the test.
- **A plan's sketch of facade/provider names and riverpod API shapes drifts
  from what actually landed**, not just across phases but within one:
  implementers must read the landed file for the real name/signature
  before writing against it, and reviewers must check names against that
  file, not the plan.
- **Serialise implementers on shared files.** The ARB file, barrel exports
  (`data.dart`, `sessions.dart`), and the test harness
  (`app_harness.dart`) each got edited by more than one task in Phase 4;
  dispatching two tasks that both touch one of these in parallel cost a
  round of conflict resolution every time. Queue tasks that share a file
  instead of parallelizing them.
- **Implementers must run tests in the foreground.** A background test run
  plus waiting on a monitor stalled one Phase 4 task for over an hour with
  no useful signal in the meantime — foreground runs surface the failure
  (or the hang) immediately.
- **A review brief must not invent requirements beyond the spec/plan.** One
  Phase 4 review raised a blocker ("known-but-undiscovered rows" handling)
  that appeared nowhere in the spec, plan or task brief; the fix was to
  rule it out of scope, not to implement it. State every review requirement
  as a citation to spec/plan/brief text, not as the reviewer's own
  inference.
- **Opus returning 529 (overloaded) is not a reason to wait it out.**
  Resume the same agent or switch it to another model rather than retrying
  the same overloaded call in a loop.

## Phase 5 (slots)

- **An autoDispose notifier read with no listener held is torn down before
  its method runs.** `container.read(provider.notifier)` on an autoDispose
  provider creates the element, hands back the notifier, and disposes the
  element immediately since nothing is listening — the notifier's own
  `state = …` inside the method that follows then throws. Hold `keepAlive`
  (a `container.listen` plus `addTearDown(sub.close)`) on that exact
  provider before reading its notifier, not just before reading its value.
- **`await`ing a `FakeDevice`-backed mutation before pumping deadlocks the
  test.** `FakeDevice` replies on a real `Timer`, not the test's virtual
  clock, so the reply never arrives while nothing pumps. Start the mutation,
  `await tester.pump()`, then `await` it: `final f = editor.rename(...);
  await tester.pump(); await f;` — never `await editor.rename(...)`
  directly.
- **Pre-flight scans catch invented names before they cost a round.** All
  seven name/API corrections in Phase 5's pre-flight scan (wrong file paths,
  a nonexistent `readNotifier`, a wrong `busy`-wrapping claim, an unbound
  `ProviderScope.containerOf` default) would each have cost an implementer
  a full dispatch-fix-review cycle if left in the brief unverified.
- **Rulings must be re-read by implementers, not assumed from the plan's own
  wording.** Two Phase 5 tasks copied the plan's sample text verbatim and
  missed a ruling that postdated the plan (rulings 10 and 17 both had this
  happen). When carrying a ruling into a dispatch, paste its replacement
  text into the brief — a ruling number alone is not enough for an
  implementer with no memory of the ledger.
- **A review brief must not add requirements beyond the plan.** Phase 5 hit
  this twice more after the Phase 4 lesson above: a reviewer flagged
  "known-but-undiscovered rows" handling and a "rejects whitespace"
  behaviour that neither the spec nor the plan asked for. Both were false
  blockers — state every review requirement as a citation, not an
  inference, same lesson as Phase 4, still not fully internalized.
- **Serialise implementers on every shared file, not just the obvious
  ones.** Beyond the ARB and the test harness (Phase 4's lesson), Phase 5
  added `app/lib/features/slots/state/slot_sense_section.dart` and
  `app/lib/features/slots/ui/slot_detail_page.dart` (plus its test) to the
  list of files more than one task touched — queue tasks on these rather
  than parallelizing.
