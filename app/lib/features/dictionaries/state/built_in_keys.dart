import 'dart:typed_data';

import '../../../core/format/hex.dart';
import '../../../data/data.dart';

/// The MIFARE Classic keys a read tries before giving up.
///
/// The transport key every blank card ships with comes first, because it
/// opens the majority of cards in one chunk of
/// MF1_CHECK_KEYS_OF_SECTORS and the facade stops as soon as every sector is
/// solved.
///
/// Source: public MIFARE Classic default-key dictionaries circulated by the
/// mfoc/libnfc/Proxmark3 community — not the GPL-3.0 reference app.
const List<String> defaultMifareKeyHex = <String>[
  'FFFFFFFFFFFF',
  'A0A1A2A3A4A5',
  'D3F7D3F7D3F7',
  '000000000000',
  'B0B1B2B3B4B5',
  '4D3A99C351DD',
  '1A982C7E459A',
  'AABBCCDDEEFF',
  '714C5C886E97',
  '587EE5F9350F',
  'A0478CC39091',
  '533CB6C723F6',
  '8FD0A4F256E9',
];

/// Fresh copies each call, so a caller mutating a key cannot poison the
/// next read's dictionary.
List<Uint8List> defaultMifareKeys() => <Uint8List>[
  for (final String hex in defaultMifareKeyHex) parseMifareKey(hex)!,
];

/// The id of the built-in list. It is not a database row: [dictionaries]
/// synthesizes it in front of the stored ones, which is what makes it
/// read-only by construction rather than by a check somewhere. A user who
/// wants to change it duplicates it (`DictionaryLibrary.duplicate`).
const String builtInDictionaryId = 'builtin-mifare';

/// The built-in list as a [KeyDictionary].
///
/// [KeyDictionary.name] is empty on purpose: the name is copy, and copy is
/// localized at render time (`dictionaryDisplayName`, `ui/`), which a value
/// baked into a stored row could never be. [KeyDictionary.updatedAt] is the
/// epoch so any real list sorts above it if a caller ever sorts the merged
/// list by date.
KeyDictionary builtInDictionary() => KeyDictionary(
  id: builtInDictionaryId,
  name: '',
  keys: defaultMifareKeys(),
  updatedAt: DateTime.utc(0),
);

bool isBuiltIn(KeyDictionary dictionary) =>
    dictionary.id == builtInDictionaryId;
