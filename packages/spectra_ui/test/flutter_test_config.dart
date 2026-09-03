import 'dart:async';
import 'dart:io' show Platform;

import 'package:alchemist/alchemist.dart';
import 'package:google_fonts/google_fonts.dart';

/// Runs every test in this package under one Alchemist configuration.
///
/// CI goldens obscure text glyphs, so they verify layout, colour and shape,
/// not typography (typography is unit-tested through the tokens). CI goldens
/// (`test/components/goldens/ci/`) are the only ones committed, and they are
/// generated on Ubuntu by `.github/workflows/goldens.yml` — the same
/// platform the `check` job compares them on — so no `diffThreshold` is set
/// and any pixel difference fails. Non-text anti-aliasing (borders, rounded
/// corners, icons) does differ by a fraction of a percent between hosts, so
/// `flutter test` on a developer's macOS machine may report golden diffs
/// that CI does not; see `README.md`. Platform goldens are opt-in via
/// `SPECTRA_PLATFORM_GOLDENS=true` for local eyeballing only, and their
/// directories are git-ignored.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  final bool platformGoldens =
      Platform.environment['SPECTRA_PLATFORM_GOLDENS'] == 'true';
  return AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      ciGoldensConfig: const CiGoldensConfig(enabled: true),
      platformGoldensConfig: PlatformGoldensConfig(enabled: platformGoldens),
    ),
    run: testMain,
  );
}
