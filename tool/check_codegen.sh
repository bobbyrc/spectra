#!/usr/bin/env bash
# Regenerates code in every package that uses build_runner and fails if
# the committed generated files differ.
set -euo pipefail
cd "$(dirname "$0")/.."
# Commands use whatever `dart`/`flutter` is on PATH (the AGENTS.md convention
# puts Flutter 3.47.2 first). Set MISE_X="mise x --" to route through mise
# instead; note `mise x` picks up fvm's older Dart on this Mac.
MISE_X="${MISE_X-}"
for pkg in packages/chameleon packages/chameleon_flutter packages/chameleon_flutter/example packages/spectra_ui packages/spectra_ui/example app; do
  if grep -q "build_runner" "$pkg/pubspec.yaml" 2>/dev/null; then
    echo "codegen: $pkg"
    (cd "$pkg" && $MISE_X dart run build_runner build --delete-conflicting-outputs >/dev/null)
  fi
  if [ -f "$pkg/l10n.yaml" ]; then
    echo "l10n: $pkg"
    (cd "$pkg" && $MISE_X flutter gen-l10n >/dev/null)
  fi
done
# Newly generated files are untracked, so a plain `git diff` misses them.
# Stage their intent so untracked-but-generated files count as stale too.
for pat in '*.g.dart' '*.freezed.dart' '*.drift.dart' '*_localizations*.dart'; do
  git add --intent-to-add -- "$pat" 2>/dev/null || true
done
if ! git diff --quiet -- '*.g.dart' '*.freezed.dart' '*.drift.dart' '*_localizations*.dart'; then
  echo "codegen: committed generated files are stale:" >&2
  git --no-pager diff --stat -- '*.g.dart' '*.freezed.dart' '*.drift.dart' '*_localizations*.dart' >&2
  exit 1
fi
echo "codegen: ok"
