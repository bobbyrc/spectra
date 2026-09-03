import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

/// A collapsed disclosure and an initially-expanded one.
Widget buildDisclosurePage(BuildContext context) {
  return ListView(
    padding: const EdgeInsets.all(SpectraSpacing.xl),
    children: <Widget>[
      const SpectraSectionHeader(title: 'Collapsed by default'),
      SpectraDisclosure(
        summary: const Text('UID: 04:A2:1B:9E'),
        detail: const Text('ATQA 0004, SAK 08, MIFARE Classic 1K.'),
      ),
      const SizedBox(height: SpectraSpacing.xl),
      const SpectraSectionHeader(title: 'Initially expanded'),
      SpectraDisclosure(
        summary: const Text('Sector 0 key details'),
        detail: const Text('Key A FFFFFFFFFFFF, Key B unknown.'),
        initiallyExpanded: true,
      ),
    ],
  );
}
