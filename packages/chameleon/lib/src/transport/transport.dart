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

/// The link needs pairing before it can carry data. Not a close: the app
/// shows the pairing step (spec 5.1) and the session reports
/// [PairingRequired].
final class TransportPairingRequired extends TransportState {
  const TransportPairingRequired();
}

/// The OS refused a permission the transport needs: Android's
/// BLUETOOTH_SCAN / BLUETOOTH_CONNECT, an iOS or macOS usage prompt the user
/// declined, or a serial port the process may not open. Not a close: the
/// transport never opened. The app shows the permission step (spec 5.1).
final class TransportPermissionDenied extends TransportState {
  const TransportPermissionDenied();
}

/// The Bluetooth adapter is off or unavailable. The app shows the
/// "turn Bluetooth on" step rather than a connection error (spec 5.1).
final class TransportAdapterOff extends TransportState {
  const TransportAdapterOff();
}

/// Moves bytes. Knows nothing about frames.
abstract interface class Transport {
  TransportKind get kind;
  Future<void> open();
  Future<void> close();

  /// Bytes from the device, in order. A broadcast stream.
  ///
  /// Contract, which every implementation must honour and every consumer
  /// may rely on:
  ///
  /// * [incoming] **never carries an error event**. A link that fails —
  ///   the cable pulled, the peripheral out of range, the notify
  ///   subscription broken — is reported on [state] as a
  ///   [TransportClosed] with [CloseCause.linkLost], and nowhere else.
  /// * [incoming] **does not close on link loss**, so a consumer cannot
  ///   use its end-of-stream as a liveness signal either. Watch [state].
  /// * [incoming] closes only after [close] (which, for a single-use
  ///   transport, is the end of its life).
  ///
  /// The reason is that a byte stream has many listeners and none of them
  /// owns the link: an error event there is either uncaught or handled
  /// several times over, while [state] is the one place the session,
  /// the DFU channel and the UI already agree to look.
  Stream<Uint8List> get incoming;
  Future<void> write(Uint8List bytes);

  /// The largest single [write] this transport accepts, in bytes.
  ///
  /// Informational: the dispatcher never chunks, because a Chameleon request
  /// always fits (4096 data bytes plus the 9-byte header and LRCs = 4105). A
  /// transport whose link MTU is smaller — BLE's 20-byte default, a serial
  /// driver's buffer — fragments internally and still reports the largest
  /// frame it will take here.
  int get maxWriteLength;
  Stream<TransportState> get state;
  TransportState get currentState;
}
