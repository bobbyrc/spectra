import 'package:alchemist/alchemist.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  for (final (String name, Brightness brightness) in <(String, Brightness)>[
    ('surfaces_light', Brightness.light),
    ('surfaces_dark', Brightness.dark),
  ]) {
    goldenTest(
      'card, list tile and section header render ($name)',
      fileName: name,
      builder: () => GoldenTestGroup(
        columns: 1,
        children: <Widget>[
          spectraScenario(
            name: 'card',
            brightness: brightness,
            width: 380,
            height: 140,
            child: const SpectraCard(
              child: SpectraListTile(
                title: 'Chameleon Ultra',
                subtitle: 'Firmware 2.0.0',
              ),
            ),
          ),
          spectraScenario(
            name: 'section header',
            brightness: brightness,
            width: 380,
            height: 100,
            child: SpectraSectionHeader(
              title: 'Slots',
              actionLabel: 'Refresh',
              onAction: () {},
            ),
          ),
          spectraScenario(
            name: 'list tile with leading and trailing',
            brightness: brightness,
            width: 380,
            height: 120,
            child: SpectraListTile(
              title: 'Office badge',
              subtitle: 'MIFARE Classic 1K',
              leading: const Icon(Icons.badge_outlined),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}
