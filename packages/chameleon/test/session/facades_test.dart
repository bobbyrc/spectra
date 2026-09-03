import 'dart:async';
import 'dart:typed_data';

import 'package:chameleon/src/fake/fake_device.dart';
import 'package:chameleon/src/model/enums.dart';
import 'package:chameleon/src/model/models.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:chameleon/src/session/connection_state.dart';
import 'package:chameleon/src/session/device_session.dart';
import 'package:chameleon/src/transport/transport.dart';
import 'package:test/test.dart';

/// A [FakeDevice] whose writes can be made to fail while the link stays up,
/// which no fake transport option produces on its own.
final class FailingWriteDevice implements Transport {
  FailingWriteDevice(this.inner);

  final FakeDevice inner;
  bool failWrites = false;

  @override
  Future<void> write(Uint8List bytes) async {
    if (failWrites) throw const Disconnected('write refused');
    return inner.write(bytes);
  }

  @override
  TransportKind get kind => inner.kind;
  @override
  Future<void> open() => inner.open();
  @override
  Future<void> close() => inner.close();
  @override
  Stream<Uint8List> get incoming => inner.incoming;
  @override
  Stream<TransportState> get state => inner.state;
  @override
  TransportState get currentState => inner.currentState;
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late FakeDevice device;
  late DeviceSession s;

  setUp(() async {
    device = FakeDevice();
    s = DeviceSession(
      device,
      idlePollInterval: const Duration(days: 1),
      batteryDelay: Duration.zero,
    );
    await s.open();
    await settle();
  });

  tearDown(() => s.close());

  test(
    'device facade reads battery and switches mode with write-through',
    () async {
      expect((await s.device.readBattery()).percent, 92);
      expect(s.battery.value?.percent, 92);
      expect(await s.device.readMode(), DeviceMode.emulator);
      await s.device.setMode(DeviceMode.reader);
      expect(s.mode.value, DeviceMode.reader);
      expect(device.firmware.mode, DeviceMode.reader);
      expect((await s.device.readIdentity()).chipId, '0102030405060708');
      expect(s.device.info?.identity?.chipId, '0102030405060708');
    },
  );

  test(
    'slot edits are written through, persisted and reflected in the cache',
    () async {
      await s.slots.setTagType(2, TagType.ntag216);
      await s.slots.setEnabled(2, Sense.hf, true);
      await s.slots.rename(2, Sense.hf, 'badge');
      await s.slots.setActive(2);
      expect(s.slots.current[2].hfType, TagType.ntag216);
      expect(s.slots.current[2].hfEnabled, isTrue);
      expect(s.slots.current[2].hfNick, 'badge');
      expect(s.slots.active, 2);
      expect(device.firmware.slotsSaved, isTrue);
      expect(device.firmware.slots[2].hfNick, 'badge');
      await s.slots.deleteSense(2, Sense.hf);
      expect(s.slots.current[2].hfType, TagType.undefined);
      expect(s.slots.current[2].hfEnabled, isFalse);
      final fresh = await s.slots.refresh();
      expect(fresh[2].hfEnabled, isFalse);
      expect(fresh[2].hfType, TagType.undefined);
    },
  );

  test('setMode is refused while a reader lease holds the mode', () async {
    final lease = await s.acquireReaderMode();
    await expectLater(s.device.setMode(DeviceMode.emulator), throwsStateError);
    expect(device.firmware.mode, DeviceMode.reader);
    await lease.release();
    await s.device.setMode(DeviceMode.reader);
    expect(s.mode.value, DeviceMode.reader);
  });

  test('re-reading unchanged settings wakes no listener', () async {
    final seen = <DeviceSettings?>[];
    s.settingsState.changes.listen(seen.add);
    await s.settings.refresh();
    await s.settings.refresh();
    await settle();
    expect(seen, isEmpty);
    await s.settings.setAnimation(AnimationMode.none);
    await settle();
    expect(seen, hasLength(1));
  });

  test('an undefined tag type clears both senses in the cache', () async {
    await s.slots.setTagType(0, TagType.undefined);
    expect(s.slots.current[0].hfType, TagType.undefined);
    expect(s.slots.current[0].lfType, TagType.undefined);
    final fresh = await s.slots.refresh();
    expect(fresh[0].hfType, TagType.undefined);
    expect(fresh[0].lfType, TagType.undefined);
  });

  test('resetToDefault clears emulator data for that sense', () async {
    await s.emulator.writeMf1Blocks(1, Uint8List.fromList(List.filled(16, 7)));
    await s.slots.resetToDefault(0, TagType.mifare1k);
    expect(await s.emulator.readMf1Blocks(1, 1), Uint8List(16));
    expect(s.slots.current[0].hfType, TagType.mifare1k);
    expect(device.firmware.slotsSaved, isTrue);
  });

