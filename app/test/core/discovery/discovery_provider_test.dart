import 'dart:async';
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/discovery/discovery_provider.dart';
import 'package:spectra/core/discovery/scanners.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/data/database/spectra_database.dart';

const usbUltra = DiscoveredDevice(
  name: 'ChameleonUltra',
  kind: TransportKind.usb,
  transportId: '/dev/cu.usbmodem1',
);

/// A scanner whose emissions the test drives, standing in for a real
/// transport's scanner without touching `chameleon_flutter`.
final class ScriptedScanner implements DeviceScanner {
  ScriptedScanner(this.kind, this.controller);
  @override
  final TransportKind kind;
  final StreamController<List<DiscoveredDevice>> controller;
  @override
  Stream<List<DiscoveredDevice>> scan() => controller.stream;
}

/// Errors once, then reports cleanly — models a real scanner (`BleScanner`,
/// `SerialScanner`) whose `scan()` stream ends on error (their own doc
/// comments) and only gets another chance from a fresh `scan()` call, which
/// is what `ref.invalidate(discoveryProvider)` (the connect screen's "Try
/// again") causes by rebuilding the provider from scratch.
final class FlipErrorScanner implements DeviceScanner {
  FlipErrorScanner(this.kind);
  @override
  final TransportKind kind;
  var _calls = 0;

  @override
  Stream<List<DiscoveredDevice>> scan() {
    _calls++;
    if (_calls == 1) {
      return Stream<List<DiscoveredDevice>>.error(const PermissionDenied());
    }
    return Stream.value(const <DiscoveredDevice>[]);
  }
}

/// A [BleAdapter] that is never called: `BleScanner` only stores the
/// adapter it is constructed with and reaches into it once `scan()` runs,
/// so a test that reads [scannersProvider]'s list without calling `scan()`
/// on anything in it can safely stub every method as "should not happen"
/// (Ruling 8, fix round 1: no `UniversalBleAdapter` in tests).
final class StubBleAdapter implements BleAdapter {
  static Never _shouldNotHappen() =>
      throw UnimplementedError('StubBleAdapter is never asked to actually run');

  @override
  Future<BleAvailability> availability() => _shouldNotHappen();
  @override
  Stream<BleScanEntry> scan({
    List<String> withServices = const <String>[],
    List<String> withNamePrefix = const <String>[],
  }) => _shouldNotHappen();
  @override
  Future<void> stopScan() => _shouldNotHappen();
  @override
  Future<void> connect(String deviceId, {Duration? timeout}) =>
      _shouldNotHappen();
  @override
  Future<void> disconnect(String deviceId) => _shouldNotHappen();
  @override
  Stream<bool> connectionChanges(String deviceId) => _shouldNotHappen();
  @override
  Future<void> discoverServices(String deviceId) => _shouldNotHappen();
  @override
  Future<int> requestMtu(String deviceId, int expectedMtu) =>
      _shouldNotHappen();
  @override
  Future<void> subscribe(
    String deviceId, {
    required String service,
    required String characteristic,
  }) => _shouldNotHappen();
  @override
  Stream<Uint8List> notifications(
    String deviceId, {
    required String service,
    required String characteristic,
  }) => _shouldNotHappen();
  @override
  Future<void> write(
    String deviceId, {
    required String service,
    required String characteristic,
    required Uint8List value,
    bool withResponse = true,
  }) => _shouldNotHappen();
  @override
  Future<void> pair(String deviceId) => _shouldNotHappen();
  @override
  Future<bool?> isPaired(String deviceId) => _shouldNotHappen();
}

/// A [SerialPortAdapter] that is never called, for the same reason as
/// [StubBleAdapter]: `SerialScanner` only reaches into it once `scan()`
/// runs.
final class StubSerialPortAdapter implements SerialPortAdapter {
  @override
  List<SerialPortDescriptor> listPorts() => throw UnimplementedError(
    'StubSerialPortAdapter is never asked to actually scan',
  );

  @override
  Future<SerialPortHandle> open(
    String path, {
    int baudRate = 115200,
    SerialControlLineMode controlLines = SerialControlLineMode.dtrOnly,
  }) => throw UnimplementedError(
    'StubSerialPortAdapter is never asked to actually open a port',
  );
}

/// `discoveryProvider` is `autoDispose` and `mergedScan` (spec 4.2, Ruling
/// 17) always emits an immediate first event — usually the empty list —
/// before any scanner has actually reported. Two consequences for tests:
///
/// * Reading `.future` with no active watcher lets Riverpod pause the
///   underlying subscription the instant the synchronous `read` call
///   returns, before the merge stream (necessarily async) ever gets to
///   emit — the read then hangs forever. A held `container.listen` keeps a
///   real watcher in place, which is how the connect screen watches it in
///   production too.
/// * `.future` itself resolves on the *first* emission, which can be that
///   placeholder empty list rather than the settled result. So tests watch
///   and read the provider's current value after letting the merge's
///   microtasks run, instead of awaiting `.future`.
ProviderSubscription<AsyncValue<DiscoveryState>> watchDiscovery(
  ProviderContainer container,
) => container.listen(discoveryProvider, (_, _) {});

Future<DiscoveryState> settledDiscovery(ProviderContainer container) async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return container.read(discoveryProvider).requireValue;
}

