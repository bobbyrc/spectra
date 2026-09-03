import 'package:chameleon/src/model/enums.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:test/test.dart';

void main() {
  test('tag types round-trip their wire codes', () {
    for (final t in TagType.values) {
      expect(TagType.fromCode(t.code), t);
    }
    expect(TagType.mifare1k.code, 1001);
    expect(TagType.ntag215.code, 1101);
    expect(TagType.seos.code, 3001);
  });

  test('unknown tag code is undefined', () {
    expect(TagType.fromCode(9999), TagType.undefined);
  });

  test('families and senses', () {
    expect(TagType.em410x.family, TagFamily.lf);
    expect(TagType.em410x.sense, Sense.lf);
    expect(TagType.mifare4k.family, TagFamily.mifareClassic);
    expect(TagType.mifare4k.sense, Sense.hf);
    expect(TagType.mf0ul11.family, TagFamily.ultralight);
    expect(TagType.hf14a4.family, TagFamily.iso14443_4);
    expect(TagType.undefined.sense, Sense.none);
  });

  test('strict enums reject unknown codes', () {
    expect(DeviceMode.fromCode(1), DeviceMode.reader);
    expect(() => DeviceMode.fromCode(7), throwsA(isA<MalformedResponse>()));
    expect(ButtonFunction.fromCode(3), ButtonFunction.cloneUid);
    expect(DeviceButton.a.code, 0x41);
    expect(KeyType.b.code, 0x61);
  });
}
