#!/usr/bin/env bash
# Packages the Flutter Linux bundle as an AppImage plus a plain tarball
# (spec 10: "Linux as an AppImage"). Linux artifacts are unsigned; there is
# no Linux signing story in the spec, so there is no secret here.
#
#   tool/package/linux_appimage.sh app/build/linux/x64/release/bundle \
#     1.0.0-rc.1 dist
#
# A Flutter Linux bundle resolves its data/ and lib/ relative to the real
# path of its own executable (/proc/self/exe), not the working directory.
# The AppDir therefore keeps the whole bundle intact side by side at
# usr/lib/spectra/{spectra,data,lib} rather than splitting the binary into
# usr/bin — a split layout builds but cannot launch.
#
# appimagetool is not available on every machine that might run this script
# (notably macOS, used for local iteration). When it is missing from PATH,
# the AppImage step is skipped with a clear notice; the tarball and the
# AppDir are still produced. The real AppImage build happens on
# ubuntu-latest in the release workflow, which installs appimagetool first.
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

# 2. Lay out the AppDir. The whole bundle (binary, data/, lib/) lands
#    intact at usr/lib/spectra so /proc/self/exe-relative asset lookup
#    keeps working; usr/bin/spectra is a symlink for anything that expects
#    a PATH-style launcher.
APPDIR="$(mktemp -d)/Spectra.AppDir"
mkdir -p "$APPDIR/usr/lib/spectra" "$APPDIR/usr/bin" \
  "$APPDIR/usr/share/applications"
cp -r "$BUNDLE/." "$APPDIR/usr/lib/spectra/"
ln -s ../lib/spectra/spectra "$APPDIR/usr/bin/spectra"
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
exec "$HERE/usr/lib/spectra/spectra" "$@"
APPRUN
chmod +x "$APPDIR/AppRun"
echo "linux_appimage: wrote AppDir at $APPDIR"

# 3. Build the AppImage, when appimagetool is available. GitHub runners
#    have no FUSE, hence extract-and-run.
if command -v appimagetool >/dev/null 2>&1; then
  ARCH=x86_64 appimagetool --appimage-extract-and-run "$APPDIR" \
    "$OUT_DIR/spectra-$VERSION-linux-x86_64.AppImage"
  echo "linux_appimage: wrote $OUT_DIR/spectra-$VERSION-linux-x86_64.AppImage"
else
  echo "linux_appimage: appimagetool not found on PATH — skipping the" \
    "AppImage build (tarball and AppDir at $APPDIR were still produced)"
fi
