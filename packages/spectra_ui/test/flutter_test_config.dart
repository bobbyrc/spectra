import 'dart:async';
import 'dart:io' show Platform;

import 'package:alchemist/alchemist.dart';
import 'package:google_fonts/google_fonts.dart';

/// Runs every test in this package under one Alchemist configuration.
///
/// CI goldens obscure text glyphs so they are platform-independent; they
/// verify layout, colour and shape, not typography (typography is
/// unit-tested through the tokens). CI goldens (`test/goldens/ci/`) are the
/// only ones committed, so a golden produced on macOS is byte-identical to
/// one produced on the Ubuntu `check` job. Platform goldens are opt-in via
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
