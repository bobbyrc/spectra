import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/discovery/discovery_provider.dart';
import 'package:spectra/core/discovery/scanners.dart';
import 'package:spectra/core/session/active_device.dart';
import 'package:spectra/core/session/session_streams.dart';
import 'package:spectra/core/session/sessions.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/data/memory/in_memory_repositories.dart';
import 'package:spectra/features/connect/connect.dart';

const emulated = FakeScanner.emulatedUltra;

/// Holds a listener on [connectControllerProvider] so the autoDispose
/// notifier survives between the calls each test makes — otherwise it is
/// torn down the instant a `read` returns with no active watcher.
ProviderContainer harness(Transport Function(DiscoveredDevice) factory) {
  final container = ProviderContainer(
    overrides: [
      knownDevicesRepositoryProvider.overrideWithValue(
        InMemoryKnownDevicesRepository(),
      ),
      scannersProvider.overrideWithValue(<DeviceScanner>[FakeScanner()]),
      transportFactoryProvider.overrideWithValue(factory),
    ],
  );
  addTearDown(container.dispose);
  final sub = container.listen(connectControllerProvider, (_, _) {});
  addTearDown(sub.close);
  return container;
}

void main() {
  test('connecting makes the session the active device', () async {
    final container = harness((_) => FakeDevice());
    await container.read(connectControllerProvider.notifier).connect(emulated);

    expect(container.read(activeDeviceProvider), isNotNull);
    expect(container.read(connectionStatusProvider), isA<SessionReady>());
    expect(container.read(connectControllerProvider).hasError, isFalse);

    await container.read(sessionsProvider.notifier).disconnectAll();
  });

  test(
    'a refused permission lands in the controller state, not a throw',
    () async {
      final container = harness(
        (_) => FakeDevice(openError: const PermissionDenied()),
      );
      await container
          .read(connectControllerProvider.notifier)
          .connect(emulated);

      final state = container.read(connectControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<PermissionDenied>());
      expect(container.read(activeDeviceProvider), isNull);
    },
  );

  test('reconnectLast connects to the last remembered device', () async {
    final container = harness((_) => FakeDevice());
    // discoveryProvider needs a live watcher to produce anything at all —
    // an unwatched read never gets past its own subscription setup — so
    // this holds one and lets its microtasks settle before reconnectLast
    // reads it (ruling 20; mirrors discovery_provider_test.dart).
    final discoverySub = container.listen(discoveryProvider, (_, _) {});
    addTearDown(discoverySub.close);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final notifier = container.read(connectControllerProvider.notifier);
    await notifier.connect(emulated);
    await container.read(sessionsProvider.notifier).disconnectAll();
    container.read(activeDeviceProvider.notifier).select(null);

    await notifier.reconnectLast();

    expect(container.read(connectionStatusProvider), isA<SessionReady>());
    await container.read(sessionsProvider.notifier).disconnectAll();
  });

  test('reconnectLast with nothing remembered is a no-op', () async {
    final container = harness((_) => FakeDevice());
    await container.read(connectControllerProvider.notifier).reconnectLast();
    expect(container.read(activeDeviceProvider), isNull);
    expect(container.read(connectControllerProvider).hasError, isFalse);
  });

  test('reset clears an error so the screen can try again', () async {
    final container = harness(
      (_) => FakeDevice(openError: const PermissionDenied()),
    );
    final notifier = container.read(connectControllerProvider.notifier);
    await notifier.connect(emulated);
    expect(container.read(connectControllerProvider).hasError, isTrue);

    notifier.reset();

    expect(container.read(connectControllerProvider).hasError, isFalse);
    expect(container.read(connectControllerProvider).isLoading, isFalse);
  });
}
