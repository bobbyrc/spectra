import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../l10n/spectra_ui_localizations.dart';
import '../theme/spectra_theme.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'hex_highlight.dart';

/// A monospaced hex dump: offset column, grouped bytes, ASCII gutter and
/// tinted highlight ranges. Takes plain bytes, never a dump model.
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
  final List<SpectraHexHighlight> highlights;
  final bool showAscii;

  Color? _tintFor(int index) {
    for (final SpectraHexHighlight h in highlights) {
      if (h.contains(index)) return h.color;
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SizedBox(
                width: 96,
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
    );
  }

  Widget _buildRow(int row, TextStyle mono, Color offsetColor) {
    final int start = row * bytesPerRow;
    final int end = (start + bytesPerRow).clamp(0, bytes.length);
    final Uint8List slice = Uint8List.sublistView(bytes, start, end);
    final List<Widget> cells = <Widget>[];
    for (int i = 0; i < slice.length; i++) {
      if (i > 0) {
        final bool groupBreak = i % groupSize == 0;
        cells.add(
          Text(groupBreak ? '  ' : ' ', style: mono), // l10n-exempt: layout gap
        );
      }
      final Color? tint = _tintFor(start + i);
      cells.add(
        Text(
          slice[i].toRadixString(16).toUpperCase().padLeft(2, '0'),
          style: tint == null ? mono : mono.copyWith(backgroundColor: tint),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: SpectraSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
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
    );
  }
}
