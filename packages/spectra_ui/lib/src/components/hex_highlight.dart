import 'package:flutter/widgets.dart' show Color;

/// A byte range the hex viewer tints, such as a sector key or a UID.
final class SpectraHexHighlight {
  const SpectraHexHighlight({
    required this.start,
    required this.length,
    required this.color,
    this.label,
  });

  /// First byte index covered.
  final int start;

  /// Number of bytes covered.
  final int length;

  final Color color;

  /// Optional semantics label announced for the range.
  final String? label;

  int get end => start + length;

  bool contains(int index) => index >= start && index < end;
}
