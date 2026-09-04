import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

/// A card grouping list tiles with leading and trailing icons.
Widget buildSurfacesPage(BuildContext context) {
  return ListView(
    padding: const EdgeInsets.all(SpectraSpacing.xl),
    children: <Widget>[
      const SpectraSectionHeader(title: 'Recent scans'),
      SpectraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SpectraListTile(
              title: 'My blue card',
              subtitle: 'MIFARE Classic 1K',
              leading: const Icon(Icons.credit_card),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            SpectraListTile(
              title: 'Office badge',
              subtitle: 'NTAG 213',
              leading: const Icon(Icons.badge_outlined),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ],
        ),
      ),
    ],
  );
}
