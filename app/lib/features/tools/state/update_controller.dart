import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/dfu/dfu_runtime.dart';
import '../../../core/errors/app_failures.dart';
import '../../../core/flags/feature_flags.dart';
import '../../../core/session/active_device.dart';
import '../../../core/session/active_session.dart';
import '../../../core/session/sessions.dart';
import 'firmware_package_source.dart';

part 'update_controller.g.dart';

/// Distinguishes "leave it alone" from "clear it" in [UpdateState.copyWith],
/// since null is a meaningful value for all three nullable fields.
const Object _unset = Object();

/// What the update screen shows (spec 7.7 step 6).
final class UpdateState {
  const UpdateState({
    this.package,
    this.phase,
    this.progress,
    this.error,
    this.running = false,
    this.completed = false,
    this.loading = false,
  });

  final LoadedFirmwarePackage? package;

  /// The orchestrator's last phase, or null before a run starts. Ruling 8-3:
  /// the recovery path does not emit the first phases, so this is the only
  /// source of truth for the step index the screen renders — nothing here
  /// assumes a run starts at [DfuPhase.checking].
  final DfuPhase? phase;
  final DfuProgress? progress;

  /// The failure of the last load or run. Cleared when either starts again.
  final Object? error;

  /// A flash is running: every control on the screen is disabled and
  /// navigation is locked (spec 5.6).
  final bool running;

  /// The last run finished successfully.
  final bool completed;

  /// A package is being read and parsed.
  final bool loading;

  /// 0..1 for the bar, or null while there is nothing to report.
  double? get fraction => progress?.fraction;

  UpdateState copyWith({
    Object? package = _unset,
    Object? phase = _unset,
    Object? progress = _unset,
    Object? error = _unset,
    bool? running,
    bool? completed,
    bool? loading,
  }) => UpdateState(
    package: identical(package, _unset)
        ? this.package
        : package as LoadedFirmwarePackage?,
    phase: identical(phase, _unset) ? this.phase : phase as DfuPhase?,
    progress: identical(progress, _unset)
        ? this.progress
        : progress as DfuProgress?,
    error: identical(error, _unset) ? this.error : error,
    running: running ?? this.running,
    completed: completed ?? this.completed,
    loading: loading ?? this.loading,
  );
}

/// Drives `DfuOrchestrator` for the update screen (spec 4.5, 7.7 step 6).
///
/// Two entry points, one run: a connected device (the orchestrator sends
/// ENTER_BOOTLOADER itself and the session moves to `SessionUpdating`), and a
/// device already sitting in its bootloader — the recovery path spec 5.6
/// guarantees, reached from the connect screen's "Recover" action.
///
/// Cancellation goes through the [CancelToken], never by cancelling the
/// subscription: unsubscribing closes the channel under an in-flight transfer
/// and leaves a half-written image on the device (`DfuOrchestrator`'s own doc).
@Riverpod(keepAlive: true)
class UpdateController extends _$UpdateController {
  CancelToken? _cancel;
  StreamSubscription<DfuEvent>? _events;

  /// Drop, do not queue: a second start while one is in flight is ignored.
  bool _inFlight = false;

  @override
  UpdateState build() {
    ref.onDispose(() {
      _cancel?.cancel();
      // Never awaited, here or anywhere else in this file: a
      // `StreamSubscription.cancel()` future does not reliably complete
      // under a fake clock, which is what every widget test runs on (the
      // same reason `DeviceSession` stopped awaiting its own). The token
      // above is what actually stops a run in flight; this only unsubscribes.
      unawaited(_events?.cancel());
    });
    return const UpdateState();
  }

