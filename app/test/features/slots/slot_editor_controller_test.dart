import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/lifecycle/wakelock.dart';
import 'package:spectra/core/session/active_device.dart';
import 'package:spectra/features/slots/state/slot_editor_controller.dart';
import 'package:spectra/features/slots/state/slot_view.dart';
import 'package:spectra/features/slots/state/slot_views_provider.dart';

import '../../support/app_harness.dart';

SlotView _view(WidgetTester tester, int index) => readProvider(
  tester,
  slotViewsProvider,
).firstWhere((SlotView v) => v.index == index);

/// Keeps [slotEditorProvider]\(index\) alive, then reads its notifier.
/// `SlotEditor` is `@riverpod` (autoDispose): a bare `.notifier` read with
/// no listener would tear the element down before the awaited body below
/// runs its `state = …` (ruling 2).
SlotEditor _editor(WidgetTester tester, int index) {
  keepAlive(tester, slotEditorProvider(index));
  return readProvider(tester, slotEditorProvider(index).notifier);
}

/// Pumps the fake device's response through: `FakeDevice.write` always
/// replies via `Future.delayed` (even with the default zero latency), which
/// is a real `Timer` under `flutter test`'s fake clock — a bare `await` on
/// the call below, with no interleaved pump, deadlocks because nothing ever
/// advances that clock. So every call here is started, then pumped, then
/// awaited (already-resolved by then) — the same shape `connectToEmulator`
/// uses for a button tap.
Future<void> _pump(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgetsApp('rename writes through to the slot cache', (tester) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);

    keepAlive(tester, slotViewsProvider);
    final Future<void> pending = _editor(
      tester,
      2,
    ).rename(Sense.hf, 'Front door');
    await _pump(tester);
    await pending;

    expect(_view(tester, 2).slot.hfNick, 'Front door');
    expect(readProvider(tester, slotEditorProvider(2)).hasError, isFalse);
  });

  testWidgetsApp('setEnabled flips one sense and leaves the other alone', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);

    keepAlive(tester, slotViewsProvider);
    final Future<void> pending = _editor(tester, 0).setEnabled(Sense.lf, false);
    await _pump(tester);
    await pending;

    expect(_view(tester, 0).slot.lfEnabled, isFalse);
    expect(_view(tester, 0).slot.hfEnabled, isTrue);
  });

  testWidgetsApp('setTagType puts an HF type on the HF side', (tester) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);

    keepAlive(tester, slotViewsProvider);
    final Future<void> pending = _editor(tester, 3).setTagType(TagType.ntag215);
    await _pump(tester);
    await pending;

    expect(_view(tester, 3).slot.hfType, TagType.ntag215);
    expect(_view(tester, 3).slot.lfType, TagType.undefined);
  });

  testWidgetsApp('clearSense empties and disables that sense', (tester) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);

    keepAlive(tester, slotViewsProvider);
    final Future<void> pending = _editor(tester, 0).clearSense(Sense.hf);
    await _pump(tester);
    await pending;

    expect(_view(tester, 0).slot.hfType, TagType.undefined);
    expect(_view(tester, 0).slot.hfEnabled, isFalse);
    // The LF side is untouched.
    expect(_view(tester, 0).slot.lfType, TagType.em410x);
  });

  testWidgetsApp('makeActive moves the active marker', (tester) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);

    keepAlive(tester, slotViewsProvider);
    final Future<void> pending = _editor(tester, 5).makeActive();
    await _pump(tester);
    await pending;

    expect(_view(tester, 5).isActive, isTrue);
    expect(_view(tester, 0).isActive, isFalse);
  });

  testWidgetsApp('a facade failure becomes an AsyncError, never a throw', (
    tester,
  ) async {
    final FakeDevice device = FakeDevice();
    await tester.pumpWidget(testApp(transport: (_) => device));
    await connectToEmulator(tester);

    // Slot 9 does not exist: the firmware answers PAR_ERR, which the SDK
    // raises as ParameterError.
    final Future<void> pending = _editor(tester, 9).makeActive();
    await _pump(tester);
    await pending;

    final AsyncValue<void> state = readProvider(tester, slotEditorProvider(9));
    expect(state.hasError, isTrue);
    expect(state.error, isA<ParameterError>());
  });

  testWidgetsApp('reset clears a failure', (tester) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);

    final SlotEditor editor = _editor(tester, 9);
    final Future<void> pending = editor.makeActive();
    await _pump(tester);
    await pending;
    expect(readProvider(tester, slotEditorProvider(9)).hasError, isTrue);

    editor.reset();
    await tester.pump();
    expect(readProvider(tester, slotEditorProvider(9)).hasError, isFalse);
  });

  testWidgetsApp('a slot mutation holds the wakelock while it is in flight', (
    tester,
  ) async {
    final FakeDevice device = FakeDevice();
    await tester.pumpWidget(testApp(transport: (_) => device));
    await connectToEmulator(tester);

    final DeviceSession session = readProvider(
      tester,
      activeSessionProvider,
    )!.session;
    expect(
      sessionNeedsWakelock(session, session.connectionState.value),
      isFalse,
      reason: 'idle',
    );

    // Slow the fake down so the mutation is observably in flight.
    device.latency = const Duration(milliseconds: 200);
    final Future<void> pending = _editor(tester, 4).rename(Sense.hf, 'slow');
    await tester.pump(const Duration(milliseconds: 20));

    expect(
      sessionNeedsWakelock(session, session.connectionState.value),
      isTrue,
      reason: 'SlotsFacade wraps every mutation in DeviceSession.busy',
    );

    device.latency = Duration.zero;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await pending;
    expect(
      sessionNeedsWakelock(session, session.connectionState.value),
      isFalse,
    );
  });
}
