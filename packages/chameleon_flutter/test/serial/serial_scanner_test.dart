import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_serial_adapter.dart';

const ultra = SerialPortDescriptor(
  path: '/dev/cu.usbmodem1',
  description: 'ChameleonUltra',
  vid: 0x6868,
  pid: 0x8686,
  manufacturer: 'Proxgrind',
  product: 'ChameleonUltra: hw_v1, fw_v2',
);

const bootloader = SerialPortDescriptor(
  path: '/dev/cu.usbmodem2',
  description: 'ChameleonUltra DFU',
  vid: 0x1915,
  pid: 0x521F,
  manufacturer: 'Nordic Semiconductor',
);

const bluetoothPort = SerialPortDescriptor(
  path: '/dev/cu.Bluetooth-Incoming-Port',
  description: 'Bluetooth-Incoming-Port',
);

void main() {
  test('the application VID/PID matches', () {
    expect(isChameleonPort(ultra), isTrue);
    expect(isBootloaderPort(ultra), isFalse);
  });

  test('the Proxgrind manufacturer alone matches, for a re-flashed VID', () {
    const p = SerialPortDescriptor(
      path: '/dev/cu.x',
      description: 'x',
      manufacturer: 'Proxgrind',
    );
    expect(isChameleonPort(p), isTrue);
  });

  test('the bootloader VID/PID is flagged, not ignored (spec 5.5)', () {
    expect(isChameleonPort(bootloader), isTrue);
    expect(isBootloaderPort(bootloader), isTrue);
  });

  test('an unrelated port is ignored', () {
    expect(isChameleonPort(bluetoothPort), isFalse);
  });

  test('enumerate returns one DiscoveredDevice per matching port', () async {
    final adapter = FakeSerialAdapter(
      ports: const [ultra, bluetoothPort, bootloader],
    );
    final scanner = SerialScanner(adapter: adapter);
    final found = await scanner.enumerate();
    expect(found.length, 2);
    expect(
      found.first,
      const DiscoveredDevice(
        name: 'ChameleonUltra: hw_v1, fw_v2',
        kind: TransportKind.usb,
        transportId: '/dev/cu.usbmodem1',
      ),
    );
    expect(found.first.isBootloader, isFalse);
    expect(found.last.isBootloader, isTrue);
    expect(found.last.transportId, '/dev/cu.usbmodem2');
    expect(scanner.kind, TransportKind.usb);
  });

  test('a port with no product string falls back to its description', () async {
    final adapter = FakeSerialAdapter(ports: const [bootloader]);
    final found = await SerialScanner(adapter: adapter).enumerate();
    expect(found.single.name, 'ChameleonUltra DFU');
  });

  test('scan polls and re-emits only when the set changes', () async {
    final adapter = FakeSerialAdapter(ports: const [ultra]);
    final scanner = SerialScanner(
      adapter: adapter,
      pollInterval: const Duration(milliseconds: 5),
    );
    final emissions = <List<DiscoveredDevice>>[];
    final sub = scanner.scan().listen(emissions.add);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      emissions.length,
      1,
      reason: 'an unchanged port list re-emits nothing',
    );
    adapter.ports = const [ultra, bootloader];
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(emissions.length, 2);
    expect(emissions.last.length, 2);
    await sub.cancel();
  });

  test(
    'an enumeration failure is an error on the stream, not a crash',
    () async {
      final adapter = _ThrowingAdapter();
      final scanner = SerialScanner(
        adapter: adapter,
        pollInterval: const Duration(milliseconds: 5),
      );
      await expectLater(scanner.scan().first, throwsA(isA<Exception>()));
    },
  );

  test(
    'scan does not re-emit when listPorts reorders the same devices',
    () async {
      final adapter = _ReorderingAdapter(const [ultra, bootloader]);
      final scanner = SerialScanner(
        adapter: adapter,
        pollInterval: const Duration(milliseconds: 5),
      );
      final emissions = <List<DiscoveredDevice>>[];
      final sub = scanner.scan().listen(emissions.add);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await sub.cancel();
      expect(
        emissions.length,
        1,
        reason:
            'a re-ordered but otherwise identical port list must not re-emit',
      );
    },
  );

  group('UsbSerialAdapter (Android)', () {
    const channel = MethodChannel('usb_serial');

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('enumerate refreshes the adapter before listing ports, so a device '
        'plugged in since the last refresh is found', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'listDevices') {
              return <Map<String, Object?>>[
                {
                  'deviceName': '/dev/bus/usb/001/002',
                  'vid': 0x6868,
                  'pid': 0x8686,
                  'productName': 'ChameleonUltra',
                  'manufacturerName': 'Proxgrind',
                  'deviceId': 1,
                  'serialNumber': null,
                  'interfaceCount': 1,
                },
              ];
            }
            return null;
          });

      // A fresh adapter's device cache starts empty (per the class doc):
      // if SerialScanner.enumerate() did not call refresh() first,
      // listPorts() would return nothing.
      final adapter = UsbSerialAdapter();
      final scanner = SerialScanner(adapter: adapter);
      final found = await scanner.enumerate();

      expect(found, hasLength(1));
      expect(found.single.transportId, '/dev/bus/usb/001/002');
    });
  });
}

final class _ThrowingAdapter extends FakeSerialAdapter {
  @override
  List<SerialPortDescriptor> listPorts() =>
      throw Exception('enumeration blew up');
}

/// Returns [_ports] on odd calls and its reverse on even calls, so a test
/// can prove the scanner's change detection tolerates reordering.
final class _ReorderingAdapter extends FakeSerialAdapter {
  _ReorderingAdapter(this._ports) : super(ports: _ports);

  final List<SerialPortDescriptor> _ports;
  int _calls = 0;

  @override
  List<SerialPortDescriptor> listPorts() {
    _calls++;
    return _calls.isOdd ? _ports : _ports.reversed.toList();
  }
}
