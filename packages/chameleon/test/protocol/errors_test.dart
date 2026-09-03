import 'package:chameleon/src/protocol/errors.dart';
import 'package:chameleon/src/protocol/status.dart';
import 'package:test/test.dart';

void main() {
  test('maps every documented status to a typed error', () {
    expect(DeviceError.fromStatus(Status.hfTagNo), isA<HfTagNotFound>());
    expect(
      DeviceError.fromStatus(Status.hfErrCrc),
      isA<HfTagError>().having((e) => e.kind, 'kind', HfTagErrorKind.crc),
    );
    expect(
      DeviceError.fromStatus(Status.mfErrAuth),
      isA<AuthenticationFailed>(),
    );
    expect(DeviceError.fromStatus(Status.lfTagNoFound), isA<LfTagNotFound>());
    expect(
      DeviceError.fromStatus(Status.lfTagLoginRequired),
      isA<LfLoginRequired>(),
    );
    expect(DeviceError.fromStatus(Status.parErr), isA<ParameterError>());
    expect(
      DeviceError.fromStatus(Status.deviceModeError),
      isA<DeviceModeError>(),
    );
    expect(DeviceError.fromStatus(Status.invalidCmd), isA<InvalidCommand>());
    expect(
      DeviceError.fromStatus(Status.notImplemented),
      isA<NotImplemented>(),
    );
    expect(
      DeviceError.fromStatus(Status.flashWriteFail),
      isA<FlashWriteFailed>(),
    );
    expect(
      DeviceError.fromStatus(Status.flashReadFail),
      isA<FlashReadFailed>(),
    );
    expect(
      DeviceError.fromStatus(Status.invalidSlotType),
      isA<InvalidSlotType>(),
    );
    expect(DeviceError.fromStatus(Status.memErr), isA<MemoryError>());
    expect(
      DeviceError.fromStatus(Status.createResponseErr),
      isA<CreateResponseError>(),
    );
    expect(DeviceError.fromStatus(Status.cmdErr), isA<CommandFailed>());
  });

  test('unknown status keeps its code', () {
    final e = DeviceError.fromStatus(0x99);
    expect(e, isA<UnknownDeviceError>());
    expect(e.code, 0x99);
  });

  test('every error is a ChameleonException with a message', () {
    expect(const Disconnected(), isA<ChameleonException>());
    expect(
      CommandTimeout(1000, const Duration(seconds: 3)).message,
      contains('3e8'),
    );
  });
}
