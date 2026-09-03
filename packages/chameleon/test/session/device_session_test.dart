import 'dart:typed_data';

import 'package:chameleon/src/codec/bytes.dart';
import 'package:chameleon/src/commands/device.dart';
import 'package:chameleon/src/fake/fake_device.dart';
import 'package:chameleon/src/fake/fake_firmware.dart';
import 'package:chameleon/src/fake/fake_firmware_config.dart';
import 'package:chameleon/src/model/enums.dart';
import 'package:chameleon/src/model/models.dart';
import 'package:chameleon/src/protocol/command.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:chameleon/src/session/connection_state.dart';
import 'package:chameleon/src/session/device_session.dart';
import 'package:chameleon/src/transport/transport.dart';
import 'package:test/test.dart';

DeviceSession sessionFor(FakeFirmwareConfig config, {FakeDevice? device}) =>
    DeviceSession(
      device ?? FakeDevice(firmware: FakeFirmware(config)),
      idlePollInterval: const Duration(days: 1),
      batteryDelay: Duration.zero,
    );

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

/// GET_ACTIVE_SLOT (1018) with a short timeout, so the retry-on-timeout
/// tests finish in milliseconds instead of the catalog's three seconds. The
/// idempotent flag is a parameter so both branches of the retry rule can be
/// exercised with the same wire behaviour.
final class FastActiveSlot extends Command<int> {
  const FastActiveSlot({required this.idempotent});

  @override
  final bool idempotent;

  @override
  int get id => 1018;

  @override
  Duration get timeout => const Duration(milliseconds: 30);

  @override
  int decode(Uint8List data) => ByteReader(data).u8();
}

