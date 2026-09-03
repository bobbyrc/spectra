import 'package:chameleon/src/session/state_stream.dart';
import 'package:test/test.dart';

void main() {
  test('values emits current then changes', () async {
    final s = StateStream<int>(1);
    final got = <int>[];
    final sub = s.values.listen(got.add);
    await Future<void>.delayed(Duration.zero);
    s.set(2);
    s.set(3);
    await Future<void>.delayed(Duration.zero);
    expect(got, [1, 2, 3]);
    expect(s.value, 3);
    await sub.cancel();
    await s.close();
  });

  test('changes carries only later values', () async {
    final s = StateStream<int>(1);
    final got = <int>[];
    final sub = s.changes.listen(got.add);
    s.set(2);
    await Future<void>.delayed(Duration.zero);
    expect(got, [2]);
    await sub.cancel();
    await s.close();
  });

  test('set after close keeps the value but emits nothing', () async {
    final s = StateStream<int>(1);
    await s.close();
    s.set(2);
    expect(s.value, 2);
  });
}
