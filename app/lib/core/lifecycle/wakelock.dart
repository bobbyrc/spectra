import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../session/active_device.dart';
import '../session/session_streams.dart';

part 'wakelock.g.dart';

/// The seam over `wakelock_plus`, so the rule above it is testable with no
/// plugin channel (spec 8.6).
abstract interface class WakelockGateway {
  Future<void> enable();
  Future<void> disable();
}

final class WakelockPlusGateway implements WakelockGateway {
  const WakelockPlusGateway();

  @override
  Future<void> enable() => WakelockPlus.enable();

  @override
  Future<void> disable() => WakelockPlus.disable();
}

/// Spec 7.4: hold the screen awake during a flash or a reader lease. The
/// lease count and the busy depth are plain getters on the session with no
/// change notification, so this polls — which keeps the SDK free of a stream
/// nothing else would use.
bool sessionNeedsWakelock(DeviceSession? session, ConnectionState state) {
  if (state is SessionUpdating) return true;
  if (session == null) return false;
  return session.readerLeaseCount > 0 || session.isBusy;
}

final class WakelockController {
  WakelockController({
    required this.gateway,
    required this.shouldHold,
    this.interval = const Duration(seconds: 1),
  });

  final WakelockGateway gateway;
  final bool Function() shouldHold;
  final Duration interval;

  Timer? _timer;
  bool _held = false;

  bool get held => _held;

  /// One evaluation. Idempotent: the gateway is only touched on a change.
  Future<void> poll() async {
    final want = shouldHold();
    if (want == _held) return;
    _held = want;
    await (want ? gateway.enable() : gateway.disable());
  }

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(poll()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    if (_held) {
      _held = false;
      unawaited(gateway.disable());
    }
  }
}

@Riverpod(keepAlive: true)
WakelockController wakelock(Ref ref) {
  final controller = WakelockController(
    gateway: const WakelockPlusGateway(),
    shouldHold: () => sessionNeedsWakelock(
      ref.read(activeSessionProvider)?.session,
      ref.read(connectionStatusProvider),
    ),
  );
  controller.start();
  ref.onDispose(controller.stop);
  return controller;
}
