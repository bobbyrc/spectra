import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  testWidgets('each connection status gets its localized label', (
    tester,
  ) async {
    for (final (SpectraConnectionStatus status, String label)
        in <(SpectraConnectionStatus, String)>[
          (SpectraConnectionStatus.disconnected, 'Disconnected'),
          (SpectraConnectionStatus.connecting, 'Connecting'),
          (SpectraConnectionStatus.connected, 'Connected'),
          (SpectraConnectionStatus.limited, 'Limited'),
          (SpectraConnectionStatus.updating, 'Updating'),
        ]) {
      await tester.pumpWidget(
        spectraHarness(child: SpectraStatusChip.connection(status)),
      );
      expect(find.text(label), findsOneWidget, reason: '$status');
    }
  });

  testWidgets('connected paints from the connected token', (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        child: const SpectraStatusChip.connection(
          SpectraConnectionStatus.connected,
        ),
      ),
    );
    final DecoratedBox box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(SpectraStatusChip),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(
      (box.decoration as BoxDecoration).border!.top.color,
      SpectraColors.light.connected,
    );
  });

  testWidgets('battery shows a percentage and a charging variant', (
    tester,
  ) async {
    await tester.pumpWidget(
      spectraHarness(child: const SpectraStatusChip.battery(percent: 87)),
    );
    expect(find.text('87%'), findsOneWidget);

    await tester.pumpWidget(
      spectraHarness(
        child: const SpectraStatusChip.battery(percent: 87, charging: true),
      ),
    );
    expect(find.text('87% charging'), findsOneWidget);
  });

  testWidgets('a low battery uses the danger token', (tester) async {
    await tester.pumpWidget(
      spectraHarness(child: const SpectraStatusChip.battery(percent: 9)),
    );
    final DecoratedBox box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(SpectraStatusChip),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(
      (box.decoration as BoxDecoration).border!.top.color,
      SpectraColors.light.danger,
    );
  });
}
