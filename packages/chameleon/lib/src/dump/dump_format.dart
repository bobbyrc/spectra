import 'dart:typed_data';

import '../model/enums.dart';
import 'em410x.dart';
import 'mifare_classic.dart';
import 'ultralight.dart';

abstract interface class CardDump {
  TagType get type;
  Uint8List toBytes();
}

final class DumpField {
  const DumpField(this.label, this.value);
  final String label;
  final String value;
}

/// Pure knowledge of one tag family's dump layout (spec 3.5).
abstract interface class DumpFormat<T extends CardDump> {
  TagFamily get family;
  T parse(Uint8List bytes, TagType type);
  List<DumpField> describe(T dump);

  /// Empty when valid; otherwise human-readable problems.
  List<String> validate(T dump);
}

abstract final class DumpFormats {
  static final Map<TagFamily, DumpFormat<CardDump>> _byFamily = {
    TagFamily.mifareClassic: const MifareClassicFormat(),
    TagFamily.ultralight: const UltralightFormat(),
    TagFamily.lf: const Em410xFormat(),
  };

  static DumpFormat<CardDump>? forType(TagType t) {
    if (t.family == TagFamily.lf && t != TagType.em410x) return null;
    return _byFamily[t.family];
  }

  static CardDump parse(Uint8List bytes, TagType t) {
    final f = forType(t);
    if (f == null) throw ArgumentError.value(t, 'type', 'no dump format');
    return f.parse(bytes, t);
  }

  /// The single source of Ultralight/NTAG page counts by type, used by the
  /// dump formats and by `FakeSlot.ntagPageCount`. Verified against
  /// `docs/research/chameleon-protocol.md`.
  static int ultralightPageCount(TagType t) => switch (t) {
    TagType.ntag210 => 20,
    TagType.ntag212 => 41,
    TagType.ntag213 => 45,
    TagType.ntag215 => 135,
    TagType.ntag216 => 231,
    TagType.mf0icu1 => 16,
    TagType.mf0icu2 => 44,
    TagType.mf0ul11 => 20,
    TagType.mf0ul21 => 41,
    _ => throw ArgumentError.value(t, 'type', 'not Ultralight'),
  };
}
