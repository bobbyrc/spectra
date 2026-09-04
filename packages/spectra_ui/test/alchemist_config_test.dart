import 'package:alchemist/alchemist.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  // AlchemistConfig.current() must be read here, at declaration time, not
  // inside a test()/testWidgets() body: `flutter test` invokes test bodies
  // through the test runner's own zone, which is not nested inside the zone
  // flutter_test_config.dart establishes via AlchemistConfig.runWithConfig.
  // Reading it eagerly - the same way alchemist's own `goldenTest()` does
  // internally (see golden_test.dart: `final config =
  // AlchemistConfig.current();` at the top of the function, before
  // `testWidgets` is called) - is the only way to observe the config
  // testExecutable sets up.
  final AlchemistConfig config = AlchemistConfig.current();

  test('CI goldens are enabled so committed goldens are platform-neutral', () {
    expect(config.ciGoldensConfig.enabled, isTrue);
  });

  test('CI goldens compare exactly: they are generated on the CI platform', () {
    expect(config.ciGoldensConfig.diffThreshold, 0.0);
  });

  test('platform goldens are off unless explicitly requested', () {
    expect(config.platformGoldensConfig.enabled, isFalse);
  });

  test('google_fonts never reaches the network in tests', () {
    expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
  });
}
