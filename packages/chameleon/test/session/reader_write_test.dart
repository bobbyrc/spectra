import 'dart:typed_data';

import 'package:chameleon/src/fake/fake_card.dart';
import 'package:chameleon/src/fake/fake_device.dart';
import 'package:chameleon/src/fake/fake_firmware.dart';
import 'package:chameleon/src/fake/fake_firmware_config.dart';
import 'package:chameleon/src/model/enums.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:chameleon/src/session/cancel_token.dart';
import 'package:chameleon/src/session/device_session.dart';
import 'package:test/test.dart';

import 'session_helpers.dart';

Uint8List b(List<int> l) => Uint8List.fromList(l);

/// A 1K dump whose every data block is filled with [fill], with a valid
/// block 0 (UID + BCC) and the transport trailers a blank card ships with.
Uint8List dump1k(int fill) {
  final Uint8List blocks = Uint8List(64 * 16);
  for (int block = 0; block < 64; block++) {
    if (block % 4 == 3 || block == 0) continue;
    blocks.fillRange(block * 16, block * 16 + 16, fill);
  }
  return blocks;
}

void main() {
  late FakeDevice device;
  late DeviceSession s;

  setUp(() async {
    device = FakeDevice();
    s = sessionFor(device);
    await s.open();
    await awaitBackgroundLoad(s);
  });

  tearDown(() => s.close());

  test('mf1WriteDump writes every data block and skips block 0', () async {
    final FakeMf1Card card = FakeMf1Card.classic1k(
      uid: b(<int>[0x11, 0x22, 0x33, 0x44]),
    );
    device.firmware.present(card);

    final result = await s.reader.mf1WriteDump(
      type: TagType.mifare1k,
      blocks: dump1k(0xAB),
      candidateKeys: <Uint8List>[FakeMf1Card.defaultKey],
    );

    // 64 blocks, minus block 0 and the 16 trailers = 47 attempted.
    expect(result.blockCount, 64);
    expect(result.attemptedBlockCount, 47);
    expect(result.writtenBlockCount, 47);
    expect(result.failedBlockCount, 0);
    expect(result.isComplete, isTrue);
    expect(result.writeMask[0], isFalse);
    expect(result.writeMask[3], isFalse); // trailer of sector 0
    expect(card.blocks.sublist(16, 32), everyElement(0xAB));
    // Block 0 was left exactly as the card had it.
    expect(card.blocks.sublist(0, 4), b(<int>[0x11, 0x22, 0x33, 0x44]));
  });

  test('mf1WriteDump writes trailers when asked', () async {
    final FakeMf1Card card = FakeMf1Card.classic1k(uid: b(<int>[1, 2, 3, 4]));
    device.firmware.present(card);
    final Uint8List blocks = dump1k(0x01);
    blocks.fillRange(3 * 16, 4 * 16, 0x77);

    final result = await s.reader.mf1WriteDump(
      type: TagType.mifare1k,
      blocks: blocks,
      candidateKeys: <Uint8List>[FakeMf1Card.defaultKey],
      writeTrailers: true,
    );

    expect(result.attemptedBlockCount, 63);
    expect(card.blocks.sublist(3 * 16, 4 * 16), everyElement(0x77));
  });

  test('a sector with no known key fails its blocks, not the run', () async {
    final FakeMf1Card card = FakeMf1Card.classic1k(uid: b(<int>[1, 2, 3, 4]));
    // Lock sector 1 behind a key the dictionary does not carry.
    card.keys[FakeMf1Card.keyId(1, KeyType.a)] = b(<int>[9, 9, 9, 9, 9, 9]);
    card.keys[FakeMf1Card.keyId(1, KeyType.b)] = b(<int>[9, 9, 9, 9, 9, 9]);
    device.firmware.present(card);

    final result = await s.reader.mf1WriteDump(
      type: TagType.mifare1k,
      blocks: dump1k(0x5A),
      candidateKeys: <Uint8List>[FakeMf1Card.defaultKey],
    );

    expect(result.isComplete, isFalse);
    expect(result.failedBlockCount, 3); // blocks 4, 5, 6
    expect(result.writeMask[4], isFalse);
    expect(result.writeMask[8], isTrue);
    expect(card.blocks.sublist(4 * 16, 5 * 16), everyElement(0x00));
  });

  test('a sector known only by key B still gets its blocks written', () async {
    final FakeMf1Card card = FakeMf1Card.classic1k(uid: b(<int>[1, 2, 3, 4]));
    // Sector 1's key A is not the dictionary's key; only key B still is,
    // so this exercises the A-then-B fallback in `_writeOneBlock`.
    card.keys[FakeMf1Card.keyId(1, KeyType.a)] = b(<int>[9, 9, 9, 9, 9, 9]);
    device.firmware.present(card);

    final result = await s.reader.mf1WriteDump(
      type: TagType.mifare1k,
      blocks: dump1k(0x42),
      candidateKeys: <Uint8List>[FakeMf1Card.defaultKey],
    );

    expect(result.writeMask[4], isTrue);
    expect(result.writeMask[5], isTrue);
    expect(result.writeMask[6], isTrue);
    expect(card.blocks.sublist(4 * 16, 5 * 16), everyElement(0x42));
    expect(result.isComplete, isTrue);
  });

  test(
    'mf1WriteDump reports progress per sector and ends in emulator mode',
    () async {
      device.firmware.present(FakeMf1Card.classic1k(uid: b(<int>[1, 2, 3, 4])));
      final List<(int, int)> seen = <(int, int)>[];

      await s.reader.mf1WriteDump(
        type: TagType.mifare1k,
        blocks: dump1k(0x10),
        candidateKeys: <Uint8List>[FakeMf1Card.defaultKey],
        onProgress: (int done, int total) => seen.add((done, total)),
      );

      expect(seen.length, 16);
      expect(seen.last, (16, 16));
      expect(s.readerLeaseCount, 0);
      expect(s.mode.value, DeviceMode.emulator);
    },
  );

  test('mf1WriteDump refuses a dump of the wrong length', () {
    expect(
      () => s.reader.mf1WriteDump(
        type: TagType.mifare1k,
        blocks: Uint8List(16),
        candidateKeys: <Uint8List>[FakeMf1Card.defaultKey],
      ),
      throwsArgumentError,
    );
  });

  test(
    'cancelling mid-write throws and leaves a partial write in place',
    () async {
      final FakeMf1Card card = FakeMf1Card.classic1k(uid: b(<int>[1, 2, 3, 4]));
      device.firmware.present(card);
      final CancelToken cancel = CancelToken();
      final List<int> done = <int>[];

      await expectLater(
        s.reader.mf1WriteDump(
          type: TagType.mifare1k,
          blocks: dump1k(0x9C),
          candidateKeys: <Uint8List>[FakeMf1Card.defaultKey],
          cancel: cancel,
          onProgress: (int d, int _) {
            done.add(d);
            if (d == 1) cancel.cancel();
          },
        ),
        throwsA(isA<CommandCancelled>()),
      );

      expect(done, <int>[1]);
      // Sector 0's data block was written before the cancel landed; sector 1
      // never started.
      expect(card.blocks.sublist(16, 32), everyElement(0x9C));
      expect(card.blocks.sublist(4 * 16, 5 * 16), everyElement(0x00));
      expect(s.readerLeaseCount, 0);
      expect(s.mode.value, DeviceMode.emulator);
    },
  );

  test(
    'a write command missing from the device bails the whole dump',
    () async {
      final Set<int> capabilities = FakeFirmwareConfig.defaultCapabilities(
        DeviceModel.ultra,
      )..remove(2009); // MF1_WRITE_ONE_BLOCK
      final FakeDevice noWriteDevice = FakeDevice(
        firmware: FakeFirmware(FakeFirmwareConfig(capabilities: capabilities)),
      );
      final DeviceSession noWriteSession = sessionFor(noWriteDevice);
      await noWriteSession.open();
      await awaitBackgroundLoad(noWriteSession);
      addTearDown(noWriteSession.close);

      final FakeMf1Card card = FakeMf1Card.classic1k(uid: b(<int>[1, 2, 3, 4]));
      noWriteDevice.firmware.present(card);
      final List<int> done = <int>[];

      await expectLater(
        noWriteSession.reader.mf1WriteDump(
          type: TagType.mifare1k,
          blocks: dump1k(0x33),
          candidateKeys: <Uint8List>[FakeMf1Card.defaultKey],
          onProgress: (int d, int _) => done.add(d),
        ),
        throwsA(isA<InvalidCommand>()),
      );

      // Bailed on the very first write attempt: not even sector 0 finished,
      // so onProgress never fired and nothing landed on the card.
      expect(done, isEmpty);
      expect(card.blocks.sublist(16, 32), everyElement(0x00));
      expect(noWriteSession.readerLeaseCount, 0);
      expect(noWriteSession.mode.value, DeviceMode.emulator);
    },
  );

  test('em410xWriteToT55xx rewrites the card the reader then scans', () async {
    device.firmware.present(
      FakeLfCard(3000, b(<int>[0x11, 0x22, 0x33, 0x44, 0x55])),
    );

    await s.reader.em410xWriteToT55xx(
      id: b(<int>[0xAA, 0xBB, 0xCC, 0xDD, 0xEE]),
      newKey: b(<int>[0x20, 0x20, 0x66, 0x66]),
      oldKeys: <Uint8List>[
        b(<int>[0x51, 0x24, 0x36, 0x48]),
      ],
    );

    expect(await s.reader.scanEm410x(), b(<int>[0xAA, 0xBB, 0xCC, 0xDD, 0xEE]));
    expect(s.readerLeaseCount, 0);
  });

  test(
    'em410xWriteToT55xx with no card in the field is LfTagNotFound',
    () async {
      await expectLater(
        s.reader.em410xWriteToT55xx(
          id: b(<int>[1, 2, 3, 4, 5]),
          newKey: b(<int>[0x20, 0x20, 0x66, 0x66]),
          oldKeys: const <Uint8List>[],
        ),
        throwsA(isA<LfTagNotFound>()),
      );
    },
  );
}
