import 'dart:typed_data';

import '../protocol/command.dart';

/// Any command by id, with an opaque payload and an opaque response. Used for
/// commands that have no typed wrapper yet and by the expert raw console.
final class RawCommand extends Command<Uint8List> {
  RawCommand(this.id, this.payload, {Duration? timeout})
    : timeout = timeout ?? const Duration(seconds: 3);

  @override
  final int id;
  final Uint8List payload;
  @override
  final Duration timeout;

  @override
  Uint8List encode() => payload;

  @override
  Uint8List decode(Uint8List data) => data;
}
