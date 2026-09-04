import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:spectra_ui/spectra_ui.dart';

import 'support.dart';

/// The Phase 4 gate on a real engine. Emulator mode only: no hardware is
/// touched, and none is needed.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('connect, dashboard, disconnect, reconnect', (tester) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await tester.pump();

    Future<void> connect() async {
      await tester.tap(find.text(FakeScanner.emulatedUltra.name));
      await pumpFrames(tester, count: 30);
    }

    expect(find.text('Connect a device'), findsOneWidget);
    await connect();
    expect(find.byType(SpectraAppShell), findsOneWidget);
    expect(find.textContaining('2.2'), findsWidgets);

    await tester.tap(find.text('Disconnect'));
    await pumpFrames(tester, count: 30);
    expect(find.text('Connect a device'), findsOneWidget);

    await connect();
    expect(find.byType(SpectraAppShell), findsOneWidget);
  });
}
