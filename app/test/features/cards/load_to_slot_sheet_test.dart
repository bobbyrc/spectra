import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/core/errors/app_failures.dart';
import 'package:spectra/core/errors/problem_view.dart';
import 'package:spectra/features/cards/state/load_to_slot_controller.dart';
import 'package:spectra/features/cards/ui/load_to_slot_sheet.dart';
import 'package:spectra/features/slots/slots.dart';
import 'package:spectra/features/tools/ui/update_page.dart';
import 'package:spectra_ui/spectra_ui.dart';

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

/// Like [openLoader], but the fake device replies with real latency
/// (`FakeDevice.latency`, zero by default) so a UI-driven test can tap into
/// the sheet while a load is still in flight (ruling 22) instead of racing a
/// load that would otherwise finish inside a single pump.
Future<SlotLoader> openSlowLoader(
  WidgetTester tester, {
  Duration latency = const Duration(milliseconds: 50),
}) async {
  useDesktopSurface(tester);
  await pumpTestApp(tester, transport: (_) => FakeDevice(latency: latency));
  await connectToEmulator(tester);
  keepAlive(tester, slotLoaderProvider);
  keepAlive(tester, slotViewsProvider);
  await pumpFrames(tester);
  return readProvider(tester, slotLoaderProvider.notifier);
}

Finder _inSheet(Finder matching) =>
    find.descendant(of: find.byType(SpectraBottomSheet), matching: matching);

