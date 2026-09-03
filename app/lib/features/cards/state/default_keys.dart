import 'dart:typed_data';

/// The MIFARE Classic default-key list moved to
/// `features/dictionaries/state/built_in_keys.dart` in Phase 9 — a feature
/// may not import another feature's internals, so `defaultMifareKeyHex`/
/// `defaultMifareKeys()` live there now, in front of
/// `DictionariesRepository`'s stored rows as a synthesized read-only
/// dictionary. The T55xx passwords below stay here: they are a write-path
/// concern (`ReaderFacade.em410xWriteToT55xx`) with no dictionary UI in v1.
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

/// A fresh copy each call, so a caller mutating a key cannot poison the
/// next write.
Uint8List defaultT55xxKey() => _hex(defaultT55xxKeyHex);

List<Uint8List> defaultT55xxOldKeys() => <Uint8List>[
  for (final String hex in defaultT55xxOldKeyHex) _hex(hex),
];
