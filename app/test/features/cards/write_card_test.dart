import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/app.dart';
import 'package:spectra/core/emulator/demo_cards.dart';
import 'package:spectra/core/errors/app_failures.dart';
import 'package:spectra/core/errors/problem_view.dart';
import 'package:spectra/features/cards/state/write_card_controller.dart';
import 'package:spectra/features/cards/ui/write_card_sheet.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';
import 'card_fixtures.dart';

/// [classic1kFilled] (or [classic1kDataOnly]) with its non-trailer blocks
/// overwritten to [fill], so a test can tell "the card now holds what was
/// written" apart from "the card already held this". Not a second fixture
/// (ruling 8): it transforms the one shared fixture rather than declaring
/// another `classic1k`.
Uint8List _withDataFill(Uint8List blocks, int fill) {
  final Uint8List out = Uint8List.fromList(blocks);
  for (int block = 1; block < 64; block++) {
    if (block % 4 == 3) continue; // Leave trailers alone.
    out.fillRange(block * 16, block * 16 + 16, fill);
  }
  return out;
}

/// The app with the emulated device's scripted cards in the reader's field
/// (`core/emulator/demo_cards.dart`), which is what the production transport
/// factory hands the fake device anyway. `demoMifareUid` matches
/// `card_fixtures.dart`'s default UID, so a shared-fixture dump lines up
/// with the field card without a per-test UID override.
Future<CardWriter> openWriter(WidgetTester tester) async {
  useDesktopSurface(tester);
  await pumpTestApp(tester, transport: (_) => buildEmulatedDevice());
  await connectToEmulator(tester);
  keepAlive(tester, cardWriterProvider);
  await pumpFrames(tester);
  return readProvider(tester, cardWriterProvider.notifier);
}

/// A fresh app with a single [FakeMf1Card] in the field, returning the
/// writer *and* the card object itself so a test can read the card's own
/// bytes back after a write — not just the result masks — to prove the
/// write actually landed on the card.
Future<(CardWriter, FakeMf1Card)> openWriterWithMf1Card(
  WidgetTester tester,
) async {
  useDesktopSurface(tester);
  final FakeMf1Card card = FakeMf1Card.classic1k(uid: demoMifareUid);
  final FakeFirmware firmware = FakeFirmware()..present(card);
  await pumpTestApp(tester, transport: (_) => FakeDevice(firmware: firmware));
  await connectToEmulator(tester);
  keepAlive(tester, cardWriterProvider);
  await pumpFrames(tester);
  return (readProvider(tester, cardWriterProvider.notifier), card);
}

/// A fresh app with a single [FakeLfCard] in the field (EM410X_SCAN, command
/// id 3000 — the same id `demo_cards.dart` scripts), returning the writer
/// and the card so a test can read its id bytes back after a write.
Future<(CardWriter, FakeLfCard)> openWriterWithLfCard(
  WidgetTester tester,
  Uint8List startingId,
) async {
  useDesktopSurface(tester);
  final FakeLfCard card = FakeLfCard(3000, startingId);
  final FakeFirmware firmware = FakeFirmware()..present(card);
  await pumpTestApp(tester, transport: (_) => FakeDevice(firmware: firmware));
  await connectToEmulator(tester);
  keepAlive(tester, cardWriterProvider);
  await pumpFrames(tester);
  return (readProvider(tester, cardWriterProvider.notifier), card);
}

