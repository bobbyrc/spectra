import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/discovery/scanners.dart';
import 'package:spectra/core/lifecycle/lifecycle_controller.dart';
import 'package:spectra/core/lifecycle/lifecycle_host.dart';

const usbUltra = DiscoveredDevice(
  name: 'ChameleonUltra',
  kind: TransportKind.usb,
  transportId: '/dev/cu.usbmodem1',
);

/// A scanner whose emissions the test drives directly, standing in for a
/// real transport's scanner — same shape as
/// `test/core/discovery/discovery_provider_test.dart`'s `ScriptedScanner`.
final class ScriptedScanner implements DeviceScanner {
  ScriptedScanner(this.kind, this.controller);
  @override
  final TransportKind kind;
  final StreamController<List<DiscoveredDevice>> controller;
  @override
  Stream<List<DiscoveredDevice>> scan() => controller.stream;
}

void main() {
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

  group('awaitDiscoveredDevice', () {
    // `awaitDiscoveredDevice` calls `Ref.listen` — production code (this
    // file's `reconnectLast`) only ever calls it well after
    // `lifecycleControllerProvider` has finished building (in response to
    // a later resume). A `Ref` captured from a throwaway provider's build
    // and used *after* `container.read` returns — never a `ref.listen`
    // issued from inside another provider's own build — mirrors that.
    ({ProviderContainer container, Ref ref}) harness(DeviceScanner scanner) {
      final container = ProviderContainer(
        overrides: [
          scannersProvider.overrideWithValue(<DeviceScanner>[scanner]),
        ],
      );
      addTearDown(container.dispose);
      late final Ref ref;
      container.read(Provider<void>((r) => ref = r));
      return (container: container, ref: ref);
    }

    test('resolves once discovery reports a matching device, even if the '
        'first emission does not have it', () async {
      final scanController = StreamController<List<DiscoveredDevice>>();
      addTearDown(scanController.close);
      final h = harness(ScriptedScanner(TransportKind.usb, scanController));

      final future = awaitDiscoveredDevice(
        h.ref,
        (d) => d.transportId == usbUltra.transportId,
      );
      DiscoveredDevice? result;
      var completed = false;
      unawaited(
        future.then((d) {
          result = d;
          completed = true;
        }),
      );

      // The first emission does not have the device.
      scanController.add(const <DiscoveredDevice>[]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);

      // A later emission does.
      scanController.add(const <DiscoveredDevice>[usbUltra]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(completed, isTrue);
      expect(result, usbUltra);
    });

    test('gives up with null once the timeout elapses', () async {
      final scanController = StreamController<List<DiscoveredDevice>>();
      addTearDown(scanController.close);
      final h = harness(ScriptedScanner(TransportKind.usb, scanController));

      final future = awaitDiscoveredDevice(
        h.ref,
        (d) => d.transportId == usbUltra.transportId,
        // A short real timeout — this test is about "the wait gives up",
        // not about the production 10s value (covered by
        // `reconnectDiscoveryTimeout`'s own default).
        timeout: const Duration(milliseconds: 20),
      );
      DiscoveredDevice? result;
      var completed = false;
      unawaited(
        future.then((d) {
          result = d;
          completed = true;
        }),
      );

      scanController.add(const <DiscoveredDevice>[]);
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 25));

      expect(completed, isTrue);
      expect(result, isNull);
    });
  });
}
