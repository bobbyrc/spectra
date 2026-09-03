import 'package:chameleon/chameleon.dart';

import '../../../data/data.dart';

/// A stored [SavedCard] seen through the SDK's dump formats (spec 3.5).
///
/// `SavedCard.tagType` is a plain `String` because the data layer stores a
/// column, not an enum. This file is the only place that string becomes a
/// [TagType] again, so a rename of the enum is one edit, not a search.
///
/// Spec 8.5's one-public-type-per-file rule is knowingly relaxed here
/// (Phase 6 ruling 17): these seven functions are one cohesive concern —
/// the adapter from a stored row to `package:chameleon`'s dump formats —
/// and splitting them would add files without adding clarity.

/// The string stored in `SavedCard.tagType`.
String tagTypeName(TagType type) => type.name;

/// The inverse of [tagTypeName]. An unknown string is [TagType.undefined]
/// rather than a throw: a row written by a future version of Spectra must
/// not make the library unopenable.
TagType tagTypeFromName(String name) {
  for (final TagType t in TagType.values) {
    if (t.name == name) return t;
  }
  return TagType.undefined;
}

/// The parsed dump, or null when this type has no [DumpFormat] (spec 3.5
/// covers MIFARE Classic, Ultralight and EM410x) or the bytes do not parse.
CardDump? parseSavedCard(SavedCard card) {
  final TagType type = tagTypeFromName(card.tagType);
  if (DumpFormats.forType(type) == null) return null;
  try {
    return DumpFormats.parse(card.bytes, type);
  } on Object {
    return null;
  }
}

/// Every `DumpFormat.describe()`'s own field label carrying the raw enum
/// name (e.g. "mifare1k"), dropped by [describeSavedCard]: the detail
/// screen already shows the product name via `tagTypeLabel`, so this field
/// would repeat the same fact under a second, unlocalized label.
const String _typeFieldLabel = 'Type';

/// The dump's headline fields, for the detail screen. Empty when the type
/// has no format.
///
/// The labels come from the SDK's own `describe()` ('UID', 'SAK', 'ATQA',
/// 'Sectors'): technical field names printed by every RFID tool, exempt from
/// localization the same way tag-type product names are labeled in
/// `core/format/tag_labels.dart` (`tagTypeLabel`) — this file only ever
/// hands callers a `TagType` or these SDK field labels, never UI copy.
List<DumpField> describeSavedCard(SavedCard card) {
  final TagType type = tagTypeFromName(card.tagType);
  final DumpFormat<CardDump>? format = DumpFormats.forType(type);
  final CardDump? dump = parseSavedCard(card);
  if (format == null || dump == null) return const <DumpField>[];
  return format
      .describe(dump)
      .where((DumpField field) => field.label != _typeFieldLabel)
      .toList();
}

/// Problems with the stored bytes, empty when the card is valid.
List<String> validateSavedCard(SavedCard card) {
  final TagType type = tagTypeFromName(card.tagType);
  final DumpFormat<CardDump>? format = DumpFormats.forType(type);
  if (format == null) return const <String>['unsupported tag type'];
  final CardDump? dump = parseSavedCard(card);
  if (dump == null) return const <String>['the bytes could not be parsed'];
  return format.validate(dump);
}

/// The unit the editor edits: a MIFARE Classic block, an Ultralight page, or
/// the whole EM410x id. Zero means "this type is not editable".
int chunkSizeFor(TagType type) => switch (type.family) {
  TagFamily.mifareClassic => 16,
  TagFamily.ultralight => 4,
  TagFamily.lf => type == TagType.em410x ? 5 : 0,
  _ => 0,
};

/// How many chunks [byteLength] bytes of [type] hold.
int chunkCountFor(TagType type, int byteLength) {
  final int size = chunkSizeFor(type);
  return size == 0 ? 0 : byteLength ~/ size;
}
