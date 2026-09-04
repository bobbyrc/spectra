import 'dart:async';
import 'dart:typed_data';

import 'package:chameleon_flutter/src/ble/ble_adapter.dart';
import 'package:chameleon_flutter/src/ble/ble_failure.dart';

/// A [BleAdapter] whose every outcome is set by the test.
///
/// Nothing here talks to a radio: it exists so the transport's retry,
/// chunking, state and error logic can be proved without a device.
///
/// `base` rather than `final` so a test that needs one more behaviour —
/// the reconnect and DFU suites do — can extend it instead of
/// reimplementing the whole interface.
base class FakeBleAdapter implements BleAdapter {
  FakeBleAdapter({
    this.availability_ = BleAvailability.poweredOn,
    this.mtu = 247,
    List<BleScanEntry> advertisements = const <BleScanEntry>[],
  }) : _seed = advertisements;

  /// Replayed on a microtask after the *first* [scan] call, so a listener
  /// attached synchronously after `scan()` still sees them. A second
  /// `scan()` does not replay them: the seeds model advertisements the
  /// radio happened to catch, not a queue the fake re-delivers to
  /// listeners already holding the stream. Use [emitAdvertisement] to push
  /// more at any time.
  final List<BleScanEntry> _seed;
  bool _seedsDelivered = false;

  /// What [availability] reports; mutable so a test can turn the radio off
  /// mid-flight. Trailing underscore because `availability` is the method.
  BleAvailability availability_;

  /// Result of [requestMtu]; a negative value makes it throw instead.
  int mtu;

  int connectAttempts = 0;

  /// Fail this many [connect] calls with [failConnectWith] before
  /// succeeding — how a retry policy is exercised.
  int failConnectTimes = 0;
  BleFailure failConnectWith = BleFailure.timeout;

  /// Thrown by the next [subscribe] / [write] / [discoverServices], then
  /// cleared.
  BleFailure? failSubscribeWith;
  BleFailure? failWriteWith;
  BleFailure? failDiscoverWith;

  /// Delivered as an error on the next [scan] stream instead of the seeds,
  /// then cleared — how "the adapter was off when we started scanning" is
  /// scripted.
  BleFailure? failScanWith;

  bool pairSucceeds = true;
  int pairCalls = 0;

  /// What [isPaired] reports, independent of whether [pair] would succeed —
  /// the Windows pre-pair path needs "not bonded yet, but pairing works".
  /// Trailing underscore because `isPaired` is the method.
  bool? isPaired_ = true;

  bool discovered = false;
  bool disconnected = false;
  bool scanStopped = false;

  /// Every chunk written, in order. The three lists are parallel.
  final List<Uint8List> writes = <Uint8List>[];
  final List<String> writtenCharacteristics = <String>[];
  final List<bool> writeWithResponse = <bool>[];

  final StreamController<BleScanEntry> _scan =
      StreamController<BleScanEntry>.broadcast();
  final StreamController<bool> _connection = StreamController<bool>.broadcast();
  final Map<String, StreamController<Uint8List>> _notify =
      <String, StreamController<Uint8List>>{};

  StreamController<Uint8List> _controllerFor(String characteristic) =>
      _notify.putIfAbsent(
        characteristic,
        () => StreamController<Uint8List>.broadcast(),
      );

  void emitNotification(String characteristic, List<int> bytes) =>
      _controllerFor(characteristic).add(Uint8List.fromList(bytes));

  void emitDisconnect() => _connection.add(false);

  /// The interface promises stream failures are [BleAdapterException]s too,
  /// so the fake has to be able to script one.
  void emitNotificationError(String characteristic, BleFailure failure) =>
      _controllerFor(
        characteristic,
      ).addError(BleAdapterException(failure, 'scripted notification failure'));

  void emitConnectionError(BleFailure failure) => _connection.addError(
    BleAdapterException(failure, 'scripted connection failure'),
  );

  void emitAdvertisement(BleScanEntry entry) => _scan.add(entry);

  @override
  Future<BleAvailability> availability() async => availability_;

  @override
  Stream<BleScanEntry> scan({
    List<String> withServices = const <String>[],
    List<String> withNamePrefix = const <String>[],
  }) {
    final failure = failScanWith;
    if (failure != null) {
      failScanWith = null;
      scheduleMicrotask(() {
        if (_scan.isClosed) return;
        _scan.addError(BleAdapterException(failure, 'scripted scan failure'));
      });
      return _scan.stream;
    }
    if (!_seedsDelivered) {
      _seedsDelivered = true;
      scheduleMicrotask(() {
        for (final e in _seed) {
          if (_scan.isClosed) return;
          _scan.add(e);
        }
      });
    }
    return _scan.stream;
  }

  @override
  Future<void> stopScan() async => scanStopped = true;

  @override
  Future<void> connect(String deviceId, {Duration? timeout}) async {
    connectAttempts++;
    if (failConnectTimes > 0) {
      failConnectTimes--;
      throw BleAdapterException(failConnectWith, 'scripted connect failure');
    }
    _connection.add(true);
  }

  @override
  Future<void> disconnect(String deviceId) async {
    disconnected = true;
    _connection.add(false);
  }

  @override
  Stream<bool> connectionChanges(String deviceId) => _connection.stream;

  @override
  Future<void> discoverServices(String deviceId) async {
    final failure = failDiscoverWith;
    if (failure != null) {
      failDiscoverWith = null;
      throw BleAdapterException(failure, 'scripted discoverServices failure');
    }
    discovered = true;
  }

  @override
  Future<int> requestMtu(String deviceId, int expectedMtu) async {
    if (mtu < 0) {
      throw const BleAdapterException(
        BleFailure.unknown,
        'platform will not report an MTU',
      );
    }
    return mtu;
  }

  @override
  Future<void> subscribe(
    String deviceId, {
    required String service,
    required String characteristic,
  }) async {
    final failure = failSubscribeWith;
    if (failure != null) {
      failSubscribeWith = null;
      throw BleAdapterException(failure, 'scripted subscribe failure');
    }
  }

  @override
  Stream<Uint8List> notifications(
    String deviceId, {
    required String service,
    required String characteristic,
  }) => _controllerFor(characteristic).stream;

  @override
  Future<void> write(
    String deviceId, {
    required String service,
    required String characteristic,
    required Uint8List value,
    bool withResponse = true,
  }) async {
    final failure = failWriteWith;
    if (failure != null) {
      failWriteWith = null;
      throw BleAdapterException(failure, 'scripted write failure');
    }
    writes.add(Uint8List.fromList(value));
    writtenCharacteristics.add(characteristic);
    writeWithResponse.add(withResponse);
  }

  @override
  Future<void> pair(String deviceId) async {
    pairCalls++;
    if (!pairSucceeds) {
      throw const BleAdapterException(
        BleFailure.insufficientAuthentication,
        'scripted pair failure',
      );
    }
  }

  @override
  Future<bool?> isPaired(String deviceId) async => isPaired_;

  Future<void> dispose() async {
    await _scan.close();
    await _connection.close();
    for (final c in _notify.values) {
      await c.close();
    }
  }
}
