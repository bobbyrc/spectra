import 'dart:typed_data';

import '../model/enums.dart';
import '../model/models.dart';
import 'dump_format.dart';

final class Em410xDump implements CardDump {
  Em410xDump(this.id);
  final Uint8List id;

  @override
  TagType get type => TagType.em410x;

  @override
  Uint8List toBytes() => id;
}

final class Em410xFormat implements DumpFormat<Em410xDump> {
  const Em410xFormat();

  @override
  TagFamily get family => TagFamily.lf;

  @override
  Em410xDump parse(Uint8List bytes, TagType type) => Em410xDump(bytes);

  @override
  List<DumpField> describe(Em410xDump d) => [DumpField('ID', hexOf(d.id))];

  @override
  List<String> validate(Em410xDump d) =>
      d.id.length == 5 ? const [] : ['id must be 5 bytes'];
}
