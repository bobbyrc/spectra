import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:spectra_ui/spectra_ui.dart';

import 'support.dart';

/// The Phase 9 gate on a real engine: edit a key list and change a device
/// setting in emulator mode. No hardware is touched, and none is needed.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('edit a dictionary and a device setting on the emulator', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await tester.pump();

    Future<void> settle([int frames = 20]) => pumpFrames(tester, count: frames);

    await tester.tap(find.text(FakeScanner.emulatedUltra.name));
    await settle(30);
    expect(find.byType(SpectraAppShell), findsOneWidget);

    await tester.tap(find.text('Tools').last);
    await settle();
    await tester.tap(find.text('Key dictionaries'));
    await settle();

    await tester.tap(find.text('New list'));
    await settle();
    await tester.enterText(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(SpectraTextField),
      ),
      'Hotel',
    );
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Save'),
      ),
    );
    await settle(30);
    expect(find.text('Hotel'), findsOneWidget);

    await tester.tap(find.text('Settings').last);
    await settle();
    await tester.tap(find.text('Start-up animation'));
    await settle();
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('None'),
      ),
    );
    await settle(30);
    await tester.ensureVisible(find.text('Save to device'));
    await settle();
    await tester.tap(find.text('Save to device'));
    await settle(30);

    expect(find.text('None'), findsOneWidget);
  });
}
