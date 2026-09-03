import 'dart:async';

import 'package:chameleon/src/dfu/response_queue.dart';
import 'package:test/test.dart';

void main() {
  const short = Duration(milliseconds: 20);

  test('buffers events that arrive before they are awaited', () async {
    final c = StreamController<int>();
    final q = ResponseQueue(c.stream);
    c.add(1);
    c.add(2);
    expect(await q.nextWithin(short), 1);
    expect(await q.nextWithin(short), 2);
    await q.cancel();
  });

  test(
    'a response arriving after a timeout does not satisfy the next request',
    () async {
      final c = StreamController<int>();
      final q = ResponseQueue(c.stream);
      await expectLater(q.nextWithin(short), throwsA(isA<TimeoutException>()));
      c.add(1); // the late reply to the request that timed out: discarded
      c.add(2); // the reply to the request that follows it
      expect(await q.nextWithin(short), 2);
      await q.cancel();
    },
  );

  test('a closed stream fails the waiter instead of hanging', () async {
    final c = StreamController<int>();
    final q = ResponseQueue(c.stream);
    final pending = q.nextWithin(const Duration(seconds: 30));
    await c.close();
    await expectLater(pending, throwsA(isA<StateError>()));
    await q.cancel();
  });
}
