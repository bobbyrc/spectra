import 'dart:typed_data';

import 'package:chameleon/src/codec/frame.dart';
import 'package:chameleon/src/commands/device.dart';
import 'package:chameleon/src/commands/hf_emulator.dart';
import 'package:chameleon/src/commands/hf_reader.dart';
import 'package:chameleon/src/commands/lf_emulator.dart';
import 'package:chameleon/src/commands/lf_reader.dart';
import 'package:chameleon/src/fake/fake_card.dart';
import 'package:chameleon/src/fake/fake_firmware.dart';
import 'package:chameleon/src/fake/fake_firmware_config.dart';
import 'package:chameleon/src/model/enums.dart';
import 'package:chameleon/src/protocol/command.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:chameleon/src/protocol/status.dart';
import 'package:test/test.dart';

R run<R>(FakeFirmware fw, Command<R> c) =>
    c.parseResponse(fw.handle(c.toFrame())!);

Uint8List b(List<int> l) => Uint8List.fromList(l);

void main() {
  test('answers version, model and capabilities', () {
    final fw = FakeFirmware();
    expect(run(fw, const GetAppVersion()).label, '2.2');
    expect(run(fw, const GetDeviceModel()), DeviceModel.ultra);
    expect(run(fw, const GetDeviceCapabilities()).supports(2000), isTrue);
  });

  test('lite has no reader capabilities and rejects reader mode', () {
    final fw = FakeFirmware(FakeFirmwareConfig.lite22());
    expect(run(fw, const GetDeviceCapabilities()).hasReader, isFalse);
    final f = fw.handle(const ChangeDeviceMode(DeviceMode.reader).toFrame())!;
    expect(f.status, Status.notImplemented);
  });

  test('pre-2.0 answers INVALID_CMD to capabilities', () {
    final fw = FakeFirmware(FakeFirmwareConfig.preTwoPointZero());
    expect(
      fw.handle(const GetDeviceCapabilities().toFrame())!.status,
      Status.invalidCmd,
    );
  });

  test('2.0 lacks GET_ALL_SLOT_NICKS and omits sleep timeout byte', () {
    final fw = FakeFirmware(FakeFirmwareConfig.ultra20());
    expect(
      fw.handle(const GetAllSlotNicks().toFrame())!.status,
      Status.invalidCmd,
    );
    expect(run(fw, const GetDeviceSettings()).sleepTimeoutSeconds, isNull);
    expect(run(fw, const GetSlotTagNick(0, Sense.hf)), 'Fake 1K');
  });

  test(
    'slot edits persist in memory and mark unsaved until SLOT_DATA_CONFIG_SAVE',
    () {
      final fw = FakeFirmware();
      run(fw, const SetSlotTagType(3, TagType.ntag215));
      run(fw, const SetSlotEnable(3, Sense.hf, true));
      run(fw, const SetSlotTagNick(3, Sense.hf, 'gym'));
      expect(run(fw, const GetSlotInfo())[3].hf, TagType.ntag215);
      expect(run(fw, const GetEnabledSlots())[3].hf, isTrue);
      expect(run(fw, const GetSlotTagNick(3, Sense.hf)), 'gym');
      expect(fw.slotsSaved, isFalse);
      run(fw, const SlotDataConfigSave());
      expect(fw.slotsSaved, isTrue);
    },
  );

  test('reader commands need reader mode', () {
    final fw = FakeFirmware();
    expect(
      fw.handle(const Hf14aScan().toFrame())!.status,
      Status.deviceModeError,
    );
    run(fw, const ChangeDeviceMode(DeviceMode.reader));
    expect(fw.handle(const Hf14aScan().toFrame())!.status, Status.hfTagNo);
  });

  test('presented MF1 card is scanned, authenticated and read', () {
    final fw = FakeFirmware();
    final card = FakeMf1Card.classic1k(uid: b([1, 2, 3, 4]));
    fw.present(card);
    run(fw, const ChangeDeviceMode(DeviceMode.reader));
    final tags = run(fw, const Hf14aScan());
    expect(tags.single.uidHex, '01020304');
    final good = FakeMf1Card.defaultKey;
    expect(
      () => run(fw, Mf1AuthOneKeyBlock(KeyType.a, 0, good)),
      returnsNormally,
    );
    expect(
      fw
          .handle(Mf1AuthOneKeyBlock(KeyType.a, 0, Uint8List(6)).toFrame())!
          .status,
      Status.mfErrAuth,
    );
    final block0 = run(fw, Mf1ReadOneBlock(KeyType.a, 0, good));
    expect(block0.sublist(0, 4), [1, 2, 3, 4]);
    run(
      fw,
      Mf1WriteOneBlock(
        KeyType.a,
        1,
        good,
        Uint8List.fromList(List.filled(16, 0x42)),
      ),
    );
    expect(card.blocks.sublist(16, 32), List.filled(16, 0x42));
  });

  test('LF card scan', () {
    final fw = FakeFirmware();
    fw.present(FakeLfCard(3000, b([0xDE, 0xAD, 0xBE, 0xEF, 0x01])));
    run(fw, const ChangeDeviceMode(DeviceMode.reader));
    expect(run(fw, const Em410xScan()), [0xDE, 0xAD, 0xBE, 0xEF, 0x01]);
    expect(
      fw.handle(const HidProxScan().toFrame())!.status,
      Status.lfTagNoFound,
    );
  });

  test('emulator block data round-trips on the active slot', () {
    final fw = FakeFirmware();
    final data = Uint8List.fromList(List.generate(32, (i) => i));
    run(fw, Mf1WriteEmuBlockData(2, data));
    expect(run(fw, const Mf1ReadEmuBlockData(2, 2)), data);
    run(fw, const SetActiveSlot(1));
    expect(run(fw, const Mf1ReadEmuBlockData(2, 2)), Uint8List(32));
  });

  test('ENTER_BOOTLOADER has no response and sets the flag', () {
    final fw = FakeFirmware();
    expect(fw.handle(const EnterBootloader().toFrame()), isNull);
    expect(fw.bootloaderRequested, isTrue);
  });

  test('malformed payload answers PAR_ERR', () {
    final fw = FakeFirmware();
    expect(fw.handle(Frame(command: 1003))!.status, Status.parErr);
  });

  test('out-of-range emulator read answers PAR_ERR', () {
    final fw = FakeFirmware();
    expect(
      fw.handle(Frame(command: 4008, data: b([250, 32])))!.status,
      Status.parErr,
    );
  });

  test('unknown command answers INVALID_CMD', () {
    final fw = FakeFirmware();
    expect(fw.handle(Frame(command: 1999))!.status, Status.invalidCmd);
  });

  test('settings save and reset', () {
    final fw = FakeFirmware();
    run(fw, const SetAnimationMode(AnimationMode.none));
    expect(run(fw, const GetDeviceSettings()).animation, AnimationMode.none);
    expect(fw.savedSettings.animation, AnimationMode.full);
    run(fw, const SaveSettings());
    expect(fw.savedSettings.animation, AnimationMode.none);
    run(fw, const ResetSettings());
    expect(run(fw, const GetDeviceSettings()).animation, AnimationMode.full);
  });

  test('legacy 0.1 refuses capabilities and reports its own version', () {
    final fw = FakeFirmware(FakeFirmwareConfig.legacy01());
    final version = run(fw, const GetAppVersion());
    expect(version.label, '0.1');
    expect(version.isLegacy, isTrue);
    expect(run(fw, const GetGitVersion()), 'v0.1.0-fake');
    expect(
      fw.handle(const GetDeviceCapabilities().toFrame())!.status,
      Status.invalidCmd,
    );
    expect(run(fw, const GetDeviceSettings()).sleepTimeoutSeconds, isNull);
  });

  test('GET_ALL_SLOT_NICKS round-trips every slot through the decoder', () {
    final fw = FakeFirmware();
    run(fw, const SetSlotTagNick(2, Sense.hf, 'office'));
    run(fw, const SetSlotTagNick(2, Sense.lf, 'gate'));
    run(fw, const SetSlotTagNick(7, Sense.lf, 'barrier'));
    final nicks = run(fw, const GetAllSlotNicks());
    expect(nicks, hasLength(8));
    expect(nicks[0], const SlotNicks('Fake 1K', ''));
    expect(nicks[2], const SlotNicks('office', 'gate'));
    expect(nicks[7], const SlotNicks('', 'barrier'));
  });

  test('MF1_CHECK_KEYS_OF_SECTORS finds the presented card keys', () {
    final fw = FakeFirmware();
    fw.present(FakeMf1Card.classic1k(uid: b([1, 2, 3, 4])));
    run(fw, const ChangeDeviceMode(DeviceMode.reader));
    final result = run(
      fw,
      Mf1CheckKeysOfSectors(
        sectors: {0, 1},
        keyTypes: {KeyType.a, KeyType.b},
        keys: [b(List.filled(6, 0xA0)), FakeMf1Card.defaultKey],
      ),
    );
    expect(result.sectors, hasLength(40));
    expect(result.sectors[0].keyA, FakeMf1Card.defaultKey);
    expect(result.sectors[0].keyB, FakeMf1Card.defaultKey);
    expect(result.sectors[1].keyA, FakeMf1Card.defaultKey);
    // Sector 2 was not in the request mask, so nothing was checked for it.
    expect(result.sectors[2].keyA, isNull);
    expect(result.sectors[2].keyB, isNull);
  });

  test('LF emulator ids round-trip for every family', () {
    final pairs = <int, (VoidCommand Function(Uint8List), Command<Uint8List>)>{
      5000: (Em410xSetEmuId.new, const Em410xGetEmuId()),
      5002: (HidProxSetEmuId.new, const HidProxGetEmuId()),
      5004: (VikingSetEmuId.new, const VikingGetEmuId()),
      5006: (PacSetEmuId.new, const PacGetEmuId()),
      5010: (JablotronSetEmuId.new, const JablotronGetEmuId()),
      5012: (IdteckSetEmuId.new, const IdteckGetEmuId()),
    };
    expect(pairs.keys.toSet(), emuLfIdLengths.keys.toSet());
    final fw = FakeFirmware();
    for (final e in pairs.entries) {
      final length = emuLfIdLengths[e.key]!;
      final id = b(List.generate(length, (i) => e.key + i));
      expect(run(fw, e.value.$2), Uint8List(length), reason: 'blank ${e.key}');
      run(fw, e.value.$1(id));
      expect(run(fw, e.value.$2), id, reason: 'round trip ${e.key}');
    }
  });

  test('LF emulator id of the wrong length answers PAR_ERR', () {
    final fw = FakeFirmware();
    expect(
      fw.handle(Frame(command: 5000, data: b([1, 2])))!.status,
      Status.parErr,
    );
  });

  test('an undefined tag type clears both senses of the slot', () {
    final fw = FakeFirmware();
    run(fw, const SetSlotTagType(0, TagType.undefined));
    expect(
      run(fw, const GetSlotInfo())[0],
      const SlotTypes(TagType.undefined, TagType.undefined),
    );
  });

  test('WIPE_FDS clears every slot and leaves them unsaved', () {
    final fw = FakeFirmware();
    run(fw, const WipeFds());
    expect(run(fw, const GetSlotInfo())[0].hf, TagType.undefined);
    expect(run(fw, const GetEnabledSlots())[0].hf, isFalse);
    expect(run(fw, const GetSlotTagNick(0, Sense.hf)), '');
    expect(fw.slotsSaved, isFalse);
  });

  test('errors surface as typed DeviceError through parseResponse', () {
    final fw = FakeFirmware();
    expect(() => run(fw, const Hf14aScan()), throwsA(isA<DeviceModeError>()));
  });
}
