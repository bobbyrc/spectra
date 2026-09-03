import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/app.dart';
import 'package:spectra/core/errors/app_failures.dart';
import 'package:spectra/features/cards/state/load_to_slot_controller.dart';
import 'package:spectra/features/slots/slots.dart';

import '../../support/app_harness.dart';
import 'card_fixtures.dart';

Future<SlotLoader> openLoader(WidgetTester tester) async {
  useDesktopSurface(tester);
  await pumpTestApp(tester, transport: (_) => FakeDevice());
  await connectToEmulator(tester);
  keepAlive(tester, slotLoaderProvider);
  keepAlive(tester, slotViewsProvider);
  await pumpFrames(tester);
  return readProvider(tester, slotLoaderProvider.notifier);
}

/// Runs [pending] to completion, corrupting the emulation memory the load
/// just wrote as soon as the write command [writeCommand] has been sent.
///
/// This is how the verification step is put under test without a device
/// that lies: the slot's stored bytes are made to diverge from the bytes
/// the load handed it, which is exactly the condition `SlotLoader._load`
/// raises `SlotLoadVerificationFailed` for. The mutation is timed off
/// `FakeDevice.received` — the request frame is recorded synchronously by
/// `write()` — so it lands after the data write and before the read-back,
/// with no reliance on how many pumps either takes.
Future<void> corruptAfterWrite(
  WidgetTester tester,
  FakeDevice device,
  Future<void> pending,
  int writeCommand,
  void Function(FakeSlot slot) corrupt,
) async {
  bool done = false;
  for (int i = 0; i < 200; i++) {
    await tester.pump(const Duration(milliseconds: 10));
    if (!done && device.received.any((Frame f) => f.command == writeCommand)) {
      corrupt(device.firmware.slot);
      done = true;
    }
  }
  expect(done, isTrue, reason: 'the load never sent command $writeCommand');
  await pending;
}

