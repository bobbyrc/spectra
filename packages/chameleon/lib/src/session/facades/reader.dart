import 'dart:typed_data';

import '../../commands/hf_reader.dart';
import '../../commands/lf_reader.dart';
import '../../dump/mf1_dump_read_result.dart';
import '../../dump/mifare_geometry.dart';
import '../../model/enums.dart';
import '../../model/models.dart';
import '../../protocol/command.dart';
import '../../protocol/errors.dart';
import '../cancel_token.dart';
import '../device_session.dart';

export '../../dump/mf1_dump_read_result.dart';

/// Reading real cards (spec 8.1).
///
/// Keys are always parameters: the SDK never keeps a dictionary of its own,
/// the app supplies the keys to try. Every method takes its own reader lease,
/// so the device is in reader mode for exactly as long as the operation runs
/// and back in emulator mode afterwards, including when the operation throws.
///
/// "No tag in the field" is a result, not an error: a scan returns an empty
/// list or null. A key that does not work is likewise a false, not a throw.
/// Everything else (a tag that answers wrongly, a device that refuses) still
/// comes out as a [ChameleonException].
final class ReaderFacade {
  ReaderFacade(this._s);
  final DeviceSession _s;

  // Geometry lives in MifareGeometry so the dump model (which has no session)
  // shares one definition with the reader; these forward for convenience.
  static int sectorCount(TagType t) => MifareGeometry.sectorCount(t);
  static int blockCount(TagType t) => MifareGeometry.blockCount(t);
  static int firstBlockOf(int sector) => MifareGeometry.firstBlockOf(sector);
  static int blocksInSector(int sector) =>
      MifareGeometry.blocksInSector(sector);

  /// Tags in the HF field, empty when there is none.
  Future<List<Hf14aTag>> scan14a() => _s.withReaderMode(
    () async =>
        await _noTagIsNull(() => _s.send(const Hf14aScan())) ?? const [],
  );

  /// Whether the tag in the field answers MIFARE Classic authentication.
  Future<bool> detectMf1Support() => _s.withReaderMode(() async {
    try {
      await _s.send(const Mf1DetectSupport());
      return true;
    } on HfTagNotFound {
      return false;
    } on HfTagError {
      return false;
    }
  });

  /// The tag's nonce generator, or null when there is no tag.
  Future<PrngType?> detectPrng() => _s.withReaderMode(
    () => _noTagIsNull(() => _s.send(const Mf1DetectPrng())),
  );

  /// Whether [key] authenticates [block]. A wrong key is false, not a throw.
  Future<bool> mf1Auth(int block, KeyType type, Uint8List key) =>
      _s.withReaderMode(() => _auth(block, type, key));

  Future<Uint8List> mf1ReadBlock(int block, KeyType type, Uint8List key) =>
      _s.withReaderMode(() => _s.send(Mf1ReadOneBlock(type, block, key)));

  Future<void> mf1WriteBlock(
    int block,
    KeyType type,
    Uint8List key,
    Uint8List data,
  ) => _s.withReaderMode(
    () => _s.send(Mf1WriteOneBlock(type, block, key, data)),
  );

  /// Asks the firmware which of [keys] work for [sectors]. The result always
  /// covers all 40 sectors; sectors that were not asked about stay null.
  Future<Mf1KeyCheckResult> mf1CheckKeys({
    required Set<int> sectors,
    Set<KeyType> keyTypes = const {KeyType.a, KeyType.b},
    required List<Uint8List> keys,
  }) => _s.withReaderMode(
    () => _s.send(
      Mf1CheckKeysOfSectors(sectors: sectors, keyTypes: keyTypes, keys: keys),
    ),
  );

  /// Reads a whole MIFARE Classic: finds a working key per sector from
  /// [candidateKeys], then reads every block of the sectors that opened.
  ///
  /// One lease and one [DeviceSession.busy] for the whole run, so the idle
  /// poll cannot interleave a housekeeping read between two blocks and the
  /// mode is switched once either way. [onProgress] is called with the
  /// sectors finished and the sectors total after each sector. [cancel] is
  /// honoured between sectors and by each command in flight; a cancelled dump
  /// throws [CommandCancelled] after the lease is released and the device is
  /// back in emulator mode.
  ///
  /// Sectors with no working key are left zero with their [Mf1DumpReadResult]
  /// mask false, which is what makes a partial dump a result rather than an
  /// error.
  Future<Mf1DumpReadResult> mf1ReadDump({
    required TagType type,
    required List<Uint8List> candidateKeys,
    void Function(int done, int total)? onProgress,
    CancelToken? cancel,
  }) {
    final sectors = MifareGeometry.sectorCount(type);
    final totalBlocks = MifareGeometry.blockCount(type);
    return _s.withReaderMode(
      () => _s.busy(
        () =>
            _readDump(sectors, totalBlocks, candidateKeys, onProgress, cancel),
      ),
    );
  }

