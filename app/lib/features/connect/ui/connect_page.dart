import 'dart:async';

import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../../core/discovery/discovery_provider.dart';
import '../../../core/errors/error_catalog.dart';
import '../../../core/errors/problem_view.dart';
import '../../../core/routing/routes.dart';
import '../../../core/session/sessions.dart';
import '../../../l10n/app_localizations.dart';
import '../state/connect_controller.dart';
import '../state/connect_row.dart';
import '../state/connect_rows_provider.dart';
import 'connect_row_tile.dart';
import 'manual_port_field.dart';

/// The full-screen connect route (spec 7.7 step 1). Layout only: the merge
/// is `connectRowsProvider` and the action is `connectControllerProvider`.
///
/// A [ConsumerStatefulWidget] rather than a [ConsumerWidget] purely to hold
/// [_ConnectPageState._attemptStarted] (fix round 2, finding 3):
/// `connectControllerProvider`'s `build()` is async, so its very first
/// frame already reports `AsyncLoading` before any row has ever been
/// tapped — gating on `connect.isLoading` alone would flash the
/// "Connecting…" indicator on every visit to this screen. Tracking "has an
/// attempt actually been started" locally, set the moment a tile is
/// tapped, distinguishes that first-frame loading from a real attempt
/// without touching `ConnectController` (out of scope this round).
class ConnectPage extends ConsumerStatefulWidget {
  const ConnectPage({super.key});

  @override
  ConsumerState<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends ConsumerState<ConnectPage> {
  bool _attemptStarted = false;

  void _connect(ConnectRow row) {
    setState(() => _attemptStarted = true);
    unawaited(
      ref.read(connectControllerProvider.notifier).connect(row.preferred),
    );
  }

  void _reconnectLast() {
    setState(() => _attemptStarted = true);
    unawaited(ref.read(connectControllerProvider.notifier).reconnectLast());
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<ConnectRow> rows = ref.watch(connectRowsProvider);
    final AsyncValue<DiscoveryState> discovery = ref.watch(discoveryProvider);
    final AsyncValue<void> connect = ref.watch(connectControllerProvider);
    final Object? problem = connect.error ?? discovery.value?.error;
    // Spec 7.6: the transport that failed explained itself as a value
    // (`GuidedTransport.guidance`, kept by `Sessions` on the failure path);
    // the words are the catalog's. Only ever shown beside the connect
    // failure it belongs to — a discovery error is a different story, and
    // a stale guidance from an earlier attempt must not be pinned to it.
    final TransportGuidance? guidance = ref.watch(
      sessionsProvider.select((s) => s.lastFailureGuidance),
    );
    // See the class doc: only a real, started attempt gates the spinner and
    // disables the rows, never the controller's own async-build loading.
    final bool connecting = _attemptStarted && connect.isLoading;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SpectraSpacing.lg),
          children: <Widget>[
            SpectraSectionHeader(title: l10n.connectTitle),
            Text(l10n.connectSubtitle),
            const SizedBox(height: SpectraSpacing.lg),
            if (connecting)
              SpectraProgressIndicator(label: l10n.connectConnecting),
            if (problem != null)
              ProblemView(
                error: problem,
                instructions: connect.hasError && guidance != null
                    ? ErrorCatalog(l10n).guidance(guidance)
                    : null,
                onAction: () {
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
                // Finding 3: null while an attempt is in flight, so every
                // row is disabled and a second tap cannot open a second
                // transport under the first attempt.
                onConnect: connecting ? null : () => _connect(row),
                onRecover: connecting
                    ? null
                    : () =>
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
              onPressed: connecting ? null : _reconnectLast,
            ),
            const SizedBox(height: SpectraSpacing.md),
            const ManualPortField(),
          ],
        ),
      ),
    );
  }
}
