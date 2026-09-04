import 'dart:typed_data';

/// A key dictionary (spec 7.3), the value type dictionaries hand out.
/// Written from Phase 9.
final class KeyDictionary {
  const KeyDictionary({
    required this.id,
    required this.name,
    required this.keys,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<Uint8List> keys;
  final DateTime updatedAt;
}
