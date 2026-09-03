import 'dart:typed_data';

/// The MIFARE Classic keys a read tries before giving up.
///
/// Phase 9 replaces this with `DictionariesRepository` (spec 7.3): the
/// reader facade already takes its keys as a parameter
/// (`ReaderFacade.mf1ReadDump(candidateKeys: …)`, spec 8.1), so swapping the
/// source is a one-line change at the call site in `read_controller.dart`
/// and nothing else moves.
///
/// The transport key every blank card ships with comes first, because it
/// opens the majority of cards in one chunk of
/// MF1_CHECK_KEYS_OF_SECTORS and the facade stops as soon as every sector is
/// solved.
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
  for (final String hex in defaultMifareKeyHex)
    Uint8List.fromList(<int>[
      for (int i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ]),
];
