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
      // Models the real transition: a session exists when the app is
      // paused, and the grace timer's `closeSessions` is what actually
      // drops it — `hasSession` has to track that to exercise the real
      // guard in `onResumed`, not just start out false.
      var hasSession = true;
      final controller = LifecycleController(
        closeSessions: () async {
          hasSession = false;
        },
        reconnectLast: () async => reconnects++,
        hasSession: () => hasSession,
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
      var hasSession = true;
      final controller = LifecycleController(
        closeSessions: () async {
          hasSession = false;
        },
        reconnectLast: () async => throw StateError('no device'),
        hasSession: () => hasSession,
      );
      controller.onPaused();
      async.elapse(const Duration(seconds: 31));
      expect(controller.onResumed, returnsNormally);
      async.flushMicrotasks();
      controller.dispose();
    });
  });

  test('pausing with no session is a no-op: no timer runs, and resuming never '
      'reconnects', () {
    fakeAsync((async) {
      var closed = 0;
      var reconnects = 0;
      final controller = LifecycleController(
        closeSessions: () async => closed++,
        reconnectLast: () async => reconnects++,
        hasSession: () => false,
      );

      controller.onPaused();
      async.elapse(const Duration(seconds: 31));
      expect(closed, 0, reason: 'no timer should have been armed');

      controller.onResumed();
      async.flushMicrotasks();

      expect(reconnects, 0, reason: 'nothing was ever closed');
      controller.dispose();
    });
  });

  test('a failing closeSessions during the grace timer does not throw '
      'unhandled, and still arms one reconnect attempt', () {
    fakeAsync((async) {
      var reconnects = 0;
      var hasSession = true;
      final controller = LifecycleController(
        closeSessions: () async {
          hasSession = false;
          throw StateError('disconnectAll blew up');
        },
        reconnectLast: () async => reconnects++,
        hasSession: () => hasSession,
      );

      controller.onPaused();
      // If the timer's callback let the exception escape unhandled,
      // fakeAsync would surface it as a test failure here.
      async.elapse(const Duration(seconds: 31));

      controller.onResumed();
      async.flushMicrotasks();

      expect(reconnects, 1);
      controller.dispose();
    });
  });

  test('a resume that declines to reconnect clears the flag, so a later short '
      'background dip does not fire a stale reconnect', () {
    fakeAsync((async) {
      var reconnects = 0;
      var hasSession = true;
      final controller = LifecycleController(
        closeSessions: () async {
          hasSession = false;
        },
        reconnectLast: () async => reconnects++,
        hasSession: () => hasSession,
      );

      controller.onPaused();
      async.elapse(const Duration(seconds: 31));

      // Something else reconnected before the resume was observed: the
      // guard declines, but must still clear the flag it consumed.
      hasSession = true;
      controller.onResumed();
      async.flushMicrotasks();
      expect(reconnects, 0);

      // A later, unrelated short background dip: well within the grace
      // period, so the timer never fires again.
      hasSession = false;
      controller.onPaused();
      async.elapse(const Duration(seconds: 2));
      controller.onResumed();
      async.flushMicrotasks();

      expect(
        reconnects,
        0,
        reason: 'the earlier cycle\'s flag must not survive to this one',
      );
      controller.dispose();
    });
  });
}
