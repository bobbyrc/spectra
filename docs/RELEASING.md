# Releasing Spectra

Spec 10. Everything here is driven by `.github/workflows/release.yml`; this
file is the human half.

## The shape of a release

1. `app/pubspec.yaml` holds the version, e.g. `version: 1.0.0+1`. The `+N`
   is the build number every platform gets.
2. `CHANGELOG.md` holds one entry per released version, Keep a Changelog
   style. A release candidate does **not** get its own entry: `v1.0.0-rc.1`
   is validated against the `[1.0.0-rc.1]` entry that is currently at the
   top of the file (the header keeps the RC suffix; a plain `1.0.0` final
   release still validates against that same entry — `check_release.dart`
   compares the tag's build name, RC suffix included, against the newest
   entry's version). When it is time to cut the next release, add a new
   `## [x.y.z] - <date>` entry above it (or edit the existing one's date if
   it drifted) before tagging; the `[Unreleased]` heading above the entries
   stays as the landing spot for change notes between releases.
3. The git tag decides what is built. `v1.0.0-rc.1` publishes a
   pre-release; `v1.0.0` publishes a final release. Apple targets get the
   version core only (`1.0.0`), because `CFBundleShortVersionString` must be
   three dotted numbers; the RC identity survives in the tag and in every
   artifact file name.
4. `dart run tool/check_release.dart --tag v1.0.0-rc.1` (or
   `RELEASE_TAG=v1.0.0-rc.1 melos run check:release`, which defaults
   `RELEASE_TAG` to `v1.0.0-rc.1` if unset) proves 1-3 agree before anything
   is tagged. It also prints, per package, whether its LICENSE is chosen,
   a TODO, or missing — a warning only, never a failure (see "Decisions
   still open" below).

## Running a release

Rehearse first, without a tag — this dispatches `.github/workflows/release.yml`
with a `tag` input and runs the full pipeline against whatever is on the
branch, ending in a draft pre-release:

```bash
gh workflow run release.yml --ref <branch> -f tag=v1.0.0-rc.1
```

Then, for the real thing:

```bash
git tag -a v1.0.0-rc.1 -m "Spectra 1.0.0-rc.1"
git push origin v1.0.0-rc.1
```

A tag push matching `v*` triggers the same workflow directly; the
`workflow_dispatch` input above is only for rehearsing before the tag
exists. Never tag `v1.0.0` at this stage — the RC is `v1.0.0-rc.1`, and
`v1.0.0` itself is a later, separate decision (see "Cutting v1.0.0" below).

The workflow's `preflight` job runs `check_release.dart` against the tag,
then a `ci` job calls `ci.yml` (format, analyze, dependency lint, codegen
freshness, every test, the macOS integration run in emulator mode, and the
debug build matrix), then five platform jobs build and package in parallel,
then `publish` attaches everything to a **draft** release (`draft: true`,
`prerelease` set from whether the tag has an RC suffix). `publish` builds
the release body from `tool/print_changelog_entry.dart`, which prints the
newest released `CHANGELOG.md` entry's body verbatim — that is why step 2
above (adding the entry before tagging) matters: an RC without a matching
entry fails `check_release.dart` in `preflight` before any building starts.
Review the draft on the repo's Releases page and publish it by hand — the
workflow never publishes automatically.

**Do not push to the branch while a dispatched release run is in flight.**
`ci.yml`'s concurrency group is `ci-${{ github.ref }}` — per ref, not
per-run — so a plain push to the same branch cancels the in-progress
release's `ci` job (`release.yml`'s own group, `release-<tag>`, does not
protect it, because the `ci` job runs `ci.yml` as a separate workflow_call
sharing `ci.yml`'s group and cancellation policy). A tag push is a
different ref from any branch, so tagging itself is unaffected; the risk is
pushing commits to the branch mid-run, or dispatching a second release run
for the same branch before the first's `ci` job finishes.

## Artifacts

The workflow's five platform jobs (`macos`, `windows`, `linux`, `android`,
`ios`) each package with a script under `tool/package/` and upload to the
draft release via `publish`.

| Platform | Script | File(s) | Signed? |
|---|---|---|---|
| macOS | `tool/package/macos_dmg.sh <Runner.app> <out.dmg>` | `spectra-<version>-macos.dmg` | Developer ID + notarized when `MACOS_CERT_P12`/`MACOS_SIGN_IDENTITY`/notary secrets exist, ad-hoc signed otherwise |
| Windows | `tool/package/windows_installer.ps1 -BuildDir <dir> -Version <v> -OutDir <dir>` | `spectra-<version>-windows-setup.exe`, `spectra-<version>-windows.zip` | Authenticode when `WINDOWS_CERT_PFX` exists, unsigned otherwise |
| Linux | `tool/package/linux_appimage.sh <bundle-dir> <version> <out-dir>` | `spectra-<version>-linux-x86_64.AppImage`, `spectra-<version>-linux-x64.tar.gz` | Unsigned by design — no Linux signing story in spec 10 |
| Android | Gradle (signing config keyed on the `ANDROID_*` env) | `spectra-<version>-android[-unsigned].apk`, `.aab` | Release keystore when `ANDROID_KEYSTORE_BASE64` exists, debug key (and the `-unsigned` suffix) otherwise |
| iOS | `tool/package/ios_ipa.sh <Runner.app> <out.ipa>` | `spectra-<version>-ios-unsigned.ipa` | Never — see "iOS and TestFlight" below |

The Windows job installs Inno Setup itself (`choco install innosetup`)
before calling `windows_installer.ps1`, because `windows-latest` no longer
ships it. `windows_installer.ps1`'s argument convention (named
`-BuildDir`/`-Version`/`-OutDir`) deliberately does not match
`macos_dmg.sh`'s positional `<app-path> <output-dmg>` — each script keeps
the convention that fits its platform.

