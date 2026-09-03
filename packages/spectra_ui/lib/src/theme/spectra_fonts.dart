import 'package:google_fonts/google_fonts.dart';

/// Disables `google_fonts`' runtime network fetch.
///
/// Tests (in this package and in any consumer, such as the gallery) must
/// call this before pumping any widget that resolves Spectra typography, so
/// a test run never depends on network access or a cached font file. Kept
/// as a public function here, rather than inline `GoogleFonts` calls at
/// each call site, so a consumer that may not import `google_fonts`
/// directly (see the dependency allowlist) still has a way to disable it.
void disableRuntimeFontFetching() {
  GoogleFonts.config.allowRuntimeFetching = false;
}
