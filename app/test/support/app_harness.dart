import 'package:chameleon/chameleon.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/app.dart';
import 'package:spectra/core/discovery/scanners.dart';
import 'package:spectra/core/session/sessions.dart';
import 'package:spectra/data/database/database_providers.dart';
import 'package:spectra/data/database/spectra_database.dart';

/// The overrides every widget test uses. Spec 7.1: overrides live at the app
/// root only — this is that root. The database is real Drift, in memory, so
/// the real queries run; the transport is a FakeDevice, so the real
/// DeviceSession runs (spec 8.6).
List<Override> appOverrides({Transport Function(DiscoveredDevice)? transport}) {
  final db = SpectraDatabase.memory();
  addTearDown(db.close);
  return <Override>[
    databaseProvider.overrideWithValue(db),
    scannersProvider.overrideWithValue(<DeviceScanner>[FakeScanner()]),
    if (transport != null)
      transportFactoryProvider.overrideWithValue(transport),
  ];
}

Widget testApp({Transport Function(DiscoveredDevice)? transport}) =>
    ProviderScope(
      overrides: appOverrides(transport: transport),
      child: const SpectraRoot(),
    );

/// Pumps [testApp]. Every test that calls this must end with `await
/// settleApp(tester);` as its last statement — see [settleApp] for why an
/// `addTearDown` cannot do this instead.
Future<void> pumpTestApp(
  WidgetTester tester, {
  Transport Function(DiscoveredDevice)? transport,
}) => tester.pumpWidget(testApp(transport: transport));

/// Taps the emulated device on the connect screen and waits for the shell.
/// The fake answers immediately, so a bounded pump loop is enough and
/// `pumpAndSettle` is avoided (the shell has running animations).
///
/// `DeviceSession`'s handshake keeps loading in the background after the
/// session is ready — including a battery read timed out to
/// `DeviceSession.batteryDelay` (5s by default; spec 8.6 does not plumb an
/// override through `transportFactoryProvider`). The loop pumps past that
/// so the underlying timer fires during the test instead of tripping
/// flutter_test's "pending timer" invariant after the widget tree is torn
/// down.
Future<void> connectToEmulator(WidgetTester tester) async {
  await tester.pump();
  await tester.tap(find.text(FakeScanner.emulatedUltra.name));
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps past one connect attempt — success or failure — that does not go
/// on to the shell (so [connectToEmulator]'s much longer loop, which also
/// pumps out the post-ready background load, would be overkill). A tap that
/// starts a failing `connect()` needs more than a couple of duration-less
/// `pump()`s: `FakeDevice.open()`'s `Future.delayed(latency)` (latency is
/// `Duration.zero` by default, but still a real timer tick) and
/// `DeviceSession.close()`'s cleanup both need an elapsed duration to
/// resolve, not just a flushed microtask queue.
Future<void> awaitConnectAttempt(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// A scanner that reports [devices] once. Lets a screen test set the scene
/// without a transport.
final class StaticScanner implements DeviceScanner {
  const StaticScanner(this.devices);
  final List<DiscoveredDevice> devices;
  @override
  TransportKind get kind => TransportKind.fake;
  @override
  Stream<List<DiscoveredDevice>> scan() => Stream.value(devices);
}

Widget testAppWithScanner(DeviceScanner scanner) {
  final db = SpectraDatabase.memory();
  addTearDown(db.close);
  return ProviderScope(
    overrides: <Override>[
      databaseProvider.overrideWithValue(db),
      scannersProvider.overrideWithValue(<DeviceScanner>[scanner]),
    ],
    child: const SpectraRoot(),
  );
}

Widget testAppWithNoDevices() =>
    testAppWithScanner(const StaticScanner(<DiscoveredDevice>[]));

Widget testAppWithBootloader() => testAppWithScanner(
  const StaticScanner(<DiscoveredDevice>[FakeScanner.emulatedBootloader]),
);

/// Pumps [testAppWithScanner]; see [pumpTestApp] — the same `settleApp`
/// obligation applies.
Future<void> pumpTestAppWithScanner(
  WidgetTester tester,
  DeviceScanner scanner,
) => tester.pumpWidget(testAppWithScanner(scanner));

Future<void> pumpTestAppWithNoDevices(WidgetTester tester) =>
    pumpTestAppWithScanner(tester, const StaticScanner(<DiscoveredDevice>[]));

Future<void> pumpTestAppWithBootloader(WidgetTester tester) =>
    pumpTestAppWithScanner(
      tester,
      const StaticScanner(<DiscoveredDevice>[FakeScanner.emulatedBootloader]),
    );

/// Taps through to a Tools sub-page. The shell is wide enough in tests that
/// the destination is a rail item.
Future<void> _openTool(WidgetTester tester, String title) async {
  await tester.tap(find.text('Tools').last);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.tap(find.text(title));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> openFrameLog(WidgetTester tester) =>
    _openTool(tester, 'Frame log');
Future<void> openUpdate(WidgetTester tester) =>
    _openTool(tester, 'Firmware update');

/// Unmounts the widget tree and pumps a few explicit-duration frames.
///
/// `ConnectPage` (reachable whenever a test builds the app root: it is the
/// entry route) watches a Drift-backed stream (`knownDevicesProvider`) for
/// as long as it is mounted. `flutter_test`'s own end-of-test cleanup —
/// `_runTestBody`'s `runApp(Container(...))` that unmounts whatever is left,
/// followed by one plain `pump()` — runs *inside* `testWidgets`'s body,
/// before `verifyInvariants` and before any `package:test` `addTearDown`
/// callback gets a chance to run (those run only after the whole `test()`
/// function, `_runTestBody` included, has returned). So an `addTearDown`
/// registered here is always too late: by the time it runs, the pending-timer
/// assertion has already fired. `flutter_test`'s own unmount pass also uses a
/// single duration-less `pump()`, which does not reliably flush a
/// zero-duration `Timer` — the `StreamQueryStore.markAsClosed` timer Drift
/// schedules when the stream's subscription is cancelled needs an explicit
/// duration to fire.
///
/// The fix has to run inside the test body itself, before it returns: unmount
/// the tree early (here, with a placeholder) and pump enough explicit-duration
/// frames to flush what that unmount schedules. Every test that pumps the app
/// root (`pumpTestApp`, `pumpTestAppWithScanner` and friends) must call this
/// as its last statement.
Future<void> settleApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}
