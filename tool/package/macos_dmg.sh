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
#   RUNNER_TEMP           required when MACOS_CERT_P12/MACOS_CERT_PASSWORD are
#                         set: a writable scratch dir for the throwaway
#                         signing keychain and the decoded .p12
set -euo pipefail
cd "$(dirname "$0")/../.."

APP_PATH="${1:?usage: macos_dmg.sh <app-path> <output-dmg>}"
OUT_DMG="${2:?usage: macos_dmg.sh <app-path> <output-dmg>}"
ENTITLEMENTS="app/macos/Runner/Release.entitlements"

mkdir -p "$(dirname "$OUT_DMG")"

# Clean up the throwaway signing keychain on any exit, so a failure partway
# through never leaves it lying around or stuck in the search list. Safe
# when no keychain was ever created (KEYCHAIN stays unset).
KEYCHAIN=""
PREVIOUS_KEYCHAINS=""
_cleanup_keychain() {
  if [ -n "$KEYCHAIN" ]; then
    security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
    if [ -n "$PREVIOUS_KEYCHAINS" ]; then
      # shellcheck disable=SC2086
      security list-keychains -d user -s $PREVIOUS_KEYCHAINS
    fi
  fi
}
trap _cleanup_keychain EXIT

# 1. Import the certificate into a throwaway keychain, if we were given one.
if [ -n "${MACOS_CERT_P12:-}" ] && [ -n "${MACOS_CERT_PASSWORD:-}" ]; then
  PREVIOUS_KEYCHAINS="$(security list-keychains -d user | tr -d '" ' | tr '\n' ' ')"
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
  # shellcheck disable=SC2086
  security list-keychains -d user -s "$KEYCHAIN" $PREVIOUS_KEYCHAINS
  rm -f "$RUNNER_TEMP/cert.p12"
  echo "macos_dmg: imported the signing certificate"
fi

# 2. Sign. No identity means an ad-hoc signature: the app still launches
#    locally (after the Gatekeeper prompt) and CI still yields an artifact.
#    When neither signing nor notarization is configured, print exactly one
#    combined notice instead of two separate ones about the same absence.
HAS_IDENTITY=false
[ -n "${MACOS_SIGN_IDENTITY:-}" ] && HAS_IDENTITY=true
HAS_NOTARY=false
if [ -n "${MACOS_NOTARY_APPLE_ID:-}" ] && [ -n "${MACOS_NOTARY_TEAM_ID:-}" ] \
  && [ -n "${MACOS_NOTARY_PASSWORD:-}" ]; then
  HAS_NOTARY=true
fi

if [ "$HAS_IDENTITY" = false ] && [ "$HAS_NOTARY" = false ]; then
  echo "macos_dmg: no signing identity and no notary credentials — ad-hoc signed, not notarized"
fi

if [ "$HAS_IDENTITY" = true ]; then
  echo "macos_dmg: signing with a Developer ID identity"
  codesign --force --deep --timestamp --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign "$MACOS_SIGN_IDENTITY" "$APP_PATH"
else
  if [ "$HAS_NOTARY" = true ]; then
    echo "macos_dmg: no MACOS_SIGN_IDENTITY — ad-hoc signing"
  fi
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
if [ "$HAS_NOTARY" = true ]; then
  echo "macos_dmg: submitting to notarytool"
  xcrun notarytool submit "$OUT_DMG" \
    --apple-id "$MACOS_NOTARY_APPLE_ID" \
    --team-id "$MACOS_NOTARY_TEAM_ID" \
    --password "$MACOS_NOTARY_PASSWORD" \
    --wait
  xcrun stapler staple "$OUT_DMG"
  echo "macos_dmg: notarized and stapled"
else
  if [ "$HAS_IDENTITY" = true ]; then
    echo "macos_dmg: notary credentials absent — skipping notarization"
  fi
fi

echo "macos_dmg: wrote $OUT_DMG"
