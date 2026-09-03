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

/// Taps [finder] and waits out the resulting async chain on the *real*
/// event loop instead of `pump()`'s fake clock.
///
/// `DeviceSession.close()` — which every failed `connect` runs — closes a
/// clutch of `StateStream`s built on broadcast `StreamController`s that have
/// never had a listener. Under `flutter_test`'s FakeAsync zone that
/// `close()`'s returned Future never completes, however many frames get
/// pumped afterwards (verified directly against `DeviceSession`, with no
/// riverpod or widget tree involved — this is a FakeAsync/broadcast-stream
/// interaction below this app, not something a screen test can route
/// around by pumping longer). It resolves in microseconds under a real
/// event loop, so the tap and the wait run inside [WidgetTester.runAsync]
/// instead; the caller still does its own `pump()` afterwards to let the
/// widget tree catch up with the now-settled provider state.
Future<void> tapAndAwaitReal(WidgetTester tester, Finder finder) async {
  await tester.runAsync(() async {
    await tester.tap(finder);
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  });
}

/// Unmounts the widget tree and pumps a few explicit-duration frames.
///
/// A test that never leaves `/connect` never disposes the Drift-backed
/// `knownDevicesProvider` stream until the widget tree itself is torn down
/// at the very end of the test — which schedules a zero-duration timer
/// (`StreamQueryStore.markAsClosed`) with no further pump to flush it,
/// tripping `flutter_test`'s pending-timer invariant. Unmounting explicitly,
/// with room afterwards to flush what that unmount schedules, avoids it. A
/// parameterless `pump()` does not reliably flush a zero-duration timer;
/// an explicit duration does.
Future<void> settleAfterConnectPage(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}
