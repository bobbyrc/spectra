import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/session/active_device.dart';
import 'package:spectra/core/session/frame_log_provider.dart';
import 'package:spectra/core/session/session_streams.dart';
import 'package:spectra/core/session/sessions.dart';
import 'package:spectra/data/memory/in_memory_repositories.dart';
import 'package:spectra/data/repository_providers.dart';

const emulated = FakeScanner.emulatedUltra;

ProviderContainer harness(Transport transport) {
  final container = ProviderContainer(
    overrides: [
      knownDevicesRepositoryProvider.overrideWithValue(
        InMemoryKnownDevicesRepository(),
      ),
      transportFactoryProvider.overrideWithValue((_) => transport),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> connectAndSelect(ProviderContainer c) async {
  final identity = await c.read(sessionsProvider.notifier).connect(emulated);
  c.read(activeDeviceProvider.notifier).select(identity);
}

/// `container.read(provider.future)` alone opens a listener, reads, then
/// closes it again in the same synchronous call (see
/// `ProviderContainer.read`). The element's internal stream is a broadcast
/// `StreamController`, which drops an event with no listener attached — so
/// when the first value arrives on a later microtask (as `StateStream.values`
/// always does), it is lost and the future never completes. `listen` with
/// `fireImmediately` sidesteps this: it delivers the current value straight
/// away and stays subscribed for whatever comes after.
Future<DeviceInfo?> readDeviceInfo(ProviderContainer c) {
  final completer = Completer<DeviceInfo?>();
  late final ProviderSubscription<AsyncValue<DeviceInfo?>> sub;
  sub = c.listen(deviceInfoProvider, (_, next) {
    next.whenData((info) {
      if (!completer.isCompleted) completer.complete(info);
    });
  }, fireImmediately: true);
  return completer.future.whenComplete(sub.close);
}

/// The fake populates all eight slots via the session's background load
/// (spec 4.3), which is fired unawaited once the session becomes ready — so
/// the value seen right after connecting is the empty placeholder, not the
/// eventual eight. Waits for that value specifically, again via `listen`
/// with `fireImmediately` rather than a racy `.future` read.
Future<List<Slot>> readSlots(ProviderContainer c) {
  final completer = Completer<List<Slot>>();
  late final ProviderSubscription<AsyncValue<List<Slot>>> sub;
  sub = c.listen(slotsProvider, (_, next) {
    next.whenData((slots) {
      if (slots.length == 8 && !completer.isCompleted) {
        completer.complete(slots);
      }
    });
  }, fireImmediately: true);
  return completer.future.whenComplete(sub.close);
}

void main() {
  test('with no session the status is disconnected', () {
    final container = harness(FakeDevice());
    expect(
      container.read(connectionStatusProvider),
      isA<SessionDisconnected>(),
    );
  });

  test('the status follows the active session', () async {
    final container = harness(FakeDevice());
    await connectAndSelect(container);
    expect(container.read(connectionStatusProvider), isA<SessionReady>());

    await container.read(sessionsProvider.notifier).disconnectAll();
    expect(
      container.read(connectionStatusProvider),
      isA<SessionDisconnected>(),
    );
  });

  test('deviceInfo carries the fake firmware version', () async {
    final container = harness(FakeDevice());
    await connectAndSelect(container);
    final info = await readDeviceInfo(container);
    expect(info!.version.label, '2.2');
    expect(info.model, DeviceModel.ultra);
    await container.read(sessionsProvider.notifier).disconnectAll();
  });

  test('slots arrive from the background load', () async {
    final container = harness(FakeDevice());
    await connectAndSelect(container);
    await expectLater(readSlots(container), completion(hasLength(8)));
    await container.read(sessionsProvider.notifier).disconnectAll();
  });

  test(
    'the frame log is the session log and has traffic after a handshake',
    () async {
      final device = FakeDevice();
      final container = harness(device);
      await connectAndSelect(container);
      final log = container.read(frameLogProvider);
      expect(log, isNotNull);
      expect(log!.entries, isNotEmpty);
      expect(log.export(), contains('cmd='));
      await container.read(sessionsProvider.notifier).disconnectAll();
    },
  );

  test('with no session there is no frame log', () {
    final container = harness(FakeDevice());
    expect(container.read(frameLogProvider), isNull);
  });
}