The Linux job stages the Flutter bundle under a directory named
`spectra-<version>-linux-x64` before calling `linux_appimage.sh`, because
that script's tarball takes its top-level directory name from the bundle
directory's own basename.

## Secrets

Set these in the repository's Actions secrets. Every one of the twelve
below is optional: when a secret is missing, the corresponding artifact is
still built — unsigned or ad-hoc signed — and the job's log says so. That is
deliberate, so a fork and a secretless rehearsal produce the same file
list. Listed exactly as `release.yml` reads them, job by job:

**macOS job** (`tool/package/macos_dmg.sh`)

- `MACOS_CERT_P12` — base64 of a Developer ID Application `.p12`. Absent:
  the app is ad-hoc signed (`codesign --sign -`) instead of with a Developer
  ID identity.
- `MACOS_CERT_PASSWORD` — that file's password. Absent: same as above.
- `MACOS_SIGN_IDENTITY` — e.g. `Developer ID Application: Name (TEAMID)`.
  Absent: ad-hoc signing, as above.
- `MACOS_NOTARY_APPLE_ID` — the Apple ID used for `notarytool`. Absent (or
  any of the next two absent): notarization is skipped entirely; the dmg is
  still produced, signed or ad-hoc.
- `MACOS_NOTARY_TEAM_ID` — the notary team id. Absent: as above.
- `MACOS_NOTARY_PASSWORD` — an app-specific password for `notarytool`.
  Absent: as above. All three notary secrets are required together or the
  dmg simply is not notarized.

**Windows job** (`tool/package/windows_installer.ps1`)

- `WINDOWS_CERT_PFX` — base64 of a code-signing `.pfx`. Absent: both the
  zip's `spectra.exe` and the installer are shipped unsigned, and the log
  says so.
- `WINDOWS_CERT_PASSWORD` — that file's password. Absent: as above.

**Android job** (Gradle, via `app/android/key.properties`-equivalent env)

