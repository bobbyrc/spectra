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
///
/// Cancel a run with the [CancelToken] passed to [run], never by cancelling
/// the subscription to its event stream: an unsubscribe closes the channel
/// out from under an in-flight transfer, which leaves the device in the
/// bootloader with a half-written image. The token stops the transfer at the
/// next packet boundary and unwinds cleanly.
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
  /// first of them. The three are consecutive, so the worst case for a run
  /// that never finds anything is three times this — not once.
  final Duration scanTimeout;

  /// How long to wait between scan passes, for scanners that report once per
  /// subscription rather than continuously.
  static const Duration _rescanDelay = Duration(milliseconds: 100);

  Stream<DfuEvent> run({
    required DfuPackage package,
    DeviceSession? session,
    DiscoveredDevice? bootloader,
    CancelToken? cancel,
  }) async* {
    try {
      // Every run verifies the package, the recovery path included: a
      // tampered image must be refused before a single byte is written.
      _checkImages(package);
      final DiscoveredDevice target;
      if (bootloader != null) {
        target = bootloader;
      } else {
        if (session == null) {
          throw DfuError('need a session or a device in the bootloader');
        }
        yield const DfuPhaseChanged(DfuPhase.checking);
        _checkModel(session, package);
        yield const DfuPhaseChanged(DfuPhase.enteringBootloader);
        await session.firmware.enterBootloader();
        await _awaitReboot(session);
        yield const DfuPhaseChanged(DfuPhase.findingBootloader);
        final found = await _find((d) => d.isBootloader, cancel);
        if (found == null) {
          throw DfuError('no bootloader found within $scanTimeout');
        }
        target = found;
      }
      yield const DfuPhaseChanged(DfuPhase.transferring);
      // `yield*` hands a stream's errors straight to the consumer rather than
      // throwing them in here, so the transfer reports its failure by hand.
      Object? failure;
      StackTrace? stack;
      yield* _transfer(() => openChannel(target), package, cancel, (e, s) {
        failure = e;
        stack = s;
      });
      if (failure != null) Error.throwWithStackTrace(failure!, stack!);
      yield const DfuPhaseChanged(DfuPhase.findingDevice);
      // The flash is done, so a cancel here only calls off the search: the
      // update succeeded and the app still has to reconnect either way.
      final device = await _find(
        (d) => !d.isBootloader,
        cancel,
        failOnCancel: false,
      );
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

  /// Refuses a package whose images do not match their own init packets.
  /// Runs on every path, recovery included: a tampered or truncated image is
  /// the one thing that must never reach the bootloader.
  static void _checkImages(DfuPackage package) {
    for (final image in package.images) {
      if (!image.hashMatches) {
        throw DfuError(
          '${image.kind.name} image hash does not match its init packet',
        );
      }
    }
  }

  /// Refuses a package built for the other model, before anything is sent: a
  /// mismatched flash bricks the device until it is recovered.
  ///
  /// A `SessionLimited` session (firmware too old to answer GET_APP_VERSION)
  /// has no `DeviceInfo`, so there is nothing to compare and the check is
  /// skipped by design — firmware that old must still be updatable. The
  /// bootloader's own hardware-version check is the backstop there: it
  /// refuses a mismatched init packet at execute time, which surfaces as a
  /// [DfuError] mid-transfer instead of before it.
  static void _checkModel(DeviceSession session, DfuPackage package) {
    final model = session.deviceInfo.value?.model;
    final wanted = package.targetModel;
    if (model != null && wanted != model) {
      throw DfuError(
        'package targets '
        '${wanted?.name ?? 'hardware version ${package.hardwareVersion}'}, '
        'device is a ${model.name}',
      );
    }
  }

  /// Waits for the link to drop, which is what ENTER_BOOTLOADER causes. Not
  /// an error if it does not: the scan that follows is the real gate, and
  /// some transports never report the close. Gives up after [scanTimeout],
  /// and on a state stream that ends without ever reporting a close.
  Future<void> _awaitReboot(DeviceSession session) async {
    if (session.transport.currentState is TransportClosed) return;
    final closed = Completer<void>();
    void done([Object? _]) {
      if (!closed.isCompleted) closed.complete();
    }

    final sub = session.transport.state.listen(
      (s) {
        if (s is TransportClosed) done();
      },
      onDone: done,
      onError: done,
      cancelOnError: true,
    );
    final timer = Timer(scanTimeout, done);
    try {
      await closed.future;
    } finally {
      timer.cancel();
      await sub.cancel();
    }
  }

  /// Opens the channel with [open], runs [SecureDfu] over it forwarding its
  /// progress, and reports a failure through [onFailure].
  ///
  /// The open is inside the same try as the transfer, so a channel that
  /// finishes opening after this stream has been unsubscribed is still closed
  /// rather than leaked. A failure in that same pre-stream section (the
  /// opener, `channel.open()`) is also reported through [onFailure] rather
  /// than thrown out of the stream: `yield*` hands a stream's errors straight
  /// to the consumer, past `run()`'s own try/catch, so a raw throw here would
  /// otherwise escape as an unhandled stream error instead of a `DfuFailed`.
  ///
  /// The failure is caught the moment it happens rather than left on a future
  /// to await later: a future carrying an error nothing has subscribed to,
  /// even for one turn, is reported as an unhandled async error.
  Stream<DfuEvent> _transfer(
    Future<DfuChannel> Function() open,
    DfuPackage package,
    CancelToken? cancel,
    void Function(Object error, StackTrace stack) onFailure,
  ) async* {
    DfuChannel? channel;
    try {
      channel = await open();
      // One lifecycle for every channel (ruling F33): the BLE channel does
      // its connect and MTU negotiation here, the serial one and the fakes
      // no-op. Inside the same try, so a failure still closes the channel.
      await channel.open();
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
      yield* events.stream;
      await done;
    } on Object catch (e, s) {
      // Everything before `yield*` throws into this generator, and `yield*`
      // hands a generator's error straight to the consumer — past `run()`'s
      // own try/catch. Reporting it through [onFailure] is what keeps the
      // promise that a run always ends in exactly one DfuFailed. Nothing
      // after `yield*` can get here: the transfer's own failure is already
      // routed to [onFailure] by `then(onError:)`, so `await done` never
      // throws, and a double report is impossible.
      onFailure(e, s);
    } finally {
      await channel?.close();
    }
  }

  /// The first device any scanner reports that [test] accepts, or null once
  /// [scanTimeout] has run out.
  ///
  /// With [failOnCancel] false a cancelled search returns null instead of
  /// throwing: after a finished flash the update has succeeded whether or not
  /// the device is found again.
  Future<DiscoveredDevice?> _find(
    bool Function(DiscoveredDevice) test,
    CancelToken? cancel, {
    bool failOnCancel = true,
  }) async {
    final deadline = DateTime.now().add(scanTimeout);
    while (true) {
      if (cancel?.isCancelled ?? false) {
        if (failOnCancel) throw const CommandCancelled();
        return null;
      }
      final left = deadline.difference(DateTime.now());
      if (left <= Duration.zero) return null;
      final hit = await _scanOnce(test, left, cancel);
      if (hit != null) return hit;
      // A cancelled pass ends early; the top of the loop decides what that
      // means, without waiting out the rescan delay first.
      if (cancel?.isCancelled ?? false) continue;
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
