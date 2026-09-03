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

  testWidgets('the app opens on the connect screen with no session', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await tester.pump();
    expect(find.text('Connect a device'), findsOneWidget);
    expect(find.byType(SpectraAppShell), findsNothing);
  });

  testWidgets('connecting to the emulated device shows the shell', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await tester.pump();

    await connectToEmulator(tester);

    expect(find.byType(SpectraAppShell), findsOneWidget);
    expect(find.text('Device'), findsWidgets);
  });

  testWidgets('the shell switches tabs without leaving the shell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await tester.pump();
    await connectToEmulator(tester);

    await tester.tap(find.text('Slots').last);
    await tester.pump();
    await tester.pump();

    expect(find.byType(SpectraAppShell), findsOneWidget);
    expect(find.textContaining('Phase 5'), findsOneWidget);
  });
}
