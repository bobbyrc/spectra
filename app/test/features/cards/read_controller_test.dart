import 'dart:typed_data';
import 'dart:ui';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/features/cards/state/read_controller.dart';
import 'package:spectra/features/cards/state/read_state.dart';

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
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpTestApp(tester, transport: (_) => device);
    await connectToEmulator(tester);
    keepAlive(tester, cardReaderProvider);
    return readProvider(tester, cardReaderProvider.notifier);
  }

  testWidgetsApp('a MIFARE Classic read comes back complete', (tester) async {
    final CardReader reader = await connected(tester, deviceWith());

    // Ruling 22: start, pump, then await — the fake replies on a real timer.
    final Future<void> run = reader.readHf();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
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

  testWidgetsApp('no card in the field is a typed error, not a crash', (
    tester,
  ) async {
    final CardReader reader = await connected(tester, deviceWith(hf: false));

    final Future<void> run = reader.readHf();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
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
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
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
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
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
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
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
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
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
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await run;
    expect(readProvider(tester, cardReaderProvider).result, isNotNull);

    reader.reset();
    await tester.pump();
    expect(readProvider(tester, cardReaderProvider).result, isNull);
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
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      // No UnmountedRefException: the notifier notices it is gone and
      // simply stops assigning state. The device read itself still
      // completes — disposing the screen does not cancel the command
      // already on the wire.
      await pending;
    },
  );

  test('classicTypeForSak maps the four SAK values', () {
    expect(classicTypeForSak(0x09), TagType.mifareMini);
    expect(classicTypeForSak(0x08), TagType.mifare1k);
    expect(classicTypeForSak(0x18), TagType.mifare4k);
    expect(classicTypeForSak(0x88), TagType.mifare1k);
    expect(classicTypeForSak(0x00), TagType.undefined);
  });
}
