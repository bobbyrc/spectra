import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

const List<SpectraDestination> _destinations = <SpectraDestination>[
  SpectraDestination(label: 'Device', icon: Icons.memory),
  SpectraDestination(label: 'Slots', icon: Icons.grid_view),
  SpectraDestination(label: 'Cards', icon: Icons.style),
];

Widget _shell({required int selectedIndex, required ValueChanged<int> onTap}) {
  return SpectraAppShell(
    destinations: _destinations,
    selectedIndex: selectedIndex,
    onDestinationSelected: onTap,
    title: 'Spectra',
    child: const Center(child: SpectraListTile(title: 'Body')),
  );
}

void main() {
  testWidgets('under 600 logical pixels it shows a bottom bar', (tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      spectraHarness(child: _shell(selectedIndex: 0, onTap: (_) {})),
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('at 600 logical pixels and above it shows a rail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      spectraHarness(child: _shell(selectedIndex: 0, onTap: (_) {})),
    );
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('selecting a destination reports its index in both layouts', (
    tester,
  ) async {
    final taps = <int>[];
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    tester.view.physicalSize = const Size(500, 900);
    await tester.pumpWidget(
      spectraHarness(child: _shell(selectedIndex: 0, onTap: taps.add)),
    );
    await tester.tap(find.text('Slots').last);
    expect(taps, <int>[1]);

    tester.view.physicalSize = const Size(900, 700);
    await tester.pumpWidget(
      spectraHarness(child: _shell(selectedIndex: 0, onTap: taps.add)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cards').last);
    expect(taps, <int>[1, 2]);
  });

  testWidgets('the body is always present', (tester) async {
    await tester.pumpWidget(
      spectraHarness(child: _shell(selectedIndex: 0, onTap: (_) {})),
    );
    expect(find.text('Body'), findsOneWidget);
  });
}
