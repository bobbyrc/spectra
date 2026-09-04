import 'package:alchemist/alchemist.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  const List<String> steps = <String>['Prepare', 'Transfer', 'Verify'];
  for (final (String name, Brightness brightness) in <(String, Brightness)>[
    ('progress_light', Brightness.light),
    ('progress_dark', Brightness.dark),
  ]) {
    goldenTest(
      'progress and step indicators render ($name)',
      fileName: name,
      builder: () => GoldenTestGroup(
        columns: 1,
        children: <Widget>[
          spectraScenario(
            name: 'determinate with cancel',
            brightness: brightness,
            width: 400,
            height: 160,
            child: SpectraProgressIndicator(
              label: 'Writing slot 3',
              detail: '12 of 64 blocks',
              value: 0.4,
              onCancel: () {},
            ),
          ),
          spectraScenario(
            name: 'step 2 of 3',
            brightness: brightness,
            width: 400,
            height: 140,
            child: const SpectraStepIndicator(steps: steps, currentIndex: 1),
          ),
          spectraScenario(
            name: 'step 2 failed',
            brightness: brightness,
            width: 400,
            height: 140,
            child: const SpectraStepIndicator(
              steps: steps,
              currentIndex: 1,
              failed: true,
            ),
          ),
        ],
      ),
    );
  }
}
