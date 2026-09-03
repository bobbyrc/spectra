import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_harness.dart';

void main() {
  testWidgets('the placeholder names the phase and the BLE notice', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openUpdate(tester);

    expect(find.textContaining('Phase 8'), findsOneWidget);
    expect(find.textContaining('pending hardware validation'), findsOneWidget);

    await settleApp(tester);
  });

  testWidgets('shows a back button that returns to Tools', (tester) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);
    await openUpdate(tester);

    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(
      find.text('Everything sent to and received from the device.'),
      findsOneWidget,
    );

    await settleApp(tester);
  });

  testWidgets('recovering from the connect screen carries the transport id', (
    tester,
  ) async {
    await tester.pumpWidget(testAppWithBootloader());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Recover'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.textContaining('fake-bootloader'), findsOneWidget);

    await settleApp(tester);
  });
}
