#!/usr/bin/env bash
# Regenerates code in every package that uses build_runner and fails if
# the committed generated files differ.
set -euo pipefail
cd "$(dirname "$0")/.."
# Locally, commands go through mise. On CI mise is absent: set MISE_X="".
MISE_X="${MISE_X-mise x --}"
for pkg in packages/chameleon packages/chameleon_flutter packages/spectra_ui app; do
  if grep -q "build_runner" "$pkg/pubspec.yaml" 2>/dev/null; then
    echo "codegen: $pkg"
    (cd "$pkg" && $MISE_X dart run build_runner build --delete-conflicting-outputs >/dev/null)
  fi
done
if ! git diff --quiet -- '*.g.dart' '*.freezed.dart' '*.drift.dart'; then
  echo "codegen: committed generated files are stale:" >&2
  git --no-pager diff --stat -- '*.g.dart' '*.freezed.dart' '*.drift.dart' >&2
  exit 1
fi
echo "codegen: ok"