void main() {
  testWidgetsApp('loads a MIFARE Classic dump into a slot and verifies it', (
    tester,
  ) async {
    final SlotLoader loader = await openLoader(tester);

    final Future<void> pending = loader.load(
      slotIndex: 2,
      type: TagType.mifare1k,
      bytes: classic1kFilled(),
      name: 'Office badge',
      fallbackLabel: 'MIFARE Classic 1K',
    );
    await pumpFrames(tester, count: 30);
    await pending;
    await pumpFrames(tester);

    final SlotLoadState state = readProvider(tester, slotLoaderProvider);
    expect(state.done, isTrue);
    expect(state.busy, isFalse);
    expect(state.error, isNull);
    expect(state.unreadSectors, isNull);
    expect(state.progress, 1);

    final List<SlotView> views = readProvider(tester, slotViewsProvider);
    expect(views[2].slot.hfType, TagType.mifare1k);
    expect(views[2].slot.hfNick, 'Office badge');
    expect(views[2].slot.hfEnabled, isTrue);
    expect(views[2].isActive, isTrue);
  });

  testWidgetsApp('reports progress through the load', (tester) async {
    final SlotLoader loader = await openLoader(tester);

    final List<double> seen = <double>[];
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(SpectraRoot)),
      listen: false,
    );
    final ProviderSubscription<SlotLoadState> sub = container.listen(
      slotLoaderProvider,
      (SlotLoadState? previous, SlotLoadState next) {
        if (next.progress != null) seen.add(next.progress!);
      },
    );
    addTearDown(sub.close);

    final Future<void> pending = loader.load(
      slotIndex: 3,
      type: TagType.mifare1k,
      bytes: classic1kFilled(),
      name: 'Progress test',
      fallbackLabel: 'MIFARE Classic 1K',
    );
    await pumpFrames(tester, count: 30);
    await pending;
    await pumpFrames(tester);

    expect(seen, isNotEmpty);
    expect(seen.first, lessThan(1));
    expect(seen.last, 1);
    // Monotonically non-decreasing: the bar never runs backward.
    for (int i = 1; i < seen.length; i++) {
      expect(seen[i], greaterThanOrEqualTo(seen[i - 1]));
    }
  });

  testWidgetsApp('loads an EM410x id into a slot', (tester) async {
    final SlotLoader loader = await openLoader(tester);

    final Future<void> pending = loader.load(
      slotIndex: 4,
      type: TagType.em410x,
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4, 5]),
      name: 'Gate fob',
      fallbackLabel: 'EM410x',
    );
    await pumpFrames(tester, count: 30);
    await pending;
    await pumpFrames(tester);

    final SlotLoadState state = readProvider(tester, slotLoaderProvider);
    expect(state.done, isTrue);
    final List<SlotView> views = readProvider(tester, slotViewsProvider);
    expect(views[4].slot.lfType, TagType.em410x);
    expect(views[4].slot.lfNick, 'Gate fob');
  });

  testWidgetsApp('loads an NTAG215 dump into a slot', (tester) async {
    final SlotLoader loader = await openLoader(tester);
    final Uint8List pages = ntag215Pages();

    final Future<void> pending = loader.load(
      slotIndex: 6,
      type: TagType.ntag215,
      bytes: pages,
      name: 'Hotel key',
      fallbackLabel: 'NTAG215',
    );
    await pumpFrames(tester, count: 30);
    await pending;
    await pumpFrames(tester);

    final SlotLoadState state = readProvider(tester, slotLoaderProvider);
    expect(state.error, isNull);
    expect(state.done, isTrue);
    // No `setAntiColl`: the firmware derives the emulated anti-collision
    // answer from pages 0-2 of the data itself
    // (`SlotLoadMethod.ultralightPages`).
    final List<SlotView> views = readProvider(tester, slotViewsProvider);
    expect(views[6].slot.hfType, TagType.ntag215);
    expect(views[6].slot.hfNick, 'Hotel key');
    expect(views[6].slot.hfEnabled, isTrue);
  });

  group('a read-back that disagrees with the dump fails verification', () {
    testWidgetsApp('MIFARE Classic, through readMf1Blocks', (tester) async {
      // Real latency, so the load's commands land across several pumps and
      // the corruption can be timed between two of them; with the default
      // zero latency the whole load resolves inside one pump.
      final FakeDevice device = FakeDevice(
        latency: const Duration(milliseconds: 20),
      );
      useDesktopSurface(tester);
      await pumpTestApp(tester, transport: (_) => device);
      await connectToEmulator(tester);
      keepAlive(tester, slotLoaderProvider);
      keepAlive(tester, slotViewsProvider);
      await pumpFrames(tester);
      final SlotLoader loader = readProvider(
        tester,
        slotLoaderProvider.notifier,
      );

      await corruptAfterWrite(
        tester,
        device,
        loader.load(
          slotIndex: 2,
          type: TagType.mifare1k,
          bytes: classic1kFilled(),
          name: 'Office badge',
          fallbackLabel: 'MIFARE Classic 1K',
        ),
        4000, // MF1_WRITE_EMU_BLOCK_DATA
        (FakeSlot slot) => slot.mf1Blocks[32] ^= 0xFF,
      );

      final SlotLoadState state = readProvider(tester, slotLoaderProvider);
      expect(state.done, isFalse);
      expect(state.error, isA<SlotLoadVerificationFailed>());
      expect(
        (state.error! as SlotLoadVerificationFailed).what,
        'the emulated blocks',
      );
    });

    testWidgetsApp('NTAG215, through readNtagPages', (tester) async {
      // Real latency, so the load's commands land across several pumps and
      // the corruption can be timed between two of them; with the default
      // zero latency the whole load resolves inside one pump.
      final FakeDevice device = FakeDevice(
        latency: const Duration(milliseconds: 20),
      );
      useDesktopSurface(tester);
      await pumpTestApp(tester, transport: (_) => device);
      await connectToEmulator(tester);
      keepAlive(tester, slotLoaderProvider);
      keepAlive(tester, slotViewsProvider);
      await pumpFrames(tester);
      final SlotLoader loader = readProvider(
        tester,
        slotLoaderProvider.notifier,
      );

      await corruptAfterWrite(
        tester,
        device,
        loader.load(
          slotIndex: 6,
          type: TagType.ntag215,
          bytes: ntag215Pages(),
          name: 'Hotel key',
          fallbackLabel: 'NTAG215',
        ),
        4022, // MF0_NTAG_WRITE_EMU_PAGE_DATA
        (FakeSlot slot) => slot.ntagPages[40] ^= 0xFF,
      );

      final SlotLoadState state = readProvider(tester, slotLoaderProvider);
      expect(state.done, isFalse);
      expect(
        (state.error! as SlotLoadVerificationFailed).what,
        'the emulated pages',
      );
    });

    testWidgetsApp('EM410x, through getLfId', (tester) async {
      // Real latency, so the load's commands land across several pumps and
      // the corruption can be timed between two of them; with the default
      // zero latency the whole load resolves inside one pump.
      final FakeDevice device = FakeDevice(
        latency: const Duration(milliseconds: 20),
      );
      useDesktopSurface(tester);
      await pumpTestApp(tester, transport: (_) => device);
      await connectToEmulator(tester);
      keepAlive(tester, slotLoaderProvider);
      keepAlive(tester, slotViewsProvider);
      await pumpFrames(tester);
      final SlotLoader loader = readProvider(
        tester,
        slotLoaderProvider.notifier,
      );

      await corruptAfterWrite(
        tester,
        device,
        loader.load(
          slotIndex: 4,
          type: TagType.em410x,
          bytes: Uint8List.fromList(<int>[1, 2, 3, 4, 5]),
          name: 'Gate fob',
          fallbackLabel: 'EM410x',
        ),
        5000, // SET_EM410X_EMU_ID
        (FakeSlot slot) => slot.lfIds[5000]![0] ^= 0xFF,
      );

      final SlotLoadState state = readProvider(tester, slotLoaderProvider);
      expect(state.done, isFalse);
      expect(
        (state.error! as SlotLoadVerificationFailed).what,
        'the stored id',
      );
    });
  });

  testWidgetsApp('an unsupported type never touches the device', (
    tester,
  ) async {
    final SlotLoader loader = await openLoader(tester);

    final Future<void> pending = loader.load(
      slotIndex: 1,
      type: TagType.hidProx,
      bytes: Uint8List(13),
      name: 'Badge',
      fallbackLabel: 'HID Prox',
    );
    await pumpFrames(tester);
    await pending;

    final SlotLoadState state = readProvider(tester, slotLoaderProvider);
    expect(state.unsupported, isTrue);
    expect(state.done, isFalse);
    expect(state.error, isNull);
    final List<SlotView> views = readProvider(tester, slotViewsProvider);
    expect(views[1].slot.lfType, TagType.undefined);
  });

  testWidgetsApp('a dump of the wrong length is refused before any write', (
    tester,
  ) async {
    final SlotLoader loader = await openLoader(tester);

    final Future<void> pending = loader.load(
      slotIndex: 1,
      type: TagType.mifare1k,
      bytes: Uint8List(32),
      name: 'Short',
      fallbackLabel: 'MIFARE Classic 1K',
    );
    await pumpFrames(tester);
    await pending;

    final SlotLoadState state = readProvider(tester, slotLoaderProvider);
    expect(state.error, isA<CardDumpLengthMismatch>());
    final CardDumpLengthMismatch failure =
        state.error! as CardDumpLengthMismatch;
    expect(failure.type, TagType.mifare1k);
    expect(failure.expected, 1024);
    expect(failure.actual, 32);
    final List<SlotView> views = readProvider(tester, slotViewsProvider);
    expect(views[1].slot.hfType, TagType.undefined);
  });

  testWidgetsApp(
    'unread sector trailers are refused until explicitly confirmed',
    (tester) async {
      final SlotLoader loader = await openLoader(tester);
      final Uint8List dataOnly = classic1kDataOnly();

      final Future<void> refused = loader.load(
        slotIndex: 5,
        type: TagType.mifare1k,
        bytes: dataOnly,
        name: 'Unread sectors',
        fallbackLabel: 'MIFARE Classic 1K',
      );
      await pumpFrames(tester);
      await refused;

      final SlotLoadState refusedState = readProvider(
        tester,
        slotLoaderProvider,
      );
      expect(refusedState.unreadSectors, isNotNull);
      expect(refusedState.unreadSectors, isNotEmpty);
      expect(refusedState.busy, isFalse);
      expect(refusedState.done, isFalse);
      expect(refusedState.error, isNull);
      final List<SlotView> beforeConfirm = readProvider(
        tester,
        slotViewsProvider,
      );
      expect(beforeConfirm[5].slot.hfType, TagType.undefined);

      final Future<void> confirmed = loader.load(
        slotIndex: 5,
        type: TagType.mifare1k,
        bytes: dataOnly,
        name: 'Unread sectors',
        fallbackLabel: 'MIFARE Classic 1K',
        confirmUnread: true,
      );
      await pumpFrames(tester, count: 30);
      await confirmed;
      await pumpFrames(tester);

      final SlotLoadState confirmedState = readProvider(
        tester,
        slotLoaderProvider,
      );
      expect(confirmedState.done, isTrue);
      expect(confirmedState.error, isNull);
      final List<SlotView> afterConfirm = readProvider(
        tester,
        slotViewsProvider,
      );
      expect(afterConfirm[5].slot.hfType, TagType.mifare1k);
    },
  );

  testWidgetsApp('a long card name is truncated to a legal nickname', (
    tester,
  ) async {
    final SlotLoader loader = await openLoader(tester);

    final Future<void> pending = loader.load(
      slotIndex: 0,
      type: TagType.mifare1k,
      bytes: classic1kFilled(),
      name: 'y' * 60,
      fallbackLabel: 'MIFARE Classic 1K',
    );
    await pumpFrames(tester, count: 30);
    await pending;
    await pumpFrames(tester);

    final List<SlotView> views = readProvider(tester, slotViewsProvider);
    expect(views[0].slot.hfNick.length, 32);
  });

  testWidgetsApp('a blank card name falls back to the tag-type label', (
    tester,
  ) async {
    final SlotLoader loader = await openLoader(tester);

    final Future<void> pending = loader.load(
      slotIndex: 6,
      type: TagType.mifare1k,
      bytes: classic1kFilled(),
      name: '   ',
      fallbackLabel: 'MIFARE Classic 1K',
    );
    await pumpFrames(tester, count: 30);
    await pending;
    await pumpFrames(tester);

    final List<SlotView> views = readProvider(tester, slotViewsProvider);
    expect(views[6].slot.hfNick, 'MIFARE Classic 1K');
  });

  testWidgetsApp('reset clears a failure so the sheet can offer it again', (
    tester,
  ) async {
    final SlotLoader loader = await openLoader(tester);
    loader.debugFail(const SessionNotReady('nope'));
    await pumpFrames(tester, count: 2);
    expect(readProvider(tester, slotLoaderProvider).error, isNotNull);

    loader.reset();
    await pumpFrames(tester, count: 2);
    final SlotLoadState state = readProvider(tester, slotLoaderProvider);
    expect(state.error, isNull);
    expect(state.unreadSectors, isNull);
  });

  testWidgetsApp('a load that outlives its provider stays silent', (
    tester,
  ) async {
    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await connectToEmulator(tester);
    final ProviderSubscription<SlotLoadState> sub = keepAlive(
      tester,
      slotLoaderProvider,
    );
    final SlotLoader loader = readProvider(tester, slotLoaderProvider.notifier);

    final Future<void> pending = loader.load(
      slotIndex: 7,
      type: TagType.em410x,
      bytes: Uint8List.fromList(<int>[9, 9, 9, 9, 9]),
      name: 'Disposed mid-load',
      fallbackLabel: 'EM410x',
    );
    // Dispose the notifier while the write is still on the wire.
    sub.close();
    await pumpFrames(tester, count: 30);

    // The write itself must not throw even though nothing is left to
    // report its outcome to.
    await pending;
  });
}
