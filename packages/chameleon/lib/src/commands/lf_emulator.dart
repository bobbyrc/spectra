import 'dart:typed_data';

import '../codec/bytes.dart';
import '../protocol/command.dart';

/// Wire lengths of each LF emulator id.
const Map<int, int> emuLfIdLengths = {
  5000: 5,
  5002: 13,
  5004: 4,
  5006: 8,
  5010: 5,
  5012: 8,
};

abstract base class _SetId extends VoidCommand {
  _SetId(this.idBytes) {
    final n = emuLfIdLengths[id]!;
    if (idBytes.length != n) {
      throw ArgumentError.value(idBytes.length, 'id', 'must be $n bytes');
    }
  }
  final Uint8List idBytes;
  @override
  Uint8List encode() => idBytes;
}

abstract base class _GetId extends Command<Uint8List> {
  const _GetId();
  @override
  bool get idempotent => true;
  @override
  Uint8List decode(Uint8List data) =>
      ByteReader(data).bytes(emuLfIdLengths[id - 1]!);
}

final class Em410xSetEmuId extends _SetId {
  Em410xSetEmuId(super.idBytes);
  @override
  int get id => 5000;
}

final class Em410xGetEmuId extends _GetId {
  const Em410xGetEmuId();
  @override
  int get id => 5001;
}

final class HidProxSetEmuId extends _SetId {
  HidProxSetEmuId(super.idBytes);
  @override
  int get id => 5002;
}

final class HidProxGetEmuId extends _GetId {
  const HidProxGetEmuId();
  @override
  int get id => 5003;
}

/// hardware-validate: id length taken from the reference app, unverified on
/// hardware.
final class VikingSetEmuId extends _SetId {
  VikingSetEmuId(super.idBytes);
  @override
  int get id => 5004;
}

/// hardware-validate: id length taken from the reference app, unverified on
/// hardware.
final class VikingGetEmuId extends _GetId {
  const VikingGetEmuId();
  @override
  int get id => 5005;
}

/// hardware-validate: id length taken from the reference app, unverified on
/// hardware.
final class PacSetEmuId extends _SetId {
  PacSetEmuId(super.idBytes);
  @override
  int get id => 5006;
}

/// hardware-validate: id length taken from the reference app, unverified on
/// hardware.
final class PacGetEmuId extends _GetId {
  const PacGetEmuId();
  @override
  int get id => 5007;
}

/// hardware-validate: id length taken from the reference app, unverified on
/// hardware.
final class JablotronSetEmuId extends _SetId {
  JablotronSetEmuId(super.idBytes);
  @override
  int get id => 5010;
}

/// hardware-validate: id length taken from the reference app, unverified on
/// hardware.
final class JablotronGetEmuId extends _GetId {
  const JablotronGetEmuId();
  @override
  int get id => 5011;
}

/// hardware-validate: id length taken from the reference app, unverified on
/// hardware.
final class IdteckSetEmuId extends _SetId {
  IdteckSetEmuId(super.idBytes);
  @override
  int get id => 5012;
}

/// hardware-validate: id length taken from the reference app, unverified on
/// hardware.
final class IdteckGetEmuId extends _GetId {
  const IdteckGetEmuId();
  @override
  int get id => 5013;
}
