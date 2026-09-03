import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderSubscription;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/data.dart';
import '../discovery/discovery_provider.dart';
import 'active_device.dart';
import 'sessions.dart';

part 'reconnect.g.dart';

/// How long a reconnect waits for [discoveryProvider] to report the known
/// device before giving up. Bounded so a reconnect that finds nothing never
/// hangs waiting on a scan that may never see the device again (asleep,
/// unplugged, out of range). A provider so a test can shorten it.
@Riverpod(keepAlive: true)
Duration reconnectDiscoveryTimeout(Ref ref) => const Duration(seconds: 10);

/// What [reconnectLastDevice] managed to do. A connect that *fails* throws
/// instead — the error itself is what the caller has to show or swallow.
enum ReconnectOutcome {
  /// A session is open and is now the active device.
  connected,

  /// Nothing has ever been connected, so there is no "last device".
  noKnownDevice,

  /// There is a last device, but no scanner saw it inside the window.
  notVisible,
}

/// The failure "Reconnect to last device" reports when there is nothing to
/// reconnect to — either outcome of [ReconnectOutcome] that is not
/// [ReconnectOutcome.connected]. A typed error so the connect screen renders
/// it through the error catalog (spec 9) like every other failure, rather
/// than growing a second, parallel way to say something went wrong.
final class NoKnownDeviceVisible implements Exception {
  const NoKnownDeviceVisible();

  @override
  String toString() => 'NoKnownDeviceVisible: no known device is visible';
}

/// Waits for [discoveryProvider] to report a device that [matches], holding
/// a live [Ref.listen] subscription so the autoDispose provider stays alive
/// for the wait — a plain `ref.read(discoveryProvider.future)` resolves on
/// discovery's very first emission (often the placeholder empty list) and
/// does not keep the provider running while this waits for a later one.
/// Resolves with `null` on timeout, or if [ref] is disposed first, rather
/// than throwing: this is a wait that gives up, not a scan failure.
///
/// Exposed (not private) so the wait is testable against a scripted
/// `discoveryProvider` override with no need to also stand up a real
/// `Sessions`/`DeviceSession`.
Future<DiscoveredDevice?> awaitDiscoveredDevice(
  Ref ref,
  bool Function(DiscoveredDevice) matches, {
  Duration? timeout,
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
    timer = Timer(
      timeout ?? ref.read(reconnectDiscoveryTimeoutProvider),
      () => finish(null),
    );
  }

  return completer.future;
}

/// Reconnects to the newest known device: wait for discovery to show it,
/// connect, and make it the active device.
///
/// The one implementation behind both ways the app reconnects — the silent
/// attempt after a resume (spec 7.4) and the connect screen's "Reconnect to
/// last device" button (spec 4.2). They differ only in what they do with the
/// result: the resume swallows everything, the button shows it.
///
/// Throws whatever the connect threw when the device *was* visible but the
/// attempt failed, after arming [Sessions.markLastDisconnected] so the
/// connect screen still preselects the row (ruling 22).
Future<ReconnectOutcome> reconnectLastDevice(
  Ref ref, {
  Duration? timeout,
}) async {
  final known = await ref.read(knownDevicesRepositoryProvider).lastSeen();
  if (known == null) return ReconnectOutcome.noKnownDevice;

  final device = await awaitDiscoveredDevice(
    ref,
    known.matches,
    timeout: timeout,
  );
  // No row on the connect screen for a device nobody has seen, so there is
  // nothing to preselect either (spec 7.4).
  if (device == null) return ReconnectOutcome.notVisible;

  try {
    final identity = await ref.read(sessionsProvider.notifier).connect(device);
    ref.read(activeDeviceProvider.notifier).select(identity);
    return ReconnectOutcome.connected;
  } on Object {
    // The device was visible but the reconnect itself failed: still
    // preselect it on the connect screen, the same as a link that dropped
    // on its own (ruling 22).
    ref.read(sessionsProvider.notifier).markLastDisconnected(device);
    rethrow;
  }
}
