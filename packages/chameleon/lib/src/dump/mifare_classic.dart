import 'dart:typed_data';

import '../model/enums.dart';
import '../model/models.dart';
import 'dump_format.dart';
import 'mifare_geometry.dart';

final class MifareClassicDump implements CardDump {
  MifareClassicDump(this.type, this.blocks);

  @override
  final TagType type;
  final Uint8List blocks;

  int get sectorCount => MifareGeometry.sectorCount(type);
  int get expectedBlockCount => MifareGeometry.blockCount(type);
  int get blockCount => blocks.length ~/ 16;

  Uint8List block(int i) => Uint8List.sublistView(blocks, i * 16, i * 16 + 16);

  /// The UID from block 0.
  ///
  /// Assumes a 4-byte (single-size) UID, which is what the Chameleon's
  /// MIFARE Classic emulation and every 1K/4K card in practice use. A 7-byte
  /// UID card would lay block 0 out differently; the firmware documentation
  /// does not say how, so this is `hardware-validate` (checklist H1) rather
  /// than a documented invariant.
  Uint8List get uid => Uint8List.sublistView(blocks, 0, 4);
  Uint8List keyA(int sector) =>
      Uint8List.sublistView(block(MifareGeometry.trailerOf(sector)), 0, 6);
  Uint8List accessBits(int sector) =>
      Uint8List.sublistView(block(MifareGeometry.trailerOf(sector)), 6, 10);
  Uint8List keyB(int sector) =>
      Uint8List.sublistView(block(MifareGeometry.trailerOf(sector)), 10, 16);

  @override
  Uint8List toBytes() => blocks;
}

final class MifareClassicFormat implements DumpFormat<MifareClassicDump> {
  const MifareClassicFormat();

  @override
  TagFamily get family => TagFamily.mifareClassic;

  @override
  MifareClassicDump parse(Uint8List bytes, TagType type) =>
      MifareClassicDump(type, bytes);

  @override
  List<DumpField> describe(MifareClassicDump d) => [
    DumpField('UID', hexOf(d.uid)),
    DumpField('Type', d.type.name),
    DumpField('Sectors', '${d.sectorCount}'),
    DumpField('Blocks', '${d.blockCount}'),
    DumpField('SAK', d.blocks.length > 5 ? hexOf([d.blocks[5]]) : ''),
    DumpField(
      'ATQA',
      d.blocks.length > 7 ? hexOf([d.blocks[7], d.blocks[6]]) : '',
    ),
  ];

  @override
  List<String> validate(MifareClassicDump d) {
    final problems = <String>[];
    if (d.blocks.length != d.expectedBlockCount * 16) {
      problems.add(
        'length ${d.blocks.length} is not ${d.expectedBlockCount * 16} bytes',
      );
      return problems;
    }
    final bcc = d.uid.fold<int>(0, (a, x) => a ^ x);
    if (d.blocks[4] != bcc) {
      problems.add('BCC ${hexOf([d.blocks[4]])} does not match UID');
    }
    return problems;
  }
}
