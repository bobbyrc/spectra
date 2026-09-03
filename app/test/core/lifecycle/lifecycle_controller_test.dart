import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/lifecycle/lifecycle_controller.dart';

void main() {
  test('pausing closes the session after the grace period', () {
    fakeAsync((async) {
      var closed = 0;
      final controller = LifecycleController(
        closeSessions: () async => closed++,
        reconnectLast: () async {},
        hasSession: () => true,
        grace: const Duration(seconds: 30),
      );

      controller.onPaused();
      async.elapse(const Duration(seconds: 29));
      expect(closed, 0);
      async.elapse(const Duration(seconds: 2));
      expect(closed, 1);
      controller.dispose();
    });
  });

  test('resuming inside the grace period keeps the session', () {
    fakeAsync((async) {
      var closed = 0;
      var reconnects = 0;
      final controller = LifecycleController(
        closeSessions: () async => closed++,
        reconnectLast: () async => reconnects++,
        hasSession: () => true,
      );

      controller.onPaused();
      async.elapse(const Duration(seconds: 5));
      controller.onResumed();
      async.elapse(const Duration(minutes: 1));

      expect(closed, 0);
      expect(reconnects, 0, reason: 'the session was never closed');
      controller.dispose();
    });
  });

  test('resuming after the grace period reconnects once', () {
    fakeAsync((async) {
      var reconnects = 0;
      final controller = LifecycleController(
        closeSessions: () async {},
        reconnectLast: () async => reconnects++,
        hasSession: () => false,
      );

      controller.onPaused();
      async.elapse(const Duration(seconds: 31));
      controller.onResumed();
      async.flushMicrotasks();
      controller.onResumed();
      async.flushMicrotasks();

      expect(reconnects, 1, reason: 'one silent attempt, not one per resume');
      controller.dispose();
    });
  });

  test('a failed reconnect is swallowed', () {
    fakeAsync((async) {
      final controller = LifecycleController(
        closeSessions: () async {},
        reconnectLast: () async => throw StateError('no device'),
        hasSession: () => false,
      );
      controller.onPaused();
      async.elapse(const Duration(seconds: 31));
      expect(controller.onResumed, returnsNormally);
      async.flushMicrotasks();
      controller.dispose();
    });
  });
}
