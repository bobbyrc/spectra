import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/discovery/discovery_provider.dart';
import '../../../core/session/active_device.dart';
import '../../../core/session/sessions.dart';
import '../../../l10n/app_localizations.dart';

/// Placeholder full-screen connect route. Lists whatever [discoveryProvider]
/// currently sees and connects on tap; Task 14 replaces this whole page
/// with the merged, badge-carrying version (spec 7.4).
class ConnectPage extends ConsumerWidget {
  const ConnectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<DiscoveryState> discovery = ref.watch(discoveryProvider);
    return ListView(
      padding: const EdgeInsets.all(SpectraSpacing.lg),
      children: <Widget>[
        SpectraSectionHeader(title: l10n.connectTitle),
        for (final DiscoveredDevice device
            in discovery.value?.devices ?? const <DiscoveredDevice>[])
          SpectraListTile(
            title: device.name,
            onTap: () async {
              final identity = await ref
                  .read(sessionsProvider.notifier)
                  .connect(device);
              ref.read(activeDeviceProvider.notifier).select(identity);
            },
          ),
      ],
    );
  }
}
