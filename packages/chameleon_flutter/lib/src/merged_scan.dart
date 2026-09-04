import 'dart:async';

import 'package:chameleon/chameleon.dart';

/// The union of every scanner's latest list, de-duplicated by
/// [DiscoveredDevice] equality — transport kind plus transport id (spec 4.2).
///
/// The contract, so the connect screen and the DFU orchestrator can rely on
/// the same behaviour whichever scanners they are handed:
///
/// * **First event.** One is emitted as soon as the stream is listened to,
///   carrying whatever is known then — usually the empty list. The union is
///   deliberately *not* held back until every scanner has reported: a
///   scanner that is slow (BLE waiting on the adapter) or silent (no ports)
///   would otherwise leave the UI with nothing to render at all.
/// * **Updates.** Every later list from any scanner re-emits the whole
///   union, never a delta.
/// * **Errors.** A scanner's error is forwarded with [Stream.addError] and
///   that scanner's rows are dropped from the union (a scanner that has
///   failed is no longer reporting what is in range), but the other
///   scanners keep running and keep producing. Restarting a failed scanner
///   means resubscribing to a fresh merged stream.
/// * **Completion.** The merged stream closes once every scanner's own
///   stream is done — a scanner that errored and ended counts as done — so
///   a caller waiting on completion over finite scanners is never left
///   hanging. With no scanners at all it emits `[]` and closes at once.
/// * **Cancel.** Cancelling the subscription cancels every scanner's.
Stream<List<DiscoveredDevice>> mergedScan(List<DeviceScanner> scanners) {
  final latest = <int, List<DiscoveredDevice>>{};
  final controller = StreamController<List<DiscoveredDevice>>();
  final subs = <StreamSubscription<List<DiscoveredDevice>>>[];

  void emit() {
    if (controller.isClosed) return;
    final merged = <DiscoveredDevice, DiscoveredDevice>{};
    for (final list in latest.values) {
      for (final d in list) {
        merged[d] = d;
      }
    }
    controller.add(List<DiscoveredDevice>.unmodifiable(merged.values));
  }

  controller.onListen = () {
    // The first event, before any scanner has said anything: an empty list
    // is a real answer ("nothing found yet"), and the UI can render it.
    emit();
    if (scanners.isEmpty) {
      unawaited(controller.close());
      return;
    }
    var done = 0;
    void oneEnded() {
      done++;
      if (done == scanners.length && !controller.isClosed) {
        unawaited(controller.close());
      }
    }

    for (var i = 0; i < scanners.length; i++) {
      final index = i;
      subs.add(
        scanners[i].scan().listen(
          (devices) {
            latest[index] = devices;
            emit();
          },
          onError: (Object e, StackTrace s) {
            // The failed scanner's rows are stale the moment it stops
            // reporting: drop them, tell the caller, leave the rest alone.
            latest.remove(index);
            if (!controller.isClosed) controller.addError(e, s);
            emit();
          },
          onDone: oneEnded,
        ),
      );
    }
  };
  controller.onCancel = () async {
    for (final s in subs) {
      // Not awaited: a `StreamSubscription.cancel()` future does not
      // reliably complete under a fake clock, which is what every widget
      // test runs on (the same reason `DeviceSession` stopped awaiting its
      // own cancels).
      unawaited(s.cancel());
    }
    subs.clear();
    if (!controller.isClosed) await controller.close();
  };
  return controller.stream;
}
