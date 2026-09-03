import 'dart:ui';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/app.dart';
import 'package:spectra/core/session/sessions.dart';
import 'package:spectra/features/connect/connect.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/app_harness.dart';

/// The roadmap's Phase 4 gate: connect to the emulator, see the dashboard,
/// disconnect, reconnect. `testWidgetsApp` (not plain `testWidgets`) so the
/// app root's stream-backed `ConnectPage` settles cleanly on teardown —
/// see its own doc comment.
void main() {
  testWidgetsApp('connect, dashboard, disconnect, reconnect', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // One fake per connect: a session owns its transport and closes it.
    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await tester.pump();

    expect(find.text('Connect a device'), findsOneWidget);
    expect(find.text('Emulated Chameleon Ultra'), findsOneWidget);

    await connectToEmulator(tester);

    expect(find.byType(SpectraAppShell), findsOneWidget);
    expect(find.textContaining('Chameleon Ultra'), findsWidgets);
    expect(
      find.textContaining('2.2'),
      findsWidgets,
      reason: 'the fake firmware version is on the dashboard',
    );

    await tester.tap(find.text('Disconnect'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Connect a device'), findsOneWidget);

    // The device is remembered now, so the row carries its identity.
    await connectToEmulator(tester);
    expect(find.byType(SpectraAppShell), findsOneWidget);
    expect(find.textContaining('2.2'), findsWidgets);
  });

  testWidgetsApp('a dropped link preselects the device until it reconnects', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // A session owns and closes its transport, so every attempt gets a
    // fresh fake; the latest is the live one the test drops.
    late FakeDevice live;
    await pumpTestApp(
      tester,
      transport: (_) {
        live = FakeDevice();
        return live;
      },
    );
    await tester.pump();
    await connectToEmulator(tester);
    expect(find.byType(SpectraAppShell), findsOneWidget);

    // The link dies on its own: the router drops back to the connect
    // screen (spec 7.2) and the row that just went away is preselected
    // (spec 7.4).
    await live.simulateLinkLoss();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Connect a device'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byType(ConnectRowTile).first)
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );

    // Reconnecting is the end of that story: nothing is left to preselect.
    // Asserted on the registry rather than the tile, because a successful
    // connect leaves the connect screen for the shell — there is no row
    // left on screen to look at.
    await connectToEmulator(tester);
    expect(find.byType(SpectraAppShell), findsOneWidget);
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(SpectraRoot)),
    );
    expect(container.read(sessionsProvider).lastDisconnected, isNull);
  });
}
