// Uses only the public barrel: no `package:chameleon/src/...` import appears
// here, so this file fails to compile if an export is missing.
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:test/test.dart';

import 'dfu/proto_builder.dart';

void main() {
  test(
    'an app can connect, read slots and scan using only public API',
    () async {
      final device = FakeDevice();
      final session = DeviceSession(
        device,
        idlePollInterval: const Duration(days: 1),
        batteryDelay: Duration.zero,
      );
      await session.open();
      expect(session.connectionState.value, isA<SessionReady>());

      final slots = await session.slots.refresh();
      expect(slots[0].hfType, TagType.mifare1k);
      expect(await session.reader.scan14a(), isEmpty);

      final dump = DumpFormats.parse(
        await session.emulator.readMf1Blocks(0, 64),
        TagType.mifare1k,
      );
      expect(dump, isA<MifareClassicDump>());
      expect(
        MifareClassicFormat().describe(dump as MifareClassicDump).first.label,
        'UID',
      );
      expect(MifareGeometry.sectorCount(TagType.mifare1k), 16);
      // The slot count belongs to the session, not to a loose top-level
      // constant, and `Status` is deliberately not exported (spec 3.3).
      expect(DeviceSession.slotCount, 8);
      expect(slots, hasLength(DeviceSession.slotCount));

      final scanners = <DeviceScanner>[FakeScanner()];
      expect(
        (await scanners.first.scan().first).single,
        FakeScanner.emulatedUltra,
      );
      expect(const HfTagNotFound(), isA<DeviceError>());
      await session.close();
    },
  );

  test('freezed models are usable through the barrel without their impls', () {
    const info = FirmwareVersion(major: 2, minor: 2);
    expect(info.copyWith(minor: 0), const FirmwareVersion(major: 2, minor: 0));
  });

  test('the frame log records and exports frames', () {
    final log = FrameLog(capacity: 2);
    log.add(FrameDirection.sent, Frame(command: 1000));
    log.add(
      FrameDirection.received,
      Frame(command: 1000, data: Uint8List.fromList([2, 2])),
    );
    expect(log.entries, hasLength(2));
    expect(log.entries.last.direction, FrameDirection.received);
    expect(log.export(), contains('cmd=1000'));
  });

  test('a cancel token reports its own cancellation', () {
    final token = CancelToken();
    expect(token.isCancelled, isFalse);
    token.cancel();
    expect(token.isCancelled, isTrue);
  });

  test(
    'the orchestrator refuses a package built for the other model',
    () async {
      final bin = Uint8List.fromList(List.generate(512, (i) => i & 0xFF));
      final device = FakeDevice();
      final session = DeviceSession(
        device,
        idlePollInterval: const Duration(days: 1),
        batteryDelay: Duration.zero,
      );
      await session.open();
      final orchestrator = DfuOrchestrator(
        scanners: [FakeScanner.forDevice(device)],
        openChannel: (_) async => device.openDfuChannel(),
        scanTimeout: const Duration(seconds: 1),
      );
      final events = await orchestrator
          .run(
            session: session,
            package: DfuPackage.fromZip(
              buildZip(
                bin: bin,
                dat: buildInitPacket(bin: bin, hwVersion: 1),
              ),
            ),
          )
          .toList();
      expect(events.last, isA<DfuFailed>());
      expect(device.inBootloader, isFalse);
      await session.close();
    },
  );
}
