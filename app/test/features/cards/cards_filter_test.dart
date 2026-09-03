import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/features/cards/state/cards_filter.dart';

SavedCard card(String id, String name, {String? folder, int day = 1}) =>
    SavedCard(
      id: id,
      name: name,
      tagType: 'mifare1k',
      bytes: Uint8List(16),
      updatedAt: DateTime.utc(2026, 9, day),
      folder: folder,
    );

void main() {
  final List<SavedCard> cards = <SavedCard>[
    card('a', 'Office badge', folder: 'Work', day: 3),
    card('b', 'Gym', folder: 'Personal', day: 5),
    card('c', 'Hotel key', day: 1),
  ];

  test('no filter keeps everything, newest first', () {
    expect(
      filterCards(cards, const CardsFilter()).map((SavedCard c) => c.id),
      <String>['b', 'a', 'c'],
    );
  });

  test('the query matches name and folder, case-insensitively', () {
    expect(
      filterCards(
        cards,
        const CardsFilter(query: 'off'),
      ).map((SavedCard c) => c.id),
      <String>['a'],
    );
    expect(
      filterCards(
        cards,
        const CardsFilter(query: 'PERSONAL'),
      ).map((SavedCard c) => c.id),
      <String>['b'],
    );
    expect(filterCards(cards, const CardsFilter(query: 'zzz')), isEmpty);
  });

  test('the folder filter is exact', () {
    expect(
      filterCards(
        cards,
        const CardsFilter(folder: 'Work'),
      ).map((SavedCard c) => c.id),
      <String>['a'],
    );
  });

  test('sorting by name is case-insensitive and alphabetical', () {
    expect(
      filterCards(
        cards,
        const CardsFilter(sort: CardsSort.name),
      ).map((SavedCard c) => c.id),
      <String>['b', 'c', 'a'],
    );
  });

  test('folders are the distinct non-null ones, alphabetical', () {
    expect(foldersOf(cards), <String>['Personal', 'Work']);
  });

  test('copyWith clears the folder only when null is passed explicitly', () {
    const CardsFilter filter = CardsFilter(folder: 'Work', query: 'x');
    expect(filter.copyWith(query: 'y').folder, 'Work');
    expect(filter.copyWith(folder: null).folder, isNull);
  });
}
