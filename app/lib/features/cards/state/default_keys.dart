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

/// The T55xx passwords an EM410x write uses.
///
/// `ReaderFacade.em410xWriteToT55xx` takes its keys as parameters, like
/// every other reader operation (spec 8.1), so the list lives in the app
/// beside the MIFARE dictionary and Phase 9's `DictionariesRepository` can
/// replace both without touching the SDK.
///
/// These are the widely published defaults for T5577 blanks, not values read
/// out of any GPL source. **`hardware-validate` (checklist H3):** whether a
/// given blank answers to them is only provable with a card in hand — a
/// blank with no password set ignores `oldKeys` entirely, and one with a
/// password Spectra does not know simply refuses the write. `FakeDevice`'s
/// EM410X_WRITE_TO_T55XX handler ignores `oldKeys` outright, so this is one
/// more thing only a real card proves.
const String defaultT55xxKeyHex = '20206666';

/// [defaultT55xxKeyHex] itself is included here (ruling 28): `newKey` is the
/// password a write leaves the card with (`ReaderFacade.em410xWriteToT55xx`'s
/// doc comment), so a blank that had no password before Spectra's first
/// write now has this one — the next write to the same card has to offer it
/// back as an old key, or it locks Spectra out of a card it just wrote.
const List<String> defaultT55xxOldKeyHex = <String>[
  '51243648',
  '19920427',
  defaultT55xxKeyHex,
];

Uint8List _hex(String hex) => Uint8List.fromList(<int>[
  for (int i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);

/// Fresh copies each call, so a caller mutating a key cannot poison the
/// next read's dictionary.
List<Uint8List> defaultMifareKeys() => <Uint8List>[
  for (final String hex in defaultMifareKeyHex) _hex(hex),
];

/// A fresh copy each call, so a caller mutating a key cannot poison the
/// next write.
Uint8List defaultT55xxKey() => _hex(defaultT55xxKeyHex);

List<Uint8List> defaultT55xxOldKeys() => <Uint8List>[
  for (final String hex in defaultT55xxOldKeyHex) _hex(hex),
];
