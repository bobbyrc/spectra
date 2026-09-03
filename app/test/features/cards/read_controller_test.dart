import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/format/hex.dart';
import 'package:spectra/features/cards/state/read_controller.dart';
import 'package:spectra/features/cards/state/read_state.dart';
import 'package:spectra/features/cards/state/write_target.dart';
import 'package:spectra/features/dictionaries/dictionaries.dart';
import 'package:spectra/features/dictionaries/state/dictionaries_provider.dart';

import '../../support/app_harness.dart';

FakeDevice deviceWith({bool hf = true, bool lf = false}) {
  final FakeFirmware firmware = FakeFirmware();
  if (hf) {
    firmware.present(
      FakeMf1Card.classic1k(
        uid: Uint8List.fromList(<int>[0xDE, 0xAD, 0xBE, 0xEF]),
      ),
    );
  }
  if (lf) {
    firmware.present(
      FakeLfCard(3000, Uint8List.fromList(<int>[0x12, 0x34, 0x56, 0x78, 0x9A])),
    );
  }
  return FakeDevice(firmware: firmware);
}

void main() {
  Future<CardReader> connected(WidgetTester tester, FakeDevice device) async {
    useDesktopSurface(tester);
    await pumpTestApp(tester, transport: (_) => device);
    await connectToEmulator(tester);
    keepAlive(tester, cardReaderProvider);
    return readProvider(tester, cardReaderProvider.notifier);
  }

  testWidgetsApp('a MIFARE Classic read comes back complete', (tester) async {
    final CardReader reader = await connected(tester, deviceWith());

    // Ruling 22: start, pump, then await — the fake replies on a real timer.
    final Future<void> run = reader.readHf();
    await pumpFrames(tester, count: 40, step: const Duration(milliseconds: 50));
    await run;

    final ReadState state = readProvider(tester, cardReaderProvider);
    expect(state.busy, isFalse);
    expect(state.error, isNull);
    final CardReadResult result = state.result!;
    expect(result.tagType, TagType.mifare1k);
    expect(result.bytes, hasLength(64 * 16));
    expect(result.canSave, isTrue);
    expect(result.isPartial, isFalse);
    expect(result.totalChunks, 64);
    expect(result.readChunks, 64);
    expect(result.keysFound, 16);
    expect(
      result.fields.firstWhere((DumpField f) => f.label == 'UID').value,
      'DEADBEEF',
    );
  });

  testWidgetsApp('a sector with no working key makes a partial read', (
    tester,
  ) async {
    final FakeFirmware firmware = FakeFirmware();
    final FakeMf1Card card = FakeMf1Card.classic1k(
      uid: Uint8List.fromList(<int>[0xDE, 0xAD, 0xBE, 0xEF]),
    );
    // Sector 5 has neither key, so its four blocks cannot be read.
    card.keys.remove(FakeMf1Card.keyId(5, KeyType.a));
    card.keys.remove(FakeMf1Card.keyId(5, KeyType.b));
    firmware.present(card);
    final CardReader reader = await connected(
      tester,
      FakeDevice(firmware: firmware),
    );

    final Future<void> run = reader.readHf();
    await pumpFrames(tester, count: 40, step: const Duration(milliseconds: 50));
    await run;

    final ReadState state = readProvider(tester, cardReaderProvider);
    expect(state.error, isNull);
    final CardReadResult result = state.result!;
    expect(result.readChunks, 60);
    expect(result.totalChunks, 64);
    expect(result.keysFound, 15);
    expect(result.isPartial, isTrue);
  });

  testWidgetsApp(
    'the read takes its candidate keys from the selected dictionary',
    (tester) async {
      final CardReader reader = await connected(tester, deviceWith());
      keepAlive(tester, dictionaryLibraryProvider);
      keepAlive(tester, selectedDictionaryProvider);
      keepAlive(tester, candidateMifareKeysProvider);
      await pumpFrames(tester);
      final DictionaryLibrary library = readProvider(
        tester,
        dictionaryLibraryProvider.notifier,
      );

      // A one-key dictionary that does not include the demo card's real
      // key (FF FF FF FF FF FF — `deviceWith`'s `FakeMf1Card.classic1k`
      // default): nothing authenticates, so the read comes back fully
      // partial rather than complete.
      final Future<String?> created = library.create(
        'Wrong key',
        keys: <Uint8List>[parseMifareKey('714C5C886E97')!],
      );
      await pumpFrames(tester, count: 3);
      final String wrongKeyDictId = (await created)!;
      await pumpFrames(tester, count: 3);
      await readProvider(
        tester,
        selectedDictionaryIdProvider.notifier,
      ).select(wrongKeyDictId);
      await pumpFrames(tester, count: 3);

      final Future<void> partialRun = reader.readHf();
      await pumpFrames(
        tester,
        count: 40,
        step: const Duration(milliseconds: 50),
      );
      await partialRun;

      final CardReadResult partial = readProvider(
        tester,
        cardReaderProvider,
      ).result!;
      expect(partial.isPartial, isTrue);
      expect(partial.keysFound, 0);

      // Selecting the built-in list again makes the same read come back
      // complete — proof the keys really came from the selected
      // dictionary and not some cached default.
      await readProvider(
        tester,
        selectedDictionaryIdProvider.notifier,
      ).select(builtInDictionaryId);
      await pumpFrames(tester, count: 3);
      reader.reset();
      await pumpFrames(tester);

      final Future<void> fullRun = reader.readHf();
      await pumpFrames(
        tester,
        count: 40,
        step: const Duration(milliseconds: 50),
      );
      await fullRun;

      final CardReadResult full = readProvider(
        tester,
        cardReaderProvider,
      ).result!;
      expect(full.isPartial, isFalse);
      expect(full.keysFound, 16);
    },
  );

  testWidgetsApp('a full read patches the recovered keys into every trailer', (
    tester,
  ) async {
    final CardReader reader = await connected(tester, deviceWith());

    final Future<void> run = reader.readHf();
    await pumpFrames(tester, count: 40, step: const Duration(milliseconds: 50));
    await run;

    final CardReadResult result = readProvider(
      tester,
      cardReaderProvider,
    ).result!;
    // The card answers a trailer read with key A zeroed (real hardware, and
    // the fake since Phase 7's fix wave). The keys `mf1ReadDump` reports are
    // patched back in, so the stored dump is loadable and writable.
    for (int sector = 0; sector < 16; sector++) {
      final int trailer = MifareGeometry.trailerOf(sector) * 16;
      expect(
        result.bytes.sublist(trailer, trailer + 6),
        everyElement(0xFF),
        reason: 'sector \$sector key A',
      );
      expect(
        result.bytes.sublist(trailer + 10, trailer + 16),
        everyElement(0xFF),
        reason: 'sector \$sector key B',
      );
    }
    expect(unreadSectors(TagType.mifare1k, result.bytes), isEmpty);
  });

  testWidgetsApp('only a sector with no recovered key stays key-A zeroed', (
    tester,
  ) async {
    final FakeFirmware firmware = FakeFirmware();
    final FakeMf1Card card = FakeMf1Card.classic1k(
      uid: Uint8List.fromList(<int>[0xDE, 0xAD, 0xBE, 0xEF]),
    );
    // Sector 9's keys are not in the candidate list, so nothing is recovered
    // for it and its trailer keeps the zeros the read left behind.
    final Uint8List unknown = Uint8List.fromList(<int>[9, 9, 9, 9, 9, 9]);
    card.keys[FakeMf1Card.keyId(9, KeyType.a)] = unknown;
    card.keys[FakeMf1Card.keyId(9, KeyType.b)] = unknown;
    firmware.present(card);
    final CardReader reader = await connected(
      tester,
      FakeDevice(firmware: firmware),
    );

    final Future<void> run = reader.readHf();
    await pumpFrames(tester, count: 40, step: const Duration(milliseconds: 50));
    await run;

    final CardReadResult result = readProvider(
      tester,
      cardReaderProvider,
    ).result!;
    expect(unreadSectors(TagType.mifare1k, result.bytes), <int>[
      9,
    ], reason: 'exactly the sector whose key was never recovered');
    final int trailer = MifareGeometry.trailerOf(9) * 16;
    expect(result.bytes.sublist(trailer, trailer + 6), everyElement(0));
  });

  testWidgetsApp('an Ultralight in the field is identity only', (tester) async {
    final FakeFirmware firmware = FakeFirmware();
    firmware.present(
      FakeUltralightCard(
        uid: Uint8List.fromList(<int>[
          0x04,
          0x11,
          0x22,
          0x33,
          0x44,
          0x55,
          0x66,
        ]),
        pages: Uint8List(4 * 20),
      ),
    );
    final CardReader reader = await connected(
      tester,
      FakeDevice(firmware: firmware),
    );

    final Future<void> run = reader.readHf();
    await pumpFrames(tester, count: 40, step: const Duration(milliseconds: 50));
    await run;

    final ReadState state = readProvider(tester, cardReaderProvider);
    expect(state.error, isNull);
    final CardReadResult result = state.result!;
    expect(result.tagType, TagType.hf14a4);
    expect(result.bytes, isEmpty);
    expect(result.canSave, isFalse);
  });

  testWidgetsApp('no card in the field is a typed error, not a crash', (
    tester,
  ) async {
    final CardReader reader = await connected(tester, deviceWith(hf: false));

    final Future<void> run = reader.readHf();
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));
    await run;

    final ReadState state = readProvider(tester, cardReaderProvider);
    expect(state.busy, isFalse);
    expect(state.result, isNull);
    expect(state.error, isA<HfTagNotFound>());
  });

  testWidgetsApp('an EM410x read returns the five id bytes', (tester) async {
    final CardReader reader = await connected(
      tester,
      deviceWith(hf: false, lf: true),
    );

    final Future<void> run = reader.readLf();
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));
    await run;

    final CardReadResult result = readProvider(
      tester,
      cardReaderProvider,
    ).result!;
    expect(result.tagType, TagType.em410x);
    expect(result.bytes, <int>[0x12, 0x34, 0x56, 0x78, 0x9A]);
    expect(result.canSave, isTrue);
    expect(
      result.fields.single.value,
      '123456789A',
      reason: "Em410xFormat.describe emits one 'ID' field",
    );
  });

  testWidgetsApp('no LF card is a typed error', (tester) async {
    final CardReader reader = await connected(tester, deviceWith(hf: false));

    final Future<void> run = reader.readLf();
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));
    await run;

    expect(
      readProvider(tester, cardReaderProvider).error,
      isA<LfTagNotFound>(),
    );
  });

  testWidgetsApp('cancelling a dump ends in CommandCancelled', (tester) async {
    final FakeDevice device = deviceWith();
    device.latency = const Duration(milliseconds: 5);
    final CardReader reader = await connected(tester, device);

    final Future<void> run = reader.readHf();
    await tester.pump(const Duration(milliseconds: 20));
    reader.cancel();
    await pumpFrames(tester, count: 40, step: const Duration(milliseconds: 50));
    await run;

    final ReadState state = readProvider(tester, cardReaderProvider);
    expect(state.busy, isFalse);
    expect(state.error, isA<CommandCancelled>());
  });

  testWidgetsApp('a second read while one is running is dropped', (
    tester,
  ) async {
    final FakeDevice device = deviceWith();
    device.latency = const Duration(milliseconds: 2);
    final CardReader reader = await connected(tester, device);

    final Future<void> first = reader.readHf();
    await tester.pump(const Duration(milliseconds: 10));
    final Future<void> second = reader.readHf();
    await pumpFrames(tester, count: 60, step: const Duration(milliseconds: 50));
    await first;
    await second;

    expect(
      device.received.where((Frame f) => f.command == 2000).length,
      1,
      reason: 'HF14A_SCAN is 2000; the dropped call sent nothing',
    );
  });

  testWidgetsApp('reset clears the last result', (tester) async {
    final CardReader reader = await connected(tester, deviceWith());
    final Future<void> run = reader.readHf();
    await pumpFrames(tester, count: 40, step: const Duration(milliseconds: 50));
    await run;
    expect(readProvider(tester, cardReaderProvider).result, isNotNull);

    reader.reset();
    await tester.pump();
    expect(readProvider(tester, cardReaderProvider).result, isNull);
  });

  testWidgetsApp('reset cancels an in-flight read so it is not repopulated', (
    tester,
  ) async {
    final FakeDevice device = deviceWith();
    device.latency = const Duration(milliseconds: 5);
    final CardReader reader = await connected(tester, device);

    final Future<void> run = reader.readHf();
    await tester.pump(const Duration(milliseconds: 20));
    reader.reset();
    await pumpFrames(tester, count: 40, step: const Duration(milliseconds: 50));
    await run;

    // The device read that was in flight when `reset()` fired still runs to
    // completion (or CommandCancelled) on the wire, but must not repopulate
    // the state `reset()` already cleared.
    final ReadState state = readProvider(tester, cardReaderProvider);
    expect(state.busy, isFalse);
    expect(state.result, isNull);
    expect(state.error, isNull);
  });

  testWidgetsApp(
    'a read that lands after the notifier is disposed stays silent',
    (tester) async {
      final FakeDevice device = deviceWith();
      await pumpTestApp(tester, transport: (_) => device);
      await connectToEmulator(tester);

      final ProviderSubscription<ReadState> alive = keepAlive(
        tester,
        cardReaderProvider,
      );
      final CardReader reader = readProvider(
        tester,
        cardReaderProvider.notifier,
      );

      // Slow the fake down so the read is still in flight when the screen
      // goes away.
      device.latency = const Duration(milliseconds: 200);
      final Future<void> pending = reader.readHf();
      await tester.pump(const Duration(milliseconds: 20));

      // The user pressed Back: the autoDispose element is torn down while
      // the device read is still running.
      alive.close();
      await tester.pump();

      device.latency = Duration.zero;
      await pumpFrames(
        tester,
        count: 40,
        step: const Duration(milliseconds: 50),
      );
      // No UnmountedRefException: the notifier notices it is gone and
      // simply stops assigning state. The device read itself still
      // completes — disposing the screen does not cancel the command
      // already on the wire.
      await pending;
    },
  );

  testWidgetsApp('reading with no active session is a typed error', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await tester.pump();
    keepAlive(tester, cardReaderProvider);
    final CardReader reader = readProvider(tester, cardReaderProvider.notifier);

    await reader.readHf();

    expect(
      readProvider(tester, cardReaderProvider).error,
      isA<SessionNotReady>(),
    );
  });

  test('classicTypeForSak maps the five SAK values', () {
    expect(classicTypeForSak(0x09), TagType.mifareMini);
    expect(classicTypeForSak(0x08), TagType.mifare1k);
    expect(classicTypeForSak(0x19), TagType.mifare2k);
    expect(classicTypeForSak(0x18), TagType.mifare4k);
    expect(classicTypeForSak(0x88), TagType.mifare1k);
    expect(classicTypeForSak(0x00), TagType.undefined);
  });
}
