import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

/// Every connection status plus a handful of battery levels.
Widget buildStatusPage(BuildContext context) {
  return ListView(
    padding: const EdgeInsets.all(SpectraSpacing.xl),
    children: <Widget>[
      const SpectraSectionHeader(title: 'Connection'),
      Wrap(
        spacing: SpectraSpacing.sm,
        runSpacing: SpectraSpacing.sm,
        children: <Widget>[
          for (final SpectraConnectionStatus status
              in SpectraConnectionStatus.values)
            SpectraStatusChip.connection(status),
        ],
      ),
      const SizedBox(height: SpectraSpacing.xl),
      const SpectraSectionHeader(title: 'Battery'),
      const Wrap(
        spacing: SpectraSpacing.sm,
        runSpacing: SpectraSpacing.sm,
        children: <Widget>[
          SpectraStatusChip.battery(percent: 87),
          SpectraStatusChip.battery(percent: 34, charging: true),
          SpectraStatusChip.battery(percent: 9),
        ],
      ),
    ],
  );
}
