import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/features/slots/state/slot_labels.dart';

void main() {
  test('selectable HF types are the emulatable HF families only', () {
    final List<TagType> hf = selectableTypes(Sense.hf);
    expect(hf, contains(TagType.mifare1k));
    expect(hf, contains(TagType.ntag215));
    expect(hf, isNot(contains(TagType.undefined)));
    expect(hf, isNot(contains(TagType.seos)));
    expect(hf, isNot(contains(TagType.hf14a4)));
    expect(hf.every((TagType t) => t.sense == Sense.hf), isTrue);
  });

  test('selectable LF types are the LF family, and none is undefined', () {
    final List<TagType> lf = selectableTypes(Sense.lf);
    expect(lf, contains(TagType.em410x));
    expect(lf, isNot(contains(TagType.undefined)));
    expect(lf.every((TagType t) => t.family == TagFamily.lf), isTrue);
  });

  test('Sense.none selects nothing', () {
    expect(selectableTypes(Sense.none), isEmpty);
  });
}