void main() {
  testWidgetsApp('writes a MIFARE Classic dump onto the card in the field', (
    tester,
  ) async {
    final (CardWriter writer, FakeMf1Card card) = await openWriterWithMf1Card(
      tester,
    );
    final Uint8List dump = _withDataFill(classic1kFilled(), 0x7E);

    final Future<void> pending = writer.write(
      type: TagType.mifare1k,
      bytes: dump,
    );
    await pumpFrames(tester, count: 40);
    await pending;
    await pumpFrames(tester);

    final CardWriteState state = readProvider(tester, cardWriterProvider);
    expect(state.error, isNull);
    expect(state.cancelled, isFalse);
    expect(state.busy, isFalse);
    expect(state.attempted, 47); // 64 blocks less block 0 and 16 trailers.
    expect(state.written, 47);
    // The card itself now holds what was written, not just the masks that
    // say so: block 0 and every trailer were already identical between
    // [card] and [dump] (same UID, same default trailer), so this is a
    // whole-card comparison, not just the data blocks.
    expect(card.blocks, dump);
  });

  testWidgetsApp('trailers are skipped by default', (tester) async {
    final CardWriter writer = await openWriter(tester);

    final Future<void> pending = writer.write(
      type: TagType.mifare1k,
      bytes: _withDataFill(classic1kFilled(), 0x11),
    );
    await pumpFrames(tester, count: 40);
    await pending;
    await pumpFrames(tester);

    expect(readProvider(tester, cardWriterProvider).attempted, 47);
  });

  testWidgetsApp('trailers go on when the caller opts in', (tester) async {
    final CardWriter writer = await openWriter(tester);

    final Future<void> pending = writer.write(
      type: TagType.mifare1k,
      bytes: _withDataFill(classic1kFilled(), 0x22),
      writeTrailers: true,
    );
    await pumpFrames(tester, count: 40);
    await pending;
    await pumpFrames(tester);

    final CardWriteState state = readProvider(tester, cardWriterProvider);
    expect(state.error, isNull);
    // 64 blocks less block 0 only: all 16 trailers now attempted too.
    expect(state.attempted, 63);
    expect(state.written, 63);
  });

  testWidgetsApp(
    'a data-only dump with trailers opted in is refused until confirmed',
    (tester) async {
      final CardWriter writer = await openWriter(tester);
      final Uint8List dataOnly = classic1kDataOnly();

      final Future<void> refused = writer.write(
        type: TagType.mifare1k,
        bytes: dataOnly,
        writeTrailers: true,
      );
      await pumpFrames(tester);
      await refused;

      final CardWriteState refusedState = readProvider(
        tester,
        cardWriterProvider,
      );
      expect(refusedState.unreadSectors, isNotNull);
      expect(refusedState.unreadSectors, isNotEmpty);
      expect(refusedState.busy, isFalse);
      expect(refusedState.error, isNull);
      expect(refusedState.isDone, isFalse);

      final Future<void> confirmed = writer.write(
        type: TagType.mifare1k,
        bytes: dataOnly,
        writeTrailers: true,
        confirmUnread: true,
      );
      await pumpFrames(tester, count: 40);
      await confirmed;
      await pumpFrames(tester);

      final CardWriteState confirmedState = readProvider(
        tester,
        cardWriterProvider,
      );
      expect(confirmedState.error, isNull);
      expect(confirmedState.unreadSectors, isNull);
      expect(confirmedState.attempted, 63);
    },
  );

  testWidgetsApp(
    'a real read dump (key A zeroed, key B and access bits intact) with '
    'trailers opted in is refused too (ruling 27)',
    (tester) async {
      final CardWriter writer = await openWriter(tester);
      final Uint8List keyAZeroed = classic1kKeyAZeroed();

      final Future<void> refused = writer.write(
        type: TagType.mifare1k,
        bytes: keyAZeroed,
        writeTrailers: true,
      );
      await pumpFrames(tester);
      await refused;

      final CardWriteState state = readProvider(tester, cardWriterProvider);
      expect(state.unreadSectors, isNotNull);
      expect(state.unreadSectors, isNotEmpty);
      expect(state.error, isNull);
      expect(state.isDone, isFalse);
    },
  );

  testWidgetsApp(
    'a data-only dump with default trailers-off never asks for confirmation',
    (tester) async {
      final CardWriter writer = await openWriter(tester);

      final Future<void> pending = writer.write(
        type: TagType.mifare1k,
        bytes: classic1kDataOnly(),
      );
      await pumpFrames(tester, count: 40);
      await pending;
      await pumpFrames(tester);

      final CardWriteState state = readProvider(tester, cardWriterProvider);
      expect(state.unreadSectors, isNull);
      expect(state.error, isNull);
      expect(state.attempted, 47);
    },
  );

  testWidgetsApp('a sector with no working key is a partial result', (
    tester,
  ) async {
    useDesktopSurface(tester);
    final FakeMf1Card card = FakeMf1Card.classic1k(uid: demoMifareUid);
    card.keys[FakeMf1Card.keyId(1, KeyType.a)] = Uint8List.fromList(<int>[
      9,
      9,
      9,
      9,
      9,
      9,
    ]);
    card.keys[FakeMf1Card.keyId(1, KeyType.b)] = Uint8List.fromList(<int>[
      9,
      9,
      9,
      9,
      9,
      9,
    ]);
    final FakeFirmware firmware = FakeFirmware()..present(card);
    await pumpTestApp(tester, transport: (_) => FakeDevice(firmware: firmware));
    await connectToEmulator(tester);
    keepAlive(tester, cardWriterProvider);
    await pumpFrames(tester);
    final CardWriter writer = readProvider(tester, cardWriterProvider.notifier);

    final Future<void> pending = writer.write(
      type: TagType.mifare1k,
      bytes: _withDataFill(classic1kFilled(), 0x5A),
    );
    await pumpFrames(tester, count: 40);
    await pending;
    await pumpFrames(tester);

    final CardWriteState state = readProvider(tester, cardWriterProvider);
    expect(state.error, isNull);
    expect(state.attempted, 47);
    expect(state.written, 44); // Sector 1's three data blocks failed.
    expect(state.isPartial, isTrue);
  });

  testWidgetsApp('a device missing MF1_WRITE_ONE_BLOCK is a typed error', (
    tester,
  ) async {
    useDesktopSurface(tester);
    final Set<int> capabilities = FakeFirmwareConfig.defaultCapabilities(
      DeviceModel.ultra,
    )..remove(2009);
    final FakeFirmware firmware = FakeFirmware(
      FakeFirmwareConfig(capabilities: capabilities),
    )..present(FakeMf1Card.classic1k(uid: demoMifareUid));
    await pumpTestApp(tester, transport: (_) => FakeDevice(firmware: firmware));
    await connectToEmulator(tester);
    keepAlive(tester, cardWriterProvider);
    await pumpFrames(tester);
    final CardWriter writer = readProvider(tester, cardWriterProvider.notifier);

    final Future<void> pending = writer.write(
      type: TagType.mifare1k,
      bytes: classic1kFilled(),
    );
    await pumpFrames(tester, count: 40);
    await pending;
    await pumpFrames(tester);

    final CardWriteState state = readProvider(tester, cardWriterProvider);
    expect(state.error, isA<InvalidCommand>());
    expect(state.cancelled, isFalse);
    expect(state.unsupported, isFalse);
  });

  testWidgetsApp('cancelling mid-write is a terminal cancelled state', (
    tester,
  ) async {
    final CardWriter writer = await openWriter(tester);

    // Cancel as soon as the first sector's progress lands, the same way
    // `reader_write_test.dart` cancels mid-write from `onProgress`.
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(SpectraRoot)),
      listen: false,
    );
    final ProviderSubscription<CardWriteState> sub = container.listen(
      cardWriterProvider,
      (CardWriteState? previous, CardWriteState next) {
        if (next.progress != null) writer.cancel();
      },
    );
    addTearDown(sub.close);

    final Future<void> pending = writer.write(
      type: TagType.mifare1k,
      bytes: _withDataFill(classic1kFilled(), 0x9C),
    );
    await pumpFrames(tester, count: 40);
    await pending;
    await pumpFrames(tester);

    final CardWriteState state = readProvider(tester, cardWriterProvider);
    expect(state.cancelled, isTrue);
    expect(state.error, isNull);
    expect(state.busy, isFalse);
  });

  testWidgetsApp('reports progress through the write', (tester) async {
    final CardWriter writer = await openWriter(tester);

    final List<double> seen = <double>[];
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(SpectraRoot)),
      listen: false,
    );
    final ProviderSubscription<CardWriteState> sub = container.listen(
      cardWriterProvider,
      (CardWriteState? previous, CardWriteState next) {
        if (next.progress != null) seen.add(next.progress!);
      },
    );
    addTearDown(sub.close);

    final Future<void> pending = writer.write(
      type: TagType.mifare1k,
      bytes: _withDataFill(classic1kFilled(), 0x10),
    );
    await pumpFrames(tester, count: 40);
    await pending;
    await pumpFrames(tester);

    expect(seen, isNotEmpty);
    expect(seen.last, 1);
    for (int i = 1; i < seen.length; i++) {
      expect(seen[i], greaterThanOrEqualTo(seen[i - 1]));
    }
  });

  testWidgetsApp('writes an EM410x id to the T55xx in the field', (
    tester,
  ) async {
    final Uint8List startingId = Uint8List.fromList(<int>[
      0x11,
      0x22,
      0x33,
      0x44,
      0x55,
    ]);
    final Uint8List newId = Uint8List.fromList(<int>[
      0xAA,
      0xBB,
      0xCC,
      0xDD,
      0xEE,
    ]);
    final (CardWriter writer, FakeLfCard card) = await openWriterWithLfCard(
      tester,
      startingId,
    );

    final Future<void> pending = writer.write(
      type: TagType.em410x,
      bytes: newId,
    );
    await pumpFrames(tester, count: 20);
    await pending;
    await pumpFrames(tester);

    final CardWriteState state = readProvider(tester, cardWriterProvider);
    expect(state.error, isNull);
    expect(state.written, 1);
    expect(state.attempted, 1);
    // The card's own id changed, not just the result masks.
    expect(card.idBytes, newId);
  });

  testWidgetsApp('an Ultralight dump is a typed unsupported state', (
    tester,
  ) async {
    final CardWriter writer = await openWriter(tester);

    final Future<void> pending = writer.write(
      type: TagType.ntag215,
      bytes: Uint8List(135 * 4),
    );
    await pumpFrames(tester);
    await pending;

    final CardWriteState state = readProvider(tester, cardWriterProvider);
    expect(state.unsupported, isTrue);
    expect(state.error, isNull);
  });

  testWidgetsApp('a dump of the wrong length is refused before any write', (
    tester,
  ) async {
    final CardWriter writer = await openWriter(tester);

    final Future<void> pending = writer.write(
      type: TagType.mifare1k,
      bytes: Uint8List(32),
    );
    await pumpFrames(tester);
    await pending;

    final CardWriteState state = readProvider(tester, cardWriterProvider);
    expect(state.error, isA<CardDumpLengthMismatch>());
    final CardDumpLengthMismatch failure =
        state.error! as CardDumpLengthMismatch;
    expect(failure.type, TagType.mifare1k);
    expect(failure.expected, 1024);
    expect(failure.actual, 32);
  });

  testWidgetsApp('no card in the field is the typed LfTagNotFound', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await connectToEmulator(tester);
    keepAlive(tester, cardWriterProvider);
    await pumpFrames(tester);
    final CardWriter writer = readProvider(tester, cardWriterProvider.notifier);

    final Future<void> pending = writer.write(
      type: TagType.em410x,
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4, 5]),
    );
    await pumpFrames(tester, count: 20);
    await pending;
    await pumpFrames(tester);

    expect(
      readProvider(tester, cardWriterProvider).error,
      isA<LfTagNotFound>(),
    );
  });

  testWidgetsApp('reset clears a failure', (tester) async {
    final CardWriter writer = await openWriter(tester);
    writer.debugFail(const LfTagNotFound());
    await pumpFrames(tester, count: 2);
    expect(readProvider(tester, cardWriterProvider).error, isNotNull);

    writer.reset();
    await pumpFrames(tester, count: 2);
    final CardWriteState state = readProvider(tester, cardWriterProvider);
    expect(state.error, isNull);
    expect(state.cancelled, isFalse);
    expect(state.unreadSectors, isNull);
  });

  testWidgetsApp('a write that outlives its provider stays silent', (
    tester,
  ) async {
    await pumpTestApp(tester, transport: (_) => buildEmulatedDevice());
    await connectToEmulator(tester);
    final ProviderSubscription<CardWriteState> sub = keepAlive(
      tester,
      cardWriterProvider,
    );
    final CardWriter writer = readProvider(tester, cardWriterProvider.notifier);

    final Future<void> pending = writer.write(
      type: TagType.mifare1k,
      bytes: _withDataFill(classic1kFilled(), 0x44),
    );
    // Dispose the notifier while the write is still on the wire.
    sub.close();
    await pumpFrames(tester, count: 40);

    // The write itself must not throw even though nothing is left to
    // report its outcome to.
    await pending;
  });

  group('the sheet', () {
    testWidgetsApp('warns, writes and summarises', (tester) async {
      await openWriter(tester);
      final BuildContext context = tester.element(find.byType(SpectraAppShell));

      final Future<bool?> pending = showWriteToCardSheet(
        context,
        type: TagType.mifare1k,
        bytes: _withDataFill(classic1kFilled(), 0x66),
        name: 'Office badge',
      );
      await pumpFrames(tester);
      expect(
        find.text(
          'Writing to a physical card has not been checked on real hardware '
          'yet. Use a card you can afford to lose.',
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(SpectraBottomSheet),
          matching: find.text('Write'),
        ),
      );
      await pumpFrames(tester, count: 40);
      expect(find.text('47 of 47 blocks written.'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(SpectraBottomSheet),
          matching: find.text('Close'),
        ),
      );
      await pumpFrames(tester);
      expect(await pending, isTrue);
    });

    testWidgetsApp('says so for a type it cannot write', (tester) async {
      await openWriter(tester);
      final BuildContext context = tester.element(find.byType(SpectraAppShell));

      final Future<bool?> pending = showWriteToCardSheet(
        context,
        type: TagType.ntag215,
        bytes: Uint8List(135 * 4),
        name: 'Tag',
      );
      await pumpFrames(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(SpectraBottomSheet),
          matching: find.text('Write'),
        ),
      );
      await pumpFrames(tester);
      expect(
        find.text('Spectra cannot write this tag type onto a card yet.'),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(SpectraBottomSheet),
          matching: find.text('Close'),
        ),
      );
      await pumpFrames(tester);
      expect(await pending, isNull);
    });

    testWidgetsApp('a failure lands in the shared ProblemView', (tester) async {
      final CardWriter writer = await openWriter(tester);
      final BuildContext context = tester.element(find.byType(SpectraAppShell));

      final Future<bool?> pending = showWriteToCardSheet(
        context,
        type: TagType.mifare1k,
        bytes: _withDataFill(classic1kFilled(), 0x66),
        name: 'Office badge',
      );
      await pumpFrames(tester);
      writer.debugFail(const HfTagNotFound());
      await pumpFrames(tester);
      expect(
        find.descendant(
          of: find.byType(SpectraBottomSheet),
          matching: find.byType(ProblemView),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.close));
      await pumpFrames(tester);
      await pending;
    });
  });
}
