import 'package:alchemist/alchemist.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  for (final (String name, Brightness brightness) in <(String, Brightness)>[
    ('disclosure_light', Brightness.light),
    ('disclosure_dark', Brightness.dark),
  ]) {
    goldenTest(
      'disclosure renders collapsed and expanded ($name)',
      fileName: name,
      builder: () => GoldenTestGroup(
        columns: 1,
        children: <Widget>[
          spectraScenario(
            name: 'collapsed',
            brightness: brightness,
            width: 400,
            height: 120,
            child: const SpectraDisclosure(
              summary: SpectraListTile(
                title: 'Firmware 2.0.0',
                subtitle: 'Up to date',
              ),
              detail: SpectraListTile(title: 'Git hash abc1234'),
            ),
          ),
          spectraScenario(
            name: 'expanded',
            brightness: brightness,
            width: 400,
            height: 220,
            child: const SpectraDisclosure(
              initiallyExpanded: true,
              summary: SpectraListTile(
                title: 'Firmware 2.0.0',
                subtitle: 'Up to date',
              ),
              detail: SpectraListTile(
                title: 'Git hash abc1234',
                subtitle: 'Built 2026-08-30',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
