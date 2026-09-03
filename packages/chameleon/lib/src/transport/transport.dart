import 'dart:typed_data';

import '../protocol/errors.dart';

enum TransportKind { usb, ble, fake }

/// Why a transport closed. The session decides whether a link loss was
/// expected (bootloader reboot) or not.
enum CloseCause {
  /// The caller asked for the transport to close.
  requested,

  /// The session asked the device to reboot, e.g. ENTER_BOOTLOADER; not a
  /// disconnect.
  expected,

  /// The link dropped without either side asking for it: cable pulled,
  /// device out of range, adapter reset.
  linkLost,
}

sealed class TransportState {
  const TransportState();
}

final class TransportOpening extends TransportState {
  const TransportOpening();
}

final class TransportOpen extends TransportState {
  const TransportOpen();
}

final class TransportClosed extends TransportState {
  const TransportClosed(this.cause, {this.error});
  final CloseCause cause;
  final TransportError? error;
}

final class TransportPairingRequired extends TransportState {
  const TransportPairingRequired();
}

/// Moves bytes. Knows nothing about frames.
abstract interface class Transport {
  TransportKind get kind;
  Future<void> open();
  Future<void> close();
  Stream<Uint8List> get incoming;
  Future<void> write(Uint8List bytes);
  Stream<TransportState> get state;
  TransportState get currentState;
}
