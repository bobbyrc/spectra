import 'dart:async';
import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';

/// GET_APP_VERSION: every firmware and the fake answer it, and it needs no
/// prior state, which makes it the right probe for a byte-level contract.
Uint8List _getAppVersionRequest() => Frame(command: 1000).encode();

/// The behaviours every [Transport] must have, whatever it is talking to
/// (spec 4.1, 5.8).
///
/// [make] must return a fresh, unopened transport on each call.
void transportContractTests(String description, Transport Function() make) {
  group('Transport contract: $description', () {
    test('open moves opening -> open and settles on TransportOpen', () async {
      final t = make();
      final seen = <TransportState>[];
      final sub = t.state.listen(seen.add);
      await t.open();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(seen.whereType<TransportOpening>(), isNotEmpty);
      expect(seen.last, isA<TransportOpen>());
      expect(t.currentState, isA<TransportOpen>());
      await sub.cancel();
      await t.close();
    });

    test('open is idempotent', () async {
      final t = make();
      await t.open();
      await t.open();
      expect(t.currentState, isA<TransportOpen>());
      await t.close();
    });

    test('writing before open throws Disconnected', () async {
      final t = make();
      await expectLater(
        t.write(Uint8List.fromList(const <int>[0x11])),
        throwsA(isA<Disconnected>()),
      );
    });

    test('a written request produces incoming bytes', () async {
      final t = make();
      final received = Completer<Uint8List>();
      final sub = t.incoming.listen((bytes) {
        if (!received.isCompleted) received.complete(bytes);
      });
      await t.open();
      await t.write(_getAppVersionRequest());
      // 2s: on some CDC-ACM stacks, asserting DTR resets the MCU, delaying
      // the first reply well past a typical command timeout (H1 watch item).
      final bytes = await received.future.timeout(const Duration(seconds: 2));
      expect(bytes, isNotEmpty);
      await sub.cancel();
      await t.close();
    });

    test(
      'incoming is a broadcast stream: two listeners both get bytes',
      () async {
        final t = make();
        final a = Completer<void>();
        final b = Completer<void>();
        final subA = t.incoming.listen((_) {
          if (!a.isCompleted) a.complete();
        });
        final subB = t.incoming.listen((_) {
          if (!b.isCompleted) b.complete();
        });
        await t.open();
        await t.write(_getAppVersionRequest());
        await Future.wait(<Future<void>>[a.future, b.future])
            .timeout(const Duration(seconds: 2));
        await subA.cancel();
        await subB.cancel();
        await t.close();
      },
    );

    test('close reports CloseCause.requested', () async {
      final t = make();
      await t.open();
      await t.close();
      final state = t.currentState;
      expect(state, isA<TransportClosed>());
      expect((state as TransportClosed).cause, CloseCause.requested);
    });

    test('close is idempotent', () async {
      final t = make();
      await t.open();
      await t.close();
      await t.close();
      expect(t.currentState, isA<TransportClosed>());
    });

    test('writing after close throws Disconnected', () async {
      final t = make();
      await t.open();
      await t.close();
      await expectLater(
        t.write(_getAppVersionRequest()),
        throwsA(isA<Disconnected>()),
      );
    });

    test('no TransportOpen is emitted after a requested close', () async {
      final t = make();
      await t.open();
      final after = <TransportState>[];
      final sub = t.state.listen(after.add);
      await t.close();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(after.whereType<TransportOpen>(), isEmpty);
      await sub.cancel();
    });

    test('a closed transport does not open again', () async {
      final t = make();
      await t.open();
      await t.close();
      await expectLater(t.open(), throwsA(isA<Disconnected>()));
    });

    test('maxWriteLength covers the largest protocol frame', () {
      final t = make();
      expect(t.maxWriteLength, greaterThanOrEqualTo(4105));
    });
  });
}