  /// Reads and parses the package at [path]. A failure leaves the previous
  /// package in place: a mistyped path should not clear a good one.
  Future<void> loadPackage(String path) async {
    if (state.running || state.loading) return;
    state = state.copyWith(loading: true, error: null, completed: false);
    try {
      final loaded = await loadFirmwarePackage(
        ref.read(firmwarePackageSourceProvider),
        path,
      );
      if (!ref.mounted) return;
      state = state.copyWith(package: loaded, loading: false);
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, error: e);
    }
  }

  /// Runs the whole update. With [bootloader] the device is already in DFU
  /// mode; without it the active session's device is rebooted first.
  Future<void> start({DiscoveredDevice? bootloader}) async {
    if (_inFlight) return;
    final package = state.package;
    if (package == null) return;
    final active = ref.read(activeSessionProvider);
    if (bootloader == null && active == null) {
      state = state.copyWith(error: const UpdateNoTarget());
      return;
    }
    if (bootloader?.kind == TransportKind.ble &&
        !ref.read(featureFlagsProvider).dfuOverBleEnabled) {
      state = state.copyWith(error: const UpdateBleDisabled());
      return;
    }

    _inFlight = true;
    final cancel = CancelToken();
    _cancel = cancel;
    ref.read(dfuActivityProvider.notifier).setRunning(true);
    state = state.copyWith(
      running: true,
      completed: false,
      error: null,
      phase: null,
      progress: null,
    );

    final orchestrator = DfuOrchestrator(
      scanners: ref.read(
        dfuScannersProvider(DfuTarget(bootloader: bootloader)),
      ),
      openChannel: ref.read(dfuChannelOpenerProvider),
      scanTimeout: ref.read(dfuScanTimeoutProvider),
    );

    DiscoveredDevice? found;
    Object? failure;
    final done = Completer<void>();
    _events = orchestrator
        .run(
          package: package.package,
          session: bootloader == null ? active!.session : null,
          bootloader: bootloader,
          cancel: cancel,
        )
        .listen(
          (event) {
            if (!ref.mounted) return;
            switch (event) {
              case DfuPhaseChanged(:final phase):
                state = state.copyWith(phase: phase);
              case DfuProgressed(:final progress):
                state = state.copyWith(progress: progress);
              case DfuCompleted(:final device):
                found = device;
              case DfuFailed(:final error):
                failure = error;
            }
          },
          // `run()` ends every path in one DfuCompleted or DfuFailed
          // (Task 1), so this is only a bug net.
          onError: (Object e) => failure = e,
          onDone: done.complete,
        );
    await done.future;
    // Not awaited. `run()` is an `async*` generator, and a generator
    // subscription's `cancel()` future does not reliably complete under
    // flutter_test's fake clock — the same reason `DeviceSession` stopped
    // awaiting its own cancels. `onDone` has already fired here, so there is
    // nothing left to wait for anyway.
    unawaited(_events?.cancel());
    _events = null;
    _cancel = null;
    _inFlight = false;

    if (failure == null) await _reconnect(previous: active, device: found);
    ref.read(dfuActivityProvider.notifier).setRunning(false);
    if (!ref.mounted) return;
    state = state.copyWith(
      running: false,
      completed: failure == null,
      error: failure,
    );
  }

  /// Closes the session the flash left in `SessionUpdating` and opens one on
  /// the device the orchestrator found coming back (spec 4.5: the reconnect
  /// is the app's, not the orchestrator's).
  ///
  /// A reconnect that fails is not an update failure: the image is written.
  /// The session is gone either way, so routing puts the connect screen one
  /// tap away and the user retries there.
  Future<void> _reconnect({
    required ActiveSession? previous,
    required DiscoveredDevice? device,
  }) async {
    final sessions = ref.read(sessionsProvider.notifier);
    if (previous != null) await sessions.disconnect(previous.identity);
    if (device == null || !ref.mounted) return;
    try {
      final identity = await sessions.connect(device);
      if (!ref.mounted) return;
      ref.read(activeDeviceProvider.notifier).select(identity);
    } on Object {
      // Deliberately ignored; see the doc comment.
    }
  }

  /// Stops the transfer at the next packet boundary. The device stays in the
  /// bootloader, which is what makes the run retryable (spec 5.6).
  void cancel() => _cancel?.cancel();

  /// Clears the last result, keeping the loaded package.
  void reset() => state = state.copyWith(
    error: null,
    completed: false,
    phase: null,
    progress: null,
  );

  @visibleForTesting
  void debugFail(Object error) =>
      state = state.copyWith(error: error, running: false);
}
