import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_serial_adapter.dart';

SerialTransport build(
  FakeSerialAdapter adapter, {
  HostPlatform platform = HostPlatform.macos,
  SerialControlLineMode mode = SerialControlLineMode.dtrOnly,
}) => SerialTransport(
  path: '/dev/cu.usbmodem1',
  adapter: adapter,
  platform: platform,
  controlLines: mode,
);

void main() {
  test(
    'open goes opening -> open at 115200 with the chosen control lines',
    () async {
      final adapter = FakeSerialAdapter();
      final t = build(adapter);
      final seen = <TransportState>[];
      t.state.listen(seen.add);
      await t.open();
      await Future<void>.delayed(Duration.zero);
      expect(seen.map((s) => s.runtimeType).toList(), [
        TransportOpening,
        TransportOpen,
      ]);
      expect(adapter.lastPath, '/dev/cu.usbmodem1');
      expect(adapter.lastBaudRate, 115200);
      expect(adapter.lastControlLines, SerialControlLineMode.dtrOnly);
      expect(t.kind, TransportKind.usb);
      await t.close();
    },
  );

  test(
    'the control-line mode is a constructor choice, not a constant',
    () async {
      final adapter = FakeSerialAdapter();
      final t = build(adapter, mode: SerialControlLineMode.hardwareFlowControl);
      await t.open();
      expect(
        adapter.lastControlLines,
        SerialControlLineMode.hardwareFlowControl,
      );
      await t.close();
    },
  );

  test('a whole frame fits in one write; the link needs no chunking', () {
    expect(build(FakeSerialAdapter()).maxWriteLength, 4105);
  });

  test('open is idempotent and opens the port once', () async {
    final adapter = FakeSerialAdapter();
    final t = build(adapter);
    await Future.wait(<Future<void>>[t.open(), t.open()]);
    await t.open();
    expect(adapter.openCalls, 1);
    await t.close();
  });

  test('bytes flow both ways', () async {
    final adapter = FakeSerialAdapter();
    final t = build(adapter);
    final got = <List<int>>[];
    t.incoming.listen((b) => got.add(b.toList()));
    await t.open();
    await t.write(Uint8List.fromList(const [0x11, 0xEF]));
    adapter.handle!.emit(const [0x11, 0xEF, 0x03]);
    await Future<void>.delayed(Duration.zero);
    expect(adapter.handle!.writes.single, [0x11, 0xEF]);
    expect(got, [
      [0x11, 0xEF, 0x03],
    ]);
    await t.close();
  });

  test('writes are serialised in call order', () async {
    final adapter = FakeSerialAdapter();
    final t = build(adapter);
    await t.open();
    final first = t.write(Uint8List.fromList(const [1]));
    final second = t.write(Uint8List.fromList(const [2]));
    await Future.wait(<Future<void>>[first, second]);
    expect(adapter.handle!.writes.map((w) => w.toList()).toList(), [
      [1],
      [2],
    ]);
    await t.close();
  });

  test('a failed write closes with linkLost and throws Disconnected', () async {
    final adapter = FakeSerialAdapter();
    final t = build(adapter);
    await t.open();
    adapter.handle!.failNextWrite(SerialFailure.disconnected);
    await expectLater(
      t.write(Uint8List.fromList(const [1])),
      throwsA(isA<Disconnected>()),
    );
    final state = t.currentState;
    expect(state, isA<TransportClosed>());
    expect((state as TransportClosed).cause, CloseCause.linkLost);
    await t.close();
  });

  test('a permission failure on Linux carries the group guidance', () async {
    final adapter = FakeSerialAdapter()
      ..failOpenWith = SerialFailure.permissionDenied;
    final t = build(adapter, platform: HostPlatform.linux);
    final seen = <TransportState>[];
    t.state.listen(seen.add);
    await expectLater(t.open(), throwsA(isA<PermissionDenied>()));
    await Future<void>.delayed(Duration.zero);
    expect(seen.any((s) => s is TransportPermissionDenied), isTrue);
    expect(t.guidance, TransportGuidance.linuxSerialGroup);
  });

  test(
    'a permission failure elsewhere carries the platform guidance',
    () async {
      for (final (platform, expected) in const [
        (HostPlatform.windows, TransportGuidance.windowsPortAccessDenied),
        (HostPlatform.macos, TransportGuidance.macosSerialEntitlement),
        (HostPlatform.android, TransportGuidance.androidUsbPermission),
      ]) {
        final adapter = FakeSerialAdapter()
          ..failOpenWith = SerialFailure.permissionDenied;
        final t = build(adapter, platform: platform);
        await expectLater(t.open(), throwsA(isA<PermissionDenied>()));
        expect(t.guidance, expected, reason: platform.name);
      }
    },
  );

  test(
    'a busy port is PortBusy, and on Linux points at ModemManager',
    () async {
      final adapter = FakeSerialAdapter()
        ..failOpenWith = SerialFailure.portBusy;
      final t = build(adapter, platform: HostPlatform.linux);
      await expectLater(t.open(), throwsA(isA<PortBusy>()));
      expect(t.guidance, TransportGuidance.linuxModemManager);
      expect(t.currentState, isA<TransportClosed>());
      expect((t.currentState as TransportClosed).error, isA<PortBusy>());
    },
  );

  test(
    'a busy port elsewhere says only that something else holds it',
    () async {
      final adapter = FakeSerialAdapter()
        ..failOpenWith = SerialFailure.portBusy;
      final t = build(adapter, platform: HostPlatform.windows);
      await expectLater(t.open(), throwsA(isA<PortBusy>()));
      expect(t.guidance, TransportGuidance.portBusyOther);
    },
  );

  test('a missing port is DeviceNotFound', () async {
    final adapter = FakeSerialAdapter()..failOpenWith = SerialFailure.notFound;
    final t = build(adapter);
    await expectLater(t.open(), throwsA(isA<DeviceNotFound>()));
    expect(t.guidance, TransportGuidance.portNotFound);
    expect((t.currentState as TransportClosed).error, isA<DeviceNotFound>());
  });

  test('an unknown open failure is Disconnected with no guidance', () async {
    for (final failure in const [
      SerialFailure.unknown,
      SerialFailure.disconnected,
    ]) {
      final adapter = FakeSerialAdapter()..failOpenWith = failure;
      final t = build(adapter);
      await expectLater(t.open(), throwsA(isA<Disconnected>()));
      expect(t.guidance, isNull, reason: failure.name);
      final state = t.currentState as TransportClosed;
      expect(state.cause, CloseCause.linkLost);
      expect(state.error, isA<Disconnected>());
    }
  });

  test('a pulled cable closes with linkLost', () async {
    final adapter = FakeSerialAdapter();
    final t = build(adapter);
    await t.open();
    adapter.handle!.dropLink();
    await Future<void>.delayed(Duration.zero);
    final state = t.currentState;
    expect(state, isA<TransportClosed>());
    expect((state as TransportClosed).cause, CloseCause.linkLost);
    expect(state.error, isA<Disconnected>());
  });

  test('the link is lost exactly once, on error then end of stream', () async {
    final adapter = FakeSerialAdapter();
    final t = build(adapter);
    final seen = <TransportState>[];
    await t.open();
    t.state.listen(seen.add);
    adapter.handle!.disconnect();
    await Future<void>.delayed(Duration.zero);
    expect(seen.length, 1);
    expect((seen.single as TransportClosed).cause, CloseCause.linkLost);
  });

  test('an end of stream with no error is still a lost link', () async {
    final adapter = FakeSerialAdapter();
    final t = build(adapter);
    await t.open();
    await adapter.handle!.close();
    await Future<void>.delayed(Duration.zero);
    final state = t.currentState as TransportClosed;
    expect(state.cause, CloseCause.linkLost);
    expect(state.error, isA<Disconnected>());
  });

  test('close is requested, idempotent, and refuses later writes', () async {
    final adapter = FakeSerialAdapter();
    final t = build(adapter);
    await t.open();
    await t.close();
    await t.close();
    expect((t.currentState as TransportClosed).cause, CloseCause.requested);
    expect(adapter.handle!.closed, isTrue);
    await expectLater(
      t.write(Uint8List.fromList(const [1])),
      throwsA(isA<Disconnected>()),
    );
  });

  test('a closed transport does not open again', () async {
    final adapter = FakeSerialAdapter();
    final t = build(adapter);
    await t.open();
    await t.close();
    await expectLater(t.open(), throwsA(isA<Disconnected>()));
    expect(adapter.openCalls, 1);
  });

  test('a close while opening hands the port back', () async {
    final adapter = FakeSerialAdapter();
    final t = build(adapter);
    // The expectation is attached before close() runs: the open fails inside
    // close(), and an error nothing is listening for is an unhandled one.
    final opening = expectLater(t.open(), throwsA(isA<Disconnected>()));
    await t.close();
    await opening;
    expect(adapter.handle!.closed, isTrue);
    expect((t.currentState as TransportClosed).cause, CloseCause.requested);
  });

  test('writing before open throws Disconnected', () async {
    final t = build(FakeSerialAdapter());
    await expectLater(
      t.write(Uint8List.fromList(const [1])),
      throwsA(isA<Disconnected>()),
    );
  });

  test('fromPath refuses a platform with no serial stack', () {
    expect(
      () => SerialTransport.fromPath('/dev/x', platform: HostPlatform.ios),
      throwsA(isA<DeviceNotFound>()),
    );
    expect(
      () => SerialTransport.fromPath('/dev/x', platform: HostPlatform.unknown),
      throwsA(isA<DeviceNotFound>()),
    );
    final t = SerialTransport.fromPath('/dev/x', platform: HostPlatform.macos);
    expect(t.path, '/dev/x');
    expect(t.controlLines, SerialControlLineMode.dtrOnly);
    expect(t.kind, TransportKind.usb);
  });

  group('serialGuidance', () {
    const table = <(SerialFailure, HostPlatform, TransportGuidance?)>[
      (
        SerialFailure.permissionDenied,
        HostPlatform.linux,
        TransportGuidance.linuxSerialGroup,
      ),
      (
        SerialFailure.permissionDenied,
        HostPlatform.windows,
        TransportGuidance.windowsPortAccessDenied,
      ),
      (
        SerialFailure.permissionDenied,
        HostPlatform.macos,
        TransportGuidance.macosSerialEntitlement,
      ),
      (
        SerialFailure.permissionDenied,
        HostPlatform.android,
        TransportGuidance.androidUsbPermission,
      ),
      (SerialFailure.permissionDenied, HostPlatform.ios, null),
      (SerialFailure.permissionDenied, HostPlatform.unknown, null),
      (
        SerialFailure.portBusy,
        HostPlatform.linux,
        TransportGuidance.linuxModemManager,
      ),
      (
        SerialFailure.portBusy,
        HostPlatform.windows,
        TransportGuidance.portBusyOther,
      ),
      (
        SerialFailure.portBusy,
        HostPlatform.macos,
        TransportGuidance.portBusyOther,
      ),
      (
        SerialFailure.portBusy,
        HostPlatform.android,
        TransportGuidance.portBusyOther,
      ),
      (
        SerialFailure.portBusy,
        HostPlatform.ios,
        TransportGuidance.portBusyOther,
      ),
      (
        SerialFailure.portBusy,
        HostPlatform.unknown,
        TransportGuidance.portBusyOther,
      ),
    ];

    for (final (failure, platform, expected) in table) {
      test('${failure.name} on ${platform.name} is $expected', () {
        expect(serialGuidance(failure, platform), expected);
      });
    }

    test('a missing port is portNotFound on every platform', () {
      for (final platform in HostPlatform.values) {
        expect(
          serialGuidance(SerialFailure.notFound, platform),
          TransportGuidance.portNotFound,
          reason: platform.name,
        );
      }
    });

    test('a dropped or unreadable link has no guidance anywhere', () {
      for (final failure in const [
        SerialFailure.disconnected,
        SerialFailure.unknown,
      ]) {
        for (final platform in HostPlatform.values) {
          expect(
            serialGuidance(failure, platform),
            isNull,
            reason: '${failure.name} on ${platform.name}',
          );
        }
      }
    });
  });
}
