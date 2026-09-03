import 'dart:async';
import 'dart:typed_data';

import '../protocol/errors.dart';
import '../session/cancel_token.dart';
import 'crc32.dart';
import 'dfu_channel.dart';
import 'dfu_opcodes.dart';
import 'dfu_package.dart';
import 'dfu_types.dart';
import 'response_queue.dart';

/// Where a transfer picks up, once the bootloader has reported what it already
/// holds: [offset] bytes with running CRC [crc], and whether the object ending
/// there still needs an Execute.
typedef _Resume = ({int offset, int crc, bool execute});

/// Nordic Secure DFU protocol v1 over an abstract [DfuChannel] (spec 4.5).
///
/// One implementation for every platform; only the channel differs. For each
/// image the sequence is: set PRN to 0, then transfer the init packet as a
/// command object and the firmware as a run of data objects. Each object is
/// selected, created, streamed in [DfuChannel.maxDataWrite] packets, checked
/// with a CRC and executed. An object whose CRC does not match is resent once
/// before the transfer fails.
///
/// A bootloader that already holds part of the image resumes: the transfer
/// restarts at the last object boundary the device's data matches, never at 0
/// while the device would keep appending. A device holding part of a
/// *different* image is reset by re-running the command object.
///
/// [run] never closes the channel: the orchestrator owns it, because after the
/// last execute the device reboots and the channel has to be torn down in a
/// transport-specific way.
final class SecureDfu {
  SecureDfu(
    this._channel, {
    this.responseTimeout = const Duration(seconds: 30),
  });

  final DfuChannel _channel;

  /// The bootloader inactivity budget: how long any one control request may
  /// go unanswered before the transfer fails.
  final Duration responseTimeout;

  /// Number of times an object is resent after a CRC mismatch.
  static const int _crcRetries = 1;

  Future<void> run(
    DfuImage image, {
    void Function(DfuProgress)? onProgress,
    CancelToken? cancel,
  }) async {
    if (image.bin.isEmpty) throw DfuError('firmware image is empty');
    if (!image.hashMatches) {
      throw DfuError('image hash does not match init packet');
    }
    final total = image.bin.length;
    var reported = -1;
    void report(DfuStage stage, int sent) {
      if (onProgress == null || sent < reported) return;
      reported = sent;
      onProgress(DfuProgress(stage, sent, total));
    }

    final responses = ResponseQueue(_channel.responses);
    try {
      await _request(responses, DfuOp.setPrn, const [0, 0]);
      report(DfuStage.init, 0);
      await _transfer(
        responses,
        type: DfuOp.typeCommand,
        data: image.dat,
        cancel: cancel,
      );
      final foreign = await _transfer(
        responses,
        type: DfuOp.typeData,
        data: image.bin,
        cancel: cancel,
        onOffset: (o) => report(DfuStage.firmware, o),
      );
      if (foreign) {
        // The bootloader holds part of some other image and would append to
        // it. Re-running the command object is what resets its firmware
        // progress; then the image goes up from the start — and progress
        // restarts with it, so the bar does not sit still while the whole
        // image is re-sent.
        reported = -1;
        await _transfer(
          responses,
          type: DfuOp.typeCommand,
          data: image.dat,
          cancel: cancel,
          force: true,
        );
        await _transfer(
          responses,
          type: DfuOp.typeData,
          data: image.bin,
          cancel: cancel,
          force: true,
          onOffset: (o) => report(DfuStage.firmware, o),
        );
      }
      report(DfuStage.done, total);
    } finally {
      // Safe to await: `ResponseQueue.cancel()` returns an already-completed
      // future and does not await the subscription's own cancel, which a
      // fake clock never drives.
      await responses.cancel();
    }
  }

  /// Transfers [data] as one or more objects of [type], resuming from whatever
  /// prefix the bootloader already holds.
  ///
  /// Returns true when the device holds a prefix of a different image, which
  /// only the caller can clear (by re-running the command object). Nothing is
  /// written in that case. With [force] the device is required to hold
  /// nothing, and the whole of [data] is sent.
  Future<bool> _transfer(
    ResponseQueue<Uint8List> responses, {
    required int type,
    required Uint8List data,
    void Function(int offset)? onOffset,
    CancelToken? cancel,
    bool force = false,
  }) async {
    final select = await _select(responses, type);
    final maxSize = _u32le(select, 0);
    if (maxSize <= 0) {
      throw DfuError('bootloader reports max object size $maxSize');
    }
    var offset = 0;
    var crc = 0;
    if (force) {
      // Only the firmware progress is reset by re-running the command object;
      // the command buffer still holds the old init packet, and creating the
      // object discards it.
      if (type == DfuOp.typeData && _u32le(select, 4) != 0) {
        throw DfuError(
          'bootloader still holds ${_u32le(select, 4)} bytes of object type '
          '$type after being reset',
        );
      }
    } else {
      final resume = await _resume(
        responses,
        type: type,
        data: data,
        maxSize: maxSize,
        devOffset: _u32le(select, 4),
        devCrc: _u32le(select, 8),
      );
      // A command object can always be restarted: creating it discards
      // whatever the bootloader held. A data object cannot.
      if (resume == null && type == DfuOp.typeData) return true;
      if (resume != null) {
        offset = resume.offset;
        crc = resume.crc;
        // The object ending at this offset was received but may never have
        // been executed. Executing an already-executed object is a no-op.
        if (resume.execute) await _request(responses, DfuOp.execute, const []);
      }
    }
    onOffset?.call(offset);
    while (offset < data.length) {
      _checkCancel(cancel);
      final objEnd = offset + (data.length - offset).clamp(0, maxSize);
      final objCrc = crc32(Uint8List.sublistView(data, offset, objEnd), crc);
      for (var attempt = 0; ; attempt++) {
        await _create(responses, type, objEnd - offset);
        var pos = offset;
        while (pos < objEnd) {
          _checkCancel(cancel);
          final end = (pos + _channel.maxDataWrite).clamp(0, objEnd);
          await _channel.writeData(Uint8List.sublistView(data, pos, end));
          pos = end;
          onOffset?.call(pos);
        }
        final crcResp = await _request(responses, DfuOp.calcCrc, const []);
        if (crcResp.length < 8) throw DfuError('short CRC response');
        final devOffset = _u32le(crcResp, 0);
        final devCrc = _u32le(crcResp, 4);
        if (devOffset == objEnd && devCrc == objCrc) break;
        if (attempt >= _crcRetries) {
          throw DfuError(
            'CRC mismatch at $objEnd: device offset $devOffset crc '
            '0x${devCrc.toRadixString(16)} expected '
            '0x${objCrc.toRadixString(16)}',
          );
        }
      }
      await _request(responses, DfuOp.execute, const []);
      offset = objEnd;
      crc = objCrc;
      onOffset?.call(offset);
    }
    return false;
  }

