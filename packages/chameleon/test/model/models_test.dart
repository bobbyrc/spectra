import 'dart:typed_data';

import 'package:chameleon/src/model/enums.dart';
import 'package:chameleon/src/model/models.dart';
import 'package:test/test.dart';

void main() {
  test('firmware version compares by major then minor', () {
    const a = FirmwareVersion(major: 2, minor: 0);
    const b = FirmwareVersion(major: 2, minor: 2);
    expect(a.isBefore(b), isTrue);
    expect(b.isBefore(a), isFalse);
    expect(a.label, '2.0');
    expect(a.isLegacy, isFalse);
    expect(const FirmwareVersion(major: 0, minor: 1).isLegacy, isTrue);
  });

  test('capabilities answer support questions', () {
    const c = Capabilities({1000, 1035, 2000});
    expect(c.supports(2000), isTrue);
    expect(c.hasReader, isTrue);
    expect(const Capabilities({1000}).hasReader, isFalse);
  });

  test('slots are value types with copyWith', () {
    const s = Slot(
      index: 0,
      hfType: TagType.mifare1k,
      lfType: TagType.em410x,
      hfEnabled: true,
      lfEnabled: false,
    );
    expect(s.copyWith(hfNick: 'work'), isNot(s));
    expect(s.copyWith(hfNick: 'work').hfNick, 'work');
    expect(s.hfNick, '');
  });

  test('hf14a tag exposes uid as hex', () {
    final t = Hf14aTag(
      uid: Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]),
      atqa: Uint8List.fromList([0x00, 0x04]),
      sak: 0x08,
      ats: Uint8List(0),
    );
    expect(t.uidHex, 'DEADBEEF');
  });
}
