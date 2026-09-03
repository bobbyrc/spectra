import 'dart:async';

import '../protocol/errors.dart';
import '../session/cancel_token.dart';
import '../session/device_session.dart';
import '../transport/scanner.dart';
import '../transport/transport.dart';
import 'dfu_channel.dart';
import 'dfu_package.dart';
import 'dfu_types.dart';
import 'secure_dfu.dart';

/// Where an update has got to. Reported in this order, once each.
enum DfuPhase {
  /// Checking the package against the connected device.
  checking,

  /// ENTER_BOOTLOADER has gone out; the device is rebooting.
  enteringBootloader,

  /// Scanning for the device's bootloader.
  findingBootloader,

  /// Running Secure DFU over the bootloader's channel.
  transferring,

  /// Scanning for the device again, now back in the application.
  findingDevice,

  /// Finished.
  done,
}

/// Everything [DfuOrchestrator.run] reports. The stream ends after a
/// [DfuCompleted] or a [DfuFailed]; there is always exactly one of them.
sealed class DfuEvent {
  const DfuEvent();
}

final class DfuPhaseChanged extends DfuEvent {
  const DfuPhaseChanged(this.phase);
  final DfuPhase phase;

  @override
  String toString() => 'DfuPhaseChanged(${phase.name})';
}

final class DfuProgressed extends DfuEvent {
  const DfuProgressed(this.progress);
  final DfuProgress progress;

  @override
  String toString() => 'DfuProgressed($progress)';
}

/// The flash succeeded. [device] is the rediscovered device, or null when it
/// had not come back within `scanTimeout` — the update is still done, only
/// the reconnect is left to the app.
final class DfuCompleted extends DfuEvent {
  const DfuCompleted(this.device);
  final DiscoveredDevice? device;

  @override
  String toString() => 'DfuCompleted($device)';
}

final class DfuFailed extends DfuEvent {
  const DfuFailed(this.error);
  final ChameleonException error;

  @override
  String toString() => 'DfuFailed($error)';
}

/// Opens a DFU channel to a discovered bootloader. Transport-specific, so the
/// app supplies it: BLE and SLIP-over-serial both live in `chameleon_flutter`.
typedef DfuChannelOpener = Future<DfuChannel> Function(DiscoveredDevice b);

/// Runs a whole update: model check, reboot, find the bootloader, transfer,
/// find the device again (spec 4.5).
///
/// Starts either from a connected [DeviceSession] or, when [run] is given a
/// [DiscoveredDevice] that is already a bootloader, from there — a device left
/// in DFU mode by a failed update is always recoverable (spec 5.6).
///
/// The session is deliberately left alone after ENTER_BOOTLOADER: the facade
/// puts it in `SessionUpdating` and it stays there through success, failure
/// and cancellation alike, because the app's reconnect logic — not the
/// orchestrator — decides what the session becomes once the device is back.
/// The channel is closed on every path out, including cancellation.
final class DfuOrchestrator {
  DfuOrchestrator({
    required this.scanners,
    required this.openChannel,
    this.scanTimeout = const Duration(seconds: 30),
  });

  /// Scanned in parallel; the first matching device wins.
  final List<DeviceScanner> scanners;
  final DfuChannelOpener openChannel;

  /// Budget for each of the two scans, and for the reboot that precedes the
  /// first of them.
  final Duration scanTimeout;

  /// How long to wait between scan passes, for scanners that report once per
  /// subscription rather than continuously.
  static const Duration _rescanDelay = Duration(milliseconds: 10);

  Stream<DfuEvent> run({
    required DfuPackage package,
    DeviceSession? session,
    DiscoveredDevice? bootloader,
    CancelToken? cancel,
  }) async* {
    try {
      var target = bootloader;
      if (target == null) {
        if (session == null) {
          throw DfuError('need a session or a device in the bootloader');
        }
        yield const DfuPhaseChanged(DfuPhase.checking);
        _check(session, package);
        yield const DfuPhaseChanged(DfuPhase.enteringBootloader);
        await session.firmware.enterBootloader();
        await _awaitReboot(session);
        yield const DfuPhaseChanged(DfuPhase.findingBootloader);
        target = await _find((d) => d.isBootloader, cancel);
        if (target == null) {
          throw DfuError('no bootloader found within $scanTimeout');
        }
      }
      yield const DfuPhaseChanged(DfuPhase.transferring);
      // `yield*` hands a stream's errors straight to the consumer rather than
      // throwing them in here, so the transfer reports its failure by hand.
      Object? failure;
      StackTrace? stack;
      yield* _transfer(await openChannel(target), package, cancel, (e, s) {
        failure = e;
        stack = s;
      });
      if (failure != null) Error.throwWithStackTrace(failure!, stack!);
      yield const DfuPhaseChanged(DfuPhase.findingDevice);
      final device = await _find((d) => !d.isBootloader, cancel);
      yield const DfuPhaseChanged(DfuPhase.done);
      yield DfuCompleted(device);
    } on ChameleonException catch (e) {
      yield DfuFailed(e);
    } on Object catch (e) {
      // Anything else — a transport's StateError, a bug — still has to end as
      // one DfuFailed: the app routes on the event, not on an escaped throw.
      yield DfuFailed(DfuError('firmware update failed: $e'));
    }
  }

