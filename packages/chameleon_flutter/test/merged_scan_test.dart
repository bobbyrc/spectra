import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Errors as soon as it is listened to, then completes.
final class _ErrorScanner implements DeviceScanner {
  @override
  TransportKind get kind => TransportKind.ble;

  @override
  Stream<List<DiscoveredDevice>> scan() =>
      Stream<List<DiscoveredDevice>>.error(StateError('scan unavailable'));
}

/// A scanner whose results are driven by hand.
final class _ManualScanner implements DeviceScanner {
  _ManualScanner(this.controller, {this.kind = TransportKind.usb});
  final StreamController<List<DiscoveredDevice>> controller;

  @override
  final TransportKind kind;

  @override
  Stream<List<DiscoveredDevice>> scan() => controller.stream;
}

/// Never emits and never ends, so a test can prove the merge does not wait
/// on it before reporting anything.
final class _SilentScanner implements DeviceScanner {
  final controller = StreamController<List<DiscoveredDevice>>();

  @override
  TransportKind get kind => TransportKind.ble;

  @override
  Stream<List<DiscoveredDevice>> scan() => controller.stream;
}

void main() {
  test('emits an empty list immediately, without waiting on a scanner', () {
    final silent = _SilentScanner();
    addTearDown(silent.controller.close);
    expect(
      mergedScan(<DeviceScanner>[silent]),
      emitsInOrder(<Object>[<DiscoveredDevice>[]]),
    );
  });

  test('with no scanners it emits an empty list and closes', () async {
    expect(await mergedScan(const <DeviceScanner>[]).toList(), <Object>[
      <DiscoveredDevice>[],
    ]);
  });

  test('unions the scanners and de-duplicates by identity', () async {
    final stream = mergedScan(<DeviceScanner>[
      FakeScanner(),
      FakeScanner(
        devices: const <DiscoveredDevice>[FakeScanner.emulatedBootloader],
      ),
    ]);
    final last = await stream.last.timeout(const Duration(seconds: 2));
    expect(last.length, 2);
    expect(last.any((d) => d.isBootloader), isTrue);
  });

  test('closes once every finite scanner is done', () async {
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
    final data = <List<DiscoveredDevice>>[];
    final sub = stream.listen(
      data.add,
      onError: (Object e, StackTrace st) {
        if (!firstError.isCompleted) firstError.complete(e);
      },
    );
    addTearDown(sub.cancel);

    await firstError.future.timeout(const Duration(seconds: 2));
    manual.add(const <DiscoveredDevice>[FakeScanner.emulatedUltra]);
    await Future<void>.delayed(Duration.zero);
    expect(data.last, contains(FakeScanner.emulatedUltra));
  });

  test("a failed scanner's rows leave the union", () async {
    final ble = StreamController<List<DiscoveredDevice>>();
    addTearDown(ble.close);
    final usb = StreamController<List<DiscoveredDevice>>();
    addTearDown(usb.close);
    final stream = mergedScan(<DeviceScanner>[
      _ManualScanner(ble, kind: TransportKind.ble),
      _ManualScanner(usb),
    ]);
    final data = <List<DiscoveredDevice>>[];
    final sub = stream.listen(data.add, onError: (Object _) {});
    addTearDown(sub.cancel);

    ble.add(const <DiscoveredDevice>[FakeScanner.emulatedUltra]);
    usb.add(const <DiscoveredDevice>[FakeScanner.emulatedBootloader]);
    await Future<void>.delayed(Duration.zero);
    expect(data.last, hasLength(2));

    // The BLE scanner fails: it is no longer reporting what is in range, so
    // its rows go, while the serial scanner's row stays.
    ble.addError(StateError('adapter off'));
    await Future<void>.delayed(Duration.zero);
    expect(data.last, <DiscoveredDevice>[FakeScanner.emulatedBootloader]);
  });

  test('cancelling the merged stream cancels every scanner', () async {
    final a = StreamController<List<DiscoveredDevice>>();
    final b = StreamController<List<DiscoveredDevice>>();
    addTearDown(a.close);
    addTearDown(b.close);
    final sub = mergedScan(<DeviceScanner>[
      _ManualScanner(a),
      _ManualScanner(b, kind: TransportKind.ble),
    ]).listen((_) {});
    await Future<void>.delayed(Duration.zero);
    expect(a.hasListener, isTrue);
    expect(b.hasListener, isTrue);
    await sub.cancel();
    expect(a.hasListener, isFalse);
    expect(b.hasListener, isFalse);
  });
}
