import 'package:alchemist/alchemist.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  for (final (String name, Brightness brightness) in <(String, Brightness)>[
    ('overlays_light', Brightness.light),
    ('overlays_dark', Brightness.dark),
  ]) {
    goldenTest(
      'input, dialog and sheet render ($name)',
      fileName: name,
      builder: () => GoldenTestGroup(
        columns: 1,
        children: <Widget>[
          spectraScenario(
            name: 'text field',
            brightness: brightness,
            width: 360,
            height: 140,
            child: const SpectraTextField(
              label: 'Nickname',
              hint: 'Office badge',
            ),
          ),
          spectraScenario(
            name: 'text field with error',
            brightness: brightness,
            width: 360,
            height: 160,
            child: const SpectraTextField(
              label: 'Nickname',
              errorText: 'Required',
            ),
          ),
          spectraScenario(
            name: 'dialog',
            brightness: brightness,
            width: 400,
            height: 400,
            child: SpectraDialog(
              title: 'Erase slot 3?',
              content: const SpectraTextField(label: 'Type ERASE'),
              actions: <Widget>[
                SpectraButton(
                  label: 'Cancel',
                  variant: SpectraButtonVariant.secondary,
                  onPressed: () {},
                ),
                SpectraButton(
                  label: 'OK',
                  variant: SpectraButtonVariant.danger,
                  onPressed: () {},
                ),
              ],
            ),
          ),
          spectraScenario(
            name: 'bottom sheet',
            brightness: brightness,
            width: 400,
            height: 220,
            child: const SpectraBottomSheet(
              title: 'Pick a slot',
              child: SpectraTextField(label: 'Filter'),
            ),
          ),
        ],
      ),
    );
  }
}
