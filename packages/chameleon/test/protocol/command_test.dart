import 'dart:typed_data';

import 'package:chameleon/src/codec/frame.dart';
import 'package:chameleon/src/protocol/command.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:test/test.dart';

final class _Echo extends Command<int> {
  const _Echo();
  @override
  int get id => 1018;
  @override
  int decode(Uint8List data) => data[0];
}

void main() {
  test('ranges map ids to success statuses', () {
    expect(CommandRange.forId(1000).successStatus, 0x68);
    expect(CommandRange.forId(2000).successStatus, 0x00);
    expect(CommandRange.forId(3000).successStatus, 0x40);
    expect(CommandRange.forId(4000).successStatus, 0x68);
    expect(CommandRange.forId(5000).successStatus, 0x68);
    expect(CommandRange.forId(6000).successStatus, 0x00);
    expect(() => CommandRange.forId(7000), throwsArgumentError);
  });

  test('parseResponse decodes on success status', () {
    final f = Frame(command: 1018, status: 0x68, data: Uint8List.fromList([5]));
    expect(const _Echo().parseResponse(f), 5);
  });

  test('parseResponse throws a typed DeviceError on failure status', () {
    final f = Frame(command: 1018, status: 0x67);
    expect(
      () => const _Echo().parseResponse(f),
      throwsA(isA<InvalidCommand>()),
    );
  });

  test('parseResponse rejects a frame for another command', () {
    final f = Frame(command: 1000, status: 0x68, data: Uint8List.fromList([5]));
    expect(
      () => const _Echo().parseResponse(f),
      throwsA(isA<MalformedResponse>()),
    );
  });

  test(
    'defaults: 3s timeout, not idempotent, expects response, empty payload',
    () {
      const c = _Echo();
      expect(c.timeout, const Duration(seconds: 3));
      expect(c.idempotent, isFalse);
      expect(c.expectsResponse, isTrue);
      expect(c.encode(), isEmpty);
      expect(c.toFrame(), Frame(command: 1018));
    },
  );
}