- `ANDROID_KEYSTORE_BASE64` — base64 of the release `.jks`/`.keystore`.
  Absent: Gradle falls back to the debug key and the workflow names the apk
  and aab `*-android-unsigned.*` instead of `*-android.*`.
- `ANDROID_KEYSTORE_PASSWORD` — the keystore password. Absent: as above.
- `ANDROID_KEY_ALIAS` — the key alias inside the keystore. Absent: as
  above.
- `ANDROID_KEY_PASSWORD` — that key's password. Absent: as above.

For a local Android release build, copy
`app/android/key.properties.example` to `app/android/key.properties` and
fill in the same four values (`storeFile`, `storePassword`, `keyAlias`,
`keyPassword`). That path and `*.jks`/`*.keystore` are git-ignored; never
commit a keystore.

The `ios` job reads no secret at all — see below.

## iOS and TestFlight

The repo carries no Apple Developer team id, so `flutter build ios --release
--no-codesign` followed by `tool/package/ios_ipa.sh` produces an
**unsigned** `.ipa`: useful for inspection (`unzip` it and confirm
`Payload/Runner.app` exists) and for re-signing, not installable as-is and
not uploadable to TestFlight in that state. Spec 10 puts the mobile stores
after v1. When a team is available, the TestFlight route is: add the team
to `app/ios/Runner.xcodeproj`, add an `ExportOptions.plist` with
`method: app-store-connect` and that team id, then replace the `ios` job's
`flutter build`/package steps with
`flutter build ipa --export-options-plist=<that file>` and an
`xcrun altool`/`notarytool`-style upload to App Store Connect. Nothing else
in the workflow changes.

## Decisions still open (the user's, not an agent's)

- **LICENSE.** `packages/spectra_ui/LICENSE` and
  `packages/chameleon_flutter/LICENSE` still read
  `TODO: Add your license here.`; `packages/chameleon` and `app` have no
  LICENSE file. `tool/check_release.dart` prints this per-package as a
  warning and never fails the release on it, so an RC can be cut before the
  choice is made — but do not publish a public final `v1.0.0` without
  choosing one. This document does not choose a license; that decision
  belongs to the user.
- **App icon and launch assets** (the app icon is unbranded). Every platform still ships the
  `flutter create` defaults: `app/macos/Runner/Assets.xcassets/AppIcon.appiconset/`,
  `app/android/app/src/main/res/mipmap-*/ic_launcher.png`,
  `app/ios/Runner/Assets.xcassets/AppIcon.appiconset/`, and no Linux icon at
  all — the AppImage borrows the macOS 256px asset
  (`tool/package/linux_appimage.sh`) until real branding lands. Real
  branding is a design task, not a release-engineering one.
- **The vendored `usb_serial` override.** Root `pubspec.yaml`'s
  `dependency_overrides` points `usb_serial` 0.5.2 at the patched copy in
  `third_party/usb_serial` (see `docs/research/DECISIONS.md`, Phase 3, for
  why). Re-check for a fixed upstream release before shipping and drop the
  override then; this is a release-blocking item to re-check, not
  something already resolved.

## Cutting v1.0.0

`v1.0.0` is not tagged until the user has run the H3 section of
`docs/hardware-checklist.md` against the `v1.0.0-rc.1` artifacts and
reported every item passing. Then:

1. Record the H3 results in `docs/hardware-checklist.md`.
2. Flip `dfuOverBleEnabled` to default-on only if the H2 and H3 BLE DFU
   items passed.
3. Add (or update) the `CHANGELOG.md` entry for `1.0.0` — move its date if
   it has drifted from the actual release date.
4. `dart run tool/check_release.dart --tag v1.0.0` (or
   `RELEASE_TAG=v1.0.0 melos run check:release`) to confirm the tag,
   `app/pubspec.yaml` and `CHANGELOG.md` agree.
5. `git tag -a v1.0.0 -m "Spectra 1.0.0" && git push origin v1.0.0`.
6. Publish the draft release the workflow creates.
