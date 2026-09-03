import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/session/active_device.dart';
import '../../../core/session/session_streams.dart';
import '../../../core/session/sessions.dart';
import '../../../l10n/app_localizations.dart';
import 'device_detail_card.dart';
import 'limited_dashboard.dart';

/// Spec 7.7 step 1: what the device is, how it is doing, and how to let go
/// of it. Layout only.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ConnectionState status = ref.watch(connectionStatusProvider);

    Future<void> disconnect() async {
      final identity = ref.read(activeDeviceProvider);
      ref.read(activeDeviceProvider.notifier).select(null);
      if (identity != null) {
        await ref.read(sessionsProvider.notifier).disconnect(identity);
      }
    }

    if (status is SessionLimited) {
      return LimitedDashboard(state: status, onDisconnect: disconnect);
    }

    final DeviceInfo? info = ref.watch(deviceInfoProvider).value;
    final BatteryInfo? battery = ref.watch(batteryProvider).value;
    final DeviceMode? mode = ref.watch(modeProvider).value;
    final int? slot = ref.watch(activeSlotProvider).value;

    return ListView(
      padding: const EdgeInsets.all(SpectraSpacing.lg),
      children: <Widget>[
        SpectraSectionHeader(title: l10n.dashboardTitle),
        Wrap(
          spacing: SpectraSpacing.sm,
          runSpacing: SpectraSpacing.sm,
          children: <Widget>[
            SpectraStatusChip.connection(
              status is SessionReady
                  ? SpectraConnectionStatus.connected
                  : SpectraConnectionStatus.connecting,
            ),
            if (battery != null)
              SpectraStatusChip.battery(percent: battery.percent),
          ],
        ),
        const SizedBox(height: SpectraSpacing.lg),
        if (info != null) DeviceDetailCard(info: info),
        const SizedBox(height: SpectraSpacing.md),
        SpectraCard(
          child: Column(
            children: <Widget>[
              SpectraListTile(
                title: switch (mode) {
                  DeviceMode.reader => l10n.dashboardModeReader,
                  DeviceMode.emulator => l10n.dashboardModeEmulator,
                  null => l10n.dashboardUnknown,
                },
                subtitle: l10n.dashboardActiveSlot,
                trailing: Text(
                  slot == null ? l10n.dashboardUnknown : '${slot + 1}',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SpectraSpacing.lg),
        SpectraButton(
          label: l10n.dashboardDisconnect,
          variant: SpectraButtonVariant.secondary,
          onPressed: disconnect,
        ),
      ],
    );
  }
}
