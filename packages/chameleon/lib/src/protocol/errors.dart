import 'status.dart';

/// Root of every error the SDK raises.
sealed class ChameleonException implements Exception {
  const ChameleonException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// A response payload that did not match the expected shape.
final class MalformedResponse extends ChameleonException {
  const MalformedResponse(super.message);
}

final class CommandTimeout extends ChameleonException {
  CommandTimeout(this.commandId, this.timeout)
    : super(
        'command 0x${commandId.toRadixString(16)} timed out after $timeout',
      );
  final int commandId;
  final Duration timeout;
}

final class CommandCancelled extends ChameleonException {
  const CommandCancelled() : super('command cancelled');
}

final class SessionNotReady extends ChameleonException {
  const SessionNotReady(super.message);
}

enum UnsupportedReason { preTwoPointZero, newerMajor, legacyMustUpdate }

final class UnsupportedFirmware extends ChameleonException {
  const UnsupportedFirmware(this.reason, super.message);
  final UnsupportedReason reason;
}

sealed class TransportError extends ChameleonException {
  const TransportError(super.message);
}

final class Disconnected extends TransportError {
  const Disconnected([super.message = 'transport closed']);
}

final class PermissionDenied extends TransportError {
  const PermissionDenied([super.message = 'permission denied']);
}

final class PortBusy extends TransportError {
  const PortBusy([super.message = 'port busy']);
}

final class DeviceNotFound extends TransportError {
  const DeviceNotFound([super.message = 'device not found']);
}

final class PairingRequired extends TransportError {
  const PairingRequired([super.message = 'pairing required']);
}

final class AdapterOff extends TransportError {
  const AdapterOff([super.message = 'adapter off']);
}

enum HfTagErrorKind {
  generic(Status.hfErrStat),
  crc(Status.hfErrCrc),
  collision(Status.hfCollision),
  bcc(Status.hfErrBcc),
  parity(Status.hfErrParity),
  ats(Status.hfErrAts);

  const HfTagErrorKind(this.code);
  final int code;
}

/// A non-success status returned by the firmware.
sealed class DeviceError extends ChameleonException {
  const DeviceError(this.code, super.message);
  final int code;

  factory DeviceError.fromStatus(int code) => switch (code) {
    Status.hfTagNo => const HfTagNotFound(),
    Status.hfErrStat => const HfTagError(
      HfTagErrorKind.generic,
      Status.hfErrStat,
    ),
    Status.hfErrCrc => const HfTagError(HfTagErrorKind.crc, Status.hfErrCrc),
    Status.hfCollision => const HfTagError(
      HfTagErrorKind.collision,
      Status.hfCollision,
    ),
    Status.hfErrBcc => const HfTagError(HfTagErrorKind.bcc, Status.hfErrBcc),
    Status.hfErrParity => const HfTagError(
      HfTagErrorKind.parity,
      Status.hfErrParity,
    ),
    Status.hfErrAts => const HfTagError(HfTagErrorKind.ats, Status.hfErrAts),
    Status.mfErrAuth => const AuthenticationFailed(),
    Status.lfTagNoFound => const LfTagNotFound(),
    Status.lfTagLoginRequired => const LfLoginRequired(),
    Status.parErr => const ParameterError(),
    Status.deviceModeError => const DeviceModeError(),
    Status.invalidCmd => const InvalidCommand(),
    Status.notImplemented => const NotImplemented(),
    Status.flashWriteFail => const FlashWriteFailed(),
    Status.flashReadFail => const FlashReadFailed(),
    Status.invalidSlotType => const InvalidSlotType(),
    Status.memErr => const MemoryError(),
    Status.createResponseErr => const CreateResponseError(),
    Status.cmdErr => const CommandFailed(),
    _ => UnknownDeviceError(code),
  };
}

final class HfTagNotFound extends DeviceError {
  const HfTagNotFound() : super(Status.hfTagNo, 'no HF tag found');
}

final class HfTagError extends DeviceError {
  const HfTagError(this.kind, int code) : super(code, 'HF tag error');
  final HfTagErrorKind kind;
}

final class AuthenticationFailed extends DeviceError {
  const AuthenticationFailed()
    : super(Status.mfErrAuth, 'authentication failed');
}

final class LfTagNotFound extends DeviceError {
  const LfTagNotFound() : super(Status.lfTagNoFound, 'no LF tag found');
}

final class LfLoginRequired extends DeviceError {
  const LfLoginRequired()
    : super(Status.lfTagLoginRequired, 'LF tag requires login');
}

final class ParameterError extends DeviceError {
  const ParameterError() : super(Status.parErr, 'parameter error');
}

final class DeviceModeError extends DeviceError {
  const DeviceModeError() : super(Status.deviceModeError, 'wrong device mode');
}

final class InvalidCommand extends DeviceError {
  const InvalidCommand() : super(Status.invalidCmd, 'invalid command');
}

final class NotImplemented extends DeviceError {
  const NotImplemented() : super(Status.notImplemented, 'not implemented');
}

final class FlashWriteFailed extends DeviceError {
  const FlashWriteFailed() : super(Status.flashWriteFail, 'flash write failed');
}

final class FlashReadFailed extends DeviceError {
  const FlashReadFailed() : super(Status.flashReadFail, 'flash read failed');
}

final class InvalidSlotType extends DeviceError {
  const InvalidSlotType() : super(Status.invalidSlotType, 'invalid slot type');
}

final class MemoryError extends DeviceError {
  const MemoryError() : super(Status.memErr, 'memory error');
}

final class CreateResponseError extends DeviceError {
  const CreateResponseError()
    : super(Status.createResponseErr, 'create response error');
}

final class CommandFailed extends DeviceError {
  const CommandFailed() : super(Status.cmdErr, 'command error');
}

final class UnknownDeviceError extends DeviceError {
  UnknownDeviceError(int code)
    : super(code, 'unknown status 0x${code.toRadixString(16)}');
}
