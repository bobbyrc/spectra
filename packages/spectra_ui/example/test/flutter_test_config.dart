import 'dart:async';

import 'package:spectra_ui/spectra_ui.dart';

/// Runs every test in this package with runtime font fetching disabled, so
/// a test run never depends on network access or a cached font file. The
/// gallery may not import `google_fonts` directly (see
/// `tool/dep_lint.dart`'s allowlist), so it goes through the kit's exported
/// `disableRuntimeFontFetching`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  disableRuntimeFontFetching();
  return testMain();
}
