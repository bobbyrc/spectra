import 'dart:typed_data';

import '../model/enums.dart';
import '../model/models.dart';
import 'dump_format.dart';

final class UltralightDump implements CardDump {
  UltralightDump(this.type, this.pages);

  @override
  final TagType type;
  final Uint8List pages;

  int get pageCount => pages.length ~/ 4;
  Uint8List page(int i) => Uint8List.sublistView(pages, i * 4, i * 4 + 4);

  /// 7-byte UID: page 0 bytes 0..2 then page 1 bytes 0..3.
  Uint8List get uid =>
      Uint8List.fromList([...pages.sublist(0, 3), ...pages.sublist(4, 8)]);

  @override
  Uint8List toBytes() => pages;
}

final class UltralightFormat implements DumpFormat<UltralightDump> {
  const UltralightFormat();

  @override
  TagFamily get family => TagFamily.ultralight;

  @override
  UltralightDump parse(Uint8List bytes, TagType type) =>
      UltralightDump(type, bytes);

  @override
  List<DumpField> describe(UltralightDump d) => [
    DumpField('UID', d.pages.length >= 8 ? hexOf(d.uid) : ''),
    DumpField('Type', d.type.name),
    DumpField('Pages', '${d.pageCount}'),
  ];

  @override
  List<String> validate(UltralightDump d) {
    final expected = DumpFormats.ultralightPageCount(d.type);
    if (d.pages.length % 4 != 0) return ['length is not a multiple of 4'];
    if (d.pageCount != expected) {
      return ['has ${d.pageCount} pages, expected $expected'];
    }
    return const [];
  }
}
