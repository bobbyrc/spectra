import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/features/connect/connect.dart';

const usb = DiscoveredDevice(
  name: 'ChameleonUltra',
  kind: TransportKind.usb,
  transportId: '/dev/cu.usbmodem1',
);
const ble = DiscoveredDevice(
  name: 'ChameleonUltra_1234',
  kind: TransportKind.ble,
  transportId: 'AA:BB:CC',
);
const otherUsb = DiscoveredDevice(
  name: 'ChameleonUltra',
  kind: TransportKind.usb,
  transportId: '/dev/cu.usbmodem2',
);
const bootloader = DiscoveredDevice(
  name: 'CU',
  kind: TransportKind.usb,
  transportId: '/dev/cu.usbmodem3',
  isBootloader: true,
);

KnownDevice knownBoth() => KnownDevice(
  identity: const DeviceIdentity('chip-1'),
  displayName: 'My Ultra',
  transports: const <KnownTransport>[
    KnownTransport(kind: TransportKind.usb, transportId: '/dev/cu.usbmodem1'),
    KnownTransport(kind: TransportKind.ble, transportId: 'AA:BB:CC'),
  ],
  lastSeen: DateTime.utc(2026, 9, 3),
);

void main() {
  test('an unknown device is one row per name and kind', () {
    final rows = mergeConnectRows(
      discovered: const <DiscoveredDevice>[usb, ble],
      known: const <KnownDevice>[],
    );
    expect(rows, hasLength(2));
    expect(rows.every((r) => r.isKnown), isFalse);
  });

  test('two unknown devices with the same name and kind share a row', () {
    final rows = mergeConnectRows(
      discovered: const <DiscoveredDevice>[usb, otherUsb],
      known: const <KnownDevice>[],
    );
    expect(rows, hasLength(1));
    expect(rows.single.devices, hasLength(2));
  });

  test('a known identity merges both transports into one row', () {
    final rows = mergeConnectRows(
      discovered: const <DiscoveredDevice>[usb, ble],
      known: <KnownDevice>[knownBoth()],
    );
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row.identity, const DeviceIdentity('chip-1'));
    expect(row.name, 'My Ultra', reason: 'the remembered name wins');
    expect(row.kinds, <TransportKind>[TransportKind.usb, TransportKind.ble]);
    expect(row.preferred.kind, TransportKind.usb);
    expect(row.lastSeen, DateTime.utc(2026, 9, 3));
  });

  test('a bootloader never merges with an application device', () {
    final rows = mergeConnectRows(
      discovered: const <DiscoveredDevice>[usb, bootloader],
      known: <KnownDevice>[knownBoth()],
    );
    expect(rows, hasLength(2));
    expect(rows.where((r) => r.isBootloader), hasLength(1));
  });

  test('known devices sort first, newest first', () {
    final rows = mergeConnectRows(
      discovered: const <DiscoveredDevice>[
        DiscoveredDevice(
          name: 'Unknown',
          kind: TransportKind.usb,
          transportId: 'x',
        ),
        usb,
      ],
      known: <KnownDevice>[knownBoth()],
    );
    expect(rows.first.isKnown, isTrue);
    expect(rows.last.name, 'Unknown');
  });

  test('the emulated device is an ordinary row', () {
    final rows = mergeConnectRows(
      discovered: const <DiscoveredDevice>[FakeScanner.emulatedUltra],
      known: const <KnownDevice>[],
    );
    expect(rows.single.name, 'Emulated Chameleon Ultra');
    expect(rows.single.kinds, <TransportKind>[TransportKind.fake]);
  });

  test('preselect sorts the matching row first and flags it', () {
    final rows = mergeConnectRows(
      discovered: const <DiscoveredDevice>[
        DiscoveredDevice(
          name: 'Another',
          kind: TransportKind.usb,
          transportId: 'y',
        ),
        usb,
      ],
      known: const <KnownDevice>[],
      preselect: usb,
    );
    expect(rows.first.isPreselected, isTrue);
    expect(rows.first.devices, contains(usb));
    expect(rows.last.isPreselected, isFalse);
  });

  test('two devices last seen in the same second sort deterministically', () {
    // Drift keeps `lastSeen` at second precision, so this tie is a real
    // one; the row key breaks it, so the list does not shuffle between
    // rebuilds.
    final at = DateTime.utc(2026, 9, 3);
    final known = <KnownDevice>[
      KnownDevice(
        identity: const DeviceIdentity('chip-2'),
        displayName: 'Second',
        transports: const <KnownTransport>[
          KnownTransport(
            kind: TransportKind.usb,
            transportId: '/dev/cu.usbmodem2',
          ),
        ],
        lastSeen: at,
      ),
      KnownDevice(
        identity: const DeviceIdentity('chip-1'),
        displayName: 'First',
        transports: const <KnownTransport>[
          KnownTransport(
            kind: TransportKind.usb,
            transportId: '/dev/cu.usbmodem1',
          ),
        ],
        lastSeen: at,
      ),
    ];

    final forwards = mergeConnectRows(
      discovered: const <DiscoveredDevice>[usb, otherUsb],
      known: known,
    );
    final backwards = mergeConnectRows(
      discovered: const <DiscoveredDevice>[otherUsb, usb],
      known: known.reversed.toList(),
    );

    expect(
      forwards.map((r) => r.key).toList(),
      backwards.map((r) => r.key).toList(),
    );
    expect(forwards.first.key, 'id:chip-1');
  });
}
