import 'dart:typed_data';

import 'crc32.dart';
import 'dfu_opcodes.dart';
import 'dfu_package.dart';

/// The bootloader side of Secure DFU: enough of the protocol to prove
/// [SecureDfu] works, and to back FakeDevice's bootloader mode.
///
/// It keeps two buffers, one per object type, exactly as a real bootloader
/// does: the command buffer holds the init packet, the data buffer the
/// firmware written so far. Data always *appends* to what is already there —
/// the only way to go back is to create an object, which rolls the buffer back
/// to the last executed boundary, or to execute a new command object, which
/// discards the firmware progress entirely.
final class FakeBootloader {
  FakeBootloader({this.maxObjectSize = 4096, this.expectedHwVersion = 0});

  /// Largest data object the bootloader accepts (a real one reports a flash
  /// page multiple).
  final int maxObjectSize;

  /// The hardware version the init packet must declare; anything else is
  /// refused at execute time.
  final int expectedHwVersion;

  /// Largest command object: the init packet always fits in one.
  static const int maxCommandSize = 512;

  final List<int> _command = [];
  final List<int> _data = [];

  /// Bytes of [_data] that survived an execute; a create rolls back to here.
  int _committed = 0;
  int _selected = DfuOp.typeCommand;

  /// The created-but-not-yet-executed object, if any.
  bool _pendingCreated = false;
  int _pendingType = DfuOp.typeCommand;
  int _pendingSize = 0;
  int _pendingReceived = 0;

  bool _failNextCreate = false;
  int _corruptCrc = 0;
  int _corruptSkip = 0;

  InitPacket? _init;

  /// Data objects the client executed (the resume path executes fewer).
  int executedDataObjects = 0;

  /// Bytes accepted on the data endpoint, of either object type. Proves a
  /// resumed transfer did not resend what the bootloader already had.
  int bytesReceived = 0;

  /// True once the whole firmware named by the init packet is written.
  bool completed = false;

  InitPacket? get init => _init;

  Uint8List get flashed => Uint8List.fromList(_data);

  /// Fails the next create with "insufficient resources".
  void failNextCreate() => _failNextCreate = true;

  /// Answers [times] CRC requests with a wrong CRC, so the client has to
  /// resend the object. [skip] leaves that many CRC requests correct first,
  /// to aim the corruption at a later object.
  void corruptNextCrc({int times = 1, int skip = 0}) {
    _corruptCrc = times;
    _corruptSkip = skip;
  }

  /// Puts the bootloader in the state an interrupted transfer leaves behind:
  /// [commandObject] executed and [data] received.
  ///
  /// Objects commit in whole [maxObjectSize] units, so any remainder of [data]
  /// past the last object boundary is modelled as a created-but-unexecuted
  /// object — exactly what a device that lost power mid-object holds.
  void preload({required Uint8List commandObject, required Uint8List data}) {
    _command
      ..clear()
      ..addAll(commandObject);
    _init = InitPacket.parse(commandObject);
    _data
      ..clear()
      ..addAll(data);
    _committed = data.length - data.length % maxObjectSize;
    _pendingCreated = _committed != data.length;
    _pendingType = DfuOp.typeData;
    _pendingSize = data.length - _committed;
    _pendingReceived = _pendingSize;
  }

  /// Adds an object the device received but never executed, on top of whatever
  /// [preload] left committed.
  void preloadUncommitted(Uint8List bytes, {int type = DfuOp.typeData}) {
    if (type == DfuOp.typeCommand) {
      _command
        ..clear()
        ..addAll(bytes);
    } else {
      _data.addAll(bytes);
    }
    _pendingCreated = true;
    _pendingType = type;
    _pendingSize = bytes.length;
    _pendingReceived = bytes.length;
  }

  List<int> get _buffer => _selected == DfuOp.typeCommand ? _command : _data;

  Uint8List handleControl(Uint8List req) {
    final op = req.isEmpty ? 0 : req[0];
    Uint8List ok([List<int> payload = const []]) => Uint8List.fromList([
      DfuOp.response,
      op,
      DfuOp.resultSuccess,
      ...payload,
    ]);
    Uint8List fail(int result) =>
        Uint8List.fromList([DfuOp.response, op, result]);
    // Every request carries its opcode; select and set-PRN carry one more
    // argument, create carries a type and a 32-bit size.
    const sizes = {
      DfuOp.select: 2,
      DfuOp.setPrn: 3,
      DfuOp.create: 6,
      DfuOp.calcCrc: 1,
      DfuOp.execute: 1,
    };
    if (req.length < (sizes[op] ?? 1)) {
      return fail(DfuOp.resultInvalidParameter);
    }

    switch (op) {
      case DfuOp.select:
        _selected = req[1];
        final bytes = _buffer;
        final max = _selected == DfuOp.typeCommand
            ? maxCommandSize
            : maxObjectSize;
        return ok([..._le(max), ..._le(bytes.length), ..._le(crc32(bytes))]);
      case DfuOp.setPrn:
        return ok();
      case DfuOp.create:
        if (_failNextCreate) {
          _failNextCreate = false;
          return fail(DfuOp.resultInsufficientResources);
        }
        _selected = req[1];
        final size = req[2] | (req[3] << 8) | (req[4] << 16) | (req[5] << 24);
        final max = _selected == DfuOp.typeCommand
            ? maxCommandSize
            : maxObjectSize;
        if (size > max) return fail(DfuOp.resultInsufficientResources);
        _pendingCreated = true;
        _pendingType = _selected;
        _pendingSize = size;
        _pendingReceived = 0;
        if (_selected == DfuOp.typeCommand) {
          // A new init packet invalidates the one in force.
          _command.clear();
          _init = null;
        } else {
          _data.removeRange(_committed, _data.length);
        }
        return ok();
      case DfuOp.calcCrc:
        final bytes = _buffer;
        var crc = crc32(bytes);
        if (_corruptSkip > 0) {
          _corruptSkip--;
        } else if (_corruptCrc > 0) {
          _corruptCrc--;
          crc ^= 0xFFFF;
        }
        return ok([..._le(bytes.length), ..._le(crc)]);
      case DfuOp.execute:
        // Nothing of this type is waiting: executing an object that is
        // already executed is a no-op, which is what lets a resuming client
        // execute unconditionally.
        if (!_pendingCreated || _pendingType != _selected) return ok();
        if (_pendingReceived != _pendingSize) {
          return fail(DfuOp.resultInvalidObject);
        }
        if (_selected == DfuOp.typeCommand) {
          final parsed = InitPacket.parse(Uint8List.fromList(_command));
          if (parsed.hwVersion != expectedHwVersion) {
            return fail(DfuOp.resultNotPermitted);
          }
          _init = parsed;
          // A fresh init packet resets the firmware progress: the image it
          // names has not been written yet, which matters for a package
          // carrying more than one image.
          _data.clear();
          _committed = 0;
          completed = false;
        } else {
          _committed = _data.length;
          executedDataObjects++;
          if (_init != null && _data.length == _init!.appSize) {
            completed = true;
          }
        }
        _pendingCreated = false;
        return ok();
      default:
        return fail(DfuOp.resultOpcodeNotSupported);
    }
  }

  void handleData(Uint8List bytes) {
    _buffer.addAll(bytes);
    _pendingReceived += bytes.length;
    bytesReceived += bytes.length;
  }

  static List<int> _le(int v) => [
    v & 0xFF,
    (v >> 8) & 0xFF,
    (v >> 16) & 0xFF,
    (v >> 24) & 0xFF,
  ];
}
