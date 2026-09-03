import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

void main() {
  testWidgets('shows the fake device model, version and disconnect', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);

    expect(find.textContaining('Ultra'), findsWidgets);
    expect(find.textContaining('2.2'), findsWidgets);
    expect(find.text('Disconnect'), findsOneWidget);

    await settleApp(tester);
  });

  testWidgets('reveals the chip id behind the disclosure', (tester) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);

    expect(find.textContaining('0102030405060708'), findsNothing);
    await tester.tap(find.text('Details'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('0102030405060708'), findsWidgets);

    await settleApp(tester);
  });

  testWidgets('disconnecting returns to the connect screen', (tester) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);

    await tester.tap(find.text('Disconnect'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Connect a device'), findsOneWidget);

    await settleApp(tester);
  });

  testWidgets('a limited session offers only the update action', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        transport: (_) =>
            FakeDevice(firmware: FakeFirmware(FakeFirmwareConfig.legacy01())),
      ),
    );
    await connectToEmulator(tester);

    expect(find.text('Update firmware'), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);
    expect(find.textContaining('must be updated'), findsOneWidget);

    await settleApp(tester);
  });
}
