# spectra_ui

Spectra's design system: colour, type, spacing and motion tokens, the
`material_ui` theme built from them, and the core components every feature
screen composes. The gallery in `example/` renders one page per component.

## Conventions

- Import `package:material_ui/material_ui.dart` or
  `package:flutter/widgets.dart` — never `package:flutter/material.dart`. The
  two libraries define the same names, so importing both does not compile.
- One public type per file, roughly 300 lines maximum.
- User-facing copy in `lib/src/components/` comes from
  `SpectraUiLocalizations`; `dart run tool/dep_lint.dart` fails on a bare
  string literal there. Mark a genuinely non-user-facing string with a
  `// l10n-exempt` comment on the same line.
- Everything tappable goes through `SpectraTappable`, which supplies the
  focus ring, Enter/Space activation and the semantics tap action.

## Goldens

Golden tests use `alchemist`. Only the **CI goldens** in
`test/components/goldens/ci/` are committed, and they are **generated on
Linux**, because that is the platform the CI `check` job compares them on
(spec 6.3: one golden platform). Platform goldens are opt-in for local
eyeballing with `SPECTRA_PLATFORM_GOLDENS=true` and are git-ignored.

A consequence: `flutter test` **on macOS may report golden diffs** even when
nothing is wrong — macOS and Linux anti-alias borders, corners and icons
slightly differently. The CI run is authoritative. Never commit goldens
regenerated on a developer machine.

To refresh the committed goldens after a visual change:

```sh
melos run goldens:update-ci    # prints the exact commands
```

which is:

```sh
gh workflow run goldens.yml --ref <branch>
gh run list --workflow goldens.yml --branch <branch> --limit 1
gh run download <run-id> -n goldens-ci -D /tmp/goldens-ci
cp /tmp/goldens-ci/*.png packages/spectra_ui/test/components/goldens/ci/
```

Then commit the PNGs and let the `check` job verify them.