  /// Refuses a package that cannot be for this device, before anything is
  /// sent: a mismatched flash bricks the device until it is recovered.
  void _check(DeviceSession session, DfuPackage package) {
    final model = session.deviceInfo.value?.model;
    final wanted = package.targetModel;
    if (model != null && wanted != model) {
      throw DfuError(
        'package targets '
        '${wanted?.name ?? 'hardware version ${package.hardwareVersion}'}, '
        'device is a ${model.name}',
      );
    }
    for (final image in package.images) {
      if (!image.hashMatches) {
        throw DfuError(
          '${image.kind.name} image hash does not match its '
          'init packet',
        );
      }
    }
  }

  /// Waits for the link to drop, which is what ENTER_BOOTLOADER causes. Not
  /// an error if it does not: the scan that follows is the real gate, and
  /// some transports never report the close.
  Future<void> _awaitReboot(DeviceSession session) async {
    if (session.transport.currentState is TransportClosed) return;
    try {
      await session.transport.state
          .firstWhere((s) => s is TransportClosed)
          .timeout(scanTimeout);
    } on TimeoutException {
      return;
    }
  }

  /// Runs [SecureDfu] over [channel], forwarding its progress and reporting a
  /// failure through [onFailure]. The channel is closed however this ends.
  ///
  /// The failure is caught the moment it happens rather than left on a future
  /// to await later: a future carrying an error nothing has subscribed to,
  /// even for one turn, is reported as an unhandled async error.
  Stream<DfuEvent> _transfer(
    DfuChannel channel,
    DfuPackage package,
    CancelToken? cancel,
    void Function(Object error, StackTrace stack) onFailure,
  ) async* {
    final events = StreamController<DfuEvent>();
    final dfu = SecureDfu(channel);
    final done = Future(() async {
      for (final image in package.images) {
        await dfu.run(
          image,
          cancel: cancel,
          onProgress: (p) => events.add(DfuProgressed(p)),
        );
      }
    }).then<void>((_) {}, onError: onFailure).whenComplete(events.close);
    try {
      yield* events.stream;
      await done;
    } finally {
      await channel.close();
    }
  }

  /// The first device any scanner reports that [test] accepts, or null once
  /// [scanTimeout] has run out.
  Future<DiscoveredDevice?> _find(
    bool Function(DiscoveredDevice) test,
    CancelToken? cancel,
  ) async {
    final deadline = DateTime.now().add(scanTimeout);
    while (true) {
      if (cancel?.isCancelled ?? false) throw const CommandCancelled();
      final left = deadline.difference(DateTime.now());
      if (left <= Duration.zero) return null;
      final hit = await _scanOnce(test, left, cancel);
      if (hit != null) return hit;
      // Scanners that emit once per subscription need another pass; ones that
      // stay open will already have used the whole budget above.
      await Future<void>.delayed(_rescanDelay);
    }
  }

  /// One pass over every scanner. Ends on the first match, when every scan
  /// stream has finished without one, when [budget] runs out, or on cancel.
  Future<DiscoveredDevice?> _scanOnce(
    bool Function(DiscoveredDevice) test,
    Duration budget,
    CancelToken? cancel,
  ) async {
    final result = Completer<DiscoveredDevice?>();
    void finish([DiscoveredDevice? d]) {
      if (!result.isCompleted) result.complete(d);
    }

    var open = scanners.length;
    void oneEnded() {
      if (--open <= 0) finish();
    }

    final subs = scanners
        .map(
          (s) => s.scan().listen(
            (devices) {
              for (final d in devices) {
                if (test(d)) return finish(d);
              }
            },
            // A scanner that fails (no permission, adapter off) must not sink
            // the whole search: the others may still find the device.
            onError: (Object _) => oneEnded(),
            onDone: oneEnded,
            cancelOnError: true,
          ),
        )
        .toList();
    if (subs.isEmpty) finish();
    final timer = Timer(budget, finish);
    final release = cancel?.onCancel(finish);
    try {
      return await result.future;
    } finally {
      timer.cancel();
      release?.call();
      for (final sub in subs) {
        await sub.cancel();
      }
    }
  }
}
