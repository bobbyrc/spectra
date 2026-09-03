import '../protocol/errors.dart';

E _byCode<E>(List<E> values, int Function(E) code, int value, String name) {
  for (final v in values) {
    if (code(v) == value) return v;
  }
  throw MalformedResponse('unknown $name code $value');
}

enum DeviceModel {
  ultra(0),
  lite(1);

  const DeviceModel(this.code);
  final int code;
  static DeviceModel fromCode(int c) =>
      _byCode(values, (e) => e.code, c, 'DeviceModel');
}

enum DeviceMode {
  emulator(0),
  reader(1);

  const DeviceMode(this.code);
  final int code;
  static DeviceMode fromCode(int c) =>
      _byCode(values, (e) => e.code, c, 'DeviceMode');
}

enum AnimationMode {
  full(0),
  minimal(1),
  none(2),
  symmetric(3);

  const AnimationMode(this.code);
  final int code;
  static AnimationMode fromCode(int c) =>
      _byCode(values, (e) => e.code, c, 'AnimationMode');
}

enum ButtonFunction {
  none(0),
  nextSlot(1),
  prevSlot(2),
  cloneUid(3),
  battery(4),
  nfcFieldGenerator(5);

  const ButtonFunction(this.code);
  final int code;
  static ButtonFunction fromCode(int c) =>
      _byCode(values, (e) => e.code, c, 'ButtonFunction');
}

enum DeviceButton {
  a(0x41),
  b(0x42);

  const DeviceButton(this.code);
  final int code;
}

enum Sense {
  none(0),
  lf(1),
  hf(2);

  const Sense(this.code);
  final int code;
  static Sense fromCode(int c) => _byCode(values, (e) => e.code, c, 'Sense');
}

enum TagFamily { undefined, lf, mifareClassic, ultralight, iso14443_4, seos }

enum TagType {
  undefined(0, TagFamily.undefined),
  em410x(100, TagFamily.lf),
  em410xElectra(104, TagFamily.lf),
  pac(150, TagFamily.lf),
  viking(170, TagFamily.lf),
  jablotron(180, TagFamily.lf),
  hidProx(200, TagFamily.lf),
  ioProx(201, TagFamily.lf),
  idteck(310, TagFamily.lf),
  mifareMini(1000, TagFamily.mifareClassic),
  mifare1k(1001, TagFamily.mifareClassic),
  mifare2k(1002, TagFamily.mifareClassic),
  mifare4k(1003, TagFamily.mifareClassic),
  ntag213(1100, TagFamily.ultralight),
  ntag215(1101, TagFamily.ultralight),
  ntag216(1102, TagFamily.ultralight),
  mf0icu1(1103, TagFamily.ultralight),
  mf0icu2(1104, TagFamily.ultralight),
  mf0ul11(1105, TagFamily.ultralight),
  mf0ul21(1106, TagFamily.ultralight),
  ntag210(1107, TagFamily.ultralight),
  ntag212(1108, TagFamily.ultralight),
  hf14a4(3000, TagFamily.iso14443_4),
  seos(3001, TagFamily.seos);

  const TagType(this.code, this.family);
  final int code;
  final TagFamily family;

  static TagType fromCode(int c) {
    for (final t in values) {
      if (t.code == c) return t;
    }
    return undefined;
  }

  Sense get sense => switch (family) {
    TagFamily.undefined => Sense.none,
    TagFamily.lf => Sense.lf,
    _ => Sense.hf,
  };
}

enum KeyType {
  a(0x60),
  b(0x61);

  const KeyType(this.code);
  final int code;
  static KeyType fromCode(int c) =>
      _byCode(values, (e) => e.code, c, 'KeyType');
}

enum Mf1WriteMode {
  normal(0),
  denied(1),
  deceive(2),
  shadow(3),
  shadowRequest(4);

  const Mf1WriteMode(this.code);
  final int code;
  static Mf1WriteMode fromCode(int c) =>
      _byCode(values, (e) => e.code, c, 'Mf1WriteMode');
}

enum PrngType {
  staticNonce(0),
  weak(1),
  hard(2);

  const PrngType(this.code);
  final int code;
  static PrngType fromCode(int c) =>
      _byCode(values, (e) => e.code, c, 'PrngType');
}
