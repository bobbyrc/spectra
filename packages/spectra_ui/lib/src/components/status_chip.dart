import 'package:material_ui/material_ui.dart';

import '../../l10n/spectra_ui_localizations.dart';
import '../theme/spectra_theme.dart';
import '../tokens/color_scheme.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'connection_status.dart';

/// A small labelled state chip, in a connection variant and a battery variant.
class SpectraStatusChip extends StatelessWidget {
  const SpectraStatusChip.connection(
    SpectraConnectionStatus this.status, {
    super.key,
  }) : percent = null,
       charging = false;

  const SpectraStatusChip.battery({
    required int this.percent,
    this.charging = false,
    super.key,
  }) : status = null;

  final SpectraConnectionStatus? status;
  final int? percent;
  final bool charging;

  /// Below this the battery chip turns danger-coloured.
  static const int lowBatteryPercent = 15;

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    final SpectraUiLocalizations l10n = SpectraUiLocalizations.of(context);
    final SpectraColorScheme colors = theme.colors;

    final (String label, Color tint, IconData icon) = switch (status) {
      SpectraConnectionStatus.disconnected => (
        l10n.statusDisconnected,
        colors.textSecondary,
        Icons.link_off,
      ),
      SpectraConnectionStatus.connecting => (
        l10n.statusConnecting,
        colors.warning,
        Icons.sync,
      ),
      SpectraConnectionStatus.connected => (
        l10n.statusConnected,
        colors.connected,
        Icons.link,
      ),
      SpectraConnectionStatus.limited => (
        l10n.statusLimited,
        colors.warning,
        Icons.warning_amber,
      ),
      SpectraConnectionStatus.updating => (
        l10n.statusUpdating,
        colors.accent,
        Icons.system_update_alt,
      ),
      null => (
        charging ? l10n.batteryCharging(percent!) : l10n.batteryLevel(percent!),
        percent! <= lowBatteryPercent ? colors.danger : colors.success,
        charging ? Icons.battery_charging_full : Icons.battery_full,
      ),
    };

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: tint),
          borderRadius: BorderRadius.circular(SpectraSpacing.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpectraSpacing.md,
            vertical: SpectraSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 14, color: tint),
              const SizedBox(width: SpectraSpacing.xs),
              Text(label, style: SpectraTypography.label.copyWith(color: tint)),
            ],
          ),
        ),
      ),
    );
  }
}
