import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra/features/connect/connect.dart';
import 'package:spectra/l10n/app_localizations.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

/// Hosts one widget under just the app's localizations and the Spectra
/// theme, for a direct component test that needs no router or session
/// (ruling 10's `ConnectProblemView` case).
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

void main() {
  testWidgets('lists the emulated device and connects to it', (tester) async {
    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await tester.pump();

    expect(find.text('Connect a device'), findsOneWidget);
    expect(find.text('Emulated Chameleon Ultra'), findsOneWidget);

    await connectToEmulator(tester);
    expect(find.byType(SpectraAppShell), findsOneWidget);

    await settleApp(tester);
  });

  testWidgets(
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

      await settleApp(tester);
    },
  );

  testWidgets('an empty scan explains that the device sleeps', (tester) async {
    await pumpTestAppWithNoDevices(tester);
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('press a button on the device'), findsOneWidget);

    await settleApp(tester);
  });

  testWidgets('a bootloader row offers Recover', (tester) async {
    await pumpTestAppWithBootloader(tester);
    await tester.pump();
    await tester.pump();

    expect(find.text('Recover'), findsOneWidget);

    await settleApp(tester);
  });

  testWidgets('retrying a failed connect clears the problem card', (
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

    await settleApp(tester);
  });

  testWidgets('ConnectProblemView shows the given instructions directly', (
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
}
