# Spikes

Short, disposable experiments run in Phase 0 to de-risk package choices before
the real code depends on them. Each section records what was run, what happened
on each platform, and a verdict.

## Spike A: libserialport_plus build hooks

**Date:** 2026-09-03
**Question:** does `libserialport_plus` compile libserialport through its
Dart code-assets build hook on macOS, Windows and Linux, and does port
enumeration run?

**Package version:** `libserialport_plus` 1.0.4 (pub.dev, published 2026-08-26),
resolved against Flutter 3.47.2 / Dart 3.13.2. Transitive build-hook deps as
resolved: `code_assets` 2.0.0, `hooks` 2.2.0, `native_toolchain_c` 0.19.4,
`record_use` 1.1.1.

**Probe:** `packages/chameleon_flutter/example` (project name `serial_probe`),
a workspace member targeting macOS, Windows and Linux. It enumerates ports on
start, logs each one with `debugPrint` and shows them in a list.

**Enumeration call used:**

```dart
final names = SerialPort.getAvailablePorts();      // List<String> of OS port names
for (final name in names) {
  final info = SerialPort(name).getInfo();          // SerialPortInfo
  // info.name, info.description, info.transport,
  // info.usbVid, info.usbPid, info.usbManufacturer, info.usbProduct
}
```

`SerialPortInfo` exposes USB VID/PID and the manufacturer/product strings as
nullable `int?`/`String?` fields, so the earlier open question about whether
VID/PID are reachable is settled: they are, no extra FFI work needed.

**macOS:** `flutter build macos --debug` succeeded on macOS 15 (arm64,
Xcode toolchain). The hook produced
`build/macos/Build/Products/Debug/serial_probe.app/Contents/Frameworks/libserialport_plus.framework`.
Running the built app enumerated three ports:

```
[serial_probe] /dev/cu.debug-console | debug-console | native | vid=? pid=? | mfr=? product=?
[serial_probe] /dev/cu.Bluetooth-Incoming-Port | Bluetooth-Incoming-Port | native | vid=? pid=? | mfr=? product=?
[serial_probe] /dev/cu.soundcoreAeroFit2 | soundcoreAeroFit2 | native | vid=? pid=? | mfr=? product=?
```

No Chameleon Ultra was attached, so VID 0x6868 / PID 0x8686 was not observed;
confirming that specific port is part of hardware handoff H1. What this run
proves is that the native library builds, loads and enumerates.

**Windows:** built on `windows-latest` in CI (MSVC toolchain, no extra setup).
Artifacts: `build/native_assets/windows/libserialport_plus.dll` and
`build/windows/x64/runner/Debug/libserialport_plus.dll`.

**Linux:** built on `ubuntu-latest` in CI with the existing apt packages
(`clang cmake ninja-build pkg-config libgtk-3-dev`) — nothing serial-specific
had to be added. Artifacts: `build/native_assets/linux/liblibserialport_plus.so`
and `build/linux/x64/debug/bundle/lib/liblibserialport_plus.so`.

CI run: https://github.com/bobbyrc/spectra/actions/runs/33714216539 — all eight
jobs succeeded, including the two temporary probe entries. A green build alone
would not have proved much (the hook skips unsupported platforms silently and
still lets the app link), so the probe jobs also asserted a `*serialport*`
artifact exists in the bundle; both found one. Those two matrix entries and the
assertion step were removed afterwards.

**Sandbox and signing observations:**

- macOS enumeration worked *without* `com.apple.security.device.serial`. The
  entitlement was added to both `DebugProfile.entitlements` and
  `Release.entitlements` anyway — the package README requires it and the
  sibling package's issue tracker reports `Operation not permitted, errno = 1`
  on `open()` without it. So: not required to *list* ports, expected to be
  required to *open* one. Confirm at hardware handoff H1.
- Native assets need no experiment flag on Flutter 3.47.2; code assets are
  stable since 3.38.
- Windows needed no C toolchain setup beyond what `windows-latest` ships, and
  the DLL is unsigned — a future signed release build will have to cover the
  hook-produced DLL, not just the app binary.
- Nothing extra was needed on Linux; libserialport is built from the vendored
  sources, not from a system `libserialport-dev`.

**Verdict: keep `libserialport_plus` 1.0.4.** It builds through its code-assets
hook on all three desktop targets with no toolchain or CI changes, enumeration
runs on macOS, and it surfaces USB VID/PID directly, which is what the
Chameleon Ultra transport needs to identify the device. The fallback
(`flutter_libserialport` 0.6.0, classic plugin build) was not needed and was
not exercised. Spec section 5.2 stands as written.

The `serial_probe` example stays in the tree: Phase 3 turns it into the serial
transport example.

## Spike B: material_ui coexistence

**Date:** 2026-09-03
**Question:** can `spectra_ui` be built on the standalone `material_ui`
package, and do `go_router` and `alchemist` still work alongside it?

**Package versions** (resolved in the root `pubspec.lock` against Flutter
3.47.2 / Dart 3.13.2): `material_ui` **1.1.1** (publisher flutter.dev,
published 2026-09-02), `alchemist` **0.14.0**, `go_router` **18.0.1**.
`material_ui` pulls in `cupertino_ui` 1.0.2, `flutter_localizations` and
`intl` 0.20.3 transitively.

