import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/data/database/drift_saved_cards_repository.dart';
import 'package:spectra/data/database/spectra_database.dart';
import 'package:spectra/data/memory/in_memory_repositories.dart';

SavedCard card(String id, {String name = 'Card', int day = 1}) => SavedCard(
  id: id,
  name: name,
  tagType: 'mifare1k',
  bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
  updatedAt: DateTime.utc(2026, 9, day),
  folder: 'Work',
  color: 0xFF4488FF,
);

void main() {
  for (final (String label, SavedCardsRepository Function() make)
      in <(String, SavedCardsRepository Function())>[
        (
          'drift',
          () {
            final SpectraDatabase db = SpectraDatabase.memory();
            addTearDown(db.close);
            return DriftSavedCardsRepository(db);
          },
        ),
        ('in memory', InMemorySavedCardsRepository.new),
      ]) {
    group(label, () {
      test('saves, reads back and deletes a card', () async {
        final SavedCardsRepository repo = make();
        await repo.save(card('a', name: 'Office badge'));

        final SavedCard? read = await repo.byId('a');
        expect(read, isNotNull);
        expect(read!.name, 'Office badge');
        expect(read.tagType, 'mifare1k');
        expect(read.bytes, <int>[1, 2, 3, 4]);
        expect(read.folder, 'Work');
        expect(read.color, 0xFF4488FF);

        await repo.delete('a');
        expect(await repo.byId('a'), isNull);
        expect(await repo.all(), isEmpty);
      });

      test('saving the same id twice replaces the row', () async {
        final SavedCardsRepository repo = make();
        await repo.save(card('a', name: 'First'));
        await repo.save(card('a', name: 'Second'));
        expect(await repo.all(), hasLength(1));
        expect((await repo.byId('a'))!.name, 'Second');
      });

      test('all() is newest-updated first', () async {
        final SavedCardsRepository repo = make();
        await repo.save(card('old', name: 'Old', day: 1));
        await repo.save(card('new', name: 'New', day: 9));
        expect((await repo.all()).map((SavedCard c) => c.id), <String>[
          'new',
          'old',
        ]);
      });

      test('watchAll() emits the current rows and then every change', () async {
        final SavedCardsRepository repo = make();
        await repo.save(card('a'));
        final Stream<List<SavedCard>> stream = repo.watchAll();
        final Future<List<List<SavedCard>>> collected = stream.take(2).toList();
        await repo.save(card('b'));
        final List<List<SavedCard>> emissions = await collected;
        expect(emissions.first.map((SavedCard c) => c.id), <String>['a']);
        expect(emissions.last.map((SavedCard c) => c.id).toSet(), <String>{
          'a',
          'b',
        });
      });
    });
  }
}
