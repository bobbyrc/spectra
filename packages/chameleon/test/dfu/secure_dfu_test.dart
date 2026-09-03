import 'dart:async';
import 'dart:typed_data';

import 'package:chameleon/src/dfu/dfu_opcodes.dart';
import 'package:chameleon/src/dfu/dfu_package.dart';
import 'package:chameleon/src/dfu/dfu_types.dart';
import 'package:chameleon/src/dfu/fake_bootloader.dart';
import 'package:chameleon/src/dfu/fake_dfu_channel.dart';
import 'package:chameleon/src/dfu/secure_dfu.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:chameleon/src/session/cancel_token.dart';
import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';

import 'proto_builder.dart';

DfuImage image(Uint8List bin, {int hw = 0}) => DfuImage(
  kind: DfuImageKind.application,
  bin: bin,
  dat: buildInitPacket(bin: bin, hwVersion: hw),
);

void main() {
  final bin = Uint8List.fromList(
    List.generate(10 * 1024 + 37, (i) => (i * 7) & 0xFF),
  );

  test('a transfer finishes under a virtual clock', () {
    // Regression: `ResponseQueue.cancel()` used to await the subscription's
    // own `cancel()`. `DfuChannel.responses` is a broadcast stream, and a
    // broadcast subscription's cancel future never completes when time is
    // virtual — which is the only kind of time a Flutter widget test has, so
    // `run()` hung forever after its last progress report there while every
    // test in this file (real time) passed.
    fakeAsync((async) {
      final ch = FakeDfuChannel(FakeBootloader(maxObjectSize: 4096));
      var finished = false;
      unawaited(SecureDfu(ch).run(image(bin)).then((_) => finished = true));
      async.elapse(const Duration(seconds: 5));
      expect(finished, isTrue, reason: 'SecureDfu.run never completed');
    });
  });

  test('flashes a firmware image in objects and 20-byte packets', () async {
    final bl = FakeBootloader(maxObjectSize: 4096);
    final ch = FakeDfuChannel(bl, maxDataWrite: 20);
    final progress = <DfuProgress>[];
    await SecureDfu(ch).run(image(bin), onProgress: progress.add);
    expect(bl.flashed, bin);
    expect(bl.init!.appSize, bin.length);
    expect(bl.completed, isTrue);
    expect(progress.last.stage, DfuStage.done);
    expect(progress.last.fraction, 1.0);
    final sent = progress.map((p) => p.bytesSent).toList();
    for (var i = 1; i < sent.length; i++) {
      expect(sent[i], greaterThanOrEqualTo(sent[i - 1]));
    }
    expect(bl.executedDataObjects, 3);
    expect(ch.isClosed, isFalse, reason: 'the orchestrator closes the channel');
  });

  test('resumes an interrupted transfer at the next object', () async {
    final img = image(bin);
    final bl = FakeBootloader(maxObjectSize: 4096)
      ..preload(
        commandObject: img.dat,
        data: Uint8List.sublistView(bin, 0, 4096),
      );
    await SecureDfu(FakeDfuChannel(bl)).run(img);
    expect(bl.flashed, bin);
    expect(bl.completed, isTrue);
    expect(bl.executedDataObjects, 2, reason: 'the first object is skipped');
  });

  test('resumes from a partly received object at the last boundary', () async {
    final img = image(bin);
    final bl = FakeBootloader(maxObjectSize: 4096)
      ..preload(
        commandObject: img.dat,
        data: Uint8List.sublistView(bin, 0, 5000),
      );
    await SecureDfu(FakeDfuChannel(bl)).run(img);
    expect(bl.flashed, bin, reason: 'no duplicated bytes');
    expect(bl.completed, isTrue);
    expect(bl.executedDataObjects, 2);
    expect(
      bl.bytesReceived,
      bin.length - 4096,
      reason: 'only the partial object and what follows it is resent',
    );
  });

  test('executes an object the device received but never executed', () async {
    final img = image(bin);
    final bl = FakeBootloader(maxObjectSize: 4096)
      ..preload(commandObject: img.dat, data: Uint8List(0))
      ..preloadUncommitted(Uint8List.sublistView(bin, 0, 4096));
    await SecureDfu(FakeDfuChannel(bl)).run(img);
    expect(bl.flashed, bin);
    expect(bl.completed, isTrue);
    expect(bl.executedDataObjects, 3, reason: 'the pending object is executed');
    expect(bl.bytesReceived, bin.length - 4096);
  });

  test(
    'executes an init packet the device received but never executed',
    () async {
      final img = image(bin);
      final bl = FakeBootloader(maxObjectSize: 4096)
        ..preloadUncommitted(img.dat, type: DfuOp.typeCommand);
      expect(bl.init, isNull);
      await SecureDfu(FakeDfuChannel(bl)).run(img);
      expect(bl.init, isNotNull, reason: 'the pending init packet is executed');
      expect(bl.flashed, bin);
      expect(
        bl.bytesReceived,
        bin.length,
        reason: 'the init packet is not resent',
      );
    },
  );

  test('discards a prefix of a different image and starts over', () async {
    final img = image(bin);
    final other = Uint8List.fromList(List.generate(4096, (i) => 0xA5));
    final bl = FakeBootloader(maxObjectSize: 4096)
      ..preload(commandObject: img.dat, data: other);
    final progress = <int>[];
    await SecureDfu(FakeDfuChannel(bl))
        .run(img, onProgress: (p) => progress.add(p.bytesSent));
    expect(bl.flashed, bin, reason: 'the foreign prefix is gone');
    expect(bl.completed, isTrue);
    expect(bl.executedDataObjects, 3);
    // The whole image is re-sent, so progress restarts from zero instead of
    // freezing at whatever the foreign prefix had reported.
    expect(progress.first, 0);
    expect(progress.where((n) => n == 0), hasLength(greaterThan(1)));
    expect(progress.last, bin.length);
  });

  test('bootloader rejecting the hardware version is a DfuError', () async {
    final bl = FakeBootloader(expectedHwVersion: 1);
    final ch = FakeDfuChannel(bl);
    await expectLater(
      SecureDfu(ch).run(image(bin, hw: 0)),
      throwsA(isA<DfuError>().having((e) => e.result, 'result', 0x08)),
    );
  });

  test('a corrupted CRC is retried once and then succeeds', () async {
    final bl = FakeBootloader()..corruptNextCrc();
    await SecureDfu(FakeDfuChannel(bl)).run(image(bin));
    expect(bl.flashed, bin);
    expect(bl.completed, isTrue);
  });

  test('a data object with a bad CRC is resent, not duplicated', () async {
    final bl = FakeBootloader(maxObjectSize: 4096)..corruptNextCrc(skip: 1);
    await SecureDfu(FakeDfuChannel(bl)).run(image(bin));
    expect(bl.flashed, bin);
    expect(bl.completed, isTrue);
    expect(bl.executedDataObjects, 3);
  });

  test('a persistent CRC mismatch is a DfuError', () async {
    final bl = FakeBootloader()..corruptNextCrc(times: 2);
    await expectLater(
      SecureDfu(FakeDfuChannel(bl)).run(image(bin)),
      throwsA(
        isA<DfuError>().having((e) => e.message, 'message', contains('CRC')),
      ),
    );
  });

  test('a failed create is reported with opcode and result', () async {
    final bl = FakeBootloader()..failNextCreate();
    await expectLater(
      SecureDfu(FakeDfuChannel(bl)).run(image(bin)),
      throwsA(
        isA<DfuError>()
            .having((e) => e.opcode, 'opcode', 0x01)
            .having((e) => e.result, 'result', 0x04),
      ),
    );
  });

  test('missing response times out as a DfuError', () async {
    final ch = FakeDfuChannel(FakeBootloader())..dropNextResponse();
    await expectLater(
      SecureDfu(
        ch,
        responseTimeout: const Duration(milliseconds: 50),
      ).run(image(bin)),
      throwsA(
        isA<DfuError>().having(
          (e) => e.message,
          'message',
          contains('timed out'),
        ),
      ),
    );
  });

  test('cancellation stops the transfer', () async {
    final bl = FakeBootloader();
    final ch = FakeDfuChannel(bl, latency: const Duration(milliseconds: 1));
    final token = CancelToken();
    final run = SecureDfu(ch).run(
      image(bin),
      cancel: token,
      onProgress: (p) {
        if (p.stage == DfuStage.firmware && p.bytesSent > 100) token.cancel();
      },
    );
    await expectLater(run, throwsA(isA<CommandCancelled>()));
    expect(bl.completed, isFalse);
    expect(bl.flashed.length, lessThan(bin.length));
    expect(ch.isClosed, isFalse);
  });

  test('a mismatched image hash is refused before any transfer', () async {
    final tampered = Uint8List.fromList(bin)..[0] ^= 1;
    final img = DfuImage(
      kind: DfuImageKind.application,
      bin: tampered,
      dat: buildInitPacket(bin: bin),
    );
    final bl = FakeBootloader();
    await expectLater(
      SecureDfu(FakeDfuChannel(bl)).run(img),
      throwsA(isA<DfuError>()),
    );
    expect(bl.init, isNull);
  });

  test('an empty firmware image is refused', () async {
    final empty = Uint8List(0);
    final img = DfuImage(
      kind: DfuImageKind.application,
      bin: empty,
      dat: buildInitPacket(bin: empty),
    );
    final bl = FakeBootloader();
    await expectLater(
      SecureDfu(FakeDfuChannel(bl)).run(img),
      throwsA(
        isA<DfuError>().having((e) => e.message, 'message', contains('empty')),
      ),
    );
    expect(bl.init, isNull);
  });

  test('the fake bootloader refuses a truncated request', () {
    final bl = FakeBootloader();
    expect(bl.handleControl(Uint8List.fromList([DfuOp.select])), [
      DfuOp.response,
      DfuOp.select,
      DfuOp.resultInvalidParameter,
    ]);
    expect(
      bl.handleControl(Uint8List.fromList([DfuOp.create, DfuOp.typeData, 0])),
      [DfuOp.response, DfuOp.create, DfuOp.resultInvalidParameter],
    );
    expect(bl.handleControl(Uint8List(0)), [
      DfuOp.response,
      0,
      DfuOp.resultInvalidParameter,
    ]);
  });

  test('an unexpected response opcode is a DfuError', () async {
    final ch = FakeDfuChannel(FakeBootloader(), garbleFirstResponse: true);
    await expectLater(
      SecureDfu(ch).run(image(bin)),
      throwsA(
        isA<DfuError>().having(
          (e) => e.message,
          'message',
          contains('unexpected'),
        ),
      ),
    );
  });
}
