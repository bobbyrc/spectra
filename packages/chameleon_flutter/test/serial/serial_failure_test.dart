import 'package:chameleon_flutter/src/host_platform.dart';
import 'package:chameleon_flutter/src/serial/serial_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapSerialError', () {
    test('POSIX errnos map to the right failure', () {
      expect(
        mapSerialError(13, 'Permission denied', HostPlatform.linux),
        SerialFailure.permissionDenied,
      );
      expect(
        mapSerialError(1, 'Operation not permitted', HostPlatform.macos),
        SerialFailure.permissionDenied,
      );
      expect(
        mapSerialError(16, 'Device or resource busy', HostPlatform.linux),
        SerialFailure.portBusy,
      );
      expect(
        mapSerialError(2, 'No such file or directory', HostPlatform.macos),
        SerialFailure.notFound,
      );
      expect(
        mapSerialError(6, 'Device not configured', HostPlatform.macos),
        SerialFailure.notFound,
      );
      expect(
        mapSerialError(19, 'No such device', HostPlatform.linux),
        SerialFailure.notFound,
      );
      expect(
        mapSerialError(5, 'Input/output error', HostPlatform.linux),
        SerialFailure.disconnected,
      );
    });

    test('Win32 codes map to the right failure', () {
      expect(
        mapSerialError(5, 'Access is denied.', HostPlatform.windows),
        SerialFailure.permissionDenied,
      );
      expect(
        mapSerialError(
          32,
          'The process cannot access the file',
          HostPlatform.windows,
        ),
        SerialFailure.portBusy,
      );
      expect(
        mapSerialError(
          2,
          'The system cannot find the file',
          HostPlatform.windows,
        ),
        SerialFailure.notFound,
      );
      expect(
        mapSerialError(
          31,
          'A device attached to the system is not functioning',
          HostPlatform.windows,
        ),
        SerialFailure.disconnected,
      );
      expect(
        mapSerialError(
          1167,
          'The device is not connected',
          HostPlatform.windows,
        ),
        SerialFailure.disconnected,
      );
    });

    test('code 5 is disambiguated by the platform', () {
      expect(
        mapSerialError(5, '', HostPlatform.linux),
        SerialFailure.disconnected,
      );
      expect(
        mapSerialError(5, '', HostPlatform.windows),
        SerialFailure.permissionDenied,
      );
    });

    test('an unknown code falls back to the message text', () {
      expect(
        mapSerialError(999, 'Permission denied', HostPlatform.linux),
        SerialFailure.permissionDenied,
      );
      expect(
        mapSerialError(999, 'Resource busy', HostPlatform.macos),
        SerialFailure.portBusy,
      );
      expect(
        mapSerialError(999, 'something else entirely', HostPlatform.linux),
        SerialFailure.unknown,
      );
    });

    test('a missing or libserialport-internal code uses the message alone', () {
      expect(
        mapSerialError(null, 'Permission denied', HostPlatform.linux),
        SerialFailure.permissionDenied,
      );
      // SP_ERR_FAIL and friends are libserialport return codes, not errnos:
      // -2 must not be read as one.
      expect(
        mapSerialError(-2, 'Device or resource busy', HostPlatform.linux),
        SerialFailure.portBusy,
      );
      expect(
        mapSerialError(-1, 'Argument error', HostPlatform.macos),
        SerialFailure.unknown,
      );
    });
  });

  test('SerialAdapterException prints its failure and message', () {
    expect(
      const SerialAdapterException(
        SerialFailure.portBusy,
        'held by ModemManager',
      ).toString(),
      'SerialAdapterException(portBusy): held by ModemManager',
    );
  });
}
