import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/discovery/scanners.dart';
import 'package:spectra/core/session/reconnect.dart';

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

    test(
      'calling it N times on one Ref registers only one dispose hook',
      () async {
        final scanController = StreamController<List<DiscoveredDevice>>();
        addTearDown(scanController.close);
        final h = harness(ScriptedScanner(TransportKind.usb, scanController));

        // Mirrors the real usage this guards against: `reconnectLastDevice`
        // is called repeatedly (once per silent reconnect on resume) with
        // the same keepAlive `Ref`, from `lifecycleControllerProvider`.
        for (var i = 0; i < 5; i++) {
          unawaited(
            awaitDiscoveredDevice(
              h.ref,
              (d) => d.transportId == usbUltra.transportId,
              timeout: const Duration(seconds: 5),
            ),
          );
        }

        expect(disposeHookRegistrationsFor(h.ref), 1);
      },
    );
  });
}
