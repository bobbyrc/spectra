import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/session/active_device.dart';
import '../../../core/session/active_session.dart';
import 'default_keys.dart';
import 'read_state.dart';

part 'read_controller.g.dart';

/// Spec 7.7 step 3: read a card through `session.reader`.
///
/// Every `ReaderFacade` method takes its own reader lease, so the device is
/// in reader mode for exactly as long as the operation runs and back in
/// emulator mode afterwards, including when it throws (spec 4.3). That lease
/// is also what holds the wakelock: `sessionNeedsWakelock`
/// (`core/lifecycle/wakelock.dart`) polls `readerLeaseCount > 0 || isBusy`,
/// and `mf1ReadDump` wraps the whole dump in one lease and one `busy`. There
/// is therefore no wakelock code here, and there must not be.
///
/// Failures stay in [ReadState.error] rather than being thrown, so the screen
/// renders them through the spec 9 catalog instead of catching. "No tag in
/// the field" is the facade's empty result, which this turns into the typed
/// [HfTagNotFound]/[LfTagNotFound] the catalog already has words for.
///
/// A call made while another is in flight is dropped, not queued (`_inFlight`);
/// the screen disables its buttons while `state.busy`. This notifier is
/// autoDispose: the Read screen's Back button can tear it down while a read
/// is still on the wire, so every assignment to [state] after an `await` is
/// guarded with `ref.mounted` (Phase 6 ruling 2) — the device read itself
/// still runs to completion, there is simply no longer anywhere to report
/// it.
@riverpod
class CardReader extends _$CardReader {
  @override
  ReadState build() {
    ref.onDispose(() {
      // Not `state` — the element is gone by now (Global Constraints).
      _cancel?.cancel();
      _inFlight = false;
    });
    return const ReadState();
  }

  CancelToken? _cancel;
  bool _inFlight = false;

  /// Scan the 13.56 MHz field, and read the whole card when it is a MIFARE
  /// Classic the firmware can authenticate.
  Future<void> readHf() => _run(
    (ReaderFacade reader, CancelToken cancel) => _readHf(reader, cancel),
  );

  /// Scan the 125 kHz field for an EM410x, the one LF family with a
  /// `DumpFormat` (spec 3.5).
  Future<void> readLf() =>
      _run((ReaderFacade reader, CancelToken cancel) => _readLf(reader));

  /// Asks the running read to stop. The SDK has no wire-level cancel, so the
  /// command in flight still runs to completion or timeout before the future
  /// resolves with [CommandCancelled] (spec 4.3's honest contract).
  void cancel() => _cancel?.cancel();

  /// Back to the empty screen, so "Read again" starts clean.
  void reset() => state = const ReadState();

  Future<CardReadResult> _readHf(
    ReaderFacade reader,
    CancelToken cancel,
  ) async {
    final List<Hf14aTag> tags = await reader.scan14a();
    if (tags.isEmpty) throw const HfTagNotFound();
    final Hf14aTag tag = tags.first;

    if (!await reader.detectMf1Support()) {
      return CardReadResult.identity(tag);
    }
    // A SAK the table does not know, on a card that authenticates: 1K is the
    // safe guess — it is the most common card by a wide margin, and a wrong
    // guess costs a partial dump, not a failure.
    final TagType guessed = classicTypeForSak(tag.sak);
    final TagType type = guessed == TagType.undefined
        ? TagType.mifare1k
        : guessed;

    if (ref.mounted) {
      state = const ReadState(busy: true, progress: 0);
    }
    final Mf1DumpReadResult dump = await reader.mf1ReadDump(
      type: type,
      candidateKeys: defaultMifareKeys(),
      onProgress: (int done, int total) {
        if (!ref.mounted) return;
        state = ReadState(
          busy: true,
          progress: total == 0 ? null : done / total,
        );
      },
      cancel: cancel,
    );

    final MifareClassicDump parsed =
        DumpFormats.parse(dump.blocks, type) as MifareClassicDump;
    return CardReadResult(
      tagType: type,
      bytes: dump.blocks,
      fields: const MifareClassicFormat().describe(parsed),
      readChunks: dump.readBlockCount,
      totalChunks: dump.blockCount,
      keysFound: dump.keys
          .where((SectorKeys k) => k.keyA != null || k.keyB != null)
          .length,
    );
  }

  Future<CardReadResult> _readLf(ReaderFacade reader) async {
    final Uint8List? id = await reader.scanEm410x();
    if (id == null) throw const LfTagNotFound();
    final Em410xDump parsed =
        DumpFormats.parse(id, TagType.em410x) as Em410xDump;
    return CardReadResult(
      tagType: TagType.em410x,
      bytes: id,
      fields: const Em410xFormat().describe(parsed),
    );
  }

  Future<void> _run(
    Future<CardReadResult> Function(ReaderFacade reader, CancelToken cancel)
    body,
  ) async {
    if (_inFlight) return;
    final ActiveSession? active = ref.read(activeSessionProvider);
    if (active == null) {
      state = const ReadState(error: SessionNotReady('no active session'));
      return;
    }
    _inFlight = true;
    final CancelToken cancel = CancelToken();
    _cancel = cancel;
    state = const ReadState(busy: true);
    try {
      final CardReadResult result = await body(active.session.reader, cancel);
      if (!ref.mounted) return;
      state = ReadState(result: result);
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = ReadState(error: error);
    } finally {
      _inFlight = false;
      _cancel = null;
    }
  }
}
