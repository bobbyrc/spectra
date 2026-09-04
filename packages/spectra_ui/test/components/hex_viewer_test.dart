import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../support/golden_harness.dart';

Uint8List _bytes(int n) =>
    Uint8List.fromList(List<int>.generate(n, (int i) => i & 0xFF));

void main() {
  test('a highlight knows the range it covers', () {
    const h = SpectraHexHighlight(
      start: 4,
      length: 3,
      color: Color(0xFF00FF00),
    );
    expect(h.end, 7);
    expect(h.contains(3), isFalse);
    expect(h.contains(4), isTrue);
    expect(h.contains(6), isTrue);
    expect(h.contains(7), isFalse);
  });

  testWidgets('renders one row per bytesPerRow with an offset column', (
    tester,
  ) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 640,
        height: 260,
        child: SpectraHexViewer(bytes: _bytes(32)),
      ),
    );
    expect(find.text('00000000'), findsOneWidget);
    expect(find.text('00000010'), findsOneWidget);
    expect(find.text('Offset'), findsOneWidget);
    expect(find.text('ASCII'), findsOneWidget);
  });

  testWidgets('groups bytes and pads a short final row', (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 640,
        height: 220,
        child: SpectraHexViewer(
          bytes: Uint8List.fromList(<int>[0x04, 0x1F, 0xAB, 0xCD, 0xEF]),
        ),
      ),
    );
    // Each byte is its own Text so highlight ranges can tint individually.
    expect(find.text('04'), findsOneWidget);
    expect(find.text('1F'), findsOneWidget);
    expect(find.text('EF'), findsOneWidget);
    // A double space marks the group break before the fifth byte, and also
    // pads the missing bytes of the short row out to bytesPerRow width.
    expect(find.text('  '), findsWidgets);
  });

  testWidgets('a short final row keeps the ASCII gutter aligned', (
    tester,
  ) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 640,
        height: 260,
        child: SpectraHexViewer(bytes: _bytes(20), bytesPerRow: 16),
      ),
    );
    // _bytes only ever produces values below 0x20, so every byte renders as
    // '.' in the ASCII gutter: 16 dots for the full first row, 4 for the
    // short second row. The first row's ASCII text and the second (short,
    // padded) row's ASCII text must start at the same x offset for the
    // gutter to line up.
    final double firstRowLeft = tester.getTopLeft(find.text('.' * 16)).dx;
    final double secondRowLeft = tester.getTopLeft(find.text('.' * 4)).dx;
    expect(secondRowLeft, firstRowLeft);
  });

  testWidgets(
    'announces a byte-count summary and the label of a highlighted range',
    (tester) async {
      await tester.pumpWidget(
        spectraHarness(
          width: 640,
          height: 220,
          child: SpectraHexViewer(
            bytes: _bytes(8),
            bytesPerRow: 8,
            groupSize: 8,
            highlights: const <SpectraHexHighlight>[
              SpectraHexHighlight(
                start: 2,
                length: 2,
                color: Color(0xFF00FF00),
                label: 'Key A',
              ),
            ],
          ),
        ),
      );
      expect(find.bySemanticsLabel('8 bytes'), findsOneWidget);
      // The highlighted byte's own text also contributes to the merged
      // node label, so match the highlight label as a substring.
      expect(find.bySemanticsLabel(RegExp('Key A')), findsWidgets);
    },
  );

  testWidgets('renders the ASCII gutter with dots for unprintables', (
    tester,
  ) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 640,
        height: 220,
        child: SpectraHexViewer(
          bytes: Uint8List.fromList(<int>[0x41, 0x42, 0x00, 0x7F]),
        ),
      ),
    );
    expect(find.text('AB..'), findsOneWidget);
  });

  testWidgets('shows the empty label for zero bytes', (tester) async {
    await tester.pumpWidget(
      spectraHarness(width: 400, child: SpectraHexViewer(bytes: Uint8List(0))),
    );
    expect(find.text('No data'), findsOneWidget);
  });

  testWidgets('a highlight tints only the bytes it covers', (tester) async {
    await tester.pumpWidget(
      spectraHarness(
        width: 640,
        height: 220,
        child: SpectraHexViewer(
          bytes: _bytes(8),
          bytesPerRow: 8,
          groupSize: 8,
          showAscii: false,
          highlights: const <SpectraHexHighlight>[
            SpectraHexHighlight(start: 2, length: 2, color: Color(0xFF00FF00)),
          ],
        ),
      ),
    );
    final Iterable<Text> cells = tester
        .widgetList<Text>(find.byType(Text))
        .where((Text t) => t.data == '02' || t.data == '03' || t.data == '05');
    expect(cells.length, 3);
    for (final Text cell in cells) {
      final bool highlighted = cell.data != '05';
      expect(
        cell.style!.backgroundColor,
        highlighted ? const Color(0xFF00FF00) : null,
        reason: cell.data,
      );
    }
  });
}
