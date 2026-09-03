import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/app.dart';
import 'package:spectra/core/discovery/scanners.dart';
import 'package:spectra/core/session/sessions.dart';
import 'package:spectra/data/database/database_providers.dart';
import 'package:spectra/data/database/spectra_database.dart';
import 'package:spectra_ui/spectra_ui.dart';

/// The Phase 5 gate on a real engine: edit and save a slot in emulator
/// mode. No hardware is touched, and none is needed.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('edit and save a slot on the emulator', (tester) async {
    final db = SpectraDatabase.memory();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          databaseProvider.overrideWithValue(db),
          scannersProvider.overrideWithValue(<DeviceScanner>[FakeScanner()]),
          transportFactoryProvider.overrideWithValue((_) => FakeDevice()),
          sessionOptionsProvider.overrideWithValue(
            const SessionOptions(batteryDelay: Duration.zero),
          ),
        ],
        child: const SpectraRoot(),
      ),
    );
    await tester.pump();

    Future<void> settle([int frames = 20]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

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
