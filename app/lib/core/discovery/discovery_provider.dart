import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'scanners.dart';

part 'discovery_provider.g.dart';

/// What the connect screen knows about what is out there right now (spec
/// 4.2).
final class DiscoveryState {
  const DiscoveryState({this.devices = const <DiscoveredDevice>[], this.error});

  final List<DiscoveredDevice> devices;

  /// The last failure any scanner reported: a denied permission, an
  /// adapter that is off (spec 5.1). Kept as the raw error so the error
  /// catalog decides the wording.
  ///
  /// Sticky, not self-clearing: a scanner that reports an error is done —
  /// `mergedScan` (its own doc comment) ends that scanner's stream on
  /// error, so it cannot recover on its own, and a later data event from a
  /// *different*, still-running scanner is not evidence anything changed
  /// for the failed one. Silently clearing it on the next unrelated update
  /// would hide a dead scanner behind a list that still looks like it is
  /// working. The only way [error] moves is a new error overwriting it, or
  /// the whole provider being rebuilt — `ref.invalidate(discoveryProvider)`,
  /// which is what the connect screen's "Try again" does (spec 5.1) and
  /// gives every scanner, including the one that failed, a fresh `scan()`.
  final Object? error;
}

/// Runs every scanner at once via [mergedScan] (spec 4.2) and folds in the
/// [manualPortsProvider] entries (spec 5.2) as ordinary usb rows, unioned
/// with the scanned devices by [DiscoveredDevice] equality (kind +
/// transportId) — a manual port a scanner also finds is one row, not two.
/// A scanner's error, forwarded by [mergedScan] with [Stream.addError],
/// becomes [DiscoveryState.error] instead of ending the stream — the other
/// scanners' devices stay listed. See [DiscoveryState.error]'s doc for why
/// it is never cleared here.
@riverpod
Stream<DiscoveryState> discovery(Ref ref) {
  final scanners = ref.watch(scannersProvider);
  final manual = ref.watch(manualPortsProvider);

  final controller = StreamController<DiscoveryState>();
  var latest = const <DiscoveredDevice>[];
  Object? lastError;
  late StreamSubscription<List<DiscoveredDevice>> sub;

  void emit() {
    if (controller.isClosed) return;
    controller.add(
      DiscoveryState(devices: _union(latest, manual), error: lastError),
    );
  }

  controller.onListen = () {
    sub = mergedScan(scanners).listen(
      (devices) {
        // Not cleared here: see [DiscoveryState.error]'s doc comment. A
        // healthy scanner reporting fresh devices is not the failed
        // scanner recovering.
        latest = devices;
        emit();
      },
      onError: (Object error) {
        lastError = error;
        emit();
      },
      onDone: () {
        if (!controller.isClosed) unawaited(controller.close());
      },
    );
  };
  controller.onCancel = () => sub.cancel();
  ref.onDispose(() {
    if (!controller.isClosed) unawaited(controller.close());
  });
  return controller.stream;
}

/// The union of [scanned] and [manual], keyed by [DiscoveredDevice]
/// equality. A manual port a scanner also reports is one row: the
/// scanner's own entry wins (it may know more — a bootloader flag, a
/// friendlier name — than the placeholder [ManualPorts.add] created).
List<DiscoveredDevice> _union(
  List<DiscoveredDevice> scanned,
  List<DiscoveredDevice> manual,
) {
  final merged = <DiscoveredDevice, DiscoveredDevice>{};
  for (final d in manual) {
    merged[d] = d;
  }
  for (final d in scanned) {
    merged[d] = d;
  }
  return List<DiscoveredDevice>.unmodifiable(merged.values);
}

/// Ports the user typed in by hand on desktop, for when enumeration finds
/// nothing (spec 5.2). They join [discoveryProvider]'s list as ordinary usb
/// entries, so the rest of the app does not know the difference.
@Riverpod(keepAlive: true)
class ManualPorts extends _$ManualPorts {
  @override
  List<DiscoveredDevice> build() => const <DiscoveredDevice>[];

  void add(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return;
    final device = DiscoveredDevice(
      name: trimmed,
      kind: TransportKind.usb,
      transportId: trimmed,
    );
    if (state.contains(device)) return;
    state = <DiscoveredDevice>[...state, device];
  }

  void remove(String path) => state = <DiscoveredDevice>[
    for (final d in state)
      if (d.transportId != path) d,
  ];
}