  /// Works out where to pick up, given what the bootloader says it holds.
  ///
  /// Returns null when none of the device's data is ours. A partially received
  /// object is never continued mid-object: the transfer restarts at the last
  /// object boundary, because a Create there is what makes the bootloader
  /// discard the partial object instead of appending to it.
  ///
  /// When the prefix does not match, one probe Create is issued at that
  /// boundary before giving up: it costs one round trip and is the only way
  /// to tell "the device holds our prefix plus a partial object of ours"
  /// from "the device holds some other image".
  Future<_Resume?> _resume(
    ResponseQueue<Uint8List> responses, {
    required int type,
    required Uint8List data,
    required int maxSize,
    required int devOffset,
    required int devCrc,
  }) async {
    if (devOffset <= 0) return (offset: 0, crc: 0, execute: false);
    if (devOffset <= data.length && _prefixCrc(data, devOffset) == devCrc) {
      if (devOffset == data.length || devOffset % maxSize == 0) {
        return (offset: devOffset, crc: devCrc, execute: true);
      }
      final boundary = devOffset - devOffset % maxSize;
      return (
        offset: boundary,
        crc: _prefixCrc(data, boundary),
        execute: false,
      );
    }
    // The prefix as a whole is not ours, but the partial object on top of it
    // might be the only difference. Create at the boundary to make the device
    // drop that object, then ask again.
    final boundary = devOffset - devOffset % maxSize;
    if (boundary <= 0 || boundary >= data.length) return null;
    await _create(responses, type, (data.length - boundary).clamp(0, maxSize));
    final select = await _select(responses, type);
    if (_u32le(select, 4) != boundary) return null;
    if (_u32le(select, 8) != _prefixCrc(data, boundary)) return null;
    return (offset: boundary, crc: _u32le(select, 8), execute: false);
  }

  static int _prefixCrc(Uint8List data, int end) =>
      crc32(Uint8List.sublistView(data, 0, end));

  /// Selects an object type; the reply is max object size, offset and CRC.
  Future<Uint8List> _select(
    ResponseQueue<Uint8List> responses,
    int type,
  ) async {
    final select = await _request(responses, DfuOp.select, [type]);
    if (select.length < 12) {
      throw DfuError('short select response for object type $type');
    }
    return select;
  }

  Future<void> _create(
    ResponseQueue<Uint8List> responses,
    int type,
    int size,
  ) => _request(responses, DfuOp.create, [type, ..._le32(size)]);

  /// Writes one control request and awaits its matching response.
  Future<Uint8List> _request(
    ResponseQueue<Uint8List> responses,
    int opcode,
    List<int> payload,
  ) async {
    await _channel.writeControl(Uint8List.fromList([opcode, ...payload]));
    final Uint8List r;
    try {
      r = await responses.nextWithin(responseTimeout);
    } on TimeoutException {
      throw DfuError(
        'opcode 0x${opcode.toRadixString(16)} timed out after '
        '$responseTimeout',
        opcode: opcode,
      );
    }
    if (r.length < 3 || r[0] != DfuOp.response || r[1] != opcode) {
      throw DfuError('unexpected DFU response ${r.toList()}', opcode: opcode);
    }
    if (r[2] != DfuOp.resultSuccess) {
      throw DfuError(
        'opcode 0x${opcode.toRadixString(16)} failed with result '
        '0x${r[2].toRadixString(16)}',
        opcode: opcode,
        result: r[2],
      );
    }
    return Uint8List.sublistView(r, 3);
  }

  void _checkCancel(CancelToken? c) {
    if (c?.isCancelled ?? false) throw const CommandCancelled();
  }

  static int _u32le(Uint8List b, int o) =>
      b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);

  static List<int> _le32(int v) => [
    v & 0xFF,
    (v >> 8) & 0xFF,
    (v >> 16) & 0xFF,
    (v >> 24) & 0xFF,
  ];
}
