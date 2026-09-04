import 'package:alchemist/alchemist.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

const List<SpectraDestination> _destinations = <SpectraDestination>[
  SpectraDestination(label: 'Device', icon: Icons.memory),
  SpectraDestination(label: 'Slots', icon: Icons.grid_view),
  SpectraDestination(label: 'Cards', icon: Icons.style),
  SpectraDestination(label: 'Tools', icon: Icons.build),
  SpectraDestination(label: 'Settings', icon: Icons.settings),
];

void main() {
  for (final (String name, Brightness brightness) in <(String, Brightness)>[
    ('app_shell_light', Brightness.light),
    ('app_shell_dark', Brightness.dark),
  ]) {
    goldenTest(
      'the shell renders both navigation layouts ($name)',
      fileName: name,
      builder: () => GoldenTestGroup(
        columns: 1,
        children: <Widget>[
          spectraScenario(
            name: 'compact, bottom bar',
            brightness: brightness,
            width: 420,
            height: 560,
            child: SpectraAppShell(
              destinations: _destinations,
              selectedIndex: 1,
              onDestinationSelected: (_) {},
              title: 'Slots',
              child: const SpectraCard(
                child: SpectraListTile(title: 'Slot list'),
              ),
            ),
          ),
          spectraScenario(
            name: 'expanded, navigation rail',
            brightness: brightness,
            width: 900,
            height: 500,
            child: SpectraAppShell(
              destinations: _destinations,
              selectedIndex: 1,
              onDestinationSelected: (_) {},
              title: 'Slots',
              child: const SpectraCard(
                child: SpectraListTile(title: 'Slot list'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
