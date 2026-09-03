import 'dart:async';

import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/discovery/scanners.dart';
import '../../../core/flags/feature_flags.dart';
import '../../../core/theme/theme_mode.dart';
import '../../../data/data.dart' show KeyDictionary;
import '../../../l10n/app_localizations.dart';
import '../../dictionaries/dictionaries.dart';
import '../state/settings_labels.dart';
import 'option_sheet.dart';

/// The app's own pubspec version (`app/pubspec.yaml`'s `version:` field).
/// `package_info_plus` is not a dependency yet, so this literal is the only
/// source — keep it in step with the pubspec by hand until that changes.
const String _appVersion = '1.0.0+1';

/// Spec 7.7 step 7 (app theme), spec 7.5 (emulator mode) and spec 5.6 (the
/// BLE DFU flag, which stays off until the user reports hardware handoff H2
/// passed — this switch is how they turn it on afterwards). Spec 7.7 step 7
/// also names "export": the About card's key-list export copies every
/// dictionary as JSON to the clipboard.
///
/// The About card lists the licences of the packages Spectra ships.
/// Spectra's own LICENSE files are still the template TODO (`AGENTS.md`), so
/// no licence is claimed for the app itself here; add that row when a
/// licence is chosen.
class AppSettingsSection extends ConsumerWidget {
  const AppSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeMode theme = ref.watch(themeModeProvider);
    final bool emulator = ref.watch(emulatorModeProvider);
    final FeatureFlags flags = ref.watch(featureFlagsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SpectraSectionHeader(title: l10n.settingsAppTitle),
        SpectraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SpectraListTile(
                title: l10n.settingsTheme,
                subtitle: themeModeLabel(theme, l10n),
                onTap: () => unawaited(_pickTheme(context, ref, theme, l10n)),
              ),
              SpectraListTile(
                title: l10n.settingsEmulator,
                subtitle: l10n.settingsEmulatorSubtitle,
                trailing: Switch(
                  value: emulator,
                  onChanged: (bool v) => unawaited(
                    ref.read(emulatorModeProvider.notifier).setEnabled(v),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SpectraSpacing.lg),
        SpectraSectionHeader(title: l10n.settingsDeveloperTitle),
        SpectraCard(
          child: SpectraListTile(
            title: l10n.settingsFlagDfuBle,
            subtitle: l10n.settingsFlagDfuBleSubtitle,
            trailing: Switch(
              value: flags.dfuOverBleEnabled,
              onChanged: (bool v) => unawaited(
                ref
                    .read(featureFlagsControllerProvider.notifier)
                    .setDfuOverBleEnabled(v),
              ),
            ),
          ),
        ),
        const SizedBox(height: SpectraSpacing.lg),
        SpectraSectionHeader(title: l10n.settingsAboutTitle),
        SpectraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SpectraListTile(
                title: l10n.settingsLicences,
                leading: const Icon(Icons.article_outlined),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: l10n.appTitle,
                ),
              ),
              SpectraListTile(
                title: l10n.settingsExportKeys,
                leading: const Icon(Icons.ios_share_outlined),
                onTap: () => unawaited(_exportKeys(context, ref, l10n)),
              ),
              SpectraListTile(
                title: l10n.settingsVersion,
                subtitle: _appVersion,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickTheme(
    BuildContext context,
    WidgetRef ref,
    ThemeMode current,
    AppLocalizations l10n,
  ) async {
    final ThemeMode? mode = await showOptionSheet<ThemeMode>(
      context: context,
      title: l10n.settingsTheme,
      options: ThemeMode.values,
      labelOf: (ThemeMode m) => themeModeLabel(m, l10n),
      selected: current,
    );
    if (mode == null) return;
    await ref.read(themeModeControllerProvider.notifier).select(mode);
  }

  /// Copies every dictionary — the built-in one included, the same shape
  /// [exportDictionariesJson] always takes — as JSON (spec 7.7 step 7,
  /// Ruling M14). Awaits `.future` rather than reading `.value`: nothing
  /// else in this screen watches [dictionariesProvider], so with no active
  /// listener its value can still be unloaded the first time this is
  /// pressed.
  Future<void> _exportKeys(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final List<KeyDictionary> dictionaries = await ref.read(
      dictionariesProvider.future,
    );
    await Clipboard.setData(
      ClipboardData(text: exportDictionariesJson(dictionaries)),
    );
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.dictExported)));
  }
}
