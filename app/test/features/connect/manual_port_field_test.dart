import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra/features/connect/connect.dart';
import 'package:spectra/l10n/app_localizations.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

/// Hosts [ManualPortField] alone, under an overridable [hostPlatformProvider]
/// (finding 2's seam) — no router or session needed to exercise its own
/// desktop/mobile branch.
Widget _manualPortField(HostPlatform platform) => ProviderScope(
  overrides: <Override>[hostPlatformProvider.overrideWithValue(platform)],
  child: MaterialApp(
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      AppLocalizations.delegate,
      ...SpectraUiLocalizations.localizationsDelegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: SpectraTheme(
      colors: SpectraColors.light,
      brightness: Brightness.light,
      child: const Scaffold(
        body: Padding(padding: EdgeInsets.all(16), child: ManualPortField()),
      ),
    ),
  ),
);

Future<void> _expand(WidgetTester tester) async {
  await tester.tap(find.text('Add a serial port'));
  await tester.pump();
  await tester.pump(SpectraMotion.medium);
}

void main() {
  testWidgetsApp('is hidden on a mobile host platform', (tester) async {
    await tester.pumpWidget(_manualPortField(HostPlatform.android));
    await tester.pump();

    expect(find.text('Add a serial port'), findsNothing);
    expect(find.byType(SpectraTextField), findsNothing);
  });

  testWidgetsApp('is shown on a desktop host platform', (tester) async {
    await tester.pumpWidget(_manualPortField(HostPlatform.macos));
    await tester.pump();

    expect(find.text('Add a serial port'), findsOneWidget);
  });

  testWidgetsApp('typing a path and submitting adds it as a connect row', (
    tester,
  ) async {
    await pumpTestApp(tester);
    await tester.pump();
    expect(find.byType(ConnectRowTile), findsOneWidget);

    await _expand(tester);
    await tester.enterText(find.byType(SpectraTextField), '/dev/cu.usbmodem1');
    await tester.tap(find.text('Add'));
    await tester.pump();
    await tester.pump();

    expect(find.text('/dev/cu.usbmodem1'), findsOneWidget);
    expect(find.byType(ConnectRowTile), findsNWidgets(2));
  });

  testWidgetsApp('an empty or whitespace path adds nothing', (tester) async {
    await pumpTestApp(tester);
    await tester.pump();
    expect(find.byType(ConnectRowTile), findsOneWidget);

    await _expand(tester);
    await tester.enterText(find.byType(SpectraTextField), '   ');
    await tester.tap(find.text('Add'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(ConnectRowTile), findsOneWidget);
  });
}
