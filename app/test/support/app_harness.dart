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