  test('settings edits update the cache and save explicitly', () async {
    await s.settings.setAnimation(AnimationMode.minimal);
    await s.settings.setButton(
      DeviceButton.b,
      ButtonFunction.nfcFieldGenerator,
      long: true,
    );
    await s.settings.setButton(DeviceButton.a, ButtonFunction.battery);
    await s.settings.setSleepTimeout(20);
    expect(s.settings.current!.animation, AnimationMode.minimal);
    expect(s.settings.current!.longButtonB, ButtonFunction.nfcFieldGenerator);
    expect(s.settings.current!.buttonA, ButtonFunction.battery);
    expect(s.settings.current!.sleepTimeoutSeconds, 20);
    expect(device.firmware.savedSettings.animation, AnimationMode.full);
    await s.settings.save();
    expect(device.firmware.savedSettings.animation, AnimationMode.minimal);
    await s.settings.reset();
    expect(s.settings.current!.animation, AnimationMode.full);
    expect(s.settings.current!.buttonA, ButtonFunction.nextSlot);
  });

  test('BLE settings are written through and bonds can be dropped', () async {
    await s.settings.setBlePairingKey('654321');
    await s.settings.setBlePairingEnabled(true);
    expect(s.settings.current!.blePairingKey, '654321');
    expect(s.settings.current!.blePairingEnabled, isTrue);
    await s.settings.deleteAllBleBonds();
    final fresh = await s.settings.refresh();
    expect(fresh.blePairingKey, '654321');
    expect(fresh.blePairingEnabled, isTrue);
  });

  test('emulator facade chunks large block writes and reads', () async {
    final data = Uint8List.fromList(List.generate(64 * 16, (i) => i & 0xFF));
    await s.emulator.writeMf1Blocks(0, data);
    expect(await s.emulator.readMf1Blocks(0, 64), data);
    expect(device.received.where((f) => f.command == 4000).length, 2);
    expect(device.received.where((f) => f.command == 4008).length, 2);
    await expectLater(
      s.emulator.writeMf1Blocks(0, Uint8List(17)),
      throwsArgumentError,
    );
  });

  test('emulator facade anti-collision, config and LF ids', () async {
    final tag = Hf14aTag(
      uid: Uint8List.fromList([9, 8, 7, 6]),
      atqa: Uint8List.fromList([0, 4]),
      sak: 8,
      ats: Uint8List(0),
    );
    await s.emulator.setAntiColl(tag);
    expect((await s.emulator.getAntiColl()).uidHex, '09080706');
    await s.emulator.setMf1WriteMode(Mf1WriteMode.shadow);
    await s.emulator.setGen1a(true);
    await s.emulator.setGen2(true);
    await s.emulator.setBlockAntiColl(true);
    await s.emulator.setDetectionEnabled(true);
    final config = await s.emulator.getMf1Config();
    expect(config.writeMode, Mf1WriteMode.shadow);
    expect(config.gen1a, isTrue);
    expect(config.gen2, isTrue);
    expect(config.blockAntiColl, isTrue);
    expect(config.detectionEnabled, isTrue);
    expect(await s.emulator.readDetectionLog(), isEmpty);
    final id = Uint8List.fromList([1, 2, 3, 4, 5]);
    await s.emulator.setLfId(TagType.em410x, id);
    expect(await s.emulator.getLfId(TagType.em410x), id);
    await expectLater(
      s.emulator.setLfId(TagType.mifare1k, id),
      throwsArgumentError,
    );
    await expectLater(
      s.emulator.getLfId(TagType.mifare1k),
      throwsArgumentError,
    );
    await expectLater(
      s.emulator.setLfId(TagType.em410x, Uint8List(4)),
      throwsArgumentError,
    );
  });

  test('emulator facade reads and writes NTAG pages', () async {
    await s.slots.setTagType(3, TagType.ntag216);
    await s.slots.setActive(3);
    expect(await s.emulator.getNtagPageCount(), 231);
    final pages = Uint8List.fromList(List.generate(8, (i) => i + 1));
    await s.emulator.writeNtagPages(4, pages);
    expect(await s.emulator.readNtagPages(4, 2), pages);
  });

  test('firmware facade enters bootloader and stays updating', () async {
    await s.firmware.enterBootloader();
    await settle();
    expect(device.firmware.bootloaderRequested, isTrue);
    expect(s.connectionState.value, isA<SessionUpdating>());
  });

  test('a failed bootloader command leaves the session ready', () async {
    // The write fails with the link still up: nothing is rebooting, so a
    // session stranded in updating would refuse every later command.
    final flaky = FailingWriteDevice(FakeDevice());
    final other = DeviceSession(
      flaky,
      idlePollInterval: const Duration(days: 1),
      batteryDelay: Duration.zero,
    );
    await other.open();
    await settle();
    flaky.failWrites = true;
    await expectLater(
      other.firmware.enterBootloader(),
      throwsA(isA<ChameleonException>()),
    );
    expect(other.connectionState.value, isA<SessionReady>());
    await other.close();
  });

  test('entering the bootloader is refused when not connected', () async {
    await s.close();
    await expectLater(s.firmware.enterBootloader(), throwsStateError);
  });
}
