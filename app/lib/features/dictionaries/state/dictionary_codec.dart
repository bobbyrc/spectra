import 'dart:convert';
import 'dart:typed_data';

import '../../../core/format/hex.dart';
import '../../../data/data.dart';

/// Spec 7.3: import a key list from the reference app's export, from the
/// plain `.dic` file every other RFID tool reads and writes, or from
/// Spectra's own versioned JSON — and export the last two.
///
/// The reference app (GameTec-live/ChameleonUltraGUI) is GPL-3.0. Only its
/// *format* is matched here — the field names its export writes — never its
/// code (`AGENTS.md`). `docs/research/reference-gui.md` records that it
/// downloads dictionaries and exports "JSON+QR" from Settings, but not the
/// field-level shape, so this reader is deliberately permissive: a
/// dictionary may arrive as a bare object, a list of objects, or an object
/// with a `dictionaries` list; keys may be spaced or colon-grouped and any
/// case. Verifying it against a real export is an H3 checklist item.
///
/// Spec 8.5's one-public-type-per-file rule is knowingly relaxed here (the
/// Phase 6 ruling 17 precedent): [ImportedDictionary],
/// [DictionaryImportProblem], [DictionaryImportException] and the three
/// top-level functions are one cohesive concern — reading and writing the
/// dictionary text formats — and splitting them would add files without
/// adding clarity.

/// What Spectra writes. Bumped only when the shape changes incompatibly.
const int spectraDictionarySchemaVersion = 1;

/// Why an import could not be read.
enum DictionaryImportProblem {
  /// The text is neither a key list nor a JSON shape this reader knows.
  notReadable,

  /// Readable, but with no keys in it.
  noKeys,

  /// A line or list entry is not a twelve-character hex key.
  badKey,
}

/// Thrown by [parseDictionaries]; nothing else escapes it.
final class DictionaryImportException implements Exception {
  const DictionaryImportException(this.problem, this.detail);

  final DictionaryImportProblem problem;

  /// The raw detail a problem view can put one tap away.
  final String detail;

  @override
  String toString() => 'DictionaryImportException(${problem.name}: $detail)';
}

/// One key list from an import, before it is given an id and saved. [name]
/// is null for a bare `.dic` paste, which carries no name — the caller
/// supplies one.
final class ImportedDictionary {
  const ImportedDictionary({required this.keys, this.name});

  final String? name;
  final List<Uint8List> keys;
}

/// Reads any of the three formats. Throws [DictionaryImportException] and
/// nothing else.
List<ImportedDictionary> parseDictionaries(String text) {
  final String trimmed = text.trim();
  if (trimmed.isEmpty) {
    throw const DictionaryImportException(
      DictionaryImportProblem.noKeys,
      'the text is empty',
    );
  }
  // A `.dic` file is not JSON, and a JSON file never starts with a hex key,
  // so the first character is enough to choose the reader — and choosing on
  // shape rather than on a thrown FormatException keeps a malformed JSON
  // paste from being silently read as a key list and reported as "bad key".
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    return _readJson(trimmed);
  }
  return <ImportedDictionary>[ImportedDictionary(keys: _readKeyLines(trimmed))];
}

List<ImportedDictionary> _readJson(String text) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (e) {
    throw DictionaryImportException(
      DictionaryImportProblem.notReadable,
      e.message,
    );
  }

  final List<Object?> raw = switch (decoded) {
    final List<Object?> list => list,
    final Map<String, Object?> map when map['dictionaries'] is List<Object?> =>
      map['dictionaries']! as List<Object?>,
    final Map<String, Object?> map when map['keys'] is List<Object?> =>
      <Object?>[map],
    _ => throw const DictionaryImportException(
      DictionaryImportProblem.notReadable,
      'expected a list of dictionaries, or an object with a "keys" list',
    ),
  };
  if (raw.isEmpty) {
    throw const DictionaryImportException(
      DictionaryImportProblem.noKeys,
      'the file holds no dictionaries',
    );
  }
  return <ImportedDictionary>[for (final Object? e in raw) _readDictionary(e)];
}

ImportedDictionary _readDictionary(Object? entry) {
  if (entry is! Map<String, Object?>) {
    throw const DictionaryImportException(
      DictionaryImportProblem.notReadable,
      'a dictionary entry is not an object',
    );
  }
  final Object? keys = entry['keys'];
  if (keys is! List<Object?>) {
    throw const DictionaryImportException(
      DictionaryImportProblem.notReadable,
      'a dictionary entry has no "keys" list',
    );
  }
  if (keys.isEmpty) {
    // An entry can be well-formed JSON and still carry a `"keys": []`
    // list — that is a readable dictionary with nothing in it, not a
    // parse failure, so it gets the same `noKeys` problem an empty `.dic`
    // paste gets rather than silently becoming an empty dictionary.
    throw const DictionaryImportException(
      DictionaryImportProblem.noKeys,
      'a dictionary entry has an empty "keys" list',
    );
  }
  final String name = entry['name']?.toString().trim() ?? '';
  return ImportedDictionary(
    name: name.isEmpty ? null : name,
    keys: <Uint8List>[for (final Object? key in keys) _readKey(key.toString())],
  );
}

List<Uint8List> _readKeyLines(String text) {
  final List<Uint8List> out = <Uint8List>[];
  for (final String line in text.split('\n')) {
    // `#` starts a comment in every .dic file in circulation; a blank line
    // is a separator, not a key.
    final String cleaned = line.split('#').first.trim();
    if (cleaned.isEmpty) continue;
    out.add(_readKey(cleaned));
  }
  if (out.isEmpty) {
    throw const DictionaryImportException(
      DictionaryImportProblem.noKeys,
      'the text holds no keys',
    );
  }
  return out;
}

Uint8List _readKey(String text) {
  final Uint8List? key = parseMifareKey(text);
  if (key == null) {
    throw DictionaryImportException(
      DictionaryImportProblem.badKey,
      '"$text" is not a $mifareKeyLength-byte key',
    );
  }
  return key;
}

/// Spectra's own export: versioned, keys as upper-case hex, so the file
/// stays diffable and hand-editable.
String exportDictionariesJson(List<KeyDictionary> dictionaries) =>
    jsonEncode(<String, Object?>{
      'schemaVersion': spectraDictionarySchemaVersion,
      'dictionaries': <Object?>[
        for (final KeyDictionary d in dictionaries)
          <String, Object?>{
            'name': d.name,
            'updatedAt': d.updatedAt.toIso8601String(),
            'keys': d.keys.map<String>(toHex).toList(),
          },
      ],
    });

/// One key per line, with the name as a leading comment: the format every
/// other tool on the bench already reads.
String exportDictionaryDic(KeyDictionary dictionary) => <String>[
  '# ${dictionary.name}',
  ...dictionary.keys.map<String>(toHex),
].join('\n');
