import 'package:chameleon_flutter/src/ble/ble_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  test('security codes become insufficientAuthentication', () {
    for (final code in const [
      'insufficientAuthentication',
      'insufficientEncryption',
      'insufficientAuthorization',
      'protectionLevelNotMet',
      'authenticationFailure',
      'notPaired',
      'pairingFailed',
    ]) {
      expect(
        bleFailureFromCode(code),
        BleFailure.insufficientAuthentication,
        reason: code,
      );
    }
  });

  test('authorization codes become permissionDenied', () {
    for (final code in const [
      'bluetoothUnauthorized',
      'bluetoothNotAllowed',
      'accessDenied',
    ]) {
      expect(
        bleFailureFromCode(code),
        BleFailure.permissionDenied,
        reason: code,
      );
    }
  });

  test('adapter codes become adapterOff', () {
    expect(bleFailureFromCode('bluetoothNotEnabled'), BleFailure.adapterOff);
    expect(bleFailureFromCode('bluetoothNotAvailable'), BleFailure.adapterOff);
  });

  test('lookup and link codes are distinguished', () {
    expect(bleFailureFromCode('deviceNotFound'), BleFailure.deviceNotFound);
    expect(
      bleFailureFromCode('characteristicNotFound'),
      BleFailure.deviceNotFound,
    );
    expect(bleFailureFromCode('deviceDisconnected'), BleFailure.disconnected);
    expect(bleFailureFromCode('connectionTerminated'), BleFailure.disconnected);
    expect(bleFailureFromCode('connectionTimeout'), BleFailure.timeout);
    expect(bleFailureFromCode('operationTimeout'), BleFailure.timeout);
    expect(bleFailureFromCode('writeFailed'), BleFailure.writeFailed);
    expect(bleFailureFromCode('writeRequestBusy'), BleFailure.writeFailed);
  });

  test('anything unrecognised is unknown, not a crash', () {
    expect(
      bleFailureFromCode('somethingNewInAFutureRelease'),
      BleFailure.unknown,
    );
    expect(bleFailureFromCode(''), BleFailure.unknown);
  });

  test('every UniversalBleErrorCode maps to some BleFailure', () {
    // UniversalBleErrorCode is a plain Dart enum, importable without a
    // plugin channel, so the mapping can be checked exhaustively here. Any
    // code universal_ble adds in a future release falls through to
    // BleFailure.unknown rather than throwing.
    for (final code in UniversalBleErrorCode.values) {
      expect(
        () => bleFailureFromCode(code.name),
        returnsNormally,
        reason: code.name,
      );
    }
    expect(
      bleFailureFromCode(UniversalBleErrorCode.insufficientAuthentication.name),
      BleFailure.insufficientAuthentication,
    );
    expect(
      bleFailureFromCode(UniversalBleErrorCode.unknownError.name),
      BleFailure.unknown,
    );
  });

  test('BleAdapterException reports its failure and message', () {
    const e = BleAdapterException(BleFailure.adapterOff, 'radio is off');
    expect(e.failure, BleFailure.adapterOff);
    expect(e.message, 'radio is off');
    expect(e.toString(), 'BleAdapterException(adapterOff): radio is off');
  });
}
