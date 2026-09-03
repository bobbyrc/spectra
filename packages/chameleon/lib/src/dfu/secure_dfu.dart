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

/// Nordic Secure DFU protocol v1 over an abstract [DfuChannel] (spec 4.5).
///
/// One implementation for every platform; only the channel differs. For each
/// image the sequence is: set PRN to 0, then transfer the init packet as a
/// command object and the firmware as a run of data objects. Each object is
/// selected, created, streamed in [DfuChannel.maxDataWrite] packets, checked
/// with a CRC and executed. An object whose CRC does not match is resent once
/// before the transfer fails.
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
      await _sendObject(
        responses,
        type: DfuOp.typeCommand,
        data: image.dat,
        cancel: cancel,
      );
      await _sendObject(
        responses,
        type: DfuOp.typeData,
        data: image.bin,
        cancel: cancel,
        onOffset: (o) => report(DfuStage.firmware, o),
      );
      report(DfuStage.done, total);
    } finally {
      await responses.cancel();
    }
  }

  /// Transfers [data] as one or more objects of [type], resuming from whatever
  /// prefix the bootloader already holds.
  Future<void> _sendObject(
    ResponseQueue<Uint8List> responses, {
    required int type,
    required Uint8List data,
    void Function(int offset)? onOffset,
    CancelToken? cancel,
  }) async {
    final select = await _request(responses, DfuOp.select, [type]);
    if (select.length < 12) {
      throw DfuError('short select response for object type $type');
    }
    final maxSize = _u32le(select, 0);
    if (maxSize <= 0) {
      throw DfuError('bootloader reports max object size $maxSize');
    }
    var offset = 0;
    var crc = 0;
    final resumeOffset = _u32le(select, 4);
    if (_isResumable(data, resumeOffset, _u32le(select, 8), maxSize)) {
      offset = resumeOffset;
      crc = _u32le(select, 8);
    }
    onOffset?.call(offset);
    while (offset < data.length) {
      _checkCancel(cancel);
      final objEnd = offset + (data.length - offset).clamp(0, maxSize);
      final objCrc = crc32(Uint8List.sublistView(data, offset, objEnd), crc);
      for (var attempt = 0; ; attempt++) {
        await _request(responses, DfuOp.create, [
          type,
          ..._le32(objEnd - offset),
        ]);
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
  }

  /// True when the bootloader already holds exactly the first [offset] bytes
  /// of [data] and stopped on an object boundary, so those objects can be
  /// skipped. A partial object is always resent from its start.
  static bool _isResumable(Uint8List data, int offset, int crc, int maxSize) {
    if (offset <= 0 || offset > data.length) return false;
    if (offset % maxSize != 0 && offset != data.length) return false;
    return crc32(Uint8List.sublistView(data, 0, offset)) == crc;
  }

  /// Writes one control request and awaits its matching response.
  Future<Uint8List> _request(
    ResponseQueue<Uint8List> responses,
    int opcode,
    List<int> payload,
  ) async {
    await _channel.writeControl(Uint8List.fromList([opcode, ...payload]));
    final Uint8List r;
    try {
      r = await responses.next.timeout(responseTimeout);
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
