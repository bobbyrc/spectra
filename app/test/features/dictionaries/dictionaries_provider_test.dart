import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/format/hex.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/features/dictionaries/state/built_in_keys.dart';
import 'package:spectra/features/dictionaries/state/dictionaries_provider.dart';
import 'package:spectra/features/dictionaries/state/dictionary_codec.dart';

import '../../support/app_harness.dart';

void main() {
  testWidgetsApp('the built-in list is first and is not a stored row', (
    tester,
  ) async {
    await pumpTestApp(tester);
    keepAlive(tester, dictionariesProvider);
    await pumpFrames(tester);

    final List<KeyDictionary> all = readProvider(
      tester,
      dictionariesProvider,
    ).value!;
    expect(all.first.id, builtInDictionaryId);
    expect(all.first.keys.map(toHex), defaultMifareKeyHex);
    expect(isBuiltIn(all.first), isTrue);

    // Nothing was written to make that true.
    final DictionariesRepository repo = readProvider(
      tester,
      dictionariesRepositoryProvider,
    );
    expect(await repo.all(), isEmpty);
  });

  testWidgetsApp('create adds a list and it appears after the built-in', (
    tester,
  ) async {
    await pumpTestApp(tester);
    keepAlive(tester, dictionariesProvider);
    keepAlive(tester, dictionaryLibraryProvider);
    await pumpFrames(tester);

    final DictionaryLibrary library = readProvider(
      tester,
      dictionaryLibraryProvider.notifier,
    );
    final Future<String?> pending = library.create('Hotel');
    await pumpFrames(tester, count: 3);
    expect(await pending, isNotNull);
    await pumpFrames(tester, count: 3);

    final List<KeyDictionary> all = readProvider(
      tester,
      dictionariesProvider,
    ).value!;
    expect(all.map((KeyDictionary d) => d.name), <String>['', 'Hotel']);
  });

  testWidgetsApp('rename, setKeys and remove write through', (tester) async {
    await pumpTestApp(tester);
    keepAlive(tester, dictionariesProvider);
    keepAlive(tester, dictionaryLibraryProvider);
    await pumpFrames(tester);

    final DictionaryLibrary library = readProvider(
      tester,
      dictionaryLibraryProvider.notifier,
    );
    final Future<String?> created = library.create('Hotel');
    await pumpFrames(tester, count: 3);
    final String id = (await created)!;
    await pumpFrames(tester, count: 3);

    KeyDictionary stored() => readProvider(
      tester,
      dictionariesProvider,
    ).value!.firstWhere((KeyDictionary d) => d.id == id);

    final Future<void> renamed = library.rename(stored(), 'Office');
    await pumpFrames(tester, count: 3);
    await renamed;
    await pumpFrames(tester, count: 3);
    expect(stored().name, 'Office');

    final Future<void> keyed = library.setKeys(stored(), <Uint8List>[
      parseMifareKey('A0A1A2A3A4A5')!,
    ]);
    await pumpFrames(tester, count: 3);
    await keyed;
    await pumpFrames(tester, count: 3);
    expect(stored().keys.map(toHex), <String>['A0A1A2A3A4A5']);

    final Future<void> removed = library.remove(id);
    await pumpFrames(tester, count: 3);
    await removed;
    await pumpFrames(tester, count: 3);
    expect(
      readProvider(
        tester,
        dictionariesProvider,
      ).value!.map((KeyDictionary d) => d.id),
      <String>[builtInDictionaryId],
    );
  });

  testWidgetsApp('duplicate copies the built-in into an editable list', (
    tester,
  ) async {
    await pumpTestApp(tester);
    keepAlive(tester, dictionariesProvider);
    keepAlive(tester, dictionaryLibraryProvider);
    await pumpFrames(tester);

    final DictionaryLibrary library = readProvider(
      tester,
      dictionaryLibraryProvider.notifier,
    );
    final Future<String?> pending = library.duplicate(
      builtInDictionary(),
      'My defaults',
    );
    await pumpFrames(tester, count: 3);
    final String id = (await pending)!;
    await pumpFrames(tester, count: 3);

    final KeyDictionary copy = readProvider(
      tester,
      dictionariesProvider,
    ).value!.firstWhere((KeyDictionary d) => d.id == id);
    expect(copy.name, 'My defaults');
    expect(copy.keys.map(toHex), defaultMifareKeyHex);
    expect(isBuiltIn(copy), isFalse);
  });

  testWidgetsApp('importText writes what it parsed', (tester) async {
    await pumpTestApp(tester);
    keepAlive(tester, dictionariesProvider);
    keepAlive(tester, dictionaryLibraryProvider);
    await pumpFrames(tester);

    final DictionaryLibrary library = readProvider(
      tester,
      dictionaryLibraryProvider.notifier,
    );
    final Future<ImportOutcome> pending = library.importText(
      'FFFFFFFFFFFF\nA0A1A2A3A4A5\n',
      fallbackName: 'Pasted',
    );
    await pumpFrames(tester, count: 3);
    final ImportOutcome outcome = await pending;
    await pumpFrames(tester, count: 3);

    expect(outcome.ok, isTrue);
    expect(outcome.written, 1);
    final KeyDictionary imported = readProvider(
      tester,
      dictionariesProvider,
    ).value!.last;
    expect(imported.name, 'Pasted');
    expect(imported.keys, hasLength(2));
  });

  testWidgetsApp('importText reports an unreadable paste and writes nothing', (
    tester,
  ) async {
    await pumpTestApp(tester);
    keepAlive(tester, dictionariesProvider);
    keepAlive(tester, dictionaryLibraryProvider);
    await pumpFrames(tester);

    final DictionaryLibrary library = readProvider(
      tester,
      dictionaryLibraryProvider.notifier,
    );
    final Future<ImportOutcome> pending = library.importText('nope');
    await pumpFrames(tester, count: 3);
    final ImportOutcome outcome = await pending;
    await pumpFrames(tester, count: 3);

    expect(outcome.ok, isFalse);
    expect(outcome.written, 0);
    expect(outcome.error, isA<DictionaryImportException>());
    expect(readProvider(tester, dictionariesProvider).value, hasLength(1));
  });

  testWidgetsApp('a second call while one is in flight is dropped', (
    tester,
  ) async {
    await pumpTestApp(tester);
    keepAlive(tester, dictionariesProvider);
    keepAlive(tester, dictionaryLibraryProvider);
    await pumpFrames(tester);

    final DictionaryLibrary library = readProvider(
      tester,
      dictionaryLibraryProvider.notifier,
    );
    final Future<String?> first = library.create('One');
    final Future<String?> second = library.create('Two');
    await pumpFrames(tester, count: 3);
    expect(await first, isNotNull);
    expect(await second, isNull, reason: 'dropped, not queued');
  });
}
