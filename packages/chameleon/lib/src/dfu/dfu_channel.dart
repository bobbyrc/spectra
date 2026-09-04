import 'dart:typed_data';

/// The two DFU endpoints: control point (with responses) and data packets.
///
/// Implemented once per transport (BLE and SLIP-over-serial live in
/// `chameleon_flutter`); [SecureDfu] is the only protocol implementation.
abstract interface class DfuChannel {
  /// Largest data packet the transport accepts (the BLE MTU payload, or the
  /// serial chunk size).
  int get maxDataWrite;

  /// Gets the channel ready to carry DFU traffic: connect, discover,
  /// subscribe, settle [maxDataWrite] — whatever the transport needs.
  ///
  /// Must be awaited before the first write; idempotent, so a second call
  /// on an already-open channel does nothing. A channel over a link that is
  /// already up (the SLIP serial channel, the fakes) implements it as a
  /// no-op, so every caller can follow one lifecycle: open, write, close.
  Future<void> open();

  Future<void> writeControl(Uint8List bytes);

  Future<void> writeData(Uint8List bytes);

  /// Control-point notifications, in order.
  Stream<Uint8List> get responses;

  Future<void> close();
}
