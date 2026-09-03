import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../platform/host_platform_provider.dart';
import '../session/reconnect.dart';
import '../session/session_streams.dart';
import '../session/sessions.dart';
import 'lifecycle_controller.dart';
import 'wakelock.dart';

part 'lifecycle_host.g.dart';

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
    // One silent attempt on resume (spec 7.4). The outcome is not worth
    // reporting — the connect screen is already what the user is looking
    // at — so "nothing known" and "not visible" are dropped here and a
    // failed connect's error is swallowed by `LifecycleController`.
    reconnectLast: () => reconnectLastDevice(ref),
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
