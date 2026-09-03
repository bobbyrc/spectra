import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/data.dart';
import '../discovery/discovery_provider.dart';
import '../session/active_device.dart';
import '../session/sessions.dart';
import 'lifecycle_controller.dart';
import 'wakelock.dart';

part 'lifecycle_host.g.dart';

@Riverpod(keepAlive: true)
LifecycleController lifecycleController(Ref ref) {
  final controller = LifecycleController(
    closeSessions: () => ref.read(sessionsProvider.notifier).disconnectAll(),
    hasSession: () => ref.read(sessionsProvider).sessions.isNotEmpty,
    reconnectLast: () async {
      final known = await ref.read(knownDevicesRepositoryProvider).lastSeen();
      if (known == null) return;
      final discovery = await ref.read(discoveryProvider.future);
      final device = discovery.devices.where(known.matches).firstOrNull;
      if (device == null) return;
      final identity = await ref
          .read(sessionsProvider.notifier)
          .connect(device);
      ref.read(activeDeviceProvider.notifier).select(identity);
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
