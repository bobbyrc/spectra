import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra/core/theme/theme_mode.dart';
import 'package:spectra/data/data.dart';

import '../../support/app_harness.dart';

void main() {
  testWidgetsApp('defaults to following the system', (tester) async {
    await pumpTestApp(tester);
    await pumpFrames(tester);
    expect(readProvider(tester, themeModeProvider), ThemeMode.system);
  });

  testWidgetsApp('a chosen theme is applied and persisted', (tester) async {
    await pumpTestApp(tester);
    await pumpFrames(tester);

    final Future<void> pending = readProvider(
      tester,
      themeModeControllerProvider.notifier,
    ).select(ThemeMode.dark);
    await pumpFrames(tester, count: 3);
    await pending;
    await pumpFrames(tester, count: 3);

    expect(readProvider(tester, themeModeProvider), ThemeMode.dark);
    expect(
      await readProvider(
        tester,
        preferencesRepositoryProvider,
      ).read(ThemeModeController.preferenceKey),
      'dark',
    );
  });
}
