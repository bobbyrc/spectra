import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/discovery/discovery_provider.dart';
import '../../../core/session/sessions.dart';
import '../../../data/data.dart';
import 'connect_row.dart';

part 'connect_rows_provider.g.dart';

@riverpod
Stream<List<KnownDevice>> knownDevices(Ref ref) =>
    ref.watch(knownDevicesRepositoryProvider).watchAll();

/// What the connect screen draws: discovery plus the manual ports, merged
/// against what the app remembers (spec 4.2), with the device whose link
/// just dropped unexpectedly (spec 7.4) preselected. This never reconnects
/// on its own — it only flags the row for the UI to highlight.
@riverpod
List<ConnectRow> connectRows(Ref ref) => mergeConnectRows(
  discovered: <DiscoveredDevice>[
    ...?ref.watch(discoveryProvider).value?.devices,
    ...ref.watch(manualPortsProvider),
  ],
  known: ref.watch(knownDevicesProvider).value ?? const <KnownDevice>[],
  preselect: ref.watch(sessionsProvider.select((s) => s.lastDisconnected)),
);
