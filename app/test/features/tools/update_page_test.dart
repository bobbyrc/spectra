import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra/app.dart';
import 'package:spectra/core/flags/feature_flags.dart';

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

  testWidgets('the BLE notice shows while dfuOverBleEnabled is false', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ...appOverrides(transport: (_) => FakeDevice()),
          featureFlagsProvider.overrideWithValue(const FeatureFlags()),
        ],
        child: const SpectraRoot(),
      ),
    );
    await connectToEmulator(tester);
    await openUpdate(tester);

    expect(find.textContaining('pending hardware validation'), findsOneWidget);

    await settleApp(tester);
  });

  testWidgets('the BLE notice is hidden once dfuOverBleEnabled is true', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ...appOverrides(transport: (_) => FakeDevice()),
          featureFlagsProvider.overrideWithValue(
            const FeatureFlags(dfuOverBleEnabled: true),
          ),
        ],
        child: const SpectraRoot(),
      ),
    );
    await connectToEmulator(tester);
    await openUpdate(tester);

    expect(find.textContaining('pending hardware validation'), findsNothing);

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
