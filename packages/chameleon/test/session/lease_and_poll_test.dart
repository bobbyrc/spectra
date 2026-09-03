import 'package:chameleon/src/fake/fake_device.dart';
import 'package:chameleon/src/fake/fake_firmware.dart';
import 'package:chameleon/src/fake/fake_firmware_config.dart';
import 'package:chameleon/src/model/enums.dart';
import 'package:chameleon/src/model/models.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:chameleon/src/session/device_session.dart';
import 'package:test/test.dart';

/// Timing here is deliberately small: poll intervals of tens of milliseconds
/// and no battery delay, so the whole file runs in well under a second.
Future<void> settle([int ms = 20]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

DeviceSession sessionFor(
  FakeDevice device, {
  Duration poll = const Duration(days: 1),
}) =>
    DeviceSession(device, idlePollInterval: poll, batteryDelay: Duration.zero);

void main() {
  test('nested leases switch mode once and restore once', () async {
    final device = FakeDevice();
    final s = sessionFor(device);
    await s.open();
    await settle();
    final before = device.received.length;
    final outer = await s.acquireReaderMode();
    final inner = await s.acquireReaderMode();
    expect(device.firmware.mode, DeviceMode.reader);
    expect(s.readerLeaseCount, 2);
    await inner.release();
    expect(device.firmware.mode, DeviceMode.reader);
    expect(inner.isReleased, isTrue);
    await outer.release();
    expect(device.firmware.mode, DeviceMode.emulator);
    expect(s.mode.value, DeviceMode.emulator);
    expect(s.readerLeaseCount, 0);
    final modeChanges = device.received
        .skip(before)
        .where((f) => f.command == 1001)
        .length;
    expect(modeChanges, 2);
    await s.close();
  });

  test('releasing a lease twice is a no-op', () async {
    final device = FakeDevice();
    final s = sessionFor(device);
    await s.open();
    await settle();
    final lease = await s.acquireReaderMode();
    await lease.release();
    final after = device.received.length;
    await lease.release();
    expect(s.readerLeaseCount, 0);
    expect(device.received.length, after);
    await s.close();
  });

  test('withReaderMode restores mode when the body throws', () async {
    final device = FakeDevice();
    final s = sessionFor(device);
    await s.open();
    await settle();
    await expectLater(
      s.withReaderMode(() async => throw StateError('boom')),
      throwsStateError,
    );
    expect(device.firmware.mode, DeviceMode.emulator);
    expect(s.readerLeaseCount, 0);
    await s.close();
  });

  test('a refused mode change leaves no lease behind', () async {
    // A device that does not answer CHANGE_DEVICE_MODE (1001).
    final config = FakeFirmwareConfig(
      capabilities: FakeFirmwareConfig.defaultCapabilities(DeviceModel.ultra)
        ..remove(1001),
    );
    final device = FakeDevice(firmware: FakeFirmware(config));
    final s = sessionFor(device);
    await s.open();
    await settle();
    await expectLater(s.acquireReaderMode(), throwsA(isA<DeviceError>()));
    expect(s.readerLeaseCount, 0);
    await s.close();
  });

  test('a Lite cannot acquire a reader lease', () async {
    final s = sessionFor(
      FakeDevice(firmware: FakeFirmware(FakeFirmwareConfig.lite22())),
    );
    await s.open();
    await expectLater(s.acquireReaderMode(), throwsA(isA<ReaderUnavailable>()));
    expect(s.readerLeaseCount, 0);
    await s.close();
  });

  test('busy tracks the block and rethrows the body error', () async {
    final device = FakeDevice();
    final s = sessionFor(device);
    await s.open();
    await settle();
    expect(s.isBusy, isFalse);
    await expectLater(
      s.busy(() async {
        expect(s.isBusy, isTrue);
        throw StateError('boom');
      }),
      throwsStateError,
    );
    expect(s.isBusy, isFalse);
    await s.close();
  });

  test('idle poll picks up an active slot changed on the device', () async {
    final device = FakeDevice();
    final s = sessionFor(device, poll: const Duration(milliseconds: 30));
    await s.open();
    await settle();
    expect(s.activeSlot.value, 0);
    device.firmware.activeSlot = 4; // as if button A was pressed
    device.firmware.battery = const BatteryInfo(millivolts: 3700, percent: 40);
    await settle(120);
    expect(s.activeSlot.value, 4);
    expect(s.battery.value!.percent, 40);
    await s.close();
  });

  test('an unchanged device polls without re-emitting state', () async {
    final device = FakeDevice();
    final s = sessionFor(device, poll: const Duration(milliseconds: 10));
    await s.open();
    await settle(40);
    final events = <Object?>[];
    s.activeSlot.changes.listen(events.add);
    s.mode.changes.listen(events.add);
    s.battery.changes.listen(events.add);
    final before = device.received.length;
    await settle(80);
    expect(device.received.length, greaterThan(before), reason: 'polled');
    expect(events, isEmpty);
    await s.close();
  });

  test(
    'a failing poll reports in the background without disconnecting',
    () async {
      final device = FakeDevice();
      final s = sessionFor(device, poll: const Duration(milliseconds: 20));
      final errors = <ChameleonException>[];
      s.backgroundErrors.listen(errors.add);
      await s.open();
      await settle();
      device.firmware.config.effectiveCapabilities.remove(1018);
      await settle(80);
      expect(errors, isNotEmpty);
      expect(s.isReady, isTrue);
      await s.close();
    },
  );

  test('idle poll pauses while a lease or busy block is active', () async {
    final device = FakeDevice();
    final s = sessionFor(device, poll: const Duration(milliseconds: 20));
    await s.open();
    await settle();
    final lease = await s.acquireReaderMode();
    final n = device.received.length;
    await settle(70);
    expect(device.received.length, n);
    await lease.release();
    await s.busy(() async {
      final m = device.received.length;
      await settle(70);
      expect(device.received.length, m);
    });
    await settle(60);
    expect(device.received.length, greaterThan(n));
    await s.close();
  });

  test('polling stops after close', () async {
    final device = FakeDevice();
    final s = sessionFor(device, poll: const Duration(milliseconds: 20));
    await s.open();
    await s.close();
    final n = device.received.length;
    await settle(80);
    expect(device.received.length, n);
  });
}
