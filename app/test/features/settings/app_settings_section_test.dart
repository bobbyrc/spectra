import 'dart:convert';

import 'package:chameleon/chameleon.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra/core/discovery/scanners.dart';
import 'package:spectra/core/flags/feature_flags.dart';
import 'package:spectra/core/theme/theme_mode.dart';
import 'package:spectra/features/dictionaries/dictionaries.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

Future<void> _openSettings(WidgetTester tester) async {
  useDesktopSurface(tester);
  await pumpTestApp(tester, transport: (_) => FakeDevice());
  await connectToEmulator(tester);
  await tester.tap(find.text('Settings').last);
  await pumpFrames(tester);
}

void main() {
  testWidgetsApp('picks a theme', (tester) async {
    await _openSettings(tester);

    await tester.tap(find.text('Theme'));
    await pumpFrames(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Dark'),
      ),
    );
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    expect(readProvider(tester, themeModeProvider), ThemeMode.dark);
  });

  testWidgetsApp('turns emulator mode off', (tester) async {
    await _openSettings(tester);

    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Emulated device'),
          matching: find.byType(SpectraListTile),
        ),
        matching: find.byType(Switch),
      ),
    );
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    expect(readProvider(tester, emulatorModeProvider), isFalse);
  });

  testWidgetsApp('flips the BLE DFU flag and says why it is off', (
    tester,
  ) async {
    await _openSettings(tester);
    expect(
      find.textContaining('recovered a device from an interrupted'),
      findsOneWidget,
    );
    expect(
      readProvider(tester, featureFlagsProvider).dfuOverBleEnabled,
      isFalse,
    );

    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Firmware update over Bluetooth'),
          matching: find.byType(SpectraListTile),
        ),
        matching: find.byType(Switch),
      ),
    );
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    expect(
      readProvider(tester, featureFlagsProvider).dfuOverBleEnabled,
      isTrue,
    );
  });

  testWidgetsApp('offers the licences', (tester) async {
    await _openSettings(tester);
    expect(find.text('Open-source licences'), findsOneWidget);
  });

  testWidgetsApp('exports every key list as JSON', (tester) async {
    final List<MethodCall> clipboard = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') clipboard.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await _openSettings(tester);
    // `dictionariesProvider` is autoDispose and nothing on this screen
    // watches it; keep it alive and pump so its first (Drift) snapshot has
    // landed before the tap, same reasoning as `keepAlive`'s own doc
    // comment.
    keepAlive(tester, dictionariesProvider);
    await pumpFrames(tester);
    await tester.ensureVisible(find.text('Export key lists'));
    await pumpFrames(tester);
    await tester.tap(find.text('Export key lists'));
    await pumpFrames(tester);

    expect(clipboard, hasLength(1));
    final Map<String, Object?> args =
        clipboard.single.arguments as Map<String, Object?>;
    final Map<String, Object?> exported =
        jsonDecode(args['text']! as String) as Map<String, Object?>;
    expect(exported['dictionaries'], isNotEmpty);
    expect(find.text('List copied to the clipboard.'), findsOneWidget);
  });
}
