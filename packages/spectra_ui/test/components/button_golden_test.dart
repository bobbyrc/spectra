import 'package:alchemist/alchemist.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  for (final (String name, Brightness brightness) in <(String, Brightness)>[
    ('button_light', Brightness.light),
    ('button_dark', Brightness.dark),
  ]) {
    goldenTest(
      'buttons render every variant and state ($name)',
      fileName: name,
      builder: () => GoldenTestGroup(
        columns: 2,
        children: <Widget>[
          spectraScenario(
            name: 'primary',
            brightness: brightness,
            child: SpectraButton(label: 'Connect', onPressed: () {}),
          ),
          spectraScenario(
            name: 'secondary',
            brightness: brightness,
            child: SpectraButton(
              label: 'Rescan',
              variant: SpectraButtonVariant.secondary,
              onPressed: () {},
            ),
          ),
          spectraScenario(
            name: 'danger',
            brightness: brightness,
            child: SpectraButton(
              label: 'Erase',
              variant: SpectraButtonVariant.danger,
              onPressed: () {},
            ),
          ),
          spectraScenario(
            name: 'disabled',
            brightness: brightness,
            child: const SpectraButton(label: 'Connect', onPressed: null),
          ),
        ],
      ),
    );
  }
}
