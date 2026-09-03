/// What an integration test runs: the same app, with the same root
/// overrides, as the widget tests.
///
/// An integration test differs from a widget test in the engine it runs on,
/// not in the app it drives — so the app under test is defined once, in
/// `test/support/app_harness.dart`, and re-exported here rather than
/// rebuilt as a second override list that drifts from the first (the two
/// had already drifted: the harness zeroes the wakelock gateway and the
/// reconnect timeout, the integration copies did not).
library;

export '../test/support/app_harness.dart'
    show appOverrides, pumpFrames, testApp;