**Probe:** `packages/spectra_ui/example` (project name `spectra_ui_gallery`).
A `GoRouter` with two routes, `/` and `/details`; each page is a `Scaffold`
with one `ElevatedButton` and one `TextField`, all from
`package:material_ui/material_ui.dart`, themed through
`MaterialApp.router(theme:, darkTheme:)`. A throwaway alchemist golden test
at `packages/spectra_ui/test/spike_golden_test.dart` rendered the same button
in light and dark; it was deleted after the run, as were its goldens.

**1. Theming entry point.** `ThemeData` and the `Theme` inherited widget,
same names as the in-SDK library — `material_ui` is a lift-and-shift of
`package:flutter/material.dart`, not a new theme system. `ColorScheme`,
`ColorScheme.fromSeed`, `TextTheme`, `MaterialApp`, `Scaffold`,
`ElevatedButton`, `TextField` are all unchanged in name and shape.
`package:material_ui/material_ui.dart` re-exports `package:flutter/widgets.dart`,
so it is a complete replacement import.

**2. In-SDK `ThemeData` or its own?** Its own. `material_ui` declares
`class ThemeData` in `lib/src/theme_data.dart`, `class Theme` in
`lib/src/theme.dart`, `class MaterialApp` in `lib/src/app.dart` and
`class MaterialPage` in `lib/src/page.dart`. These are *different types* from
the in-SDK ones, which still exist in Flutter 3.47.2 at
`packages/flutter/lib/material.dart`. Confirmed by the analyzer: importing
both libraries unprefixed and naming `ThemeData` gives

```
error - The name 'ThemeData' is defined in the libraries
'package:flutter/src/material/theme_data.dart (via package:flutter/material.dart)'
and 'package:material_ui/src/theme_data.dart (via package:material_ui/material_ui.dart)'
- ambiguous_import
```

**3. Coexistence in one app: yes, with a prefix.** Both libraries can be
imported into the same program; what fails is importing both *unprefixed* into
the same file and using a shared name. `import 'package:flutter/material.dart'
as legacy;` alongside `import 'package:material_ui/material_ui.dart' as
modern;` analyzes clean. The lint the spec plans (no
`package:flutter/material.dart` under `app/lib/features`) keeps this from ever
arising in feature code. Nothing in the gallery was forced to import in-SDK
Material.

**4. go_router.** No bridge needed at all: `go_router` 18.0.1 *depends on*
`material_ui ^1.0.0` and `cupertino_ui ^1.0.0` and has no import of
`package:flutter/material.dart` anywhere in `lib/`. Its
`lib/src/pages/material.dart` imports `package:material_ui/material_ui.dart`,
so the default `MaterialPage` and its transitions are the `material_ui` ones.
Default-builder routes and `context.go()` navigation both worked; the widget
test drives `/` -> `/details` -> `/` and finds the button and the text field on
each page, and asserts `Theme.of(context).colorScheme.primary` on the button's
element equals the app's seeded scheme, so the components take the theme rather
than a fallback.

**5. alchemist.** It does *not* need a `MaterialApp` wrapper, and it does not
need an in-SDK `ThemeData` from us either. alchemist 0.14.0 still imports
`package:flutter/material.dart` throughout `lib/`, but it does not wrap the
widget under test in a `MaterialApp`: its `FlutterGoldenTestWrapper` supplies a
legacy `Theme` (falling back to `ThemeData.fallback()`), a localizations
wrapper and a `Navigator`. A `material_ui` `ElevatedButton` rendered inside a
`GoldenTestScenario` with no wrapper at all built and painted; wrapping the
button in a `material_ui` `Theme` is what gives it our colors, and the light
and dark scenarios came out visibly different. No `flutter_test_config.dart`
and no `AlchemistConfig` were needed. Both `--update-goldens` and the plain
verification run passed, producing `test/goldens/macos/` and `test/goldens/ci/`
PNGs.

Two alchemist notes for Phase 2: it prints `package:alchemist has
'uses-material-design: true' set but the primary pubspec contains
'uses-material-design: false'` — set `uses-material-design: true` in
`packages/spectra_ui/pubspec.yaml` when real goldens land, or Material icons
will not render. And it tags its tests `golden`, which wants a `dart_test.yaml`
entry to silence the warning.

**Evidence:** `flutter build macos --debug` in the example succeeded
(`✓ Built build/macos/Build/Products/Debug/spectra_ui_gallery.app`) and the
built binary ran for 8s without exiting, logging the Impeller backend and a
Dart VM service URL. Navigation evidence is the widget test, not a driven
window. Root `dart analyze --fatal-infos .`, `dart format
--set-exit-if-changed .` and `dart run tool/dep_lint.dart` are all clean.

**Verdict: build `spectra_ui` on `material_ui` 1.1.1.** It is the flutter.dev
extraction, it is a drop-in for the in-SDK library, go_router is already
material_ui-native, and alchemist goldens work against material_ui widgets. No
fallback to in-SDK Material 3 is needed and spec section 6's choice stands.

One correction to spec section 6: the planned bridge file that derives an
in-SDK `ThemeData` "for dependencies that need one (go_router page
transitions, alchemist)" is not needed — neither dependency needs one, for the
reasons above. Do not write it speculatively. If some future dependency does
need one, `material_ui` already ships `MaterialUiCompatibilityBridge`, which
maps a modern `ThemeData` to a legacy one and overrides legacy localizations;
note it is annotated `@Deprecated` on arrival, since it exists only for the
migration window. Section 6 has been amended to say this.

Kept in the tree: the gallery example is now the two-route `material_ui` +
`go_router` shell that Phase 2 grows into the component gallery. `alchemist`
stays a dev dependency of `spectra_ui` for Phase 2's real goldens.
