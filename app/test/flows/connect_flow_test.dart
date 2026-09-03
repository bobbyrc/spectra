import 'dart:ui';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
