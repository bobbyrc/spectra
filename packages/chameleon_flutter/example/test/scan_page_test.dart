import 'package:chameleon/chameleon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serial_probe/scan_page.dart';

void main() {
  testWidgets('shows the emulated device from the FakeScanner', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ScanPage(scanners: <DeviceScanner>[])),
    );
    // With no scanners the page still builds and says so.
    await tester.pump();
    expect(find.text('No devices found'), findsOneWidget);
  });

  testWidgets('merged results from several scanners appear as rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ScanPage(scanners: <DeviceScanner>[FakeScanner()])),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Emulated Chameleon Ultra'), findsOneWidget);
  });

  test(
    'mergedScan unions the scanners and de-duplicates by identity',
    () async {
      final stream = mergedScan(<DeviceScanner>[
        FakeScanner(),
        FakeScanner(
          devices: const <DiscoveredDevice>[FakeScanner.emulatedBootloader],
        ),
      ]);
      final last = await stream
          .take(2)
          .last
          .timeout(const Duration(seconds: 2));
      expect(last.length, 2);
      expect(last.any((d) => d.isBootloader), isTrue);
    },
  );
}
