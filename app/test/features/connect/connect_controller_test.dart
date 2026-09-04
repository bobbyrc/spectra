import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/discovery/discovery_provider.dart';
import 'package:spectra/core/discovery/scanners.dart';
import 'package:spectra/core/session/active_device.dart';
import 'package:spectra/core/session/reconnect.dart';
import 'package:spectra/core/session/session_streams.dart';
import 'package:spectra/core/session/sessions.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/data/memory/in_memory_repositories.dart';
import 'package:spectra/features/connect/connect.dart';

const emulated = FakeScanner.emulatedUltra;

/// Holds a listener on [connectControllerProvider] so the autoDispose
/// notifier survives between the calls each test makes — otherwise it is
/// torn down the instant a `read` returns with no active watcher.
ProviderContainer harness(
  Transport Function(DiscoveredDevice) factory, {
  List<DeviceScanner> scanners = const <DeviceScanner>[],
  bool hold = true,
}) {
  final container = ProviderContainer(
    overrides: [
      knownDevicesRepositoryProvider.overrideWithValue(
        InMemoryKnownDevicesRepository(),
      ),
      scannersProvider.overrideWithValue(
        scanners.isEmpty ? <DeviceScanner>[FakeScanner()] : scanners,
      ),
      transportFactoryProvider.overrideWithValue(factory),
      // Real time, but short: the "not visible" path waits this out.
      reconnectDiscoveryTimeoutProvider.overrideWithValue(
        const Duration(milliseconds: 20),
      ),
    ],
  );
  addTearDown(container.dispose);
  if (hold) {
    final sub = container.listen(connectControllerProvider, (_, _) {});
    addTearDown(sub.close);
  }
  return container;
}

/// A scanner that reports an empty list for ever: the device is remembered
/// but nothing can see it.
final class _NoDevicesScanner implements DeviceScanner {
  const _NoDevicesScanner();
  @override
  TransportKind get kind => TransportKind.usb;
  @override
  Stream<List<DiscoveredDevice>> scan() =>
      Stream<List<DiscoveredDevice>>.value(const <DiscoveredDevice>[]);
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

  test('reconnectLast with nothing remembered reports it', () async {
    final container = harness((_) => FakeDevice());

    await container.read(connectControllerProvider.notifier).reconnectLast();

    expect(container.read(activeDeviceProvider), isNull);
    // R26: a button that silently does nothing is a broken button.
    expect(
      container.read(connectControllerProvider).error,
      isA<NoKnownDeviceVisible>(),
    );
  });

  test(
    'reconnectLast reports a remembered device that is not visible',
    () async {
      // Remembered, but nothing is scanning it any more, so the wait times
      // out (20ms, per the harness override) instead of connecting.
      final container = harness(
        (_) => FakeDevice(),
        scanners: const <DeviceScanner>[_NoDevicesScanner()],
      );
      await container
          .read(knownDevicesRepositoryProvider)
          .remember(
            identity: const DeviceIdentity('fake-chip'),
            displayName: emulated.name,
            kind: emulated.kind,
            transportId: emulated.transportId,
          );

      await container.read(connectControllerProvider.notifier).reconnectLast();

      expect(
        container.read(connectControllerProvider).error,
        isA<NoKnownDeviceVisible>(),
      );
      expect(container.read(activeDeviceProvider), isNull);
    },
  );

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

  test(
    'a connect that lands after the controller is disposed is silent',
    () async {
      // Nothing holds the autoDispose notifier but the listener below, so
      // closing it mid-connect is the "user left the connect screen while it
      // was still connecting" case.
      final container = harness((_) => FakeDevice(), hold: false);
      final sub = container.listen(connectControllerProvider, (_, _) {});
      final pending = container
          .read(connectControllerProvider.notifier)
          .connect(emulated);

      sub.close();

      // No UnmountedRefException from the post-await `state =`.
      await pending;
      // The session the attempt opened is still real: it is the reporting
      // that is dropped, not the work.
      expect(container.read(sessionsProvider).sessions, isNotEmpty);
      expect(container.read(activeDeviceProvider), isNotNull);

      await container.read(sessionsProvider.notifier).disconnectAll();
    },
  );

  test('a reconnectLast that lands after disposal is silent', () async {
    final container = harness((_) => FakeDevice(), hold: false);
    final sub = container.listen(connectControllerProvider, (_, _) {});
    final pending = container
        .read(connectControllerProvider.notifier)
        .reconnectLast();

    sub.close();

    await pending;
  });
}
