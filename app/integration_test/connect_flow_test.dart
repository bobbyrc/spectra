import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:spectra/app.dart';
import 'package:spectra/core/discovery/scanners.dart';
import 'package:spectra/core/session/sessions.dart';
import 'package:spectra/data/database/database_providers.dart';
import 'package:spectra/data/database/spectra_database.dart';
import 'package:spectra_ui/spectra_ui.dart';

/// The Phase 4 gate on a real engine. Emulator mode only: no hardware is
/// touched, and none is needed.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('connect, dashboard, disconnect, reconnect', (tester) async {
    final db = SpectraDatabase.memory();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          databaseProvider.overrideWithValue(db),
          scannersProvider.overrideWithValue(<DeviceScanner>[FakeScanner()]),
          transportFactoryProvider.overrideWithValue((_) => FakeDevice()),
          // Real timers on a real engine: zero the battery-read delay so
          // the pump loop below does not have to wait out 5 real seconds.
          sessionOptionsProvider.overrideWithValue(
            const SessionOptions(batteryDelay: Duration.zero),
          ),
        ],
        child: const SpectraRoot(),
      ),
    );
    await tester.pump();

    Future<void> connect() async {
      await tester.tap(find.text(FakeScanner.emulatedUltra.name));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    expect(find.text('Connect a device'), findsOneWidget);
    await connect();
    expect(find.byType(SpectraAppShell), findsOneWidget);
    expect(find.textContaining('2.2'), findsWidgets);

    await tester.tap(find.text('Disconnect'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Connect a device'), findsOneWidget);

    await connect();
    expect(find.byType(SpectraAppShell), findsOneWidget);
  });
}
