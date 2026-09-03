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
  /// catalog decides the wording. `null` once every scanner has reported
  /// cleanly again.
  final Object? error;
}

/// Runs every scanner at once via [mergedScan] (spec 4.2) and folds in the
/// [manualPortsProvider] entries (spec 5.2) as ordinary usb rows. A
/// scanner's error, forwarded by [mergedScan] with [Stream.addError],
/// becomes [DiscoveryState.error] instead of ending the stream — the other
/// scanners' devices stay listed.
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
      DiscoveryState(
        devices: <DiscoveredDevice>[...latest, ...manual],
        error: lastError,
      ),
    );
  }

  controller.onListen = () {
    sub = mergedScan(scanners).listen(
      (devices) {
        // Not cleared here: [mergedScan] emits the recomputed union right
        // after an error too (with the failed scanner's rows dropped), and
        // that is not a recovery. [DiscoveryState.error] is the *last*
        // failure any scanner reported (its doc comment) — it only moves
        // when a new one arrives, not when an unrelated list updates.
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
