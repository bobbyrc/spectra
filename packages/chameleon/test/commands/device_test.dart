import 'dart:typed_data';

import 'package:chameleon/src/codec/frame.dart';
import 'package:chameleon/src/commands/device.dart';
import 'package:chameleon/src/model/enums.dart';
import 'package:chameleon/src/model/models.dart';
import 'package:chameleon/src/protocol/command.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:test/test.dart';

Uint8List b(List<int> l) => Uint8List.fromList(l);
Frame ok(int cmd, List<int> data) =>
    Frame(command: cmd, status: 0x68, data: b(data));

void main() {
  group('encode', () {
    final cases = <(Command<dynamic>, int, List<int>)>[
      (const GetAppVersion(), 1000, []),
      (const ChangeDeviceMode(DeviceMode.reader), 1001, [1]),
      (const SetActiveSlot(3), 1003, [3]),
      (const SetSlotTagType(2, TagType.mifare1k), 1004, [2, 0x03, 0xE9]),
      (const SetSlotDataDefault(2, TagType.em410x), 1005, [2, 0x00, 0x64]),
      (const SetSlotEnable(1, Sense.hf, true), 1006, [1, 2, 1]),
      (const SetSlotTagNick(0, Sense.lf, 'ab'), 1007, [0, 1, 0x61, 0x62]),
      (const GetSlotTagNick(4, Sense.hf), 1008, [4, 2]),
      (const EnterBootloader(), 1010, []),
      (const SetAnimationMode(AnimationMode.minimal), 1015, [1]),
      (const DeleteSlotTagNick(5, Sense.lf), 1021, [5, 1]),
      (const DeleteSlotSenseType(6, Sense.hf), 1024, [6, 2]),
      (const GetButtonPressConfig(DeviceButton.b), 1026, [0x42]),
      (
        const SetButtonPressConfig(DeviceButton.a, ButtonFunction.nextSlot),
        1027,
        [0x41, 1],
      ),
      (
        const SetLongButtonPressConfig(DeviceButton.b, ButtonFunction.battery),
        1029,
        [0x42, 4],
      ),
      (
        const SetBlePairingKey('123456'),
        1030,
        [0x31, 0x32, 0x33, 0x34, 0x35, 0x36],
      ),
      (const SetBlePairingEnable(true), 1037, [1]),
      (const SetSleepTimeout(30), 1040, [30]),
    ];
    for (final (cmd, id, payload) in cases) {
      test('$id ${cmd.runtimeType}', () {
        expect(cmd.id, id);
        expect(cmd.encode(), payload);
      });
    }
  });

  group('decode', () {
    test('GetAppVersion', () {
      expect(
        const GetAppVersion().parseResponse(ok(1000, [2, 1])),
        const FirmwareVersion(major: 2, minor: 1),
      );
    });
    test('GetDeviceMode', () {
      expect(
        const GetDeviceMode().parseResponse(ok(1002, [0])),
        DeviceMode.emulator,
      );
    });
    test('GetSlotTagNick decodes utf8', () {
      expect(
        const GetSlotTagNick(0, Sense.hf).parseResponse(ok(1008, [0xC3, 0xA9])),
        'é',
      );
    });
    test('GetDeviceChipId is upper hex', () {
      expect(
        const GetDeviceChipId().parseResponse(
          ok(1011, [1, 2, 3, 4, 5, 6, 7, 0xAB]),
        ),
        '01020304050607AB',
      );
    });
    test('GetDeviceAddress is colon separated', () {
      expect(
        const GetDeviceAddress().parseResponse(ok(1012, [1, 2, 3, 4, 5, 0xFF])),
        '01:02:03:04:05:FF',
      );
    });
    test('GetGitVersion', () {
      expect(const GetGitVersion().parseResponse(ok(1017, [0x76, 0x32])), 'v2');
    });
    test('GetActiveSlot', () {
      expect(const GetActiveSlot().parseResponse(ok(1018, [7])), 7);
    });
    test('GetSlotInfo decodes eight pairs', () {
      final data = List<int>.generate(32, (i) => 0)
        ..[0] = 0x03
        ..[1] = 0xE9
        ..[2] = 0x00
        ..[3] = 0x64;
      final info = const GetSlotInfo().parseResponse(ok(1019, data));
      expect(info.length, 8);
      expect(info[0], const SlotTypes(TagType.mifare1k, TagType.em410x));
      expect(info[7], const SlotTypes(TagType.undefined, TagType.undefined));
    });
    test('GetEnabledSlots', () {
      final data = List<int>.filled(16, 0)
        ..[0] = 1
        ..[3] = 1;
      final en = const GetEnabledSlots().parseResponse(ok(1023, data));
      expect(en[0], const SlotEnabled(true, false));
      expect(en[1], const SlotEnabled(false, true));
    });
    test('GetBatteryInfo', () {
      expect(
        const GetBatteryInfo().parseResponse(ok(1025, [0x0F, 0xA0, 85])),
        const BatteryInfo(millivolts: 4000, percent: 85),
      );
    });
    test('GetButtonPressConfig', () {
      expect(
        const GetButtonPressConfig(DeviceButton.a).parseResponse(ok(1026, [2])),
        ButtonFunction.prevSlot,
      );
    });
    test('GetBlePairingKey', () {
      expect(
        const GetBlePairingKey().parseResponse(ok(1031, '123456'.codeUnits)),
        '123456',
      );
    });
    test('GetDeviceModel', () {
      expect(
        const GetDeviceModel().parseResponse(ok(1033, [1])),
        DeviceModel.lite,
      );
    });
    test('GetDeviceSettings without sleep timeout', () {
      final s = const GetDeviceSettings().parseResponse(
        ok(1034, [5, 0, 1, 2, 3, 4, 1, ...'123456'.codeUnits]),
      );
      expect(s.version, 5);
      expect(s.animation, AnimationMode.full);
      expect(s.buttonA, ButtonFunction.nextSlot);
      expect(s.longButtonB, ButtonFunction.battery);
      expect(s.blePairingEnabled, isTrue);
      expect(s.blePairingKey, '123456');
      expect(s.sleepTimeoutSeconds, isNull);
    });
    test('GetDeviceSettings with sleep timeout and unknown trailing bytes', () {
      final s = const GetDeviceSettings().parseResponse(
        ok(1034, [6, 0, 0, 0, 0, 0, 0, ...'000000'.codeUnits, 8, 0xFF]),
      );
      expect(s.sleepTimeoutSeconds, 8);
    });
    test('GetDeviceCapabilities', () {
      final c = const GetDeviceCapabilities().parseResponse(
        ok(1035, [0x03, 0xE8, 0x07, 0xD0]),
      );
      expect(c.commandIds, {1000, 2000});
    });
    test('GetBlePairingEnable', () {
      expect(const GetBlePairingEnable().parseResponse(ok(1036, [0])), isFalse);
    });
    test('GetAllSlotNicks', () {
      final data = <int>[];
      for (var i = 0; i < 8; i++) {
        if (i == 0) {
          data.addAll([2, 0x68, 0x69, 0]);
        } else {
          data.addAll([0, 0]);
        }
      }
      final n = const GetAllSlotNicks().parseResponse(ok(1038, data));
      expect(n[0], const SlotNicks('hi', ''));
      expect(n[5], const SlotNicks('', ''));
    });
    test('GetSleepTimeout', () {
      expect(const GetSleepTimeout().parseResponse(ok(1039, [15])), 15);
    });
    test('short payloads are MalformedResponse', () {
      expect(
        () => const GetAppVersion().parseResponse(ok(1000, [2])),
        throwsA(isA<MalformedResponse>()),
      );
    });
  });

  test('EnterBootloader expects no response', () {
    expect(const EnterBootloader().expectsResponse, isFalse);
  });

  test('SetSlotTagNick rejects nicks longer than 32 bytes', () {
    expect(
      () => SetSlotTagNick(0, Sense.hf, 'x' * 33).encode(),
      throwsArgumentError,
    );
  });

  test('reads are idempotent, writes are not', () {
    expect(const GetActiveSlot().idempotent, isTrue);
    expect(const SetActiveSlot(1).idempotent, isFalse);
  });
}
