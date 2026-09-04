import 'package:chameleon/chameleon.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/session/active_device.dart';
import '../../../core/session/reconnect.dart';
import '../../../core/session/sessions.dart';

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
    // Both notifiers are keepAlive and are read *before* the await: this
    // controller is autoDispose, and the user leaving the connect screen
    // mid-attempt must not stop the attempt from finishing and recording
    // its result.
    final Sessions sessions = ref.read(sessionsProvider.notifier);
    final ActiveDevice active = ref.read(activeDeviceProvider.notifier);
    state = const AsyncLoading<void>();
    final AsyncValue<void> result = await AsyncValue.guard<void>(() async {
      final identity = await sessions.connect(device);
      active.select(identity);
    });
    if (!ref.mounted) return;
    state = result;
  }

  /// "Reconnect to last device" (spec 4.2), on the same
  /// [reconnectLastDevice] the silent post-resume attempt uses (R26) — the
  /// button used to read discovery once and return silently when the row
  /// was not there yet, which for a device that has not been scanned in
  /// this second is a button that does nothing.
  ///
  /// The controller stays loading for the whole wait, and an outcome with
  /// nothing to connect to becomes a [NoKnownDeviceVisible] the screen
  /// renders through the error catalog — the button reports, where the
  /// resume path stays silent.
  Future<void> reconnectLast() async {
    state = const AsyncLoading<void>();
    final AsyncValue<void> result = await AsyncValue.guard<void>(() async {
      final outcome = await reconnectLastDevice(ref);
      if (outcome != ReconnectOutcome.connected) {
        throw const NoKnownDeviceVisible();
      }
    });
    // Disposed while the wait ran (see [connect]): there is nowhere left to
    // report the outcome.
    if (!ref.mounted) return;
    state = result;
  }

  /// "Try again" (spec 5.1): clears a failed attempt back to the idle
  /// state, so the screen can offer the connect action again. Discovery's
  /// own error is a separate concern — the screen resets that by
  /// invalidating `discoveryProvider`.
  void reset() => state = const AsyncData<void>(null);
}
