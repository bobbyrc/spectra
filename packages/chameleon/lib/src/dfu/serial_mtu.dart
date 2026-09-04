import 'dart:typed_data';

import 'dfu_opcodes.dart';

/// The `GetSerialMTU` exchange, used by the serial DFU channel to size its
/// data writes (spec 4.5, 5.3).
///
/// Layout and arithmetic are nrfutil's
/// (`nordicsemi/dfu/dfu_transport_serial.py`): `DfuTransportSerial.open`
/// sends the bare opcode, `__get_mtu` reads a little-endian uint16 from the
/// response payload, and the data chunk is `(mtu - 1) // 2 - 1` — halved
/// because SLIP escaping can double a payload, so a worst-case frame still
/// fits the bootloader's buffer.
///
/// Kept here rather than in `chameleon_flutter`: `SecureDfu` is the only DFU
/// protocol implementation (spec 4.5), so the wire knowledge stays in the
/// SDK and the channel only performs the exchange.
abstract final class DfuSerialMtu {
  /// The control request: the opcode with no parameters.
  static Uint8List request() => Uint8List.fromList(<int>[DfuOp.getSerialMtu]);

  /// The MTU in [response], or null when it is not a successful reply to
  /// [request] — a bootloader that does not implement the opcode answers
  /// `NRF_DFU_RES_CODE_OP_CODE_NOT_SUPPORTED`, which is a normal outcome,
  /// not an error.
  static int? parse(Uint8List response) {
    if (response.length < 5) return null;
    if (response[0] != DfuOp.response) return null;
    if (response[1] != DfuOp.getSerialMtu) return null;
    if (response[2] != DfuOp.resultSuccess) return null;
    return response[3] | (response[4] << 8);
  }

  /// The largest data payload one SLIP frame may carry for [mtu].
  static int chunkSize(int mtu) => (mtu - 1) ~/ 2 - 1;
}
