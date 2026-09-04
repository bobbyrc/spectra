import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter/widgets.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/lifecycle/lifecycle_controller.dart';
import 'package:spectra/core/lifecycle/lifecycle_host.dart';
import 'package:spectra/core/platform/host_platform_provider.dart';
import 'package:spectra/core/session/session_streams.dart';

/// Pins [connectionStatusProvider] to a fixed state, so a test can say "a
/// firmware update is in flight" without a session.
final class _FixedStatus extends ConnectionStatus {
  _FixedStatus(this._state);
  final ConnectionState _state;
  @override
  ConnectionState build() => _state;
}

void main() {
  group('canGraceCloseNow', () {
    /// A controller whose `canGraceClose` is the real production rule, run
    /// against [platform] and [status]. `grace` is zero, so "armed" is
    /// observable one event-loop turn later.
    ({LifecycleController controller, List<int> closes}) controllerFor(
      HostPlatform platform,
      ConnectionState status,
    ) {
      final container = ProviderContainer(
        overrides: [
          hostPlatformProvider.overrideWithValue(platform),
          connectionStatusProvider.overrideWith(() => _FixedStatus(status)),
        ],
      );
      addTearDown(container.dispose);
      late final Ref ref;
      container.read(Provider<void>((r) => ref = r));

      final closes = <int>[];
      final controller = LifecycleController(
        closeSessions: () async => closes.add(1),
        reconnectLast: () async {},
        hasSession: () => true,
        canGraceClose: () => canGraceCloseNow(ref),
        grace: Duration.zero,
      );
      addTearDown(controller.dispose);
      return (controller: controller, closes: closes);
    }

    test('a desktop pause arms no grace close', () async {
      final h = controllerFor(HostPlatform.macos, const SessionConnecting());
      h.controller.onPaused();
      await Future<void>.delayed(Duration.zero);
      expect(h.closes, isEmpty);
    });

    test('a mobile pause arms the grace close', () async {
      final h = controllerFor(HostPlatform.android, const SessionConnecting());
      h.controller.onPaused();
      await Future<void>.delayed(Duration.zero);
      expect(h.closes, hasLength(1));
    });

    test('a mobile pause mid-update arms no grace close', () async {
      final h = controllerFor(HostPlatform.ios, const SessionUpdating());
      h.controller.onPaused();
      await Future<void>.delayed(Duration.zero);
      expect(h.closes, isEmpty);
    });
  });

  group('AppLifecycleHost', () {
    testWidgets(
      'forwards paused/resumed to the controller, not inactive/hidden, and '
      'removes the observer on dispose',
      (tester) async {
        var closes = 0;
        var reconnects = 0;
        var hasSession = true;
        final controller = LifecycleController(
          closeSessions: () async {
            closes++;
            hasSession = false;
          },
          reconnectLast: () async => reconnects++,
          hasSession: () => hasSession,
          // Zero so a single `pump` is enough to observe the timer firing —
          // this test is about which lifecycle states reach the
          // controller, not about the grace period's length (covered by
          // `lifecycle_controller_test.dart`).
          grace: Duration.zero,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              lifecycleControllerProvider.overrideWithValue(controller),
            ],
            child: const AppLifecycleHost(child: SizedBox()),
          ),
        );

        // inactive and hidden are not forwarded to the controller at all.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump(const Duration(seconds: 1));
        expect(closes, 0);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        await tester.pump(const Duration(seconds: 1));
        expect(closes, 0);

        // paused starts the grace timer (zero here, so an explicit
        // `pump(Duration.zero)` — which actually advances the fake clock,
        // unlike a bare `pump()` — is enough for it to fire).
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump(Duration.zero);
        expect(closes, 1);

        // resumed calls onResumed, which attempts the one silent reconnect
        // now that the session is gone.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump(Duration.zero);
        expect(reconnects, 1);

        // Disposing the host removes its WidgetsBindingObserver: a later
        // lifecycle event reaches nobody, so the counts stay put.
        await tester.pumpWidget(const SizedBox());
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump(const Duration(seconds: 1));
        expect(closes, 1);
      },
    );
  });
}
