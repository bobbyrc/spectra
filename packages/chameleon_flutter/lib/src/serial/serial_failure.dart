import '../host_platform.dart';

/// The distinctions the serial transport makes (spec 5.2).
enum SerialFailure {
  /// The process may not open the port: Linux group/udev, Windows
  /// access-denied, macOS sandbox without the serial entitlement.
  permissionDenied,

  /// Another process holds the port. ModemManager on Linux is the usual
  /// cause; on Windows it is a terminal left open.
  portBusy,

  /// The port does not exist (any more).
  notFound,

  /// The link dropped after it was open: the cable was pulled.
  disconnected,

  /// Anything we cannot tell apart.
  unknown,
}

/// The only exception type a `SerialPortAdapter` throws.
///
/// Wrapping every native error in this keeps `libserialport_plus` types out
/// of the transport, which is what makes the transport unit-testable.
final class SerialAdapterException implements Exception {
  const SerialAdapterException(this.failure, this.message);

  final SerialFailure failure;
  final String message;

  @override
  String toString() => 'SerialAdapterException(${failure.name}): $message';
}

/// Maps a native serial error to a [SerialFailure].
///
/// [code] is what `SerialPortException.code` carries: `sp_last_error_code()`,
/// which is errno on POSIX and `GetLastError()` on Windows — hence the
/// [platform] parameter, without which Windows `ERROR_ACCESS_DENIED` (5) and
/// POSIX `EIO` (5) are indistinguishable.
///
/// [code] may be null (no code available) and may be one of libserialport's
/// own negative `SP_ERR_*` return values, which are not system codes; in
/// both cases only [message] is consulted. The message is also the fallback
/// for a system code we do not recognise, because libserialport sometimes
/// reports a generic code with a specific string.
SerialFailure mapSerialError(int? code, String message, HostPlatform platform) {
  final byCode = (code == null || code < 0)
      ? null
      : switch (platform) {
          HostPlatform.windows => switch (code) {
            5 => SerialFailure.permissionDenied, // ERROR_ACCESS_DENIED
            32 => SerialFailure.portBusy, // ERROR_SHARING_VIOLATION
            2 || 3 => SerialFailure.notFound, // FILE_ / PATH_NOT_FOUND
            31 => SerialFailure.disconnected, // ERROR_GEN_FAILURE
            1167 => SerialFailure.disconnected, // ERROR_DEVICE_NOT_CONNECTED
            _ => null,
          },
          _ => switch (code) {
            1 => SerialFailure.permissionDenied, // EPERM (macOS sandbox)
            13 => SerialFailure.permissionDenied, // EACCES
            16 => SerialFailure.portBusy, // EBUSY
            2 => SerialFailure.notFound, // ENOENT
            6 => SerialFailure.notFound, // ENXIO
            19 => SerialFailure.notFound, // ENODEV
            5 => SerialFailure.disconnected, // EIO
            _ => null,
          },
        };
  if (byCode != null) return byCode;

  final text = message.toLowerCase();
  if (text.contains('permission denied') ||
      text.contains('access is denied') ||
      text.contains('operation not permitted')) {
    return SerialFailure.permissionDenied;
  }
  if (text.contains('busy') || text.contains('cannot access the file')) {
    return SerialFailure.portBusy;
  }
  if (text.contains('no such file') ||
      text.contains('no such device') ||
      text.contains('cannot find the file')) {
    return SerialFailure.notFound;
  }
  if (text.contains('input/output error') || text.contains('not connected')) {
    return SerialFailure.disconnected;
  }
  return SerialFailure.unknown;
}
