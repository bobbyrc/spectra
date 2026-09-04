import 'dart:typed_data';

import '../codec/frame.dart';
import 'errors.dart';

/// Firmware command ranges and the status value each treats as success.
enum CommandRange {
  device(0x68),
  hfReader(0x00),
  lfReader(0x40),
  hfEmulator(0x68),
  lfEmulator(0x68),

  /// Success status 0x00 pending hardware validation (hardware-validate).
  iso14443_4(0x00);

  const CommandRange(this.successStatus);
  final int successStatus;

  static CommandRange forId(int id) => switch (id ~/ 1000) {
    1 => device,
    2 => hfReader,
    3 => lfReader,
    4 => hfEmulator,
    5 => lfEmulator,
    6 => iso14443_4,
    _ => throw ArgumentError.value(id, 'id', 'unknown command range'),
  };
}

/// One firmware command: how to encode its request and decode its response.
abstract base class Command<R> {
  const Command();

  int get id;
  CommandRange get range => CommandRange.forId(id);
  Duration get timeout => const Duration(seconds: 3);

  /// Safe to retry once after a timeout.
  bool get idempotent => false;

  /// False for commands the firmware never answers (ENTER_BOOTLOADER).
  bool get expectsResponse => true;

  Uint8List encode() => Uint8List(0);

  R decode(Uint8List data);

  Frame toFrame() => Frame(command: id, data: encode());

  R parseResponse(Frame frame) {
    if (frame.command != id) {
      throw MalformedResponse('expected response to $id, got ${frame.command}');
    }
    if (frame.status != range.successStatus) {
      throw DeviceError.fromStatus(frame.status);
    }
    try {
      return decode(frame.data);
    } on RangeError catch (e) {
      throw MalformedResponse('short response for command $id: $e');
    }
  }
}

/// A command whose successful response carries nothing useful.
abstract base class VoidCommand extends Command<void> {
  const VoidCommand();

  @override
  void decode(Uint8List data) {}
}