void main() {
  test(
    'reaches ready on a 2.2 Ultra with only three handshake commands',
    () async {
      final device = FakeDevice();
      final s = sessionFor(FakeFirmwareConfig.ultra22(), device: device);
      final states = <ConnectionState>[];
      s.connectionState.changes.listen(states.add);
      await s.open();
      expect(s.connectionState.value, isA<SessionReady>());
      expect(device.received.take(3).map((f) => f.command), [1035, 1000, 1033]);
      expect(states.first, isA<SessionConnecting>());
      expect(s.deviceInfo.value!.model, DeviceModel.ultra);
      await s.close();
      expect(
        s.connectionState.value,
        isA<SessionDisconnected>().having(
          (d) => d.cause,
          'cause',
          DisconnectCause.requested,
        ),
      );
    },
  );

  test(
    'loads identity, mode, slots, settings and battery in the background',
    () async {
      final s = sessionFor(FakeFirmwareConfig.ultra22());
      await s.open();
      await settle();
      expect(s.deviceInfo.value!.identity!.chipId, '0102030405060708');
      expect(s.deviceInfo.value!.gitVersion, 'v2.2.0-fake');
      expect(s.mode.value, DeviceMode.emulator);
      expect(s.slotsState.value.length, 8);
      expect(s.slotsState.value[0].hfNick, 'Fake 1K');
      expect(s.activeSlot.value, 0);
      expect(s.settingsState.value!.blePairingKey, '123456');
      expect(s.battery.value!.percent, 92);
      await s.close();
    },
  );

  test(
    '2.0 firmware without GET_ALL_SLOT_NICKS still loads nicknames',
    () async {
      final s = sessionFor(FakeFirmwareConfig.ultra20());
      await s.open();
      await settle();
      expect(s.connectionState.value, isA<SessionReady>());
      expect(s.slotsState.value[0].hfNick, 'Fake 1K');
      expect(s.settingsState.value!.sleepTimeoutSeconds, isNull);
      await s.close();
    },
  );

  test('pre-2.0 firmware lands in limited(preTwoPointZero)', () async {
    final s = sessionFor(FakeFirmwareConfig.preTwoPointZero());
    await s.open();
    expect(
      s.connectionState.value,
      isA<SessionLimited>().having(
        (l) => l.reason,
        'reason',
        UnsupportedReason.preTwoPointZero,
      ),
    );
    await s.close();
  });

  test('legacy 0.1 lands in limited(legacyMustUpdate)', () async {
    final s = sessionFor(FakeFirmwareConfig.legacy01());
    await s.open();
    final limited = s.connectionState.value as SessionLimited;
    expect(limited.reason, UnsupportedReason.legacyMustUpdate);
    expect(limited.version, const FirmwareVersion(major: 0, minor: 1));
    await s.close();
  });

  test('a newer major lands in limited(newerMajor)', () async {
    final s = sessionFor(
      FakeFirmwareConfig(version: const FirmwareVersion(major: 3, minor: 0)),
    );
    await s.open();
    expect(
      (s.connectionState.value as SessionLimited).reason,
      UnsupportedReason.newerMajor,
    );
    await s.close();
  });

  test(
    'limited sessions refuse ordinary commands but allow ENTER_BOOTLOADER',
    () async {
      final device = FakeDevice(
        firmware: FakeFirmware(FakeFirmwareConfig.preTwoPointZero()),
      );
      final s = sessionFor(
        FakeFirmwareConfig.preTwoPointZero(),
        device: device,
      );
      await s.open();
      // The refusal carries why the firmware is unusable, so the app can
      // say "update me" rather than "not ready".
      await expectLater(
        s.send(const GetActiveSlot()),
        throwsA(
          isA<UnsupportedFirmware>().having(
            (e) => e.reason,
            'reason',
            UnsupportedReason.preTwoPointZero,
          ),
        ),
      );
      await s.send(const EnterBootloader(), allowLimited: true);
      expect(device.firmware.bootloaderRequested, isTrue);
      // The device reboots without answering: the close that follows was
      // asked for, so it is reported as expected rather than as a link loss.
      await settle();
      expect(
        s.connectionState.value,
        isA<SessionDisconnected>().having(
          (d) => d.cause,
          'cause',
          DisconnectCause.expected,
        ),
      );
      await s.close();
    },
  );

  test('background failures surface as errors, not refusals', () async {
    final device = FakeDevice();
    final s = sessionFor(FakeFirmwareConfig.ultra22(), device: device);
    device.firmware.config.effectiveCapabilities.remove(1034);
    final errors = <ChameleonException>[];
    s.backgroundErrors.listen(errors.add);
    await s.open();
    await settle();
    expect(s.connectionState.value, isA<SessionReady>());
    expect(s.settingsState.value, isNull);
    expect(errors.whereType<InvalidCommand>(), isNotEmpty);
    await s.close();
  });

  test('link loss while ready is an unexpected disconnect', () async {
    final device = FakeDevice();
    final s = sessionFor(FakeFirmwareConfig.ultra22(), device: device);
    await s.open();
    await device.simulateLinkLoss();
    await settle();
    expect(
      (s.connectionState.value as SessionDisconnected).cause,
      DisconnectCause.unexpected,
    );
    await s.close();
  });

  test(
    'a lost link releases the transport and refuses later commands',
    () async {
      final device = FakeDevice();
      final s = sessionFor(FakeFirmwareConfig.ultra22(), device: device);
      await s.open();
      await device.simulateLinkLoss();
      await settle();
      await expectLater(
        s.send(const GetActiveSlot()),
        throwsA(isA<SessionNotReady>()),
      );
      // The dispatcher went with the link, but the last known state is still
      // readable and close() is still safe.
      expect(s.deviceInfo.value, isNotNull);
      await s.close();
      expect(s.connectionState.value, isA<SessionDisconnected>());
    },
  );

  test('opening twice is a programming error', () async {
    final s = sessionFor(FakeFirmwareConfig.ultra22());
    await s.open();
    await expectLater(s.open(), throwsA(isA<StateError>()));
    await s.close();
    await expectLater(s.open(), throwsA(isA<StateError>()));
  });

  test('concurrent opens share one handshake', () async {
    final device = FakeDevice();
    final s = sessionFor(FakeFirmwareConfig.ultra22(), device: device);
    await Future.wait([s.open(), s.open()]);
    expect(s.connectionState.value, isA<SessionReady>());
    expect(device.received.where((f) => f.command == 1035), hasLength(1));
    await s.close();
  });

  test('transport open failure is reported and rethrown', () async {
    final device = FakeDevice(openError: const PermissionDenied());
    final s = sessionFor(FakeFirmwareConfig.ultra22(), device: device);
    await expectLater(s.open(), throwsA(isA<PermissionDenied>()));
    expect(
      (s.connectionState.value as SessionDisconnected).error,
      isA<PermissionDenied>(),
    );
    await s.close();
  });

  test('an idempotent read is retried once after a dropped response', () async {
    final device = FakeDevice();
    final s = sessionFor(FakeFirmwareConfig.ultra22(), device: device);
    await s.open();
    await settle();
    final before = device.received.length;
    device.dropNextResponse();
    expect(await s.send(const FastActiveSlot(idempotent: true)), 0);
    expect(device.received.length - before, 2);
    await s.close();
  });

  test('a non-idempotent command is not retried', () async {
    final device = FakeDevice();
    final s = sessionFor(FakeFirmwareConfig.ultra22(), device: device);
    await s.open();
    await settle();
    final before = device.received.length;
    device.dropNextResponse();
    await expectLater(
      s.send(const FastActiveSlot(idempotent: false)),
      throwsA(isA<CommandTimeout>()),
    );
    expect(device.received.length - before, 1);
    await s.close();
  });

  test('close shuts the session streams down', () async {
    final s = sessionFor(FakeFirmwareConfig.ultra22());
    await s.open();
    await settle();
    await s.close();
    expect(s.backgroundErrors.isBroadcast, isTrue);
    await expectLater(s.connectionState.changes.isEmpty, completion(isTrue));
    await expectLater(s.backgroundErrors.isEmpty, completion(isTrue));
    await expectLater(
      s.send(const GetActiveSlot()),
      throwsA(isA<SessionNotReady>()),
    );
  });

  test('the first battery read waits out the battery delay', () async {
    // The firmware reports garbage for the first seconds after power-up, so
    // the background load holds GET_BATTERY_INFO (1025) back that long.
    final device = FakeDevice();
    final s = DeviceSession(
      device,
      idlePollInterval: const Duration(days: 1),
      batteryDelay: const Duration(milliseconds: 200),
    );
    await s.open();
    await settle();
    expect(device.received.where((f) => f.command == 1025), isEmpty);
    expect(s.battery.value, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(device.received.where((f) => f.command == 1025), hasLength(1));
    expect(s.battery.value, isNotNull);
    await s.close();
  });

  group('a transport state that is not a close but stops the link', () {
    for (final (state, error) in <(TransportState, Type)>[
      (const TransportPairingRequired(), PairingRequired),
      (const TransportPermissionDenied(), PermissionDenied),
      (const TransportAdapterOff(), AdapterOff),
    ]) {
      test(
        '${state.runtimeType} disconnects the session with $error',
        () async {
          final device = FakeDevice();
          final s = sessionFor(FakeFirmwareConfig.ultra22(), device: device);
          await s.open();
          expect(s.connectionState.value, isA<SessionReady>());
          device.emitState(state);
          await settle();
          expect(
            s.connectionState.value,
            isA<SessionDisconnected>()
                .having((d) => d.cause, 'cause', DisconnectCause.unexpected)
                .having((d) => d.error, 'error', isA<TransportError>()),
          );
          expect(s.connectionState.value, isA<SessionDisconnected>());
          expect(
            (s.connectionState.value as SessionDisconnected).error.runtimeType,
            error,
          );
          await s.close();
        },
      );

      test(
        'open() throws $error when ${state.runtimeType} arrives while connecting',
        () async {
          final device = FakeDevice(latency: const Duration(milliseconds: 20));
          final s = sessionFor(FakeFirmwareConfig.ultra22(), device: device);
          final opening = s.open();
          device.emitState(state, setCurrent: false);
          await expectLater(opening, throwsA(isA<TransportError>()));
          expect(s.connectionState.value, isA<SessionDisconnected>());
          expect(
            (s.connectionState.value as SessionDisconnected).error.runtimeType,
            error,
          );
          await s.close();
        },
      );
    }
  });

  test('a disconnected session is spent and cannot be opened again', () async {
    final device = FakeDevice();
    final s = sessionFor(FakeFirmwareConfig.ultra22(), device: device);
    await s.open();
    await device.simulateLinkLoss();
    await settle();
    expect(s.connectionState.value, isA<SessionDisconnected>());
    await device.open();
    expect(
      s.open,
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('spent'),
        ),
      ),
    );
    await s.close();
  });

  test('a silent pre-2.0 device reaches limited in seconds', () async {
    // Both handshake probes (1035, 1000) go unanswered: one second each,
    // no retry, so an old device is diagnosed instead of hanging the UI.
    final device = FakeDevice()
      ..dropNextResponse()
      ..dropNextResponse();
    final s = sessionFor(FakeFirmwareConfig.ultra22(), device: device);
    final watch = Stopwatch()..start();
    await s.open();
    watch.stop();
    expect(
      s.connectionState.value,
      isA<SessionLimited>().having(
        (l) => l.reason,
        'reason',
        UnsupportedReason.preTwoPointZero,
      ),
    );
    // Two one-second probes plus the 500 ms drain between them. Before the
    // probe timeouts this was two three-second timeouts with a retry each.
    expect(watch.elapsedMilliseconds, lessThan(3000));
    await s.close();
  });

  test('one dropped response does not stall the next command', () async {
    // The command's own three-second timeout dominates; what the bounded
    // drain window buys is the rest — the retry and the seven commands after
    // it are held for 500 ms, not for another full timeout (which used to
    // make this run past six seconds).
    final device = FakeDevice();
    final s = sessionFor(FakeFirmwareConfig.ultra22(), device: device);
    await s.open();
    await settle();
    device.dropNextResponse();
    final watch = Stopwatch()..start();
    final slots = await s.slots.refresh();
    watch.stop();
    expect(slots, hasLength(DeviceSession.slotCount));
    expect(watch.elapsedMilliseconds, lessThan(4000));
    await s.close();
  });
}
