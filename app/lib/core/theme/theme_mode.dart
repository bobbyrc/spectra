import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/data.dart';

part 'theme_mode.g.dart';

/// The app's theme choice (spec 7.7 step 7), persisted like every other app
/// preference. The same `PreferencesRepository`-backed keepAlive shape
/// `core/flags/feature_flags.dart` uses: an async controller, plus a plain
/// value provider so a widget above `Localizations` — `SpectraRoot` — can
/// read it synchronously.
@Riverpod(keepAlive: true)
class ThemeModeController extends _$ThemeModeController {
  static const String preferenceKey = 'app.themeMode';

  @override
  Future<ThemeMode> build() async {
    final String? stored = await ref
        .watch(preferencesRepositoryProvider)
        .read(preferenceKey);
    return ThemeMode.values
            .where((ThemeMode m) => m.name == stored)
            .firstOrNull ??
        ThemeMode.system;
  }

  Future<void> select(ThemeMode mode) async {
    await ref
        .read(preferencesRepositoryProvider)
        .write(preferenceKey, mode.name);
    if (!ref.mounted) return;
    state = AsyncData<ThemeMode>(mode);
  }
}

/// The theme as a plain value: the system theme until the stored one loads,
/// which is the safe direction (it is what the platform already shows).
@Riverpod(keepAlive: true)
ThemeMode themeMode(Ref ref) =>
    ref.watch(themeModeControllerProvider).value ?? ThemeMode.system;
