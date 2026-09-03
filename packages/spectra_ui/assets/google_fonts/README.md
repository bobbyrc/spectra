# Bundled fonts

google_fonts fetches font files over the network by default. That makes
tests non-deterministic and breaks offline builds, so the exact weights the
design system uses are vendored here and resolved locally
(`GoogleFonts.config.allowRuntimeFetching = false` in
`test/flutter_test_config.dart`). google_fonts matches bundled assets to a
requested weight by filename, so the names on disk must stay exactly as
below.

## Files

- `Inter-Regular.ttf`, `Inter-Medium.ttf`, `Inter-SemiBold.ttf`,
  `Inter-Bold.ttf` — Inter 4.1, from the `extras/ttf/` static build in the
  [Inter 4.1 release](https://github.com/rsms/inter/releases/tag/v4.1)
  (`https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip`).
  The `static/` directory does not exist for Inter under
  `https://github.com/google/fonts/tree/main/ofl/inter` (that repo ships
  only the variable font), so these came from the upstream Inter release
  instead, per the project's font-sourcing ruling.
- `JetBrainsMono-Regular.ttf` — JetBrains Mono 2.304, from `fonts/ttf/` in the
  [JetBrainsMono v2.304 release](https://github.com/JetBrains/JetBrainsMono/releases/tag/v2.304)
  (`https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip`).
  Same reasoning: `https://github.com/google/fonts/tree/main/ofl/jetbrainsmono`
  only ships the variable font, not a `static/` directory.

## License

Both Inter and JetBrains Mono are licensed under the SIL Open Font License,
Version 1.1. The upstream license text is copied alongside the fonts:

- `Inter-OFL.txt` (from `LICENSE.txt` in the Inter 4.1 release)
- `JetBrainsMono-OFL.txt` (from `OFL.txt` in the JetBrainsMono v2.304 release)
