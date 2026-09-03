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
}
