// A failed [DeviceSession.open] leaves nobody listening on several of the
// session's [StateStream]s (nothing ever subscribed to `.changes`, only
// `.value` was read). `DeviceSession.close()` must still complete under a
// virtual clock — `flutter_test`'s widget tests run inside one — even though
// nothing is left to pump a `Timer` those streams might be waiting on.
import 'dart:async';

import 'package:chameleon/src/fake/fake_device.dart';
import 'package:chameleon/src/protocol/errors.dart';
import 'package:chameleon/src/session/device_session.dart';
import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';

void main() {
  test('close() completes under FakeAsync after a failed open()', () {
    fakeAsync((async) {
      final device = FakeDevice(openError: const PermissionDenied());
      final session = DeviceSession(device);

      var openThrew = false;
      unawaited(
        session.open().catchError((Object _) {
          openThrew = true;
        }),
      );
      async.elapse(const Duration(seconds: 1));
      expect(openThrew, isTrue);

      var closed = false;
      unawaited(session.close().then((_) => closed = true));
      async.elapse(const Duration(seconds: 1));

      expect(
        closed,
        isTrue,
        reason: 'DeviceSession.close() did not complete under FakeAsync',
      );
    });
  });
}
