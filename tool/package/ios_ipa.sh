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
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/Payload"
cp -R "$APP_PATH" "$STAGE/Payload/"
rm -f "$OUT_IPA"
(cd "$STAGE" && zip -r -q -y "$OUT_IPA" Payload)

echo "ios_ipa: wrote $OUT_IPA (unsigned — see docs/RELEASING.md)"
