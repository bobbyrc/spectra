import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/discovery/discovery_provider.dart';
import '../../../core/routing/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../state/connect_controller.dart';
import '../state/connect_row.dart';
import '../state/connect_rows_provider.dart';
import 'connect_problem_view.dart';
import 'connect_row_tile.dart';
import 'manual_port_field.dart';

/// The full-screen connect route (spec 7.7 step 1). Layout only: the merge
/// is `connectRowsProvider` and the action is `connectControllerProvider`.
class ConnectPage extends ConsumerWidget {
  const ConnectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<ConnectRow> rows = ref.watch(connectRowsProvider);
    final AsyncValue<DiscoveryState> discovery = ref.watch(discoveryProvider);
    final AsyncValue<void> connect = ref.watch(connectControllerProvider);
    final Object? problem = connect.error ?? discovery.value?.error;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SpectraSpacing.lg),
          children: <Widget>[
            SpectraSectionHeader(title: l10n.connectTitle),
            Text(l10n.connectSubtitle),
            const SizedBox(height: SpectraSpacing.lg),
            if (connect.isLoading)
              SpectraProgressIndicator(label: l10n.connectConnecting),
            if (problem != null)
              ConnectProblemView(
                error: problem,
                onRetry: () {
                  // Ruling 11: clear the failed attempt first, then give
                  // every scanner — including the one that failed — a
                  // fresh scan (`discoveryProvider`'s own doc comment).
                  ref.read(connectControllerProvider.notifier).reset();
                  ref.invalidate(discoveryProvider);
                },
              ),
            for (final ConnectRow row in rows)
              ConnectRowTile(
                row: row,
                onConnect: () => ref
                    .read(connectControllerProvider.notifier)
                    .connect(row.preferred),
                onRecover: () =>
                    GoRouter.of(context)
                        .go(AppRoutes.recover(row.preferred.transportId)),
              ),
            if (rows.isEmpty)
              SpectraCard(
                child: Text(
                  discovery.isLoading
                      ? l10n.connectScanning
                      : l10n.connectNothingFound,
                ),
              ),
            const SizedBox(height: SpectraSpacing.lg),
            SpectraButton(
              label: l10n.connectReconnectLast,
              variant: SpectraButtonVariant.secondary,
              onPressed: () =>
                  ref.read(connectControllerProvider.notifier).reconnectLast(),
            ),
            const SizedBox(height: SpectraSpacing.md),
            const ManualPortField(),
          ],
        ),
      ),
    );
  }
}
