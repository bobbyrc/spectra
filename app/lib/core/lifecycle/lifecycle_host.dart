import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/data.dart';
import '../discovery/discovery_provider.dart';
import '../platform/host_platform_provider.dart';
import '../session/active_device.dart';
import '../session/session_streams.dart';
import '../session/sessions.dart';
import 'lifecycle_controller.dart';
import 'wakelock.dart';

part 'lifecycle_host.g.dart';

/// How long a silent reconnect (spec 7.4) waits for [discoveryProvider] to
/// report the known device again before giving up. Bounded so a resume
/// that finds nothing never hangs waiting on a scan that may never see the
/// device again (asleep, unplugged, out of range).
const Duration reconnectDiscoveryTimeout = Duration(seconds: 10);

/// Waits for [discoveryProvider] to report a device that [matches], holding
/// a live [Ref.listen] subscription so the autoDispose provider stays alive
/// for the wait — a plain `ref.read(discoveryProvider.future)` resolves on
/// discovery's very first emission (often the placeholder empty list) and
/// does not keep the provider running while this waits for a later one.
/// Resolves with `null` on [timeout], or if [ref] is disposed first,
/// rather than throwing: a silent reconnect gives up quietly, it does not
/// surface a scan failure. Exposed (not private) so this wait is testable
/// against a scripted `discoveryProvider` override with no need to also
/// stand up a real `Sessions`/`DeviceSession`.
Future<DiscoveredDevice?> awaitDiscoveredDevice(
  Ref ref,
  bool Function(DiscoveredDevice) matches, {
  Duration timeout = reconnectDiscoveryTimeout,
}) {
  final completer = Completer<DiscoveredDevice?>();
  Timer? timer;
  late final ProviderSubscription<AsyncValue<DiscoveryState>> sub;

  void finish(DiscoveredDevice? device) {
    if (completer.isCompleted) return;
    timer?.cancel();
    sub.close();
    completer.complete(device);
  }

  sub = ref.listen<AsyncValue<DiscoveryState>>(discoveryProvider, (_, next) {
    final device = next.value?.devices.where(matches).firstOrNull;
    if (device != null) finish(device);
  });
  ref.onDispose(() => finish(null));

  final already = ref
      .read(discoveryProvider)
      .value
      ?.devices
      .where(matches)
      .firstOrNull;
  if (already != null) {
    finish(already);
  } else {
    timer = Timer(timeout, () => finish(null));
  }

  return completer.future;
}

/// Whether backgrounding the app right now should close the session after
/// the grace period (spec 7.4, R24).
///
/// Only on mobile: a desktop app that loses focus is not being put away —
/// its window is still there and its cable is still plugged in — so closing
/// the session behind the user's back would be a surprise, not a courtesy.
/// And never while the device is being flashed: a [SessionUpdating] session
/// dropped halfway through leaves a bricked device, which is the one
/// outcome worth holding a link open across any amount of backgrounding.
bool canGraceCloseNow(Ref ref) =>
    isMobile(ref.read(hostPlatformProvider)) &&
    ref.read(connectionStatusProvider) is! SessionUpdating;

@Riverpod(keepAlive: true)
LifecycleController lifecycleController(Ref ref) {
  final controller = LifecycleController(
    closeSessions: () => ref.read(sessionsProvider.notifier).disconnectAll(),
    hasSession: () => ref.read(sessionsProvider).sessions.isNotEmpty,
    canGraceClose: () => canGraceCloseNow(ref),
    reconnectLast: () async {
      final known = await ref.read(knownDevicesRepositoryProvider).lastSeen();
      if (known == null) return;

      final device = await awaitDiscoveredDevice(ref, known.matches);
      if (device == null) {
        // Discovery never showed the device inside the window: there is no
        // row on the connect screen for a device nobody has seen, so there
        // is nothing to preselect either (spec 7.4) — just give up.
        return;
      }

      try {
        final identity = await ref
            .read(sessionsProvider.notifier)
            .connect(device);
        ref.read(activeDeviceProvider.notifier).select(identity);
      } on Object {
        // The device was visible but the reconnect itself failed: still
        // preselect it on the connect screen, the same as a link that
        // dropped on its own (ruling 22).
        ref.read(sessionsProvider.notifier).markLastDisconnected(device);
        rethrow;
      }
    },
  );
  ref.onDispose(controller.dispose);
  return controller;
}

/// Turns the platform's lifecycle callbacks into [LifecycleController] calls.
/// Contributes no layout of its own.
class AppLifecycleHost extends ConsumerStatefulWidget {
  const AppLifecycleHost({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<AppLifecycleHost> createState() => _AppLifecycleHostState();
}

class _AppLifecycleHostState extends ConsumerState<AppLifecycleHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Reading the wakelock provider once is enough: it is keepAlive and
    // starts its own poll timer. Deferred so the first frame is not blocked
    // by a plugin call (relocated here from `SpectraRoot` — Task 12's
    // comment).
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(wakelockProvider),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(lifecycleControllerProvider);
    switch (state) {
      case AppLifecycleState.paused:
        controller.onPaused();
      case AppLifecycleState.resumed:
        unawaited(controller.onResumed());
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
