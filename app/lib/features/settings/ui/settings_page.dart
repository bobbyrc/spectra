import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../l10n/app_localizations.dart';
import 'device_settings_section.dart';

/// Spec 7.7 step 7: device settings. Task 12 adds the rest of Settings
/// (dictionaries, app settings, export) alongside [DeviceSettingsSection].
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
      ],
    );
  }
}
