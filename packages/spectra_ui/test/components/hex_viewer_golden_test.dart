import 'dart:typed_data';

import 'package:alchemist/alchemist.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

void main() {
  final Uint8List block = Uint8List.fromList(
    List<int>.generate(48, (int i) => (i * 7 + 0x20) & 0xFF),
  );
  for (final (String name, Brightness brightness) in <(String, Brightness)>[
    ('hex_viewer_light', Brightness.light),
    ('hex_viewer_dark', Brightness.dark),
  ]) {
    goldenTest(
      'hex viewer renders rows, groups and highlights ($name)',
      fileName: name,
      builder: () => GoldenTestGroup(
        columns: 1,
        children: <Widget>[
          spectraScenario(
            name: 'three rows with a highlighted key range',
            brightness: brightness,
            width: 900,
            height: 220,
            child: SpectraHexViewer(
              bytes: block,
              highlights: <SpectraHexHighlight>[
                SpectraHexHighlight(
                  start: 6,
                  length: 6,
                  color: brightness == Brightness.dark
                      ? SpectraColors.dark.warning
                      : SpectraColors.light.warning,
                  label: 'Key A',
                ),
              ],
            ),
          ),
          spectraScenario(
            name: 'empty',
            brightness: brightness,
            width: 400,
            height: 120,
            child: SpectraHexViewer(bytes: Uint8List(0)),
          ),
        ],
      ),
    );
  }
}
