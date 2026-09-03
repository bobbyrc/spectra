import 'dart:typed_data';

import '../../commands/hf_reader.dart';
import '../../commands/lf_reader.dart';
import '../../dump/mf1_dump_read_result.dart';
import '../../dump/mf1_dump_write_result.dart';
import '../../dump/mifare_geometry.dart';
import '../../model/enums.dart';
import '../../model/models.dart';
import '../../protocol/command.dart';
import '../../protocol/errors.dart';
import '../cancel_token.dart';
import '../device_session.dart';

export '../../dump/mf1_dump_read_result.dart';
export '../../dump/mf1_dump_write_result.dart';

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

  static const Set<KeyType> _bothKeyTypes = {KeyType.a, KeyType.b};

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
  ///
  /// Only a tag-level failure is a false: a device that refuses the command
  /// (a Lite, or firmware answering [NotImplemented]) still throws, because
  /// that says nothing about the tag.
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
  ///
  /// A dictionary longer than one request holds ([Mf1CheckKeysOfSectors.maxKeys]
  /// keys) is split across requests, and each request asks only about the
  /// sectors still missing a key, so a large dictionary is neither refused
  /// nor re-tried against sectors that are already open.
  Future<Mf1KeyCheckResult> mf1CheckKeys({
    required Set<int> sectors,
    Set<KeyType> keyTypes = const {KeyType.a, KeyType.b},
    required List<Uint8List> keys,
    CancelToken? cancel,
  }) => _s.withReaderMode(
    () async => Mf1KeyCheckResult(
      await _checkKeysChunked(sectors, keyTypes, keys, cancel),
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

  /// Writes [blocks] onto the MIFARE Classic in the field: the mirror of
  /// [mf1ReadDump], and it holds the same guarantees — keys found once from
  /// [candidateKeys], one lease and one [DeviceSession.busy] for the whole
  /// run, [onProgress] called with the sectors finished and the sectors
  /// total after each sector, and [cancel] honoured between sectors and by
  /// each command in flight.
  ///
  /// Block 0 is never written: it is the manufacturer block, and only a
  /// "magic" card accepts a write there. Sector trailers are skipped unless
  /// [writeTrailers] is set, because writing a trailer with access bits the
  /// card cannot satisfy locks that sector for good. Skipped blocks are
  /// false in both masks of the result, which is why
  /// [Mf1DumpWriteResult.isComplete] measures written against *attempted*.
  ///
  /// A block the card refuses is left false rather than throwing, so one bad
  /// block costs one block and not the whole write.
  ///
  /// `hardware-validate` (checklist H3): which key a data block accepts for
  /// a write depends on its access bits, so the key A then key B order used
  /// here is only proven on a real card. Against `FakeDevice` both keys are
  /// the transport key and the order never shows.
  Future<Mf1DumpWriteResult> mf1WriteDump({
    required TagType type,
    required Uint8List blocks,
    required List<Uint8List> candidateKeys,
    bool writeTrailers = false,
    void Function(int done, int total)? onProgress,
    CancelToken? cancel,
  }) {
    final int sectors = MifareGeometry.sectorCount(type);
    final int totalBlocks = MifareGeometry.blockCount(type);
    if (blocks.length != totalBlocks * 16) {
      throw ArgumentError.value(
        blocks.length,
        'blocks',
        'must be ${totalBlocks * 16} bytes for $type',
      );
    }
    return _s.withReaderMode(
      () => _s.busy(
        () => _writeDump(
          sectors,
          totalBlocks,
          blocks,
          candidateKeys,
          writeTrailers,
          onProgress,
          cancel,
        ),
      ),
    );
  }

  Future<Uint8List?> scanEm410x() => _lfScan(const Em410xScan());
  Future<Uint8List?> scanHidProx() => _lfScan(const HidProxScan());
  Future<Uint8List?> scanViking() => _lfScan(const VikingScan());
  Future<Uint8List?> scanPac() => _lfScan(const PacScan());

  /// Writes an EM410x [id] onto the T55xx card in the field
  /// (EM410X_WRITE_TO_T55XX).
  ///
  /// Keys are parameters here as everywhere on this facade (spec 8.1): the
  /// SDK keeps no password list of its own. [newKey] is the four-byte
  /// password the card is left with, and [oldKeys] are the passwords tried
  /// to unlock it first — an empty list is a card with no password set.
  ///
  /// `hardware-validate` (checklist H3): the fake accepts the command and
  /// rewrites the card it is presenting, but which passwords a blank T55xx
  /// actually answers to, and whether a card takes the write at all, is
  /// only proven on real hardware.
  Future<void> em410xWriteToT55xx({
    required Uint8List id,
    required Uint8List newKey,
    required List<Uint8List> oldKeys,
  }) => _s.withReaderMode(
    () => _s.send(
      Em410xWriteToT55xx(cardId: id, newKey: newKey, oldKeys: oldKeys),
    ),
  );

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

  Future<Mf1DumpWriteResult> _writeDump(
    int sectors,
    int totalBlocks,
    Uint8List blocks,
    List<Uint8List> candidateKeys,
    bool writeTrailers,
    void Function(int done, int total)? onProgress,
    CancelToken? cancel,
  ) async {
    final written = List<bool>.filled(totalBlocks, false);
    final attempted = List<bool>.filled(totalBlocks, false);
    final keys = await _keysForDump(sectors, candidateKeys, cancel);
    for (var sector = 0; sector < sectors; sector++) {
      _throwIfCancelled(cancel);
      final first = MifareGeometry.firstBlockOf(sector);
      final end = first + MifareGeometry.blocksInSector(sector);
      final trailer = MifareGeometry.trailerOf(sector);
      for (var block = first; block < end; block++) {
        if (block == 0) continue;
        if (block == trailer && !writeTrailers) continue;
        attempted[block] = true;
        written[block] = await _writeOneBlock(
          block,
          keys[sector],
          Uint8List.sublistView(blocks, block * 16, block * 16 + 16),
          cancel,
        );
      }
      onProgress?.call(sector + 1, sectors);
    }
    return Mf1DumpWriteResult(
      writeMask: written,
      attemptMask: attempted,
      keys: keys,
    );
  }

  /// Key A first, then key B. A data block whose access bits refuse key A
  /// can still be written with key B, and a refusal of one key says nothing
  /// about the other, so both are tried before the block is given up on.
  Future<bool> _writeOneBlock(
    int block,
    SectorKeys k,
    Uint8List data,
    CancelToken? cancel,
  ) async {
    for (final (KeyType, Uint8List) candidate in <(KeyType, Uint8List)>[
      if (k.keyA case final Uint8List a) (KeyType.a, a),
      if (k.keyB case final Uint8List b) (KeyType.b, b),
    ]) {
      try {
        await _s.send(
          Mf1WriteOneBlock(candidate.$1, block, candidate.$2, data),
          cancel: cancel,
        );
        return true;
      } on DeviceError {
        // Wrong key for this block, or a card that would not take it:
        // try the other key, then give this one block up.
      }
    }
    return false;
  }

  /// One working key per sector. Uses MF1_CHECK_KEYS_OF_SECTORS, which tries
  /// a whole chunk of the dictionary on the device in one round trip, and
  /// falls back to authenticating sector by sector only when the firmware
  /// does not have that command.
  Future<List<SectorKeys>> _keysForDump(
    int sectors,
    List<Uint8List> candidateKeys,
    CancelToken? cancel,
  ) => _supports(Mf1CheckKeysOfSectors.commandId)
      ? _checkKeys(sectors, candidateKeys, cancel)
      : _probeKeys(sectors, candidateKeys, cancel);

  /// Runs the dictionary past the device in chunks of
  /// [Mf1CheckKeysOfSectors.maxKeys], merging the answers: the first key
  /// found for a sector and key type wins, and the run stops as soon as every
  /// sector has both keys, so a dictionary whose first chunk opens the card
  /// still costs one request.
  Future<List<SectorKeys>> _checkKeys(
    int sectors,
    List<Uint8List> candidateKeys,
    CancelToken? cancel,
  ) async {
    final all = await _checkKeysChunked(
      {for (var s = 0; s < sectors; s++) s},
      _bothKeyTypes,
      candidateKeys,
      cancel,
    );
    return all.take(sectors).toList();
  }

  /// One CHECK_KEYS_OF_SECTORS run over a dictionary of any size.
  ///
  /// Each request carries at most [Mf1CheckKeysOfSectors.maxKeys] keys and
  /// asks only about the sectors that still lack one of [keyTypes]: a sector
  /// opened by the first chunk costs nothing in the second, and the run stops
  /// early once every asked-about sector is solved. The result always covers
  /// all 40 sectors, whatever was asked about.
  Future<List<SectorKeys>> _checkKeysChunked(
    Set<int> sectors,
    Set<KeyType> keyTypes,
    List<Uint8List> keys,
    CancelToken? cancel,
  ) async {
    final out = [for (var s = 0; s < 40; s++) SectorKeys(sector: s)];
    if (keys.isEmpty || sectors.isEmpty || keyTypes.isEmpty) return out;
    var pending = {...sectors};
    const chunkSize = Mf1CheckKeysOfSectors.maxKeys;
    for (
      var offset = 0;
      offset < keys.length && pending.isNotEmpty;
      offset += chunkSize
    ) {
      _throwIfCancelled(cancel);
      final found = await _s.send(
        Mf1CheckKeysOfSectors(
          sectors: pending,
          keyTypes: keyTypes,
          keys: keys.skip(offset).take(chunkSize).toList(),
        ),
        cancel: cancel,
      );
      pending = {
        for (final sector in pending)
          if (!_merge(out, found, sector, keyTypes)) sector,
      };
    }
    return out;
  }

  /// Folds the answer for one sector into [out], and says whether every key
  /// type asked about is now known.
  bool _merge(
    List<SectorKeys> out,
    Mf1KeyCheckResult found,
    int sector,
    Set<KeyType> keyTypes,
  ) {
    final have = out[sector];
    final got = found.sectors[sector];
    final merged = SectorKeys(
      sector: sector,
      keyA: have.keyA ?? got.keyA,
      keyB: have.keyB ?? got.keyB,
    );
    out[sector] = merged;
    return keyTypes.every(
      (t) => (t == KeyType.a ? merged.keyA : merged.keyB) != null,
    );
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
