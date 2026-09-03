import 'dart:ui';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/routing/app_sections.dart';
import 'package:spectra/core/routing/routes.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

void main() {
  test('there are five top-level sections, in spec 7.2 order', () {
    expect(appSections.map((s) => s.path).toList(), <String>[
      AppRoutes.device,
      AppRoutes.slots,
      AppRoutes.cards,
      AppRoutes.tools,
      AppRoutes.settings,
    ]);
  });

  testWidgetsApp('the app opens on the connect screen with no session', (
    tester,
  ) async {
    await pumpTestApp(tester);
    await tester.pump();
    expect(find.text('Connect a device'), findsOneWidget);
    expect(find.byType(SpectraAppShell), findsNothing);
  });

  testWidgetsApp('connecting to the emulated device shows the shell', (
    tester,
  ) async {
    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await tester.pump();

    await connectToEmulator(tester);

    expect(find.byType(SpectraAppShell), findsOneWidget);
    expect(find.text('Device'), findsWidgets);
  });

  testWidgetsApp(
    'a live session dropping redirects the shell back to /connect',
    (tester) async {
      // Proves `RouterRefresh`/`redirectFor` (spec 7.2) actually fire on a
      // real, unexpected disconnect, not just on the connect/disconnect
      // buttons the other tests already exercise.
      late FakeDevice device;
      await pumpTestApp(tester, transport: (_) => device = FakeDevice());
      await tester.pump();
      await connectToEmulator(tester);

      expect(find.byType(SpectraAppShell), findsOneWidget);

      await device.simulateLinkLoss();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(SpectraAppShell), findsNothing);
      expect(find.text('Connect a device'), findsOneWidget);
    },
  );

  testWidgetsApp('the shell switches tabs without leaving the shell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await tester.pump();
    await connectToEmulator(tester);

    await tester.tap(find.text('Slots').last);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(SpectraAppShell), findsOneWidget);
    expect(find.byType(SpectraSlotTile), findsNWidgets(8));
  });
}
