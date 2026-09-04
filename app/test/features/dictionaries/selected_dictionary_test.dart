import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/format/hex.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/features/dictionaries/state/built_in_keys.dart';
import 'package:spectra/features/dictionaries/state/dictionaries_provider.dart';
import 'package:spectra/features/dictionaries/state/selected_dictionary.dart';

import '../../support/app_harness.dart';

void main() {
  testWidgetsApp('defaults to the built-in list', (tester) async {
    await pumpTestApp(tester);
    keepAlive(tester, selectedDictionaryProvider);
    keepAlive(tester, candidateMifareKeysProvider);
    await pumpFrames(tester);

    expect(
      readProvider(tester, selectedDictionaryProvider).value!.id,
      builtInDictionaryId,
    );
    expect(
      readProvider(tester, candidateMifareKeysProvider).value!.map(toHex),
      defaultMifareKeyHex,
    );
  });

  testWidgetsApp('selecting a list changes the candidate keys and persists', (
    tester,
  ) async {
    await pumpTestApp(tester);
    keepAlive(tester, selectedDictionaryProvider);
    keepAlive(tester, candidateMifareKeysProvider);
    keepAlive(tester, dictionaryLibraryProvider);
    await pumpFrames(tester);

    final DictionaryLibrary library = readProvider(
      tester,
      dictionaryLibraryProvider.notifier,
    );
    final Future<String?> created = library.create(
      'Hotel',
      keys: <Uint8List>[parseMifareKey('714C5C886E97')!],
    );
    await pumpFrames(tester, count: 3);
    final String id = (await created)!;
    await pumpFrames(tester, count: 3);

    final Future<void> selected = readProvider(
      tester,
      selectedDictionaryIdProvider.notifier,
    ).select(id);
    await pumpFrames(tester, count: 3);
    await selected;
    await pumpFrames(tester, count: 3);

    expect(readProvider(tester, selectedDictionaryProvider).value!.id, id);
    expect(
      readProvider(tester, candidateMifareKeysProvider).value!.map(toHex),
      <String>['714C5C886E97'],
    );
    expect(
      await readProvider(
        tester,
        preferencesRepositoryProvider,
      ).read(SelectedDictionaryId.preferenceKey),
      id,
    );
  });

  testWidgetsApp('falls back to the built-in list when the selection is gone', (
    tester,
  ) async {
    await pumpTestApp(tester);
    keepAlive(tester, selectedDictionaryProvider);
    await pumpFrames(tester);

    final Future<void> selected = readProvider(
      tester,
      selectedDictionaryIdProvider.notifier,
    ).select('deleted-list');
    await pumpFrames(tester, count: 3);
    await selected;
    await pumpFrames(tester, count: 3);

    expect(
      readProvider(tester, selectedDictionaryProvider).value!.id,
      builtInDictionaryId,
    );
  });

  testWidgetsApp('an empty list still gives a read something to try', (
    tester,
  ) async {
    await pumpTestApp(tester);
    keepAlive(tester, candidateMifareKeysProvider);
    keepAlive(tester, dictionaryLibraryProvider);
    await pumpFrames(tester);

    final DictionaryLibrary library = readProvider(
      tester,
      dictionaryLibraryProvider.notifier,
    );
    final Future<String?> created = library.create('Empty');
    await pumpFrames(tester, count: 3);
    final String id = (await created)!;
    await pumpFrames(tester, count: 3);

    final Future<void> selected = readProvider(
      tester,
      selectedDictionaryIdProvider.notifier,
    ).select(id);
    await pumpFrames(tester, count: 3);
    await selected;
    await pumpFrames(tester, count: 3);

    expect(readProvider(tester, candidateMifareKeysProvider).value, isNotEmpty);
  });
}
