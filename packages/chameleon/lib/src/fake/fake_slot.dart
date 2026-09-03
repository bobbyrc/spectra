import 'dart:typed_data';

import '../commands/lf_emulator.dart' show emuLfIdLengths;
import '../dump/dump_format.dart';
import '../model/enums.dart';
import '../model/models.dart';

/// One of the eight emulation slots the fake firmware holds in memory.
final class FakeSlot {
  TagType hfType = TagType.undefined;
  TagType lfType = TagType.undefined;
  bool hfEnabled = false;
  bool lfEnabled = false;
  String hfNick = '';
  String lfNick = '';

  /// 4K worth of MIFARE Classic emulation memory (256 blocks of 16 bytes).
  final Uint8List mf1Blocks = Uint8List(256 * 16);

  Hf14aTag antiColl = Hf14aTag(
    uid: Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]),
    atqa: Uint8List.fromList([0x00, 0x04]),
    sak: 0x08,
    ats: Uint8List(0),
  );

  Mf1EmulatorConfig mf1Config = const Mf1EmulatorConfig(
    detectionEnabled: false,
    gen1a: false,
    gen2: false,
    blockAntiColl: false,
    writeMode: Mf1WriteMode.normal,
  );

  bool uidMagic = false;

  /// NTAG216 worth of page memory (231 pages of 4 bytes).
  final Uint8List ntagPages = Uint8List(231 * 4);

  final Map<int, Uint8List> lfIds = {
    for (final e in emuLfIdLengths.entries) e.key: Uint8List(e.value),
  };

  final List<Uint8List> detectionLog = [];

  /// Pages the emulated tag reports, or zero when the slot holds no NTAG.
  ///
  /// Delegates to the one page-count table so the fake can never disagree
  /// with the dump formats about how big a tag is.
  int get ntagPageCount => hfType.family == TagFamily.ultralight
      ? DumpFormats.ultralightPageCount(hfType)
      : 0;
}
