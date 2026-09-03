import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../l10n/spectra_ui_localizations.dart';
import '../theme/spectra_theme.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'hex_highlight.dart';

/// A monospaced hex dump: offset column, grouped bytes, ASCII gutter and
/// tinted highlight ranges. Takes plain bytes, never a dump model.
///
/// Rows are built eagerly into a `Column`, so a caller holding a very large
/// dump should page it into smaller `SpectraHexViewer` instances rather than
/// passing megabytes of `bytes` to a single viewer.
class SpectraHexViewer extends StatelessWidget {
  const SpectraHexViewer({
    required this.bytes,
    this.bytesPerRow = 16,
    this.groupSize = 4,
    this.highlights = const <SpectraHexHighlight>[],
    this.showAscii = true,
    super.key,
  });

  final Uint8List bytes;
  final int bytesPerRow;
  final int groupSize;

  /// Byte ranges to tint. When two entries cover the same byte, the first
  /// one in this list wins; later entries covering that byte are not shown.
  final List<SpectraHexHighlight> highlights;
  final bool showAscii;

  /// Width of the offset gutter. Wide enough for the eight-digit hex offset
  /// the rows print, so the header and every row line up.
  static const double offsetColumnWidth = 96;

  SpectraHexHighlight? _highlightFor(int index) {
    for (final SpectraHexHighlight h in highlights) {
      if (h.contains(index)) return h;
    }
    return null;
  }

  static String _ascii(Uint8List row) {
    final StringBuffer buffer = StringBuffer();
    for (final int b in row) {
      buffer.write(b >= 0x20 && b <= 0x7E ? String.fromCharCode(b) : '.');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    final SpectraUiLocalizations l10n = SpectraUiLocalizations.of(context);
    final TextStyle mono = SpectraTypography.mono.copyWith(
      color: theme.colors.textPrimary,
    );
    final TextStyle header = SpectraTypography.label.copyWith(
      color: theme.colors.textSecondary,
    );

    if (bytes.isEmpty) {
      return Text(
        l10n.hexViewerEmpty,
        style: SpectraTypography.body.copyWith(
          color: theme.colors.textSecondary,
        ),
      );
    }

    final int rowCount = (bytes.length + bytesPerRow - 1) ~/ bytesPerRow;
    return Semantics(
      label: l10n.hexViewerSummary(bytes.length),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                SizedBox(
                  width: offsetColumnWidth,
                  child: Text(l10n.hexViewerOffsetHeader, style: header),
                ),
                if (showAscii) ...<Widget>[
                  const SizedBox(width: SpectraSpacing.lg),
                  Text(l10n.hexViewerAsciiHeader, style: header),
                ],
              ],
            ),
            const SizedBox(height: SpectraSpacing.xs),
            for (int row = 0; row < rowCount; row++)
              _buildRow(row, mono, theme.colors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(int row, TextStyle mono, Color offsetColor) {
    final int start = row * bytesPerRow;
    final int rowLength = (bytes.length - start).clamp(0, bytesPerRow);
    final Uint8List slice = Uint8List.sublistView(
      bytes,
      start,
      start + rowLength,
    );
    final List<Widget> cells = <Widget>[];
    // Iterate the full row width, not just the bytes present, so a short
    // final row still reserves the same width as a full row and the ASCII
    // gutter after it lines up column-for-column with the rows above it.
    for (int i = 0; i < bytesPerRow; i++) {
      if (i > 0) {
        final bool groupBreak = i % groupSize == 0;
        cells.add(
          Text(groupBreak ? '  ' : ' ', style: mono), // l10n-exempt: layout gap
        );
      }
      if (i >= rowLength) {
        cells.add(
          Text('  ', style: mono), // l10n-exempt: padding for a short row
        );
        continue;
      }
      final SpectraHexHighlight? highlight = _highlightFor(start + i);
      final Widget cell = Text(
        slice[i].toRadixString(16).toUpperCase().padLeft(2, '0'),
        style: highlight == null
            ? mono
            : mono.copyWith(backgroundColor: highlight.color),
      );
      cells.add(
        highlight?.label == null
            ? cell
            : Semantics(label: highlight!.label, child: cell),
      );
    }
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: SpectraSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: offsetColumnWidth,
              child: Text(
                start.toRadixString(16).toUpperCase().padLeft(8, '0'),
                style: mono.copyWith(color: offsetColor),
              ),
            ),
            Row(mainAxisSize: MainAxisSize.min, children: cells),
            if (showAscii) ...<Widget>[
              const SizedBox(width: SpectraSpacing.lg),
              Text(_ascii(slice), style: mono),
            ],
          ],
        ),
      ),
    );
  }
}
