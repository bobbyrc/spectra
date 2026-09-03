import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/format/hex.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/features/dictionaries/state/dictionary_codec.dart';

void main() {
  group('parseDictionaries', () {
    test('reads a plain .dic list, one key per line', () {
      final List<ImportedDictionary> out = parseDictionaries(
        '# mfoc-style comment\n'
        'FFFFFFFFFFFF\n'
        'a0a1a2a3a4a5\n'
        '\n',
      );
      expect(out, hasLength(1));
      expect(out.single.name, isNull);
      expect(out.single.keys.map(toHex), <String>[
        'FFFFFFFFFFFF',
        'A0A1A2A3A4A5',
      ]);
    });

    test('reads the reference app export fixture', () {
      final String text = File('test/fixtures/reference_dictionary.json')
          .readAsStringSync();

      final List<ImportedDictionary> out = parseDictionaries(text);
      expect(out.map((ImportedDictionary d) => d.name), <String>[
        'Transport',
        'Hotel',
      ]);
      expect(out.first.keys, hasLength(3));
      expect(toHex(out.first.keys[1]), 'A0A1A2A3A4A5');
    });

    test('reads a bare object with a keys list', () {
      final List<ImportedDictionary> out = parseDictionaries(
        '{"name":"One","keys":["FFFFFFFFFFFF"]}',
      );
      expect(out.single.name, 'One');
      expect(out.single.keys, hasLength(1));
    });

    test('reads a JSON list of dictionaries', () {
      final List<ImportedDictionary> out = parseDictionaries(
        '[{"name":"A","keys":["FFFFFFFFFFFF"]},'
        '{"name":"B","keys":["000000000000"]}]',
      );
      expect(out, hasLength(2));
    });

    test('round-trips Spectra own export', () {
      final KeyDictionary dictionary = KeyDictionary(
        id: 'x',
        name: 'Mine',
        keys: <Uint8List>[parseMifareKey('B0B1B2B3B4B5')!],
        updatedAt: DateTime.utc(2026, 9, 3),
      );

      final List<ImportedDictionary> back = parseDictionaries(
        exportDictionariesJson(<KeyDictionary>[dictionary]),
      );
      expect(back.single.name, 'Mine');
      expect(toHex(back.single.keys.single), 'B0B1B2B3B4B5');
    });

    test('a .dic export round-trips through the line reader', () {
      final KeyDictionary dictionary = KeyDictionary(
        id: 'x',
        name: 'Mine',
        keys: <Uint8List>[parseMifareKey('B0B1B2B3B4B5')!],
        updatedAt: DateTime.utc(2026, 9, 3),
      );
      expect(
        parseDictionaries(exportDictionaryDic(dictionary)).single.keys.single,
        dictionary.keys.single,
      );
    });

    test('rejects a line that is not a key', () {
      expect(
        () => parseDictionaries('FFFFFFFFFFFF\nnot-a-key\n'),
        throwsA(
          isA<DictionaryImportException>().having(
            (DictionaryImportException e) => e.problem,
            'problem',
            DictionaryImportProblem.badKey,
          ),
        ),
      );
    });

    test('rejects a key of the wrong length', () {
      expect(
        () => parseDictionaries('{"keys":["FFFFFFFF"]}'),
        throwsA(
          isA<DictionaryImportException>().having(
            (DictionaryImportException e) => e.problem,
            'problem',
            DictionaryImportProblem.badKey,
          ),
        ),
      );
    });

    test('rejects JSON that holds no keys at all', () {
      expect(
        () => parseDictionaries('{"dictionaries":[]}'),
        throwsA(
          isA<DictionaryImportException>().having(
            (DictionaryImportException e) => e.problem,
            'problem',
            DictionaryImportProblem.noKeys,
          ),
        ),
      );
    });

    test('rejects empty text', () {
      expect(
        () => parseDictionaries('   \n\n'),
        throwsA(
          isA<DictionaryImportException>().having(
            (DictionaryImportException e) => e.problem,
            'problem',
            DictionaryImportProblem.noKeys,
          ),
        ),
      );
    });

    test('rejects JSON of a shape it does not understand', () {
      expect(
        () => parseDictionaries('{"dictionaries":{"a":1}}'),
        throwsA(
          isA<DictionaryImportException>().having(
            (DictionaryImportException e) => e.problem,
            'problem',
            DictionaryImportProblem.notReadable,
          ),
        ),
      );
    });
  });

  group('exportDictionariesJson', () {
    test('is versioned and lists keys as upper-case hex', () {
      final Map<String, Object?> decoded = jsonDecode(
        exportDictionariesJson(<KeyDictionary>[
          KeyDictionary(
            id: 'x',
            name: 'Mine',
            keys: <Uint8List>[parseMifareKey('aabbccddeeff')!],
            updatedAt: DateTime.utc(2026, 9, 3),
          ),
        ]),
      ) as Map<String, Object?>;
      expect(decoded['schemaVersion'], spectraDictionarySchemaVersion);
      final List<Object?> list = decoded['dictionaries']! as List<Object?>;
      final Map<String, Object?> first = list.single! as Map<String, Object?>;
      expect(first['keys'], <String>['AABBCCDDEEFF']);
    });
  });
}
