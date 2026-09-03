import 'package:chameleon/chameleon.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/discovery/discovery_provider.dart';
import '../../../core/session/active_device.dart';
import '../../../core/session/sessions.dart';
import '../../../data/data.dart';

part 'connect_controller.g.dart';

/// The connect action, with its progress and its failure. Failures stay in
/// the state rather than being thrown, so the screen renders them through
/// the error catalog (spec 9) instead of catching.
///
/// Every attempt opens a fresh [DeviceSession] via [Sessions.connect] — this
/// never reuses a session across attempts.
@riverpod
class ConnectController extends _$ConnectController {
  @override
  Future<void> build() async {}

  Future<void> connect(DiscoveredDevice device) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard<void>(() async {
      final identity = await ref
          .read(sessionsProvider.notifier)
          .connect(device);
      ref.read(activeDeviceProvider.notifier).select(identity);
    });
  }

  /// "Reconnect to last device" (spec 4.2): the newest known identity, if it
  /// is visible right now. Silent when it is not — a device that is asleep
  /// or unplugged is not an error worth a dialog.
  Future<void> reconnectLast() async {
    final known = await ref.read(knownDevicesRepositoryProvider).lastSeen();
    if (known == null) return;
    final visible =
        ref.read(discoveryProvider).value?.devices ??
        const <DiscoveredDevice>[];
    final device = visible.where(known.matches).firstOrNull;
    if (device == null) return;
    await connect(device);
  }

  /// "Try again" (spec 5.1): clears a failed attempt back to the idle
  /// state, so the screen can offer the connect action again. Discovery's
  /// own error is a separate concern — the screen resets that by
  /// invalidating `discoveryProvider`.
  void reset() => state = const AsyncData<void>(null);
}
