import 'dart:typed_data';

/// A saved card dump (spec 7.3), the value type the card library hands out.
/// Written from Phase 6.
final class SavedCard {
  const SavedCard({
    required this.id,
    required this.name,
    required this.tagType,
    required this.bytes,
    required this.updatedAt,
    this.folder,
    this.color,
  });

  final String id;
  final String name;
  final String tagType;
  final Uint8List bytes;
  final DateTime updatedAt;
  final String? folder;
  final int? color;
}
