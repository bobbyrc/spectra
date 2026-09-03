import 'dart:typed_data';

import 'package:chameleon_flutter/src/serial/serial_adapter.dart';
import 'package:chameleon_flutter/src/serial/serial_failure.dart';
import 'package:chameleon_flutter/src/serial/serial_ids.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_serial_adapter.dart';

const _ultra = SerialPortDescriptor(
  path: '/dev/tty.usbmodem1101',
  description: 'ChameleonUltra',
  vid: ChameleonUsbIds.applicationVid,
  pid: ChameleonUsbIds.applicationPid,
);

void main() {
  test('lists the scripted ports', () {
    expect(FakeSerialAdapter(ports: const [_ultra]).listPorts(), [_ultra]);
  });

  test('open records the path, baud rate and control-line mode', () async {
    final adapter = FakeSerialAdapter();

    await adapter.open(
      '/dev/tty.usbmodem1101',
      controlLines: SerialControlLineMode.hardwareFlowControl,
    );

    expect(adapter.openCalls, 1);
    expect(adapter.lastPath, '/dev/tty.usbmodem1101');
    expect(adapter.lastBaudRate, ChameleonUsbIds.baudRate);
    expect(adapter.lastControlLines, SerialControlLineMode.hardwareFlowControl);
    expect(adapter.handle, isNotNull);
  });

  test('a scripted open failure throws a typed exception', () async {
    final adapter = FakeSerialAdapter()..failOpenWith = SerialFailure.portBusy;

    await expectLater(
      adapter.open('/dev/ttyACM0'),
      throwsA(
        isA<SerialAdapterException>().having(
          (e) => e.failure,
          'failure',
          SerialFailure.portBusy,
        ),
      ),
    );
  });

  test('the handle captures writes and replays injected bytes', () async {
    final adapter = FakeSerialAdapter();
    final handle = await adapter.open('/dev/ttyACM0') as FakeSerialHandle;
    final seen = <Uint8List>[];
    handle.incoming.listen(seen.add);

    await handle.write(Uint8List.fromList([0x11, 0xEF]));
    handle.emit(const [0x11, 0x00]);
    await Future<void>.delayed(Duration.zero);

    expect(handle.writes.single, [0x11, 0xEF]);
    expect(seen.single, [0x11, 0x00]);
  });

  test('failNextWrite fails exactly one write', () async {
    final adapter = FakeSerialAdapter();
    final handle = await adapter.open('/dev/ttyACM0') as FakeSerialHandle;
    handle.failNextWrite(SerialFailure.disconnected);

    await expectLater(
      handle.write(Uint8List.fromList([1])),
      throwsA(isA<SerialAdapterException>()),
    );
    await handle.write(Uint8List.fromList([2]));

    expect(handle.writes.single, [2]);
  });

  test('dropLink errors the stream once and disconnect then ends it', () async {
    final adapter = FakeSerialAdapter();
    final handle = await adapter.open('/dev/ttyACM0') as FakeSerialHandle;
    final errors = <Object>[];
    var done = false;
    handle.incoming.listen(
      (_) {},
      onError: errors.add,
      onDone: () => done = true,
    );

    handle.dropLink();
    await Future<void>.delayed(Duration.zero);
    expect(errors.single, isA<SerialAdapterException>());
    expect(done, isFalse);

    // At most one error, ever: the second drop is swallowed.
    handle.disconnect();
    await Future<void>.delayed(Duration.zero);
    expect(errors, hasLength(1));
    expect(done, isTrue);
  });

  test(
    'write after close reports a disconnect, and close is idempotent',
    () async {
      final adapter = FakeSerialAdapter();
      final handle = await adapter.open('/dev/ttyACM0') as FakeSerialHandle;

      await handle.close();
      await handle.close();

      expect(handle.closed, isTrue);
      await expectLater(
        handle.write(Uint8List.fromList([1])),
        throwsA(
          isA<SerialAdapterException>().having(
            (e) => e.failure,
            'failure',
            SerialFailure.disconnected,
          ),
        ),
      );
    },
  );
}
