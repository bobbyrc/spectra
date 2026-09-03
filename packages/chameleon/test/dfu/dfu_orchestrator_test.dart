import 'dart:typed_data';

import 'package:chameleon/src/dfu/dfu_orchestrator.dart';
import 'package:chameleon/src/dfu/dfu_package.dart';
import 'package:chameleon/src/dfu/fake_dfu_channel.dart';
import 'package:chameleon/src/fake/fake_device.dart';
import 'package:chameleon/src/fake/fake_firmware.dart';
import 'package:chameleon/src/fake/fake_firmware_config.dart';
import 'package:chameleon/src/fake/fake_scanner.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:chameleon/src/session/cancel_token.dart';
import 'package:chameleon/src/session/connection_state.dart';
import 'package:chameleon/src/session/device_session.dart';
import 'package:test/test.dart';

import 'proto_builder.dart';

DfuPackage package(Uint8List bin, {int hw = 0}) => DfuPackage.fromZip(
  buildZip(
    bin: bin,
    dat: buildInitPacket(bin: bin, hwVersion: hw),
  ),
);

void main() {
  final bin = Uint8List.fromList(List.generate(6000, (i) => i & 0xFF));

  DeviceSession sessionFor(FakeDevice device) => DeviceSession(
    device,
    idlePollInterval: const Duration(days: 1),
    batteryDelay: Duration.zero,
  );

  final channels = <FakeDfuChannel>[];

  DfuOrchestrator orchestratorFor(
    FakeDevice device, {
    Duration latency = Duration.zero,
  }) => DfuOrchestrator(
    scanners: [FakeScanner.forDevice(device)],
    openChannel: (_) async {
      final c = device.openDfuChannel(latency: latency);
      channels.add(c);
      return c;
    },
    scanTimeout: const Duration(seconds: 1),
  );

  /// Puts [device] in the bootloader the way a previous, interrupted update
  /// would have: an ENTER_BOOTLOADER frame and nothing else.
  Future<void> enterBootloader(FakeDevice device) async {
    await device.open();
    await device.write(
      Uint8List.fromList([0x11, 0xEF, 0x03, 0xF2, 0, 0, 0, 0, 0x0B, 0x00]),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(device.inBootloader, isTrue);
  }

  setUp(channels.clear);

  test('updates a connected device end to end and finds it again', () async {
    final device = FakeDevice();
    final s = sessionFor(device);
    await s.open();
    final events = await orchestratorFor(device)
        .run(session: s, package: package(bin))
        .toList();
    expect(events.whereType<DfuPhaseChanged>().map((e) => e.phase), [
      DfuPhase.checking,
      DfuPhase.enteringBootloader,
      DfuPhase.findingBootloader,
      DfuPhase.transferring,
      DfuPhase.findingDevice,
      DfuPhase.done,
    ]);
    expect(
      events.last,
      isA<DfuCompleted>().having(
        (e) => e.device,
        'device',
        FakeScanner.emulatedUltra,
      ),
    );
    final progress = events.whereType<DfuProgressed>().toList();
    expect(progress, isNotEmpty);
    expect(progress.last.progress.bytesSent, bin.length);
    expect(device.bootloader.flashed, bin);
    expect(device.inBootloader, isFalse);
    expect(channels.single.isClosed, isTrue);
    // The session is deliberately left updating: the orchestrator does not
    // touch it after ENTER_BOOTLOADER, so the app's reconnect logic owns it.
    expect(s.connectionState.value, isA<SessionUpdating>());
    await s.close();
  });

  test(
    'refuses a package for the other model before touching the device',
    () async {
      final device = FakeDevice();
      final s = sessionFor(device);
      await s.open();
      final events = await orchestratorFor(device)
          .run(session: s, package: package(bin, hw: 1))
          .toList();
      expect(
        events.last,
        isA<DfuFailed>().having((e) => e.error, 'error', isA<DfuError>()),
      );
      expect(events.whereType<DfuPhaseChanged>().map((e) => e.phase), [
        DfuPhase.checking,
      ]);
      expect(device.firmware.bootloaderRequested, isFalse);
      expect(channels, isEmpty);
      await s.close();
    },
  );

  test(
    'recovers a device already in the bootloader without a session',
    () async {
      final device = FakeDevice();
      await enterBootloader(device);
      final events = await orchestratorFor(device)
          .run(
            package: package(bin),
            bootloader: FakeScanner.emulatedBootloader,
          )
          .toList();
      expect(
        events.whereType<DfuPhaseChanged>().first.phase,
        DfuPhase.transferring,
      );
      expect(events.last, isA<DfuCompleted>());
      expect(device.bootloader.flashed, bin);
    },
  );

  test('works on a limited session (outdated firmware)', () async {
    final device = FakeDevice(
      firmware: FakeFirmware(FakeFirmwareConfig.preTwoPointZero()),
    );
    final s = sessionFor(device);
    await s.open();
    expect(s.connectionState.value, isA<SessionLimited>());
    final events = await orchestratorFor(device)
        .run(session: s, package: package(bin))
        .toList();
    expect(events.last, isA<DfuCompleted>());
    await s.close();
  });

  test('bootloader not found is a DfuFailed', () async {
    final device = FakeDevice();
    final s = sessionFor(device);
    await s.open();
    final orchestrator = DfuOrchestrator(
      scanners: [FakeScanner(devices: const [])],
      openChannel: (_) async => device.openDfuChannel(),
      scanTimeout: const Duration(milliseconds: 50),
    );
    final events = await orchestrator
        .run(session: s, package: package(bin))
        .toList();
    expect(
      events.last,
      isA<DfuFailed>().having(
        (e) => e.error.message,
        'message',
        contains('bootloader'),
      ),
    );
    await s.close();
  });

  test('refuses a tampered image on the recovery path too', () async {
    final device = FakeDevice();
    await enterBootloader(device);
    final tampered = DfuPackage.fromZip(
      buildZip(
        bin: bin,
        dat: buildInitPacket(bin: Uint8List.fromList([1, 2, 3])),
      ),
    );
    final events = await orchestratorFor(device)
        .run(package: tampered, bootloader: FakeScanner.emulatedBootloader)
        .toList();
    expect(
      events.single,
      isA<DfuFailed>().having((e) => e.error, 'error', isA<DfuError>()),
    );
    expect(channels, isEmpty);
    // Nothing was created or written on the bootloader.
    expect(device.bootloader.flashed, isEmpty);
    expect(device.bootloader.bytesReceived, 0);
    expect(device.bootloader.init, isNull);
  });

  test('a channel that opens after an unsubscribe is still closed', () async {
    final device = FakeDevice();
    await enterBootloader(device);
    FakeDfuChannel? opened;
    final orchestrator = DfuOrchestrator(
      scanners: [FakeScanner.forDevice(device)],
      openChannel: (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return opened = device.openDfuChannel();
      },
      scanTimeout: const Duration(seconds: 1),
    );
    final sub = orchestrator
        .run(package: package(bin), bootloader: FakeScanner.emulatedBootloader)
        .listen((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await sub.cancel();
    expect(opened, isNotNull);
    expect(opened!.isClosed, isTrue);
  });

  test(
    'cancelling mid-transfer fails, closes the channel and stays recoverable',
    () async {
      final small = Uint8List.fromList(List.generate(600, (i) => i & 0xFF));
      final device = FakeDevice();
      final s = sessionFor(device);
      await s.open();
      final cancel = CancelToken();
      final events = <DfuEvent>[];
      final stream = orchestratorFor(
        device,
        latency: const Duration(milliseconds: 1),
      ).run(session: s, package: package(small), cancel: cancel);
      await for (final e in stream) {
        events.add(e);
        if (e is DfuProgressed) cancel.cancel();
      }
      expect(
        events.last,
        isA<DfuFailed>().having(
          (e) => e.error,
          'error',
          isA<CommandCancelled>(),
        ),
      );
      expect(channels.single.isClosed, isTrue);
      // Still in the bootloader: the update can be retried without a session.
      expect(device.inBootloader, isTrue);
      await s.close();
    },
  );
}
