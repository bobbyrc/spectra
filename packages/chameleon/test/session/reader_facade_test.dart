import 'dart:typed_data';

import 'package:chameleon/src/fake/fake_card.dart';
import 'package:chameleon/src/fake/fake_device.dart';
import 'package:chameleon/src/fake/fake_firmware.dart';
import 'package:chameleon/src/fake/fake_firmware_config.dart';
import 'package:chameleon/src/model/enums.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:chameleon/src/session/cancel_token.dart';
import 'package:chameleon/src/session/device_session.dart';
import 'package:chameleon/src/session/facades/reader.dart';
import 'package:test/test.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));
Uint8List b(List<int> l) => Uint8List.fromList(l);

DeviceSession sessionFor(FakeDevice device) => DeviceSession(
  device,
  idlePollInterval: const Duration(days: 1),
  batteryDelay: Duration.zero,
);

/// Every CHANGE_DEVICE_MODE the device saw, in order, as the mode asked for.
List<DeviceMode> modeChanges(FakeDevice d) => [
  for (final f in d.received)
    if (f.command == 1001) DeviceMode.fromCode(f.data[0]),
];

void main() {
  late FakeDevice device;
  late DeviceSession s;

  setUp(() async {
    device = FakeDevice();
    s = sessionFor(device);
    await s.open();
    await settle();
  });

  tearDown(() => s.close());

  test(
    'scan14a returns empty when no card and restores emulator mode',
    () async {
      expect(await s.reader.scan14a(), isEmpty);
      expect(device.firmware.mode, DeviceMode.emulator);
      expect(s.readerLeaseCount, 0);
    },
  );

  test('scan14a returns the presented card', () async {
    device.firmware.present(FakeMf1Card.classic1k(uid: b([1, 2, 3, 4])));
    final tags = await s.reader.scan14a();
    expect(tags.single.uidHex, '01020304');
    expect(await s.reader.detectMf1Support(), isTrue);
    expect(await s.reader.detectPrng(), PrngType.weak);
  });

  test('detectMf1Support is false and detectPrng null with no card', () async {
    expect(await s.reader.detectMf1Support(), isFalse);
    expect(await s.reader.detectPrng(), isNull);
    expect(device.firmware.mode, DeviceMode.emulator);
  });

  test(
    'mf1Auth is false on a wrong key, read and write work with the right key',
    () async {
      final card = FakeMf1Card.classic1k(uid: b([1, 2, 3, 4]));
      device.firmware.present(card);
      expect(await s.reader.mf1Auth(0, KeyType.a, Uint8List(6)), isFalse);
      expect(
        await s.reader.mf1Auth(0, KeyType.a, FakeMf1Card.defaultKey),
        isTrue,
      );
      final block = await s.reader.mf1ReadBlock(
        0,
        KeyType.a,
        FakeMf1Card.defaultKey,
      );
      expect(block.sublist(0, 4), [1, 2, 3, 4]);
      await s.reader.mf1WriteBlock(
        4,
        KeyType.a,
        FakeMf1Card.defaultKey,
        b(List.filled(16, 1)),
      );
      expect(card.blocks.sublist(64, 80), List.filled(16, 1));
      expect(device.firmware.mode, DeviceMode.emulator);
    },
  );

  test('a read with the wrong key still restores emulator mode', () async {
    device.firmware.present(FakeMf1Card.classic1k(uid: b([1, 2, 3, 4])));
    await expectLater(
      s.reader.mf1ReadBlock(0, KeyType.a, Uint8List(6)),
      throwsA(isA<AuthenticationFailed>()),
    );
    expect(device.firmware.mode, DeviceMode.emulator);
    expect(s.readerLeaseCount, 0);
  });

  test('mf1CheckKeys finds keys per sector', () async {
    device.firmware.present(FakeMf1Card.classic1k(uid: b([1, 2, 3, 4])));
    final r = await s.reader.mf1CheckKeys(
      sectors: {0, 1},
      keys: [Uint8List(6), FakeMf1Card.defaultKey],
    );
    expect(r.sectors[0].keyA, FakeMf1Card.defaultKey);
    expect(r.sectors[1].keyB, FakeMf1Card.defaultKey);
    expect(r.sectors[2].keyA, isNull);
  });

  test('mf1ReadDump reads every block of a 1K with the right keys and reports progress', () async {
    final card = FakeMf1Card.classic1k(uid: b([1, 2, 3, 4]));
    device.firmware.present(card);
    final progress = <int>[];
    final totals = <int>{};
    final dump = await s.reader.mf1ReadDump(
      type: TagType.mifare1k,
      candidateKeys: [FakeMf1Card.defaultKey],
      onProgress: (done, total) {
        progress.add(done);
        totals.add(total);
      },
    );
    expect(dump.blockCount, 64);
    expect(dump.isComplete, isTrue);
    expect(dump.blocks, card.blocks);
    expect(dump.keys, hasLength(16));
    expect(dump.keys[3].keyA, FakeMf1Card.defaultKey);
    expect(progress, List.generate(16, (i) => i + 1));
    expect(totals, {16});
    expect(device.firmware.mode, DeviceMode.emulator);
    expect(s.readerLeaseCount, 0);
  });

  test('mf1ReadDump marks unreadable sectors and stays partial', () async {
    final card = FakeMf1Card.classic1k(uid: b([1, 2, 3, 4]));
    card.keys.remove(FakeMf1Card.keyId(5, KeyType.a));
    card.keys.remove(FakeMf1Card.keyId(5, KeyType.b));
    device.firmware.present(card);
    final dump = await s.reader.mf1ReadDump(
      type: TagType.mifare1k,
      candidateKeys: [FakeMf1Card.defaultKey],
    );
    expect(dump.isComplete, isFalse);
    expect(dump.readMask.sublist(20, 24), everyElement(isFalse));
    expect(dump.readMask.sublist(0, 20), everyElement(isTrue));
    expect(dump.readMask.sublist(24), everyElement(isTrue));
    expect(dump.blocks.sublist(320, 384), everyElement(0));
    expect(dump.keys[5].keyA, isNull);
    expect(dump.keys[5].keyB, isNull);
  });

  test(
    'mf1ReadDump reads a sector with only key B in the dictionary',
    () async {
      final card = FakeMf1Card.classic1k(uid: b([1, 2, 3, 4]));
      card.keys.remove(FakeMf1Card.keyId(7, KeyType.a));
      device.firmware.present(card);
      final dump = await s.reader.mf1ReadDump(
        type: TagType.mifare1k,
        candidateKeys: [FakeMf1Card.defaultKey],
      );
      expect(dump.keys[7].keyA, isNull);
      expect(dump.keys[7].keyB, FakeMf1Card.defaultKey);
      expect(dump.readMask.sublist(28, 32), everyElement(isTrue));
      expect(dump.isComplete, isTrue);
      expect(dump.blocks, card.blocks);
    },
  );

  test('a dictionary larger than one request is checked in chunks', () async {
    final card = FakeMf1Card.classic1k(uid: b([1, 2, 3, 4]));
    device.firmware.present(card);
    // 100 keys, the only working one in the second chunk (index 90).
    final dictionary = [
      for (var i = 0; i < 100; i++) b([0, 0, 0, 0, 0, i & 0xFF]),
    ];
    dictionary[90] = FakeMf1Card.defaultKey;
    final dump = await s.reader.mf1ReadDump(
      type: TagType.mifare1k,
      candidateKeys: dictionary,
    );
    expect(dump.isComplete, isTrue);
    expect(dump.keys[0].keyA, FakeMf1Card.defaultKey);
    expect(device.received.where((f) => f.command == 2012), hasLength(2));
  });

  test(
    'a dictionary that works in its first chunk costs one request',
    () async {
      device.firmware.present(FakeMf1Card.classic1k(uid: b([1, 2, 3, 4])));
      final dictionary = [
        FakeMf1Card.defaultKey,
        for (var i = 0; i < 99; i++) b([0, 0, 0, 0, 0, i & 0xFF]),
      ];
      final dump = await s.reader.mf1ReadDump(
        type: TagType.mifare1k,
        candidateKeys: dictionary,
      );
      expect(dump.isComplete, isTrue);
      expect(device.received.where((f) => f.command == 2012), hasLength(1));
    },
  );

  test('mf1ReadDump falls back to per-block auth without CHECK_KEYS', () async {
    final device = FakeDevice(
      firmware: FakeFirmware(
        FakeFirmwareConfig(
          capabilities: FakeFirmwareConfig.defaultCapabilities(
            DeviceModel.ultra,
          )..remove(2012),
        ),
      ),
    );
    final s = sessionFor(device);
    addTearDown(s.close);
    await s.open();
    await settle();
    final card = FakeMf1Card.classic1k(uid: b([1, 2, 3, 4]));
    card.keys.remove(FakeMf1Card.keyId(2, KeyType.a));
    card.keys.remove(FakeMf1Card.keyId(2, KeyType.b));
    device.firmware.present(card);
    final dump = await s.reader.mf1ReadDump(
      type: TagType.mifare1k,
      candidateKeys: [Uint8List(6), FakeMf1Card.defaultKey],
    );
    expect(device.received.where((f) => f.command == 2012), isEmpty);
    expect(dump.isComplete, isFalse);
    expect(dump.keys[0].keyA, FakeMf1Card.defaultKey);
    expect(dump.keys[2].keyA, isNull);
    expect(dump.readMask.sublist(8, 12), everyElement(isFalse));
    expect(dump.readMask.sublist(12), everyElement(isTrue));
    expect(device.firmware.mode, DeviceMode.emulator);
  });

  test(
    'cancelling mid-dump throws and leaves the device in emulator mode',
    () async {
      device.firmware.present(FakeMf1Card.classic1k(uid: b([1, 2, 3, 4])));
      final cancel = CancelToken();
      final done = <int>[];
      await expectLater(
        s.reader.mf1ReadDump(
          type: TagType.mifare1k,
          candidateKeys: [FakeMf1Card.defaultKey],
          cancel: cancel,
          onProgress: (d, _) {
            done.add(d);
            if (d == 2) cancel.cancel();
          },
        ),
        throwsA(isA<CommandCancelled>()),
      );
      expect(done, [1, 2]);
      expect(device.firmware.mode, DeviceMode.emulator);
      expect(s.readerLeaseCount, 0);
      expect(s.isBusy, isFalse);
    },
  );

  test('LF scans return null when absent and bytes when present', () async {
    expect(await s.reader.scanEm410x(), isNull);
    device.firmware.present(FakeLfCard(3000, b([1, 2, 3, 4, 5])));
    expect(await s.reader.scanEm410x(), [1, 2, 3, 4, 5]);
    expect(await s.reader.scanHidProx(), isNull);
    expect(await s.reader.scanViking(), isNull);
    expect(await s.reader.scanPac(), isNull);
    expect(device.firmware.mode, DeviceMode.emulator);
  });

  test('a scan that starts while a lease is being released still runs in reader mode', () async {
    device.firmware.present(FakeMf1Card.classic1k(uid: b([1, 2, 3, 4])));
    final lease = await s.acquireReaderMode();
    expect(device.firmware.mode, DeviceMode.reader);
    // Acquire during release: the release's switch to emulator is in flight
    // when the scan asks for reader mode again.
    final releasing = lease.release();
    final scanning = s.reader.scan14a();
    final tags = await scanning;
    await releasing;
    expect(tags.single.uidHex, '01020304');
    expect(device.firmware.mode, DeviceMode.emulator);
    expect(s.readerLeaseCount, 0);
    // One switch per direction per transition, alternating, ending emulator.
    expect(modeChanges(device), [
      DeviceMode.reader,
      DeviceMode.emulator,
      DeviceMode.reader,
      DeviceMode.emulator,
    ]);
  });

  test('a device with no reader refuses reader work', () async {
    final device = FakeDevice(
      firmware: FakeFirmware(FakeFirmwareConfig.lite22()),
    );
    final s = sessionFor(device);
    addTearDown(s.close);
    await s.open();
    await settle();
    await expectLater(s.reader.scan14a(), throwsA(isA<ReaderUnavailable>()));
    expect(s.readerLeaseCount, 0);
  });

  test('geometry helpers', () {
    expect(ReaderFacade.sectorCount(TagType.mifare1k), 16);
    expect(ReaderFacade.sectorCount(TagType.mifare4k), 40);
    expect(ReaderFacade.blockCount(TagType.mifareMini), 20);
    expect(ReaderFacade.firstBlockOf(32), 128);
    expect(ReaderFacade.blocksInSector(39), 16);
  });
}
