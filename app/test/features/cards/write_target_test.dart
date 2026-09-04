import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/features/cards/state/write_target.dart';

void main() {
  group('slotLoadMethodFor', () {
    test('MIFARE Classic loads as blocks', () {
      expect(
        slotLoadMethodFor(TagType.mifare1k),
        SlotLoadMethod.mifareClassicBlocks,
      );
      expect(
        slotLoadMethodFor(TagType.mifare4k),
        SlotLoadMethod.mifareClassicBlocks,
      );
    });

    test('Ultralight/NTAG loads as pages', () {
      expect(
        slotLoadMethodFor(TagType.ntag215),
        SlotLoadMethod.ultralightPages,
      );
      expect(
        slotLoadMethodFor(TagType.mf0icu1),
        SlotLoadMethod.ultralightPages,
      );
    });

    test('em410x loads as an LF id', () {
      expect(slotLoadMethodFor(TagType.em410x), SlotLoadMethod.em410xId);
    });

    test('the other five emulatable LF types are unsupported (ruling 11)', () {
      expect(slotLoadMethodFor(TagType.hidProx), SlotLoadMethod.unsupported);
      expect(slotLoadMethodFor(TagType.viking), SlotLoadMethod.unsupported);
      expect(slotLoadMethodFor(TagType.pac), SlotLoadMethod.unsupported);
      expect(slotLoadMethodFor(TagType.jablotron), SlotLoadMethod.unsupported);
      expect(slotLoadMethodFor(TagType.idteck), SlotLoadMethod.unsupported);
    });

    test('undefined and ISO14443-4 are unsupported, not a guess', () {
      expect(slotLoadMethodFor(TagType.undefined), SlotLoadMethod.unsupported);
      expect(slotLoadMethodFor(TagType.hf14a4), SlotLoadMethod.unsupported);
      expect(slotLoadMethodFor(TagType.seos), SlotLoadMethod.unsupported);
    });
  });

  group('writeMethodFor', () {
    test('MIFARE Classic writes blocks and EM410x writes a T55xx', () {
      expect(
        writeMethodFor(TagType.mifare1k),
        CardWriteMethod.mifareClassicBlocks,
      );
      expect(writeMethodFor(TagType.em410x), CardWriteMethod.em410xT55xx);
    });

    test('Ultralight has no reader write in the SDK, so it is unsupported', () {
      expect(writeMethodFor(TagType.ntag215), CardWriteMethod.unsupported);
      expect(writeMethodFor(TagType.mf0icu1), CardWriteMethod.unsupported);
    });

    test('other LF types and undefined/ISO14443-4 are unsupported', () {
      expect(writeMethodFor(TagType.hidProx), CardWriteMethod.unsupported);
      expect(writeMethodFor(TagType.undefined), CardWriteMethod.unsupported);
      expect(writeMethodFor(TagType.hf14a4), CardWriteMethod.unsupported);
      expect(writeMethodFor(TagType.seos), CardWriteMethod.unsupported);
    });
  });

  group('expectedDumpLength', () {
    test('is the dump size the device expects', () {
      expect(expectedDumpLength(TagType.mifare1k), 64 * 16);
      expect(expectedDumpLength(TagType.mifare4k), 256 * 16);
      expect(expectedDumpLength(TagType.ntag215), 135 * 4);
      expect(expectedDumpLength(TagType.em410x), 5);
      expect(expectedDumpLength(TagType.hidProx), 0);
    });
  });

  group('slotNicknameFor', () {
    test('passes a short name through unchanged', () {
      expect(
        slotNicknameFor('Front door', fallbackLabel: 'EM410x'),
        'Front door',
      );
    });

    test('trims surrounding whitespace', () {
      expect(
        slotNicknameFor('  Front door  ', fallbackLabel: 'EM410x'),
        'Front door',
      );
    });

    test('truncates to 32 UTF-8 bytes', () {
      final String nick = slotNicknameFor('x' * 50, fallbackLabel: 'EM410x');
      expect(nick.length, 32);
    });

    test('never splits a multi-byte character', () {
      // 11 four-byte emoji is 44 bytes; 8 of them fit in 32.
      final String nick = slotNicknameFor('😀' * 11, fallbackLabel: 'EM410x');
      expect(nick, '😀' * 8);
    });

    test('falls back to the tag-type label for a blank name', () {
      expect(
        slotNicknameFor('', fallbackLabel: 'MIFARE Classic 1K'),
        'MIFARE Classic 1K',
      );
    });

    test('falls back for a whitespace-only name', () {
      expect(slotNicknameFor('   ', fallbackLabel: 'EM410x'), 'EM410x');
    });
  });

  group('antiCollForClassic', () {
    test('reads UID, SAK and ATQA out of block 0', () {
      final Uint8List blocks = Uint8List(64 * 16);
      blocks.setRange(0, 4, <int>[0xDE, 0xAD, 0xBE, 0xEF]);
      blocks[4] = 0xDE ^ 0xAD ^ 0xBE ^ 0xEF;
      blocks[5] = 0x08;
      blocks[6] = 0x04;
      blocks[7] = 0x00;

      final Hf14aTag tag = antiCollForClassic(blocks);
      expect(tag.uid, Uint8List.fromList(<int>[0xDE, 0xAD, 0xBE, 0xEF]));
      expect(tag.sak, 0x08);
      expect(tag.atqa, Uint8List.fromList(<int>[0x00, 0x04]));
      expect(tag.ats, isEmpty);
    });
  });

  group('unreadSectors', () {
    // A trailer's real shape: FF×6 key A, FF 07 80 69 access bits, FF×6
    // key B — the same layout `FakeMf1Card.classic1k` presents.
    Uint8List trailerBlock({List<int>? keyA}) => Uint8List.fromList(<int>[
      ...keyA ?? const <int>[0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF],
      0xFF,
      0x07,
      0x80,
      0x69,
      0xFF,
      0xFF,
      0xFF,
      0xFF,
      0xFF,
      0xFF,
    ]);

    Uint8List classicWith(Uint8List sector0Trailer) {
      final Uint8List blocks = Uint8List(64 * 16);
      // Sector 0's trailer is block 3.
      blocks.setRange(3 * 16, 4 * 16, sector0Trailer);
      // Every other sector keeps a normal, fully-known trailer so only
      // sector 0's flag depends on what the test passes in.
      for (int s = 1; s < 16; s++) {
        final int start = (s * 4 + 3) * 16;
        blocks.setRange(start, start + 16, trailerBlock());
      }
      return blocks;
    }

    test('an all-zero trailer is unread (never authenticated)', () {
      final Uint8List blocks = classicWith(Uint8List(16));
      expect(unreadSectors(TagType.mifare1k, blocks), <int>[0]);
    });

    test('key A zero with real key B and access bits is unread — the real '
        'shape of a read dump (ruling 27)', () {
      final Uint8List blocks = classicWith(
        trailerBlock(keyA: const <int>[0, 0, 0, 0, 0, 0]),
      );
      expect(unreadSectors(TagType.mifare1k, blocks), <int>[0]);
    });

    test('a real key A is read, not unread', () {
      final Uint8List blocks = classicWith(trailerBlock());
      expect(unreadSectors(TagType.mifare1k, blocks), isEmpty);
    });
  });
}
