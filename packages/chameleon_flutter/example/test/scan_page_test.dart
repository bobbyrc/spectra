import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serial_probe/scan_page.dart';

/// Reports [callCount] scan() calls, and a single empty list per call.
final class _CountingScanner implements DeviceScanner {
  int callCount = 0;

  @override
  TransportKind get kind => TransportKind.fake;

  @override
  Stream<List<DiscoveredDevice>> scan() {
    callCount++;
    return Stream<List<DiscoveredDevice>>.value(const <DiscoveredDevice>[]);
  }
}

/// Errors as soon as it is listened to, then completes.
final class _ErrorScanner implements DeviceScanner {
  @override
  TransportKind get kind => TransportKind.ble;

  @override
  Stream<List<DiscoveredDevice>> scan() =>
      Stream<List<DiscoveredDevice>>.error(StateError('scan unavailable'));
}

/// A scanner whose results are driven by hand, for asserting later events
/// still arrive after another scanner has errored.
final class _ManualScanner implements DeviceScanner {
  _ManualScanner(this.controller);
  final StreamController<List<DiscoveredDevice>> controller;

  @override
  TransportKind get kind => TransportKind.usb;

  @override
  Stream<List<DiscoveredDevice>> scan() => controller.stream;
}

/// Rebuilds [child] on demand without recreating its State, so a test can
/// force ScanPage's build() to run again while keeping the same State (and
/// therefore the same `late final` merged stream).
class _RebuildHarness extends StatefulWidget {
  const _RebuildHarness({required this.child, super.key});
  final Widget child;

  @override
  State<_RebuildHarness> createState() => _RebuildHarnessState();
}

class _RebuildHarnessState extends State<_RebuildHarness> {
  int _ticks = 0;
  void rebuild() => setState(() => _ticks++);

  @override
  Widget build(BuildContext context) => widget.child;
}

void main() {
  testWidgets('with no scanners, ScanPage shows "No devices found"', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ScanPage(scanners: <DeviceScanner>[])),
    );
    await tester.pump();
    expect(find.text('No devices found'), findsOneWidget);
  });

  testWidgets('merged results from several scanners appear as rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ScanPage(scanners: <DeviceScanner>[FakeScanner()])),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Emulated Chameleon Ultra'), findsOneWidget);
  });

  testWidgets(
    'a scan error shows a banner but keeps the other scanner\'s rows',
    (tester) async {
      final manual = StreamController<List<DiscoveredDevice>>();
      addTearDown(manual.close);
      await tester.pumpWidget(
        MaterialApp(
          home: ScanPage(
            scanners: <DeviceScanner>[_ErrorScanner(), _ManualScanner(manual)],
          ),
        ),
      );
      await tester.pump();
      manual.add(const <DiscoveredDevice>[FakeScanner.emulatedUltra]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('Scan failed'), findsOneWidget);
      expect(find.text('Emulated Chameleon Ultra'), findsOneWidget);
    },
  );

  testWidgets('mergedScan is subscribed once across rebuilds', (tester) async {
    final scanner = _CountingScanner();
    final key = GlobalKey<_RebuildHarnessState>();
    await tester.pumpWidget(
      MaterialApp(
        home: _RebuildHarness(
          key: key,
          child: ScanPage(scanners: <DeviceScanner>[scanner]),
        ),
      ),
    );
    await tester.pump();
    expect(scanner.callCount, 1);

    key.currentState!.rebuild();
    await tester.pump();
    key.currentState!.rebuild();
    await tester.pump();

    expect(scanner.callCount, 1);
  });

  test(
    'mergedScan unions the scanners and de-duplicates by identity',
    () async {
      final stream = mergedScan(<DeviceScanner>[
        FakeScanner(),
        FakeScanner(
          devices: const <DiscoveredDevice>[FakeScanner.emulatedBootloader],
        ),
      ]);
      final last = await stream
          .take(2)
          .last
          .timeout(const Duration(seconds: 2));
      expect(last.length, 2);
      expect(last.any((d) => d.isBootloader), isTrue);
    },
  );

  test('mergedScan closes once every finite scanner is done', () async {
    final stream = mergedScan(<DeviceScanner>[FakeScanner()]);
    // FakeScanner.scan() is Stream.value(...), which emits once then
    // completes; the merged stream must complete too, not hang forever.
    await stream.toList().timeout(const Duration(seconds: 2));
  });

  test('an error from one scanner leaves the other producing', () async {
    final manual = StreamController<List<DiscoveredDevice>>();
    addTearDown(manual.close);
    final stream = mergedScan(<DeviceScanner>[
      _ErrorScanner(),
      _ManualScanner(manual),
    ]);

    final firstError = Completer<Object>();
    final firstData = Completer<List<DiscoveredDevice>>();
    final sub = stream.listen(
      (data) {
        if (!firstData.isCompleted) firstData.complete(data);
      },
      onError: (Object e, StackTrace st) {
        if (!firstError.isCompleted) firstError.complete(e);
      },
    );
    addTearDown(sub.cancel);

    await firstError.future.timeout(const Duration(seconds: 2));
    manual.add(const <DiscoveredDevice>[FakeScanner.emulatedUltra]);
    final data = await firstData.future.timeout(const Duration(seconds: 2));
    expect(data, contains(FakeScanner.emulatedUltra));
  });
}
