import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Tristate;

import 'package:chameleon/chameleon.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra/features/connect/connect.dart';
import 'package:spectra/features/tools/tools.dart';
import 'package:spectra/l10n/app_localizations.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

/// Hosts one widget under just the app's localizations and the Spectra
/// theme, for a direct component test that needs no router or session
/// (ruling 10's `ConnectProblemView` case, and finding 5's preselect case).
Widget _localizedApp(Widget child) {
  const SpectraColorScheme colors = SpectraColors.light;
  return MaterialApp(
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      AppLocalizations.delegate,
      ...SpectraUiLocalizations.localizationsDelegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: SpectraTheme(
      colors: colors,
      brightness: Brightness.light,
      child: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
}

/// A [Transport] that delegates every call to [_inner] except [open], which
/// waits on [_gate] first — for a connect attempt that a test controls the
/// end of (fix round 2, finding 3). `FakeDevice` itself has no
/// delay/completer seam on `open()`, only a fixed `latency` applied inside
/// an already-successful open, so this wraps it instead.
final class _GatedTransport implements Transport {
  _GatedTransport(this._inner, this._gate);

  final FakeDevice _inner;
  final Completer<void> _gate;

  @override
  Future<void> open() async {
    await _gate.future;
    await _inner.open();
  }

  @override
  Future<void> close() => _inner.close();

  @override
  TransportKind get kind => _inner.kind;

  @override
  Stream<Uint8List> get incoming => _inner.incoming;

  @override
  Future<void> write(Uint8List bytes) => _inner.write(bytes);

  @override
  int get maxWriteLength => _inner.maxWriteLength;

  @override
  Stream<TransportState> get state => _inner.state;

  @override
  TransportState get currentState => _inner.currentState;
}

void main() {
  testWidgetsApp('lists the emulated device and connects to it', (
    tester,
  ) async {
    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await tester.pump();

    expect(find.text('Connect a device'), findsOneWidget);
    expect(find.text('Emulated Chameleon Ultra'), findsOneWidget);

    await connectToEmulator(tester);
    expect(find.byType(SpectraAppShell), findsOneWidget);
  });

  testWidgetsApp(
    'a refused permission shows the message and the recovery action',
    (tester) async {
      await pumpTestApp(
        tester,
        transport: (_) => FakeDevice(openError: const PermissionDenied()),
      );
      await tester.pump();

      await tester.tap(find.text('Emulated Chameleon Ultra'));
      await awaitConnectAttempt(tester);

      expect(
        find.text('Spectra needs permission to reach the device.'),
        findsOneWidget,
      );
      expect(find.text('Open settings'), findsOneWidget);
    },
  );

  testWidgetsApp('an empty scan explains that the device sleeps', (
    tester,
  ) async {
    await pumpTestAppWithNoDevices(tester);
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('press a button on the device'), findsOneWidget);
  });

  testWidgetsApp('a bootloader row offers Recover', (tester) async {
    await pumpTestAppWithBootloader(tester);
    await tester.pump();
    await tester.pump();

    expect(find.text('Recover'), findsOneWidget);
  });

  testWidgetsApp('retrying a failed connect clears the problem card', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      transport: (_) => FakeDevice(openError: const PermissionDenied()),
    );
    await tester.pump();

    await tester.tap(find.text('Emulated Chameleon Ultra'));
    await awaitConnectAttempt(tester);
    expect(
      find.text('Spectra needs permission to reach the device.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Open settings'));
    await awaitConnectAttempt(tester);

    expect(
      find.text('Spectra needs permission to reach the device.'),
      findsNothing,
    );
  });

  testWidgetsApp(
    'recovering a bootloader device opens the update page for its transport '
    'id',
    (tester) async {
      await pumpTestAppWithBootloader(tester);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Recover'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(UpdatePage), findsOneWidget);
      final GoRouterState routerState = GoRouterState.of(
        tester.element(find.byType(UpdatePage)),
      );
      expect(
        routerState.uri.queryParameters['recover'],
        FakeScanner.emulatedBootloader.transportId,
      );
    },
  );

  testWidgetsApp(
    'a connect attempt in flight disables every row so a second tap opens '
    'no second transport',
    (tester) async {
      final gate = Completer<void>();
      var opens = 0;
      await pumpTestAppWithScanner(
        tester,
        const StaticScanner(<DiscoveredDevice>[
          FakeScanner.emulatedUltra,
          FakeScanner.emulatedLite,
        ]),
        transport: (_) {
          opens++;
          return _GatedTransport(FakeDevice(), gate);
        },
      );
      await tester.pump();

      await tester.tap(find.text(FakeScanner.emulatedUltra.name));
      await tester.pump();
      await tester.pump();

      // The first row's tile is now mid-`open()`, gated on `gate`: the
      // controller is loading, so every `ConnectRowTile.onTap` (finding 3)
      // is null. A tap that would otherwise start a second connect must be
      // a no-op.
      expect(find.text('Connecting…'), findsOneWidget);
      await tester.tap(find.text(FakeScanner.emulatedLite.name));
      await tester.pump();
      await tester.pump();
      expect(opens, 1);

      // Let the gated open() through and out to the shell — the same
      // longer pump [connectToEmulator] uses, since a successful connect's
      // handshake keeps loading in the background past a plain
      // `awaitConnectAttempt` (see that helper's doc comment).
      gate.complete();
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(SpectraAppShell), findsOneWidget);
      expect(opens, 1);
    },
  );

  testWidgetsApp('ConnectProblemView shows the given instructions directly', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        ConnectProblemView(
          error: const PermissionDenied(),
          instructions: 'Enable Bluetooth for Spectra in system settings.',
          onRetry: () {},
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Enable Bluetooth for Spectra in system settings.'),
      findsOneWidget,
    );
  });

  testWidgetsApp('a preselected row carries Semantics(selected: true)', (
    tester,
  ) async {
    const ConnectRow row = ConnectRow(
      key: 'name:Emulated Chameleon Ultra|fake|false',
      name: 'Emulated Chameleon Ultra',
      devices: <DiscoveredDevice>[FakeScanner.emulatedUltra],
      isBootloader: false,
      isPreselected: true,
    );
    await tester.pumpWidget(
      _localizedApp(
        ConnectRowTile(row: row, onConnect: () {}, onRecover: () {}),
      ),
    );
    await tester.pump();

    final SemanticsData data = tester
        .getSemantics(find.byType(ConnectRowTile))
        .getSemanticsData();
    expect(data.flagsCollection.isSelected, Tristate.isTrue);
  });
}
