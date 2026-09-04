import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import 'support.dart';

/// The Phase 5 gate on a real engine: edit and save a slot in emulator
/// mode. No hardware is touched, and none is needed.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('edit and save a slot on the emulator', (tester) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await tester.pump();

    Future<void> settle([int frames = 20]) => pumpFrames(tester, count: frames);

    await tester.tap(find.text(FakeScanner.emulatedUltra.name));
    await settle(30);
    expect(find.byType(SpectraAppShell), findsOneWidget);

    await tester.tap(find.text('Slots').last);
    await settle();
    expect(find.byType(SpectraSlotTile), findsNWidgets(8));

    await tester.tap(find.byType(SpectraSlotTile).at(2));
    await settle();

    await tester.enterText(find.byType(SpectraTextField).first, 'Front door');
    await tester.pump();
    await tester.tap(find.text('Save name').first);
    await settle();

    await tester.tap(find.text('Make active'));
    await settle();

    await tester.tap(find.byType(BackButton));
    await settle();

    final SpectraSlotTile third = tester.widget<SpectraSlotTile>(
      find.byType(SpectraSlotTile).at(2),
    );
    expect(third.nickname, 'Front door');
    expect(third.active, isTrue);
  });
}
