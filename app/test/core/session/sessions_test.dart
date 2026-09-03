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

/// A container whose transport factory is [transportFactory] itself, for
/// tests that need to count or vary calls rather than serve a fixed map.
ProviderContainer harnessWithFactory(
  Transport Function(DiscoveredDevice) transportFactory,
) {
  final container = ProviderContainer(
    overrides: [
      knownDevicesRepositoryProvider.overrideWithValue(
        InMemoryKnownDevicesRepository(),
      ),
      transportFactoryProvider.overrideWithValue(transportFactory),
    ],
  );
  addTearDown(container.dispose);
  return container;
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

  test(
    'closing a session directly does not arm lastDisconnected (spec 7.4)',
    () async {
      final h = harness({emulated.transportId: FakeDevice()});
      final notifier = h.container.read(sessionsProvider.notifier);
      final identity = await notifier.connect(emulated);
      final session = h.container
          .read(deviceSessionProvider(identity))!
          .session;

      await session.close();
      await Future<void>.delayed(Duration.zero);

      expect(h.container.read(sessionsProvider).sessions, isEmpty);
      expect(h.container.read(sessionsProvider).lastDisconnected, isNull);
    },
  );

  test('connecting a second transport for the same identity replaces the first '
      'session', () async {
    const other = DiscoveredDevice(
      name: 'Other',
      kind: TransportKind.fake,
      transportId: 'fake-ultra-2',
    );
    final firstDevice = FakeDevice();
    final secondDevice = FakeDevice();
    final h = harness({
      emulated.transportId: firstDevice,
      other.transportId: secondDevice,
    });
    final notifier = h.container.read(sessionsProvider.notifier);

    final firstIdentity = await notifier.connect(emulated);
    final firstSession = h.container
        .read(deviceSessionProvider(firstIdentity))!
        .session;

    final secondIdentity = await notifier.connect(other);

    expect(secondIdentity, firstIdentity);
    expect(h.container.read(sessionsProvider).sessions, hasLength(1));
    expect(firstSession.connectionState.value, isA<SessionDisconnected>());
    expect(
      h.container.read(deviceSessionProvider(secondIdentity))!.device,
      other,
    );

    await notifier.disconnectAll();
  });

  test('concurrent connects for the same device share one open', () async {
    var factoryCalls = 0;
    final device = FakeDevice();
    final container = harnessWithFactory((_) {
      factoryCalls++;
      return device;
    });
    final notifier = container.read(sessionsProvider.notifier);

    final first = notifier.connect(emulated);
    final second = notifier.connect(emulated);
    final results = await Future.wait([first, second]);

    expect(results[0], results[1]);
    expect(factoryCalls, 1);
    expect(container.read(sessionsProvider).sessions, hasLength(1));

    await notifier.disconnectAll();
  });

  test('a lost link is handled once even if disconnect races it', () async {
    final device = FakeDevice();
    final h = harness({emulated.transportId: device});
    final notifier = h.container.read(sessionsProvider.notifier);
    final identity = await notifier.connect(emulated);

    final linkLoss = device.simulateLinkLoss();
    final raceDisconnect = notifier.disconnect(identity);
    await Future.wait([linkLoss, raceDisconnect]);
    await Future<void>.delayed(Duration.zero);

    expect(h.container.read(sessionsProvider).sessions, isEmpty);
  });

  test('consumeLastDisconnected clears the preselected device', () async {
    final device = FakeDevice();
    final h = harness({emulated.transportId: device});
    final notifier = h.container.read(sessionsProvider.notifier);
    await notifier.connect(emulated);

    await device.simulateLinkLoss();
    await Future<void>.delayed(Duration.zero);
    expect(h.container.read(sessionsProvider).lastDisconnected, emulated);

    final consumed = notifier.consumeLastDisconnected();

    expect(consumed, emulated);
    expect(h.container.read(sessionsProvider).lastDisconnected, isNull);
    expect(notifier.consumeLastDisconnected(), isNull);
  });

  test('markLastDisconnected arms the connect screen preselect with no session '
      'ever registered', () {
    final h = harness({});
    final notifier = h.container.read(sessionsProvider.notifier);
    expect(h.container.read(sessionsProvider).lastDisconnected, isNull);

    notifier.markLastDisconnected(emulated);

    expect(h.container.read(sessionsProvider).lastDisconnected, emulated);
    expect(h.container.read(sessionsProvider).sessions, isEmpty);
  });

  test('a failed connect can be retried with a fresh transport', () async {
    var calls = 0;
    final failing = FakeDevice(openError: const PermissionDenied());
    final succeeding = FakeDevice();
    final container = harnessWithFactory((_) {
      calls++;
      return calls == 1 ? failing : succeeding;
    });
    final notifier = container.read(sessionsProvider.notifier);

    await expectLater(
      notifier.connect(emulated),
      throwsA(isA<PermissionDenied>()),
    );
    final identity = await notifier.connect(emulated);

    expect(calls, 2);
    expect(container.read(sessionsProvider).sessions, hasLength(1));
    expect(
      container
          .read(deviceSessionProvider(identity))!
          .session
          .connectionState
          .value,
      isA<SessionReady>(),
    );

    await notifier.disconnectAll();
  });
}
