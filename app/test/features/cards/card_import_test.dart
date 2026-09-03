import 'dart:io';
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/features/cards/state/card_codec.dart';
import 'package:spectra/features/cards/state/card_import.dart';

void main() {
  test('imports the reference app fixture', () {
    final String text = File('test/fixtures/reference_card_mifare_mini.json')
        .readAsStringSync();
    final List<ImportedCard> cards = parseCardsJson(text);

    expect(cards, hasLength(1));
    final ImportedCard card = cards.single;
    expect(card.name, 'Reference Mini');
    expect(card.tagType, TagType.mifareMini);
    expect(card.bytes, hasLength(20 * 16));
    expect(card.bytes.sublist(0, 5), <int>[0xDE, 0xAD, 0xBE, 0xEF, 0x22]);
    expect(card.folder, 'Imported');
    expect(card.color, 4284790262);

    // The imported bytes are a valid dump, not just the right length.
    expect(
      validateSavedCard(
        SavedCard(
          id: 'x',
          name: card.name,
          tagType: tagTypeName(card.tagType),
          bytes: card.bytes,
          updatedAt: DateTime.utc(2026, 9, 3),
        ),
      ),
      isEmpty,
    );
  });

  test('imports a single object as well as a list', () {
    const String single =
        '{"name":"One","tag":"em410X","uid":"1234567890","data":[]}';
    final ImportedCard card = parseCardsJson(single).single;
    expect(card.tagType, TagType.em410x);
    expect(card.bytes, <int>[0x12, 0x34, 0x56, 0x78, 0x90]);
  });

  test('round-trips Spectra\'s own export', () {
    final SavedCard saved = SavedCard(
      id: 'a',
      name: 'Office badge',
      tagType: 'mifare1k',
      bytes: Uint8List(64 * 16)..[0] = 0xAB,
      updatedAt: DateTime.utc(2026, 9, 3),
      folder: 'Work',
      color: 0xFF4C8DFF,
    );
    final String text = exportCardsJson(<SavedCard>[saved]);
    expect(text, contains('"schemaVersion":$spectraCardSchemaVersion'));

    final ImportedCard back = parseCardsJson(text).single;
    expect(back.name, 'Office badge');
    expect(back.tagType, TagType.mifare1k);
    expect(back.bytes.length, 64 * 16);
    expect(back.bytes[0], 0xAB);
    expect(back.folder, 'Work');
    expect(back.color, 0xFF4C8DFF);
  });

  test('a non-JSON string is a typed problem', () {
    expect(
      () => parseCardsJson('not json at all'),
      throwsA(
        isA<CardImportException>().having(
          (CardImportException e) => e.problem,
          'problem',
          CardImportProblem.notJson,
        ),
      ),
    );
  });

  test('an empty list is a typed problem', () {
    expect(
      () => parseCardsJson('[]'),
      throwsA(
        isA<CardImportException>().having(
          (CardImportException e) => e.problem,
          'problem',
          CardImportProblem.noCards,
        ),
      ),
    );
  });

  test('a tag type Spectra has no format for is refused by name', () {
    expect(
      () => parseCardsJson('{"name":"x","tag":"iso15693","data":[]}'),
      throwsA(
        isA<CardImportException>()
            .having(
              (CardImportException e) => e.problem,
              'problem',
              CardImportProblem.unsupportedTagType,
            )
            .having(
              (CardImportException e) => e.detail,
              'detail',
              contains('iso15693'),
            ),
      ),
    );
  });

  test('non-hex data is refused', () {
    expect(
      () => parseCardsJson('{"name":"x","tag":"mifare1K","data":["zzzz"]}'),
      throwsA(
        isA<CardImportException>().having(
          (CardImportException e) => e.problem,
          'problem',
          CardImportProblem.badBytes,
        ),
      ),
    );
  });
}
