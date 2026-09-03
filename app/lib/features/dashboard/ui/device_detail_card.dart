import 'package:chameleon/chameleon.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../l10n/app_localizations.dart';

/// Spec 1: the summary is what the device is; chip id, build string and BLE
/// address are expert detail, one tap away.
class DeviceDetailCard extends StatelessWidget {
  const DeviceDetailCard({required this.info, super.key});

  final DeviceInfo info;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String model = switch (info.model) {
      DeviceModel.ultra => l10n.dashboardModelUltra,
      DeviceModel.lite => l10n.dashboardModelLite,
    };
    return SpectraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SpectraListTile(title: model, subtitle: l10n.dashboardModel),
          SpectraListTile(
            title: info.version.label,
            subtitle: l10n.dashboardFirmware,
          ),
          SpectraDisclosure(
            summary: Text(l10n.commonDetails),
            detail: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SpectraListTile(
                  title: info.gitVersion ?? l10n.dashboardUnknown,
                  subtitle: l10n.dashboardGitVersion,
                ),
                SpectraListTile(
                  title: info.identity?.chipId ?? l10n.dashboardUnknown,
                  subtitle: l10n.dashboardChipId,
                ),
                SpectraListTile(
                  title: info.bleAddress ?? l10n.dashboardUnknown,
                  subtitle: l10n.dashboardBleAddress,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