void main() {
  test(
    'emulator mode is on and puts the emulated device in the list',
    () async {
      final db = SpectraDatabase.memory();
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          // Ruling 8 (fix round 1): stub the adapter seams so
          // `defaultScanners` never constructs a real `UniversalBleAdapter`
          // or platform serial adapter just to build this list.
          scannerBleAdapterProvider.overrideWithValue(StubBleAdapter()),
          scannerSerialAdapterProvider.overrideWithValue(
            StubSerialPortAdapter(),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(emulatorModeProvider), isTrue);
      final scanners = container.read(scannersProvider);
      expect(scanners.whereType<FakeScanner>(), isNotEmpty);
      // The list is built from the stubs above, not real adapters: a
      // `BleScanner`/`SerialScanner` is present (construction alone proves
      // nothing touched the platform), but nobody here calls `scan()` on
      // them, so the stubs' "should not happen" methods stay uncalled.
      expect(scanners.whereType<BleScanner>(), isNotEmpty);
    },
  );

  test('turning emulator mode off removes the fake scanner', () async {
    final db = SpectraDatabase.memory();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        scannerBleAdapterProvider.overrideWithValue(StubBleAdapter()),
        scannerSerialAdapterProvider.overrideWithValue(StubSerialPortAdapter()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(emulatorModeProvider.notifier).setEnabled(false);
    expect(container.read(scannersProvider).whereType<FakeScanner>(), isEmpty);
  });

  test('discovery reports the emulated device', () async {
    final container = ProviderContainer(
      overrides: [
        scannersProvider.overrideWithValue(<DeviceScanner>[FakeScanner()]),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(watchDiscovery(container).close);

    final state = await settledDiscovery(container);
    expect(state.devices, contains(FakeScanner.emulatedUltra));
  });

  test('a manual port joins the discovered list', () async {
    final container = ProviderContainer(
      overrides: [
        scannersProvider.overrideWithValue(<DeviceScanner>[FakeScanner()]),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(watchDiscovery(container).close);
    await settledDiscovery(container);

    container.read(manualPortsProvider.notifier).add('/dev/cu.usbmodem9');
    final manual = container.read(manualPortsProvider).single;
    expect(manual.kind, TransportKind.usb);
    expect(manual.transportId, '/dev/cu.usbmodem9');

    final state = await settledDiscovery(container);
    expect(state.devices, contains(manual));
  });

  test(
    'a manual port whose path a scanner already reports yields one row',
    () async {
      final usb = StreamController<List<DiscoveredDevice>>();
      final container = ProviderContainer(
        overrides: [
          scannersProvider.overrideWithValue(<DeviceScanner>[
            ScriptedScanner(TransportKind.usb, usb),
          ]),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(usb.close);
      // Added before discoveryProvider is ever built/watched: adding a
      // manual port later would invalidate-and-rebuild it, and a rebuild
      // re-subscribes to every scanner's `scan()` stream — `usb` here is a
      // single-subscription StreamController standing in for a real
      // scanner, which (like the real ones) supports exactly one listen.
      container.read(manualPortsProvider.notifier).add(usbUltra.transportId);
      addTearDown(watchDiscovery(container).close);
      usb.add(const <DiscoveredDevice>[usbUltra]);

      final state = await settledDiscovery(container);
      expect(
        state.devices.where((d) => d.transportId == usbUltra.transportId),
        hasLength(1),
      );
      expect(state.devices, contains(usbUltra));
    },
  );

  test(
    'one scanner failing leaves the other scanner s devices listed',
    () async {
      final ble = StreamController<List<DiscoveredDevice>>();
      final container = ProviderContainer(
        overrides: [
          scannersProvider.overrideWithValue(<DeviceScanner>[
            FakeScanner(),
            ScriptedScanner(TransportKind.ble, ble),
          ]),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(ble.close);

      final states = <DiscoveryState>[];
      final sub = container.listen(discoveryProvider, (previous, next) {
        final value = next.value;
        if (value != null) states.add(value);
      }, fireImmediately: true);
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);

      ble.addError(const PermissionDenied());
      await Future<void>.delayed(Duration.zero);

      expect(states.last.error, isA<PermissionDenied>());
      expect(states.last.devices, contains(FakeScanner.emulatedUltra));
    },
  );

  test('a later report from the surviving scanner does not clear a sticky '
      'error', () async {
    final ble = StreamController<List<DiscoveredDevice>>();
    final usb = StreamController<List<DiscoveredDevice>>();
    final container = ProviderContainer(
      overrides: [
        scannersProvider.overrideWithValue(<DeviceScanner>[
          ScriptedScanner(TransportKind.ble, ble),
          ScriptedScanner(TransportKind.usb, usb),
        ]),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(ble.close);
    addTearDown(usb.close);

    final states = <DiscoveryState>[];
    final sub = container.listen(discoveryProvider, (previous, next) {
      final value = next.value;
      if (value != null) states.add(value);
    }, fireImmediately: true);
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);

    // A real scanner's stream ends on error (BleScanner/SerialScanner's
    // own doc comments); close it here to model that faithfully.
    ble.addError(const PermissionDenied());
    await ble.close();
    await Future<void>.delayed(Duration.zero);
    expect(states.last.error, isA<PermissionDenied>());

    // The usb scanner is still running and reports something new — this
    // is not the ble scanner recovering.
    usb.add(const <DiscoveredDevice>[usbUltra]);
    await Future<void>.delayed(Duration.zero);

    expect(states.last.error, isA<PermissionDenied>());
    expect(states.last.devices, contains(usbUltra));
  });

  test('invalidating the provider clears a sticky error and rescans', () async {
    final flip = FlipErrorScanner(TransportKind.ble);
    final container = ProviderContainer(
      overrides: [
        scannersProvider.overrideWithValue(<DeviceScanner>[flip]),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(watchDiscovery(container).close);

    final first = await settledDiscovery(container);
    expect(first.error, isA<PermissionDenied>());

    container.invalidate(discoveryProvider);
    final second = await settledDiscovery(container);
    expect(second.error, isNull);
  });
}
