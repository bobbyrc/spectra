import 'dart:typed_data';

import '../../commands/hf_emulator.dart';
import '../../commands/lf_emulator.dart';
import '../../model/enums.dart';
import '../../model/models.dart';
import '../../protocol/command.dart';
import '../device_session.dart';

/// One LF family's emulator id commands: the set command's id (which is also
/// the key into [emuLfIdLengths]), how to build it, and the matching read.
///
/// A [setId] that drifts from the command [build] makes cannot go unnoticed:
/// the command's own constructor checks the id length against the same table.
typedef _LfIdCommands = ({
  int setId,
  VoidCommand Function(Uint8List) build,
  Command<Uint8List> read,
});

/// Operates on the active slot's emulator data (spec 8.1).
///
/// Reads and writes larger than the firmware's per-frame limit are chunked
/// here, and the whole chunked run holds [DeviceSession.busy] so the idle
/// poll cannot interleave a housekeeping read between two chunks.
final class EmulatorFacade {
  EmulatorFacade(this._s);
  final DeviceSession _s;

  /// The firmware reads and writes at most 32 blocks per frame.
  static const int _blocksPerChunk = 32;

  static final Map<TagType, _LfIdCommands> _lfIdCommands = {
    TagType.em410x: (
      setId: 5000,
      build: Em410xSetEmuId.new,
      read: const Em410xGetEmuId(),
    ),
    TagType.hidProx: (
      setId: 5002,
      build: HidProxSetEmuId.new,
      read: const HidProxGetEmuId(),
    ),
    TagType.viking: (
      setId: 5004,
      build: VikingSetEmuId.new,
      read: const VikingGetEmuId(),
    ),
    TagType.pac: (
      setId: 5006,
      build: PacSetEmuId.new,
      read: const PacGetEmuId(),
    ),
    TagType.jablotron: (
      setId: 5010,
      build: JablotronSetEmuId.new,
      read: const JablotronGetEmuId(),
    ),
    TagType.idteck: (
      setId: 5012,
      build: IdteckSetEmuId.new,
      read: const IdteckGetEmuId(),
    ),
  };

  Future<Uint8List> readMf1Blocks(int start, int count) => _s.busy(() async {
    final out = BytesBuilder(copy: false);
    var offset = 0;
    while (offset < count) {
      final n = (count - offset).clamp(1, _blocksPerChunk);
      out.add(await _s.send(Mf1ReadEmuBlockData(start + offset, n)));
      offset += n;
    }
    return out.toBytes();
  });

  Future<void> writeMf1Blocks(int start, Uint8List data) => _s.busy(() async {
    if (data.isEmpty || data.length % 16 != 0) {
      throw ArgumentError.value(
        data.length,
        'data',
        'must be a multiple of 16',
      );
    }
    final total = data.length ~/ 16;
    var offset = 0;
    while (offset < total) {
      final n = (total - offset).clamp(1, _blocksPerChunk);
      await _s.send(
        Mf1WriteEmuBlockData(
          start + offset,
          Uint8List.sublistView(data, offset * 16, (offset + n) * 16),
        ),
      );
      offset += n;
    }
  });

  Future<Hf14aTag> getAntiColl() => _s.send(const Hf14aGetAntiCollData());

  Future<void> setAntiColl(Hf14aTag t) => _s.send(
    Hf14aSetAntiCollData(uid: t.uid, atqa: t.atqa, sak: t.sak, ats: t.ats),
  );

  Future<Mf1EmulatorConfig> getMf1Config() =>
      _s.send(const Mf1GetEmulatorConfig());

  Future<void> setMf1WriteMode(Mf1WriteMode m) => _s.send(Mf1SetWriteMode(m));
  Future<void> setGen1a(bool v) => _s.send(Mf1SetGen1aMode(v));
  Future<void> setGen2(bool v) => _s.send(Mf1SetGen2Mode(v));
  Future<void> setBlockAntiColl(bool v) => _s.send(Mf1SetBlockAntiCollMode(v));
  Future<void> setDetectionEnabled(bool v) => _s.send(Mf1SetDetectionEnable(v));

  /// The captured nonces, or an empty list when detection caught nothing:
  /// asking for the log of an empty buffer is a wasted round trip.
  Future<List<DetectionLogEntry>> readDetectionLog() => _s.busy(() async {
    final count = await _s.send(const Mf1GetDetectionCount());
    if (count == 0) return const <DetectionLogEntry>[];
    return _s.send(const Mf1GetDetectionLog(0));
  });

  // Not chunked: the largest emulated tag (NTAG216, 231 pages) is 924 bytes,
  // well inside one frame.
  Future<Uint8List> readNtagPages(int start, int count) =>
      _s.send(Mf0NtagReadEmuPageData(start, count));

  Future<void> writeNtagPages(int start, Uint8List data) =>
      _s.send(Mf0NtagWriteEmuPageData(start, data));

  Future<int> getNtagPageCount() => _s.send(const Mf0NtagGetPageCount());

  /// The SET_EMU_ID command id of [t]'s LF family, or null when the type is
  /// not an LF emulator type.
  static int? lfSetCommandId(TagType t) => _lfIdCommands[t]?.setId;

  Future<void> setLfId(TagType type, Uint8List id) async {
    final commands = _require(type);
    final expected = emuLfIdLengths[commands.setId]!;
    if (id.length != expected) {
      throw ArgumentError.value(id.length, 'id', 'must be $expected bytes');
    }
    await _s.send(commands.build(id));
  }

  Future<Uint8List> getLfId(TagType type) async => _s.send(_require(type).read);

  _LfIdCommands _require(TagType type) {
    final commands = _lfIdCommands[type];
    if (commands == null) {
      throw ArgumentError.value(type, 'type', 'not an LF emulator type');
    }
    return commands;
  }
}
