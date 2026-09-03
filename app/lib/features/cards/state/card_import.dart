import 'dart:convert';
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';

import '../../../data/data.dart';
import 'card_codec.dart';
import 'hex.dart';

/// Spec 7.3: import from the reference app's JSON export, and Spectra's own
/// versioned format.
///
/// The reference app (GameTec-live/ChameleonUltraGUI) is GPL-3.0. Only its
/// *format* is matched here — the field names its export writes — never its
/// code (`AGENTS.md`). `docs/research/reference-gui.md` records that it
/// exports cards as JSON with folders and colours but not the field-level
/// shape, so the reader below is deliberately permissive: a card may arrive
/// as a bare object, a list of objects, or an object with a `cards` list; hex
/// may carry spaces or colons; the tag name is matched case-insensitively
/// against both the reference spellings and Spectra's own `TagType.name`.
/// Verifying it against a real export is an H3 checklist item (Task 14).
///
/// Spec 8.5's one-public-type-per-file rule is knowingly relaxed here
/// (Phase 6 ruling 17): [ImportedCard], [CardImportProblem],
/// [CardImportException] and the two top-level functions are one cohesive
/// concern — reading and writing the JSON card format — and splitting them
/// would add files without adding clarity.

/// What Spectra writes. Bumped only when the shape changes incompatibly.
const int spectraCardSchemaVersion = 1;

/// The reference app's tag names, mapped to the SDK's enum. Case-insensitive
/// at the call site; only the families with a `DumpFormat` (spec 3.5) are
/// here, because there is nothing to store for the others.
const Map<String, TagType> referenceTagNames = <String, TagType>{
  'mifaremini': TagType.mifareMini,
  'mifare1k': TagType.mifare1k,
  'mifare2k': TagType.mifare2k,
  'mifare4k': TagType.mifare4k,
  'ntag210': TagType.ntag210,
  'ntag212': TagType.ntag212,
  'ntag213': TagType.ntag213,
  'ntag215': TagType.ntag215,
  'ntag216': TagType.ntag216,
  'ultralight': TagType.mf0icu1,
  'ultralightc': TagType.mf0icu2,
  'ultralight11': TagType.mf0ul11,
  'ultralight21': TagType.mf0ul21,
  'em410x': TagType.em410x,
};

/// Why an import could not be read.
enum CardImportProblem {
  /// The text is not JSON, or not a shape this reader understands.
  notJson,

  /// Valid JSON with no cards in it.
  noCards,

  /// A card names a tag type Spectra has no dump format for.
  unsupportedTagType,

  /// A card's data is not hex, or is empty.
  badBytes,
}

/// Thrown by [parseCardsJson]; nothing else escapes it.
final class CardImportException implements Exception {
  const CardImportException(this.problem, this.detail);

  final CardImportProblem problem;

  /// The raw detail a problem view can put one tap away.
  final String detail;

  @override
  String toString() => 'CardImportException(${problem.name}: $detail)';
}

/// One card from an import, before it is given an id and saved.
final class ImportedCard {
  const ImportedCard({
    required this.name,
    required this.tagType,
    required this.bytes,
    this.folder,
    this.color,
  });

  final String name;
  final TagType tagType;
  final Uint8List bytes;
  final String? folder;
  final int? color;
}

/// Reads either format: the reference app's export, or Spectra's own.
/// Throws [CardImportException] and nothing else.
List<ImportedCard> parseCardsJson(String text) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (e) {
    throw CardImportException(CardImportProblem.notJson, e.message);
  }

  final List<Object?> raw = switch (decoded) {
    final List<Object?> list => list,
    final Map<String, Object?> map when map['cards'] is List<Object?> =>
      map['cards']! as List<Object?>,
    final Map<String, Object?> map => <Object?>[map],
    _ => throw const CardImportException(
      CardImportProblem.notJson,
      'expected an object or a list of objects',
    ),
  };
  if (raw.isEmpty) {
    throw const CardImportException(
      CardImportProblem.noCards,
      'the file holds no cards',
    );
  }
  return <ImportedCard>[for (final Object? entry in raw) _readCard(entry)];
}

ImportedCard _readCard(Object? entry) {
  if (entry is! Map<String, Object?>) {
    throw const CardImportException(
      CardImportProblem.notJson,
      'a card entry is not an object',
    );
  }
  final String tagName = (entry['tag'] ?? entry['tagType'] ?? '').toString();
  final TagType type =
      referenceTagNames[tagName.toLowerCase()] ?? tagTypeFromName(tagName);
  if (type == TagType.undefined || DumpFormats.forType(type) == null) {
    throw CardImportException(
      CardImportProblem.unsupportedTagType,
      'no dump format for tag type "$tagName"',
    );
  }

  final Uint8List bytes = _readBytes(entry, type);
  final String rawName = entry['name']?.toString().trim() ?? '';
  return ImportedCard(
    name: rawName.isEmpty ? tagName : rawName,
    tagType: type,
    bytes: bytes,
    folder: entry['folder']?.toString(),
    color: entry['color'] is int ? entry['color']! as int : null,
  );
}

/// The dump, from `data` (one hex string per block or page) or — for an LF
/// card, which the reference app stores as an id rather than a dump — from
/// `uid`.
Uint8List _readBytes(Map<String, Object?> entry, TagType type) {
  final Object? data = entry['data'];
  final List<Object?> rows = data is List<Object?> ? data : const <Object?>[];
  if (rows.isEmpty) {
    final Uint8List? id = parseHex((entry['uid'] ?? '').toString());
    if (id == null || id.isEmpty) {
      throw const CardImportException(
        CardImportProblem.badBytes,
        'the card has neither data rows nor a uid',
      );
    }
    return id;
  }
  final BytesBuilder out = BytesBuilder();
  for (final Object? row in rows) {
    final Uint8List? bytes = parseHex(row.toString());
    if (bytes == null) {
      throw CardImportException(
        CardImportProblem.badBytes,
        'row "$row" is not hex',
      );
    }
    out.add(bytes);
  }
  return out.toBytes();
}

/// Spectra's own export: versioned, with the dump as one hex string per card
/// so the file stays diffable and hand-editable.
String exportCardsJson(List<SavedCard> cards) => jsonEncode(<String, Object?>{
  'schemaVersion': spectraCardSchemaVersion,
  'cards': <Object?>[
    for (final SavedCard card in cards)
      <String, Object?>{
        'name': card.name,
        'tag': card.tagType,
        'folder': card.folder,
        'color': card.color,
        'updatedAt': card.updatedAt.toIso8601String(),
        'data': <String>[toHex(card.bytes)],
      },
  ],
});
