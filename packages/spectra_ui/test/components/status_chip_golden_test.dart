import 'package:alchemist/alchemist.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  for (final (String name, Brightness brightness) in <(String, Brightness)>[
    ('status_chip_light', Brightness.light),
    ('status_chip_dark', Brightness.dark),
  ]) {
    goldenTest(
      'status chips render every variant ($name)',
      fileName: name,
      builder: () => GoldenTestGroup(
        columns: 3,
        children: <Widget>[
          for (final SpectraConnectionStatus status
              in SpectraConnectionStatus.values)
            spectraScenario(
              name: status.name,
              brightness: brightness,
              width: 220,
              height: 100,
              child: SpectraStatusChip.connection(status),
            ),
          spectraScenario(
            name: 'battery 87',
            brightness: brightness,
            width: 220,
            height: 100,
            child: const SpectraStatusChip.battery(percent: 87),
          ),
          spectraScenario(
            name: 'battery 34 charging',
            brightness: brightness,
            width: 220,
            height: 100,
            child: const SpectraStatusChip.battery(percent: 34, charging: true),
          ),
          spectraScenario(
            name: 'battery 9',
            brightness: brightness,
            width: 220,
            height: 100,
            child: const SpectraStatusChip.battery(percent: 9),
          ),
        ],
      ),
    );
  }
}
