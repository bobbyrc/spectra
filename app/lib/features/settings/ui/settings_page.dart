import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../l10n/app_localizations.dart';
import 'app_settings_section.dart';
import 'device_settings_section.dart';

/// Spec 7.7 step 7: device settings plus the app's own settings — theme,
/// emulator mode, feature flags and about (Task 12).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(SpectraSpacing.lg),
      children: <Widget>[
        SpectraSectionHeader(title: l10n.navSettings),
        const DeviceSettingsSection(),
        const SizedBox(height: SpectraSpacing.xl),
        const AppSettingsSection(),
      ],
    );
  }
}
