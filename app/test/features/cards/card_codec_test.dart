import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/features/cards/state/card_codec.dart';
import 'package:spectra/features/cards/state/hex.dart';
import 'package:spectra/features/dictionaries/dictionaries.dart';

SavedCard mini({Uint8List? bytes}) {
  final Uint8List blocks = bytes ?? Uint8List(20 * 16);
  if (bytes == null) {
    blocks.setRange(0, 4, <int>[0xDE, 0xAD, 0xBE, 0xEF]);
    blocks[4] = 0x22; // BCC of DE AD BE EF
  }
  return SavedCard(
    id: 'a',
    name: 'Mini',
    tagType: 'mifareMini',
    bytes: blocks,
    updatedAt: DateTime.utc(2026, 9, 3),
  );
}

void main() {
  group('hex', () {
    test('round-trips bytes', () {
      expect(toHex(<int>[0x0A, 0xFF]), '0AFF');
      expect(toHex(<int>[0x0A, 0xFF], separator: ' '), '0A FF');
      expect(parseHex('0aff'), <int>[0x0A, 0xFF]);
      expect(parseHex('0A FF'), <int>[0x0A, 0xFF]);
      expect(parseHex('0A:FF'), <int>[0x0A, 0xFF]);
    });

    test('rejects odd length and non-hex', () {
      expect(parseHex('0AF'), isNull);
      expect(parseHex('zz'), isNull);
      expect(parseHex(''), isEmpty);
    });
  });

  group('tag type names', () {
    test('round-trip through the stored string', () {
      expect(tagTypeName(TagType.mifare1k), 'mifare1k');
      expect(tagTypeFromName('mifare1k'), TagType.mifare1k);
      expect(tagTypeFromName('em410x'), TagType.em410x);
      expect(tagTypeFromName('nonsense'), TagType.undefined);
    });
  });

  group('saved card through the dump formats', () {
    test('describes a MIFARE Classic Mini', () {
      final List<DumpField> fields = describeSavedCard(mini());
      expect(
        fields.map((DumpField f) => f.label),
        containsAll(<String>['UID', 'Sectors']),
      );
      expect(
        fields.firstWhere((DumpField f) => f.label == 'UID').value,
        'DEADBEEF',
      );
    });

    test('validates length and BCC', () {
      expect(validateSavedCard(mini()), isEmpty);
      final Uint8List broken = Uint8List(20 * 16);
      broken.setRange(0, 4, <int>[0xDE, 0xAD, 0xBE, 0xEF]);
      broken[4] = 0x00;
      expect(validateSavedCard(mini(bytes: broken)), isNotEmpty);
    });

    test('an unsupported type is a problem, not a crash', () {
      final SavedCard seos = SavedCard(
        id: 'b',
        name: 'SEOS',
        tagType: 'seos',
        bytes: Uint8List(4),
        updatedAt: DateTime.utc(2026, 9, 3),
      );
      expect(parseSavedCard(seos), isNull);
      expect(describeSavedCard(seos), isEmpty);
      expect(validateSavedCard(seos), <String>['unsupported tag type']);
    });
  });

  group('chunking', () {
    test('one chunk is a block, a page or the whole LF id', () {
      expect(chunkSizeFor(TagType.mifare1k), 16);
      expect(chunkSizeFor(TagType.ntag215), 4);
      expect(chunkSizeFor(TagType.em410x), 5);
      expect(chunkSizeFor(TagType.seos), 0);
      expect(chunkCountFor(TagType.mifare1k, 64 * 16), 64);
      expect(chunkCountFor(TagType.seos, 16), 0);
    });
  });

  test('the default key list starts with the transport key', () {
    final List<Uint8List> keys = defaultMifareKeys();
    expect(keys.first, <int>[0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
    expect(keys.every((Uint8List k) => k.length == 6), isTrue);
    // Fresh copies: mutating one must not change the next call's list.
    keys.first[0] = 0;
    expect(defaultMifareKeys().first[0], 0xFF);
  });
}
