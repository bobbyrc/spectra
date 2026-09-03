import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

/// A 48-byte sample dump with one highlighted key range.
Widget buildHexViewerPage(BuildContext context) {
  final Uint8List sample = Uint8List.fromList(
    List<int>.generate(48, (int i) => (i * 7 + 0x20) & 0xFF),
  );
  return ListView(
    padding: const EdgeInsets.all(SpectraSpacing.xl),
    children: <Widget>[
      const SpectraSectionHeader(title: 'Sector 0 with Key A highlighted'),
      const SizedBox(height: SpectraSpacing.md),
      SpectraHexViewer(
        bytes: sample,
        highlights: <SpectraHexHighlight>[
          SpectraHexHighlight(
            start: 6,
            length: 6,
            color: SpectraTheme.of(context).colors.warning,
            label: 'Key A',
          ),
        ],
      ),
      const SizedBox(height: SpectraSpacing.xl),
      const SpectraSectionHeader(title: 'Empty'),
      SpectraHexViewer(bytes: Uint8List(0)),
    ],
  );
}
