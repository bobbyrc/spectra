import 'dart:typed_data';

import 'package:chameleon/src/dfu/dfu_package.dart';
import 'package:chameleon/src/dfu/dfu_types.dart';
import 'package:chameleon/src/dfu/fake_bootloader.dart';
import 'package:chameleon/src/dfu/fake_dfu_channel.dart';
import 'package:chameleon/src/dfu/secure_dfu.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:chameleon/src/session/cancel_token.dart';
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
