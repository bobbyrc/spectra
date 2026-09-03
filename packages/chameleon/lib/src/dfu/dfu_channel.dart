import 'dart:typed_data';

/// The two DFU endpoints: control point (with responses) and data packets.
///
/// Implemented once per transport (BLE and SLIP-over-serial live in
/// `chameleon_flutter`); [SecureDfu] is the only protocol implementation.
abstract interface class DfuChannel {
  /// Largest data packet the transport accepts (the BLE MTU payload, or the
  /// serial chunk size).
  int get maxDataWrite;

  Future<void> writeControl(Uint8List bytes);

  Future<void> writeData(Uint8List bytes);

  /// Control-point notifications, in order.
  Stream<Uint8List> get responses;

  Future<void> close();
}