  Future<Uint8List?> scanEm410x() => _lfScan(const Em410xScan());
  Future<Uint8List?> scanHidProx() => _lfScan(const HidProxScan());
  Future<Uint8List?> scanViking() => _lfScan(const VikingScan());
  Future<Uint8List?> scanPac() => _lfScan(const PacScan());

  Future<Mf1DumpReadResult> _readDump(
    int sectors,
    int totalBlocks,
    List<Uint8List> candidateKeys,
    void Function(int done, int total)? onProgress,
    CancelToken? cancel,
  ) async {
    final blocks = Uint8List(totalBlocks * 16);
    final mask = List<bool>.filled(totalBlocks, false);
    final keys = await _keysForDump(sectors, candidateKeys, cancel);
    for (var sector = 0; sector < sectors; sector++) {
      _throwIfCancelled(cancel);
      final key = _pick(keys[sector]);
      if (key != null) {
        final first = MifareGeometry.firstBlockOf(sector);
        final end = first + MifareGeometry.blocksInSector(sector);
        for (var block = first; block < end; block++) {
          try {
            final data = await _s.send(
              Mf1ReadOneBlock(key.$1, block, key.$2),
              cancel: cancel,
            );
            blocks.setRange(block * 16, block * 16 + 16, data);
            mask[block] = true;
          } on DeviceError {
            // A block the tag would not give up: left zero and unread, so a
            // flaky block costs one block rather than the whole dump.
          }
        }
      }
      onProgress?.call(sector + 1, sectors);
    }
    return Mf1DumpReadResult(blocks: blocks, readMask: mask, keys: keys);
  }

  /// One working key per sector. Uses MF1_CHECK_KEYS_OF_SECTORS, which tries
  /// the whole dictionary on the device in one round trip, and falls back to
  /// authenticating sector by sector when the firmware does not have that
  /// command or the dictionary is larger than one request can carry.
  Future<List<SectorKeys>> _keysForDump(
    int sectors,
    List<Uint8List> candidateKeys,
    CancelToken? cancel,
  ) async {
    if (candidateKeys.length <= Mf1CheckKeysOfSectors.maxKeys) {
      final check = Mf1CheckKeysOfSectors(
        sectors: {for (var s = 0; s < sectors; s++) s},
        keyTypes: const {KeyType.a, KeyType.b},
        keys: candidateKeys,
      );
      if (_supports(check.id)) {
        final found = await _s.send(check, cancel: cancel);
        return found.sectors.take(sectors).toList();
      }
    }
    return _probeKeys(sectors, candidateKeys, cancel);
  }

  Future<List<SectorKeys>> _probeKeys(
    int sectors,
    List<Uint8List> candidateKeys,
    CancelToken? cancel,
  ) async {
    final out = <SectorKeys>[];
    for (var sector = 0; sector < sectors; sector++) {
      _throwIfCancelled(cancel);
      final block = MifareGeometry.firstBlockOf(sector);
      Uint8List? keyA;
      Uint8List? keyB;
      for (final key in candidateKeys) {
        if (keyA == null && await _auth(block, KeyType.a, key, cancel)) {
          keyA = key;
        }
        if (keyB == null && await _auth(block, KeyType.b, key, cancel)) {
          keyB = key;
        }
        if (keyA != null && keyB != null) break;
      }
      out.add(SectorKeys(sector: sector, keyA: keyA, keyB: keyB));
    }
    return out;
  }

  /// The key to read a sector with: key A when it is known, else key B.
  (KeyType, Uint8List)? _pick(SectorKeys k) {
    final a = k.keyA;
    if (a != null) return (KeyType.a, a);
    final b = k.keyB;
    if (b != null) return (KeyType.b, b);
    return null;
  }

  /// A key that does not work is false; anything else (no tag, a tag error)
  /// is a real failure and propagates.
  Future<bool> _auth(
    int block,
    KeyType type,
    Uint8List key, [
    CancelToken? cancel,
  ]) async {
    try {
      await _s.send(Mf1AuthOneKeyBlock(type, block, key), cancel: cancel);
      return true;
    } on AuthenticationFailed {
      return false;
    }
  }

  bool _supports(int commandId) =>
      _s.deviceInfo.value?.capabilities.supports(commandId) ?? false;

  Future<Uint8List?> _lfScan(Command<Uint8List> c) =>
      _s.withReaderMode(() => _noTagIsNull(() => _s.send(c)));

  Future<T?> _noTagIsNull<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on HfTagNotFound {
      return null;
    } on LfTagNotFound {
      return null;
    }
  }

  void _throwIfCancelled(CancelToken? cancel) {
    if (cancel?.isCancelled ?? false) throw const CommandCancelled();
  }
}
