import 'package:chameleon/src/codec/frame.dart';
import 'package:chameleon/src/transport/frame_log.dart';
import 'package:test/test.dart';

void main() {
  test('keeps only the newest entries', () {
    final log = FrameLog(capacity: 2);
    log.add(FrameDirection.sent, Frame(command: 1));
    log.add(FrameDirection.sent, Frame(command: 2));
    log.add(FrameDirection.received, Frame(command: 3));
    expect(log.entries.map((e) => e.frame.command), [2, 3]);
  });

  test('exports one line per frame', () {
    final log = FrameLog();
    log.add(FrameDirection.sent, Frame(command: 1000));
    expect(log.export(), contains('> cmd=1000'));
  });
}
