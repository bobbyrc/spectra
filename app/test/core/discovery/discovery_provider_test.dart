import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/discovery/discovery_provider.dart';
import 'package:spectra/core/discovery/scanners.dart';

/// A scanner whose emissions the test drives, standing in for a real
/// transport's scanner without touching `chameleon_flutter`.
final class ScriptedScanner implements DeviceScanner {
  ScriptedScanner(this.kind, this.controller);
  @override
  final TransportKind kind;
  final StreamController<List<DiscoveredDevice>> controller;
  @override
  Stream<List<DiscoveredDevice>> scan() => controller.stream;
}

/// `discoveryProvider` is `autoDispose` and `mergedScan` (spec 4.2, Ruling
/// 17) always emits an immediate first event — usually the empty list —
/// before any scanner has actually reported. Two consequences for tests:
///
/// * Reading `.future` with no active watcher lets Riverpod pause the
///   underlying subscription the instant the synchronous `read` call
///   returns, before the merge stream (necessarily async) ever gets to
///   emit — the read then hangs forever. A held `container.listen` keeps a
///   real watcher in place, which is how the connect screen watches it in
///   production too.
/// * `.future` itself resolves on the *first* emission, which can be that
///   placeholder empty list rather than the settled result. So tests watch
///   and read the provider's current value after letting the merge's
///   microtasks run, instead of awaiting `.future`.
ProviderSubscription<AsyncValue<DiscoveryState>> watchDiscovery(
  ProviderContainer container,
) => container.listen(discoveryProvider, (_, _) {});

Future<DiscoveryState> settledDiscovery(ProviderContainer container) async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return container.read(discoveryProvider).requireValue;
}

void main() {
  test(
    'emulator mode is on and puts the emulated device in the list',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(emulatorModeProvider), isTrue);
      expect(
        container.read(scannersProvider).whereType<FakeScanner>(),
        isNotEmpty,
      );
    },
  );

  test('turning emulator mode off removes the fake scanner', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(emulatorModeProvider.notifier).setEnabled(false);
    expect(container.read(scannersProvider).whereType<FakeScanner>(), isEmpty);
  });

  test('discovery reports the emulated device', () async {
    final container = ProviderContainer(
      overrides: [
        scannersProvider.overrideWithValue(<DeviceScanner>[FakeScanner()]),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(watchDiscovery(container).close);

    final state = await settledDiscovery(container);
    expect(state.devices, contains(FakeScanner.emulatedUltra));
  });

  test('a manual port joins the discovered list', () async {
    final container = ProviderContainer(
      overrides: [
        scannersProvider.overrideWithValue(<DeviceScanner>[FakeScanner()]),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(watchDiscovery(container).close);
    await settledDiscovery(container);

    container.read(manualPortsProvider.notifier).add('/dev/cu.usbmodem9');
    final manual = container.read(manualPortsProvider).single;
    expect(manual.kind, TransportKind.usb);
    expect(manual.transportId, '/dev/cu.usbmodem9');

    final state = await settledDiscovery(container);
    expect(state.devices, contains(manual));
  });

  test(
    'one scanner failing leaves the other scanner s devices listed',
    () async {
      final ble = StreamController<List<DiscoveredDevice>>();
      final container = ProviderContainer(
        overrides: [
          scannersProvider.overrideWithValue(<DeviceScanner>[
            FakeScanner(),
            ScriptedScanner(TransportKind.ble, ble),
          ]),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(ble.close);

      final states = <DiscoveryState>[];
      final sub = container.listen(discoveryProvider, (previous, next) {
        final value = next.value;
        if (value != null) states.add(value);
      }, fireImmediately: true);
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);

      ble.addError(const PermissionDenied());
      await Future<void>.delayed(Duration.zero);

      expect(states.last.error, isA<PermissionDenied>());
      expect(states.last.devices, contains(FakeScanner.emulatedUltra));
    },
  );
}
