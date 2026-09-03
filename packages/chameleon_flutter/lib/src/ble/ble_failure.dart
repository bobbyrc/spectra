/// The distinctions the BLE transport actually makes, mapped from
/// universal_ble's 61-value `UniversalBleErrorCode`. Keeping the mapping in
/// one pure function means the transport can be tested without the plugin.
enum BleFailure {
  /// The link needs a bond the device does not have: spec 5.1 detects
  /// `pairingRequired` from exactly this on subscribe or write.
  insufficientAuthentication,

  /// The OS refused the Bluetooth permission.
  permissionDenied,

  /// The adapter is off or unavailable.
  adapterOff,

  /// The device, service or characteristic could not be found.
  deviceNotFound,

  /// The link dropped.
  disconnected,

  /// The operation timed out.
  timeout,

  /// A write was rejected.
  writeFailed,

  /// Anything else, including codes added by a future universal_ble.
  unknown,
}

/// The only exception type a [BleAdapter] throws.
///
/// Wrapping every plugin error in this keeps `universal_ble` types out of
/// the transport, which is what makes the transport unit-testable.
final class BleAdapterException implements Exception {
  const BleAdapterException(this.failure, this.message);

  final BleFailure failure;
  final String message;

  @override
  String toString() => 'BleAdapterException(${failure.name}): $message';
}

/// Maps a `UniversalBleErrorCode.name` to a [BleFailure].
///
/// Takes the code's *name* rather than the enum so this file has no
/// universal_ble import and stays unit-testable. Every code universal_ble
/// 2.2.0 defines that the transport can distinguish is listed; everything
/// else — including codes a future release adds — is [BleFailure.unknown].
BleFailure bleFailureFromCode(String code) => switch (code) {
  'insufficientAuthentication' ||
  'insufficientEncryption' ||
  'insufficientAuthorization' ||
  'insufficientKeySize' ||
  'protectionLevelNotMet' ||
  'authenticationFailure' ||
  'notPaired' ||
  'notPairable' ||
  'pairingFailed' ||
  'pairingCancelled' ||
  'pairingTimeout' ||
  'pairingNotAllowed' => BleFailure.insufficientAuthentication,
  'bluetoothUnauthorized' ||
  'bluetoothNotAllowed' ||
  'accessDenied' => BleFailure.permissionDenied,
  'bluetoothNotEnabled' ||
  'bluetoothNotAvailable' ||
  'webBluetoothGloballyDisabled' => BleFailure.adapterOff,
  'deviceNotFound' ||
  'serviceNotFound' ||
  'characteristicNotFound' => BleFailure.deviceNotFound,
  'deviceDisconnected' ||
  'connectionTerminated' ||
  'connectionRejected' => BleFailure.disconnected,
  'connectionTimeout' || 'operationTimeout' => BleFailure.timeout,
  'writeFailed' ||
  'writeNotPermitted' ||
  'writeRequestBusy' ||
  'characteristicDoesNotSupportWrite' => BleFailure.writeFailed,
  _ => BleFailure.unknown,
};
