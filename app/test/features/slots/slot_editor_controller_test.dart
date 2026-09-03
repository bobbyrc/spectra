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
Future<void> _pump(WidgetTester tester, [int frames = 10]) =>
    pumpFrames(tester, count: frames, step: const Duration(milliseconds: 20));

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
    expect(readProvider(tester, slotEditorProvider(2)), isA<AsyncData<void>>());
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

  testWidgetsApp('a mutation with no active session becomes SessionNotReady', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await tester.pump();

    // Lets `build(0)`'s own (trivially empty, but still async) Future
    // settle to `AsyncData(null)` before the mutation below touches
    // `state` — otherwise the build's completion can land after the
    // mutation and clobber the error it just set (see task-5-report.md's
    // note on this same microtask race).
    final SlotEditor editor = _editor(tester, 0);
    await tester.pump();

    final Future<void> pending = editor.makeActive();
    await _pump(tester);
    await pending;

    final AsyncValue<void> state = readProvider(tester, slotEditorProvider(0));
    expect(state.hasError, isTrue);
    expect(state.error, isA<SessionNotReady>());
  });

  testWidgetsApp(
    'a second mutation while one is in flight is dropped, not queued',
    (tester) async {
      final FakeDevice device = FakeDevice();
      await tester.pumpWidget(testApp(transport: (_) => device));
      await connectToEmulator(tester);

      final SlotEditor editor = _editor(tester, 2);
      // Neither call is awaited before the second lands, so the guard sees
      // the first still in flight (ruling 9's shape).
      final Future<void> first = editor.rename(Sense.hf, 'First');
      final Future<void> second = editor.rename(Sense.hf, 'Second');
      await _pump(tester);
      await first;
      await second;

      expect(device.received.where((Frame f) => f.command == 1007).length, 1);
    },
  );

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
      reason: 'every mutation that writes and saves',
    );

    device.latency = Duration.zero;
    await pumpFrames(tester, count: 40, step: const Duration(milliseconds: 50));
    await pending;
    expect(
      sessionNeedsWakelock(session, session.connectionState.value),
      isFalse,
    );
  });

  testWidgetsApp(
    'a mutation that lands after the editor is disposed stays silent',
    (tester) async {
      final FakeDevice device = FakeDevice();
      await tester.pumpWidget(testApp(transport: (_) => device));
      await connectToEmulator(tester);

      keepAlive(tester, slotViewsProvider);
      final ProviderSubscription<AsyncValue<void>> alive = keepAlive(
        tester,
        slotEditorProvider(2),
      );
      final SlotEditor editor = readProvider(
        tester,
        slotEditorProvider(2).notifier,
      );

      // Slow the fake down so the write is still in flight when the detail
      // page goes away.
      device.latency = const Duration(milliseconds: 200);
      final Future<void> pending = editor.rename(Sense.hf, 'Late');
      await tester.pump(const Duration(milliseconds: 20));

      // The user pressed Back: the autoDispose element is torn down while
      // the device write is still running.
      alive.close();
      await tester.pump();

      device.latency = Duration.zero;
      await pumpFrames(
        tester,
        count: 40,
        step: const Duration(milliseconds: 50),
      );
      // No UnmountedRefException: the notifier notices it is gone and
      // simply stops writing state.
      await pending;

      // The device write itself still completed — cancelling the screen
      // does not cancel the command already on the wire.
      expect(_view(tester, 2).slot.hfNick, 'Late');
    },
  );
}
