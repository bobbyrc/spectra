import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/session/active_device.dart';
import 'package:spectra/core/session/session_identity.dart';
import 'package:spectra/core/session/sessions.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/data/memory/in_memory_repositories.dart';

const emulated = FakeScanner.emulatedUltra;

/// A container whose transports are the fakes [devices] hands out, keyed by
/// transportId, and whose known-devices repository is in memory.
({ProviderContainer container, InMemoryKnownDevicesRepository known}) harness(
  Map<String, Transport> devices,
) {
  final known = InMemoryKnownDevicesRepository();
  final container = ProviderContainer(
    overrides: [
      knownDevicesRepositoryProvider.overrideWithValue(known),
      transportFactoryProvider.overrideWithValue(
        (DiscoveredDevice d) => devices[d.transportId]!,
      ),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, known: known);
}

void main() {
  test('fallbackIdentity is stable and names the transport', () {
    expect(fallbackIdentity(emulated), fallbackIdentity(emulated));
    expect(fallbackIdentity(emulated).chipId, contains('fake-ultra'));
  });

  test('connecting registers the session under its chip id', () async {
    final device = FakeDevice();
    final h = harness({emulated.transportId: device});
    final identity = await h.container
        .read(sessionsProvider.notifier)
        .connect(emulated);

    expect(identity, DeviceIdentity(FakeFirmwareConfig().chipId));
    final active = h.container.read(deviceSessionProvider(identity));
    expect(active, isNotNull);
    expect(active!.session.connectionState.value, isA<SessionReady>());
    expect(active.device, emulated);

    await h.container.read(sessionsProvider.notifier).disconnectAll();
  });

  test('connecting remembers the device for the connect screen', () async {
    final h = harness({emulated.transportId: FakeDevice()});
    final identity = await h.container
        .read(sessionsProvider.notifier)
        .connect(emulated);

    final remembered = await h.known.byIdentity(identity);
    expect(remembered!.displayName, emulated.name);
    expect(remembered.transports.single.transportId, emulated.transportId);

    await h.container.read(sessionsProvider.notifier).disconnectAll();
  });

  test('a limited device is registered under the fallback identity', () async {
    final device = FakeDevice(
      firmware: FakeFirmware(FakeFirmwareConfig.legacy01()),
    );
    final h = harness({emulated.transportId: device});
    final identity = await h.container
        .read(sessionsProvider.notifier)
        .connect(emulated);

    expect(identity, fallbackIdentity(emulated));
    expect(
      h.container
          .read(deviceSessionProvider(identity))!
          .session
          .connectionState
          .value,
      isA<SessionLimited>(),
    );

    await h.container.read(sessionsProvider.notifier).disconnectAll();
  });

  test('a failed open registers nothing and rethrows', () async {
    final device = FakeDevice(openError: const PermissionDenied());
    final h = harness({emulated.transportId: device});

    await expectLater(
      h.container.read(sessionsProvider.notifier).connect(emulated),
      throwsA(isA<PermissionDenied>()),
    );
    expect(h.container.read(sessionsProvider).sessions, isEmpty);
  });

  test('connecting twice to the same device reuses the session', () async {
    final h = harness({emulated.transportId: FakeDevice()});
    final notifier = h.container.read(sessionsProvider.notifier);
    final first = await notifier.connect(emulated);
    final second = await notifier.connect(emulated);

    expect(second, first);
    expect(h.container.read(sessionsProvider).sessions, hasLength(1));

    await notifier.disconnectAll();
  });

  test('disconnect closes the session and drops it', () async {
    final h = harness({emulated.transportId: FakeDevice()});
    final notifier = h.container.read(sessionsProvider.notifier);
    final identity = await notifier.connect(emulated);
    final session = h.container.read(deviceSessionProvider(identity))!.session;

    await notifier.disconnect(identity);

    expect(h.container.read(sessionsProvider).sessions, isEmpty);
    expect(session.connectionState.value, isA<SessionDisconnected>());
  });

  test('a lost link drops the session and preselects the device', () async {
    final device = FakeDevice();
    final h = harness({emulated.transportId: device});
    final notifier = h.container.read(sessionsProvider.notifier);
    await notifier.connect(emulated);

    await device.simulateLinkLoss();
    await Future<void>.delayed(Duration.zero);

    expect(h.container.read(sessionsProvider).sessions, isEmpty);
    expect(h.container.read(sessionsProvider).lastDisconnected, emulated);
  });

  test('the active device names one of the registered sessions', () async {
    final h = harness({emulated.transportId: FakeDevice()});
    final notifier = h.container.read(sessionsProvider.notifier);
    expect(h.container.read(activeSessionProvider), isNull);

    final identity = await notifier.connect(emulated);
    h.container.read(activeDeviceProvider.notifier).select(identity);

    expect(h.container.read(activeSessionProvider)!.identity, identity);

    await notifier.disconnectAll();
    expect(h.container.read(activeSessionProvider), isNull);
  });
}
