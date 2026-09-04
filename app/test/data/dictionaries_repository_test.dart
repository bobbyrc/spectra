import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/data/database/drift_dictionaries_repository.dart';
import 'package:spectra/data/database/spectra_database.dart';
import 'package:spectra/data/memory/in_memory_repositories.dart';

Uint8List _key(int fill) => Uint8List.fromList(List<int>.filled(6, fill));

KeyDictionary _dict(String id, {String name = 'Keys', int fill = 0xFF}) =>
    KeyDictionary(
      id: id,
      name: name,
      keys: <Uint8List>[_key(fill)],
      updatedAt: DateTime.utc(2026, 9, 3),
    );

void main() {
  // Both implementations answer the same questions the same way; a test that
  // only exercised the in-memory one would prove nothing about what ships.
  for (final MapEntry<String, DictionariesRepository Function()> entry
      in <String, DictionariesRepository Function()>{
        'drift': () {
          final SpectraDatabase db = SpectraDatabase.memory();
          addTearDown(db.close);
          return DriftDictionariesRepository(db);
        },
        'in memory': InMemoryDictionariesRepository.new,
      }.entries) {
    group(entry.key, () {
      test('saves and reads back a dictionary, keys intact', () async {
        final DictionariesRepository repo = entry.value();
        await repo.save(_dict('a', name: 'Transport', fill: 0xA0));

        final List<KeyDictionary> all = await repo.all();
        expect(all, hasLength(1));
        expect(all.single.name, 'Transport');
        expect(all.single.keys.single, _key(0xA0));
        expect(all.single.updatedAt, DateTime.utc(2026, 9, 3));
      });

      test('save replaces an existing row', () async {
        final DictionariesRepository repo = entry.value();
        await repo.save(_dict('a', name: 'One'));
        await repo.save(_dict('a', name: 'Two'));

        final List<KeyDictionary> all = await repo.all();
        expect(all, hasLength(1));
        expect(all.single.name, 'Two');
      });

      test('orders newest-updated first', () async {
        final DictionariesRepository repo = entry.value();
        await repo.save(
          KeyDictionary(
            id: 'old',
            name: 'Old',
            keys: <Uint8List>[_key(1)],
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
        await repo.save(
          KeyDictionary(
            id: 'new',
            name: 'New',
            keys: <Uint8List>[_key(2)],
            updatedAt: DateTime.utc(2026, 6, 1),
          ),
        );

        expect((await repo.all()).map((KeyDictionary d) => d.id), <String>[
          'new',
          'old',
        ]);
      });

      test('delete removes exactly one row', () async {
        final DictionariesRepository repo = entry.value();
        await repo.save(_dict('a'));
        await repo.save(_dict('b'));
        await repo.delete('a');

        expect((await repo.all()).map((KeyDictionary d) => d.id), <String>[
          'b',
        ]);
      });

      test('watchAll emits the current rows, then every change', () async {
        final DictionariesRepository repo = entry.value();
        await repo.save(_dict('a'));

        final Stream<List<KeyDictionary>> stream = repo.watchAll();
        final Future<List<List<KeyDictionary>>> first2 = stream
            .take(2)
            .toList();
        await repo.save(_dict('b'));

        final List<List<KeyDictionary>> emitted = await first2;
        expect(emitted.first.map((KeyDictionary d) => d.id), <String>['a']);
        expect(emitted.last.map((KeyDictionary d) => d.id), hasLength(2));
      });

      test('all() and watchAll() both return a growable list', () async {
        final DictionariesRepository repo = entry.value();
        await repo.save(_dict('a'));

        // `DriftDictionariesRepository.watchAll()` used to build its list
        // with `growable: false` while `all()` did not — a caller that
        // sorted or otherwise mutated a `watchAll()` result in place would
        // throw only for that method, only on that implementation. Both
        // methods on both implementations must agree.
        (await repo.all()).add(_dict('b'));
        (await repo.watchAll().first).add(_dict('c'));
      });

      test(
        'an empty key list round-trips as empty, not as one blank key',
        () async {
          final DictionariesRepository repo = entry.value();
          await repo.save(
            KeyDictionary(
              id: 'empty',
              name: 'Empty',
              keys: const <Uint8List>[],
              updatedAt: DateTime.utc(2026, 9, 3),
            ),
          );
          expect((await repo.all()).single.keys, isEmpty);
        },
      );
    });
  }
}
