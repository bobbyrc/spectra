import 'package:alchemist/alchemist.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  for (final (String name, Brightness brightness) in <(String, Brightness)>[
    ('slot_tile_light', Brightness.light),
    ('slot_tile_dark', Brightness.dark),
  ]) {
    goldenTest(
      'slot tiles render every state ($name)',
      fileName: name,
      builder: () => GoldenTestGroup(
        columns: 2,
        children: <Widget>[
          spectraScenario(
            name: 'active with two tag types',
            brightness: brightness,
            width: 320,
            height: 160,
            child: const SpectraSlotTile(
              number: 1,
              enabled: true,
              active: true,
              nickname: 'Office badge',
              tagTypes: <String>['MIFARE Classic 1K', 'EM410X'],
            ),
          ),
          spectraScenario(
            name: 'enabled',
            brightness: brightness,
            width: 320,
            height: 160,
            child: const SpectraSlotTile(
              number: 2,
              enabled: true,
              nickname: 'Gate fob',
              tagTypes: <String>['EM410X'],
            ),
          ),
          spectraScenario(
            name: 'empty',
            brightness: brightness,
            width: 320,
            height: 160,
            child: const SpectraSlotTile(number: 3, enabled: true),
          ),
          spectraScenario(
            name: 'disabled',
            brightness: brightness,
            width: 320,
            height: 160,
            child: const SpectraSlotTile(
              number: 4,
              enabled: false,
              nickname: 'Spare',
              tagTypes: <String>['NTAG215'],
            ),
          ),
        ],
      ),
    );
  }
}
