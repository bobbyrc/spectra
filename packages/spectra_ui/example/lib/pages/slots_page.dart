import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

/// One slot tile for each state: active, enabled, empty and disabled.
Widget buildSlotsPage(BuildContext context) {
  return ListView(
    padding: const EdgeInsets.all(SpectraSpacing.xl),
    children: <Widget>[
      const SpectraSectionHeader(title: 'Slots'),
      SpectraSlotTile(
        number: 1,
        enabled: true,
        active: true,
        nickname: 'My blue card',
        tagTypes: const <String>['MIFARE Classic 1K'],
        onTap: () {},
      ),
      const SizedBox(height: SpectraSpacing.md),
      SpectraSlotTile(
        number: 2,
        enabled: true,
        nickname: 'Office badge',
        tagTypes: const <String>['NTAG 213'],
        onTap: () {},
      ),
      const SizedBox(height: SpectraSpacing.md),
      SpectraSlotTile(number: 3, enabled: true, onTap: () {}),
      const SizedBox(height: SpectraSpacing.md),
      const SpectraSlotTile(number: 4, enabled: false),
    ],
  );
}