void main() {
  testWidgetsApp('confirms, loads and reports done', (tester) async {
    await openLoader(tester);
    final BuildContext context = tester.element(find.byType(SpectraAppShell));

    final Future<bool?> pending = showLoadToSlotSheet(
      context,
      slotIndex: 2,
      type: TagType.mifare1k,
      bytes: classic1kFilled(),
      name: 'Office badge',
    );
    await pumpFrames(tester);
    expect(find.text('Load into slot 3'), findsOneWidget);
    expect(_inSheet(find.text('MIFARE Classic 1K')), findsOneWidget);
    expect(
      _inSheet(find.text('Slot 3 becomes the slot the device emulates.')),
      findsOneWidget,
    );

    await tester.tap(_inSheet(find.text('Load')));
    await pumpFrames(tester, count: 30);
    expect(_inSheet(find.text('Loaded into slot 3.')), findsOneWidget);

    final List<SlotView> views = readProvider(tester, slotViewsProvider);
    expect(views[2].slot.hfType, TagType.mifare1k);
    expect(views[2].slot.hfNick, 'Office badge');
    expect(views[2].slot.hfEnabled, isTrue);

    await tester.tap(_inSheet(find.text('Close')));
    await pumpFrames(tester);
    expect(await pending, isTrue);
  });

  testWidgetsApp('says so for a type it cannot emulate, and touches nothing', (
    tester,
  ) async {
    await openLoader(tester);
    final BuildContext context = tester.element(find.byType(SpectraAppShell));

    // Slot 0 is the fake device's factory default (`FakeFirmware`'s
    // constructor prefills it), so an untouched slot for this assertion is
    // slot 1.
    final Future<bool?> pending = showLoadToSlotSheet(
      context,
      slotIndex: 1,
      type: TagType.hidProx,
      bytes: Uint8List(13),
      name: 'Badge',
    );
    await pumpFrames(tester);
    await tester.tap(_inSheet(find.text('Load')));
    await pumpFrames(tester);
    expect(
      _inSheet(find.text('Spectra cannot emulate this tag type yet.')),
      findsOneWidget,
    );

    final List<SlotView> views = readProvider(tester, slotViewsProvider);
    expect(views[1].slot.lfType, TagType.undefined);

    await tester.tap(_inSheet(find.text('Close')));
    await pumpFrames(tester);
    expect(await pending, isNull);
  });

  testWidgetsApp('a dismissal before confirming writes nothing', (
    tester,
  ) async {
    await openLoader(tester);
    final BuildContext context = tester.element(find.byType(SpectraAppShell));

    final Future<bool?> pending = showLoadToSlotSheet(
      context,
      slotIndex: 1,
      type: TagType.mifare1k,
      bytes: classic1kFilled(),
      name: 'Never loaded',
    );
    await pumpFrames(tester);

    await tester.tap(find.byIcon(Icons.close));
    await pumpFrames(tester);
    expect(await pending, isNull);

    final List<SlotView> views = readProvider(tester, slotViewsProvider);
    expect(views[1].slot.hfType, TagType.undefined);
  });

  testWidgetsApp(
    'shows a verification failure through the shared ProblemView',
    (tester) async {
      final SlotLoader loader = await openLoader(tester);
      final BuildContext context = tester.element(find.byType(SpectraAppShell));

      final Future<bool?> pending = showLoadToSlotSheet(
        context,
        slotIndex: 0,
        type: TagType.mifare1k,
        bytes: classic1kFilled(),
        name: 'Office badge',
      );
      await pumpFrames(tester);
      loader.debugFail(const SlotLoadVerificationFailed('the emulated blocks'));
      await pumpFrames(tester);

      expect(_inSheet(find.byType(ProblemView)), findsOneWidget);

      // `find.text` matches the whole string, so 'Load' finds the confirm
      // button and not the sheet's 'Load into slot 1' title.
      await tester.tap(_inSheet(find.text('Try again')));
      await pumpFrames(tester);
      expect(_inSheet(find.text('Load')), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await pumpFrames(tester);
      await pending;
    },
  );

  testWidgetsApp('a wrong-length dump shows its message with no retry action', (
    tester,
  ) async {
    final SlotLoader loader = await openLoader(tester);
    final BuildContext context = tester.element(find.byType(SpectraAppShell));

    final Future<bool?> pending = showLoadToSlotSheet(
      context,
      slotIndex: 0,
      type: TagType.mifare1k,
      bytes: classic1kFilled(),
      name: 'Office badge',
    );
    await pumpFrames(tester);
    loader.debugFail(
      const CardDumpLengthMismatch(
        type: TagType.mifare1k,
        expected: 1024,
        actual: 32,
      ),
    );
    await pumpFrames(tester);

    // Recovery `none`: no `ProblemView`/"Try again" — a plain message and
    // a close, since the dump's length will not change on a retry.
    expect(_inSheet(find.byType(ProblemView)), findsNothing);
    expect(_inSheet(find.text('Try again')), findsNothing);
    expect(_inSheet(find.text('Close')), findsOneWidget);

    await tester.tap(_inSheet(find.text('Close')));
    await pumpFrames(tester);
    expect(await pending, isNull);
  });

  testWidgetsApp(
    'unread sector trailers warn by name and need an explicit confirm',
    (tester) async {
      await openLoader(tester);
      final BuildContext context = tester.element(find.byType(SpectraAppShell));

      final Future<bool?> pending = showLoadToSlotSheet(
        context,
        slotIndex: 5,
        type: TagType.mifare1k,
        bytes: classic1kDataOnly(),
        name: 'Unread sectors',
      );
      await pumpFrames(tester);
      await tester.tap(_inSheet(find.text('Load')));
      await pumpFrames(tester);

      // Nothing was sent to the device yet.
      List<SlotView> views = readProvider(tester, slotViewsProvider);
      expect(views[5].slot.hfType, TagType.undefined);
      expect(
        _inSheet(find.text('Some sectors have no known key')),
        findsOneWidget,
      );
      // `classic1kDataOnly` zeros every sector's trailer, so the plural
      // form of `cardsLoadUnreadSectorsBody` is what actually renders.
      expect(
        _inSheet(find.textContaining('were never read; they will load blank.')),
        findsOneWidget,
      );

      await tester.tap(_inSheet(find.text('Load anyway')));
      await pumpFrames(tester, count: 30);
      expect(_inSheet(find.text('Loaded into slot 6.')), findsOneWidget);

      views = readProvider(tester, slotViewsProvider);
      expect(views[5].slot.hfType, TagType.mifare1k);

      await tester.tap(_inSheet(find.text('Close')));
      await pumpFrames(tester);
      expect(await pending, isTrue);
    },
  );

  testWidgetsApp('the unread-sector warning offers a way back to confirm', (
    tester,
  ) async {
    await openLoader(tester);
    final BuildContext context = tester.element(find.byType(SpectraAppShell));

    final Future<bool?> pending = showLoadToSlotSheet(
      context,
      slotIndex: 5,
      type: TagType.mifare1k,
      bytes: classic1kDataOnly(),
      name: 'Unread sectors',
    );
    await pumpFrames(tester);
    await tester.tap(_inSheet(find.text('Load')));
    await pumpFrames(tester);
    expect(
      _inSheet(find.text('Some sectors have no known key')),
      findsOneWidget,
    );

    // Review I3: 'Load anyway' was the only button, so a user who did not
    // want to load blank sectors had to dismiss the sheet.
    await tester.tap(_inSheet(find.text('Cancel')));
    await pumpFrames(tester);
    expect(_inSheet(find.text('Some sectors have no known key')), findsNothing);
    expect(_inSheet(find.text('Load')), findsOneWidget);

    // Nothing reached the device.
    final List<SlotView> views = readProvider(tester, slotViewsProvider);
    expect(views[5].slot.hfType, TagType.undefined);

    await tester.tap(_inSheet(find.byIcon(Icons.close)));
    await pumpFrames(tester);
    expect(await pending, isNull);
  });

  testWidgetsApp('opening the sheet a second time resets the previous run', (
    tester,
  ) async {
    await openLoader(tester);
    final BuildContext context = tester.element(find.byType(SpectraAppShell));

    final Future<bool?> first = showLoadToSlotSheet(
      context,
      slotIndex: 3,
      type: TagType.mifare1k,
      bytes: classic1kFilled(),
      name: 'First load',
    );
    await pumpFrames(tester);
    await tester.tap(_inSheet(find.text('Load')));
    await pumpFrames(tester, count: 30);
    expect(_inSheet(find.text('Loaded into slot 4.')), findsOneWidget);
    await tester.tap(_inSheet(find.text('Close')));
    await pumpFrames(tester);
    expect(await first, isTrue);

    final Future<bool?> second = showLoadToSlotSheet(
      context,
      slotIndex: 6,
      type: TagType.mifare1k,
      bytes: classic1kFilled(),
      name: 'Second load',
    );
    await pumpFrames(tester);
    // Ruling 5: the confirm card is back, not the first load's "done".
    expect(_inSheet(find.text('Loaded into slot 4.')), findsNothing);
    expect(_inSheet(find.text('Load')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await pumpFrames(tester);
    expect(await second, isNull);
  });

  testWidgetsApp(
    'a firmware-level failure opens the update screen, not a reset',
    (tester) async {
      final SlotLoader loader = await openLoader(tester);
      final BuildContext context = tester.element(find.byType(SpectraAppShell));

      final Future<bool?> pending = showLoadToSlotSheet(
        context,
        slotIndex: 0,
        type: TagType.mifare1k,
        bytes: classic1kFilled(),
        name: 'Office badge',
      );
      await pumpFrames(tester);
      // A device that does not carry the command at all; its recovery is
      // `ErrorRecovery.update`, which must go somewhere (review I2).
      loader.debugFail(const NotImplemented());
      await pumpFrames(tester);

      await tester.tap(_inSheet(find.text('Update firmware')));
      await pumpFrames(tester);

      expect(find.byType(SpectraBottomSheet), findsNothing);
      expect(find.byType(UpdatePage), findsOneWidget);
      expect(await pending, isNull);
    },
  );

  testWidgetsApp(
    'cannot be dismissed through the sheet while a load is in flight '
    '(ruling 30)',
    (tester) async {
      await openSlowLoader(tester);
      final BuildContext context = tester.element(find.byType(SpectraAppShell));

      final Future<bool?> pending = showLoadToSlotSheet(
        context,
        slotIndex: 2,
        type: TagType.mifare1k,
        bytes: classic1kFilled(),
        name: 'Office badge',
      );
      await pumpFrames(tester);
      await tester.tap(_inSheet(find.text('Load')));
      await pumpFrames(
        tester,
        count: 3,
        step: const Duration(milliseconds: 20),
      );

      // The sheet's own close icon goes through `Navigator.maybePop`, which
      // `PopScope(canPop: !state.busy)` refuses while busy — a slot caught
      // between `resetToDefault` and the data write is worse than a slot
      // the user waited two seconds for.
      await tester.tap(_inSheet(find.byIcon(Icons.close)));
      await pumpFrames(tester);
      expect(find.byType(SpectraBottomSheet), findsOneWidget);

      // The load runs to completion regardless.
      await pumpFrames(tester, count: 60);
      expect(_inSheet(find.text('Loaded into slot 3.')), findsOneWidget);

      final List<SlotView> views = readProvider(tester, slotViewsProvider);
      expect(views[2].slot.hfType, TagType.mifare1k);

      await tester.tap(_inSheet(find.text('Close')));
      await pumpFrames(tester);
      expect(await pending, isTrue);
    },
  );

  testWidgetsApp(
    'warns that the target slot\'s other sense stays live, and leaves it enabled',
    (tester) async {
      final SlotLoader loader = await openLoader(tester);
      final BuildContext context = tester.element(find.byType(SpectraAppShell));

      // Slot 4 already emulates an HF card; loading an LF id into it must
      // not clobber that side, and the confirm step has to say so first.
      // `FakeDevice` answers on the test's fake clock (ruling 22): capture
      // the future and pump *before* awaiting it, never await it directly.
      final Future<void> setup = loader.load(
        slotIndex: 3,
        type: TagType.mifare1k,
        bytes: classic1kFilled(),
        name: 'HF side',
        fallbackLabel: 'MIFARE Classic 1K',
      );
      await pumpFrames(tester, count: 30);
      await setup;
      loader.reset();
      await pumpFrames(tester);

      final Future<bool?> pending = showLoadToSlotSheet(
        context,
        slotIndex: 3,
        type: TagType.em410x,
        bytes: Uint8List.fromList(<int>[1, 2, 3, 4, 5]),
        name: 'LF side',
      );
      await pumpFrames(tester);
      expect(
        _inSheet(
          find.text(
            "Slot 4's High frequency side already emulates MIFARE Classic "
            '1K; it stays enabled, so both sides will be live after this '
            'load.',
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(_inSheet(find.text('Load')));
      await pumpFrames(tester, count: 30);
      expect(_inSheet(find.text('Loaded into slot 4.')), findsOneWidget);

      final List<SlotView> views = readProvider(tester, slotViewsProvider);
      expect(views[3].slot.hfEnabled, isTrue);
      expect(views[3].slot.hfType, TagType.mifare1k);
      expect(views[3].slot.lfEnabled, isTrue);
      expect(views[3].slot.lfType, TagType.em410x);

      await tester.tap(_inSheet(find.text('Close')));
      await pumpFrames(tester);
      await pending;
    },
  );
}
