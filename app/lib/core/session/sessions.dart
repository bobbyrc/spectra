import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/data.dart';
import 'active_session.dart';
import 'session_identity.dart';

part 'sessions.g.dart';

/// Sentinel distinguishing "leave `lastDisconnected` alone" from "set it to
/// null" in [SessionsState.copyWith], since `null` is itself a valid value.
const Object _unset = Object();

/// Every open session, keyed by identity (spec 7.1). Multi-device is not
/// built, but this is the shape that makes adding it later invisible to
/// feature code.
final class SessionsState {
  const SessionsState({
    this.sessions = const <DeviceIdentity, ActiveSession>{},
    this.lastDisconnected,
  });

  final Map<DeviceIdentity, ActiveSession> sessions;

  /// The device whose link went away without being asked to. The connect
  /// screen preselects it (spec 7.4) and consumes it once via
  /// [Sessions.consumeLastDisconnected].
  final DiscoveredDevice? lastDisconnected;

  /// [lastDisconnected] defaults to "unchanged"; pass `null` explicitly to
  /// clear it.
  SessionsState copyWith({
    Map<DeviceIdentity, ActiveSession>? sessions,
    Object? lastDisconnected = _unset,
  }) => SessionsState(
    sessions: sessions ?? this.sessions,
    lastDisconnected: identical(lastDisconnected, _unset)
        ? this.lastDisconnected
        : lastDisconnected as DiscoveredDevice?,
  );
}

/// How a [DiscoveredDevice] becomes a [Transport]. Injected so tests connect
/// to a scripted `FakeDevice` (spec 8.6).
@Riverpod(keepAlive: true)
Transport Function(DiscoveredDevice) transportFactory(Ref ref) =>
    ChameleonTransports.transportFor;

@Riverpod(keepAlive: true)
class Sessions extends _$Sessions {
  final Map<DeviceIdentity, StreamSubscription<ConnectionState>> _watchers =
      <DeviceIdentity, StreamSubscription<ConnectionState>>{};

  // Mirrors `state.sessions`. `onDispose` runs after Riverpod has torn the
  // element down, so reading `state` from inside it (or from a stream event
  // that lands after dispose) is refused; this field is what dispose and the
  // watcher's own staleness check use instead.
  Map<DeviceIdentity, ActiveSession> _liveSessions =
      <DeviceIdentity, ActiveSession>{};

  // One in-flight `connect` per device, so a second call while the first is
  // still opening joins it rather than opening a second transport. Also lets
  // `disconnectAll` wait out an open already underway before it tears
  // everything down.
  final Map<DiscoveredDevice, Future<DeviceIdentity>> _connecting =
      <DiscoveredDevice, Future<DeviceIdentity>>{};

  @override
  SessionsState build() {
    ref.onDispose(() {
      for (final sub in _watchers.values) {
        unawaited(sub.cancel());
      }
      for (final entry in _liveSessions.values) {
        unawaited(entry.session.close());
      }
    });
    return const SessionsState();
  }

  void _setState(SessionsState next) {
    state = next;
    _liveSessions = next.sessions;
  }

  /// Opens the transport, runs the handshake, then registers the session
  /// under the identity the handshake produced. Nothing is registered when
  /// the open fails, and the transport is closed by the session itself.
  ///
  /// A second call for the same [device] while the first is still opening
  /// joins that attempt instead of opening a second transport (spec 8.6); a
  /// call for a device already registered under a session returns that
  /// session's identity with no new transport at all.
  ///
  /// When the handshake resolves to an identity another transport already
  /// holds a session for (the same chip, reached a second way), that earlier
  /// session is disconnected first — one session per identity, last connect
  /// wins (spec 7.1).
  ///
  /// A `disconnect`/`disconnectAll` that lands while an open is in flight
  /// does not cancel it: [disconnectAll] waits the attempt out (successful
  /// or not) before deciding what is left to close. Disposing the whole
  /// provider (the app shutting down) does not wait for an in-flight open;
  /// a session that finishes opening after that point is never closed by
  /// this registry.
  Future<DeviceIdentity> connect(DiscoveredDevice device) {
    final existing = state.sessions.entries
        .where((e) => e.value.device == device)
        .firstOrNull;
    if (existing != null) return Future.value(existing.key);

    final inFlight = _connecting[device];
    if (inFlight != null) return inFlight;

    final attempt = _connectNew(device);
    _connecting[device] = attempt;
    // Both branches supplied, and both explicitly `void` (so `then` never
    // tries to chain onto whatever `Map.remove` returns), so this derived
    // future never carries an unhandled error of its own — `attempt` itself
    // still propagates the error to every caller that awaited it from
    // [connect].
    unawaited(
      attempt.then(
        (_) {
          _connecting.remove(device);
        },
        onError: (_) {
          _connecting.remove(device);
        },
      ),
    );
    return attempt;
  }

  Future<DeviceIdentity> _connectNew(DiscoveredDevice device) async {
    final session = DeviceSession(ref.read(transportFactoryProvider)(device));
    try {
      await session.open();
    } on Object {
      await session.close();
      rethrow;
    }
    final identity = await resolveIdentity(session, device);

    // One session per identity (spec 7.1): a session already registered
    // under this identity — reached over a different transport — is
    // superseded by this one.
    if (state.sessions.containsKey(identity)) {
      await disconnect(identity);
    }

    final entry = ActiveSession(
      identity: identity,
      device: device,
      session: session,
    );
    _setState(
      state.copyWith(
        sessions: <DeviceIdentity, ActiveSession>{
          ...state.sessions,
          identity: entry,
        },
      ),
    );
    _watch(entry);
    await ref
        .read(knownDevicesRepositoryProvider)
        .remember(
          identity: identity,
          displayName: device.name,
          kind: device.kind,
          transportId: device.transportId,
        );
    return identity;
  }

  Future<void> disconnect(DeviceIdentity identity) async {
    final entry = state.sessions[identity];
    if (entry == null) return;
    _forget(identity);
    await entry.session.close();
  }

  Future<void> disconnectAll() async {
    if (_connecting.isNotEmpty) {
      // Let every open in flight land — successfully (it registers, and is
      // then closed below) or not (nothing to close) — before deciding
      // what is left to disconnect.
      await Future.wait(
        _connecting.values.map((f) => f.then((_) {}, onError: (_) {})),
      );
    }
    for (final identity in state.sessions.keys.toList()) {
      await disconnect(identity);
    }
  }

  /// Arms [SessionsState.lastDisconnected] for [device] directly, with no
  /// session ever having been registered for it. Used when a silent
  /// reconnect (spec 7.4) finds the device but the reconnect attempt itself
  /// fails: the connect screen still preselects it, exactly as it would for
  /// a link that dropped on its own.
  void markLastDisconnected(DiscoveredDevice device) {
    _setState(state.copyWith(lastDisconnected: device));
  }

  /// Clears and returns the device whose link dropped unexpectedly (spec
  /// 7.4), for the connect screen to preselect once. Null when nothing is
  /// pending.
  DiscoveredDevice? consumeLastDisconnected() {
    final dropped = state.lastDisconnected;
    if (dropped != null) _setState(state.copyWith(lastDisconnected: null));
    return dropped;
  }

  /// A link that dies on its own drops the session; only an unexpected
  /// disconnect (spec 7.4) leaves the device behind for the connect screen
  /// to preselect — a close the app asked for, or one another `connect`
  /// superseded, is not a surprise. A close already routed through
  /// [disconnect] or [_connectNew]'s supersession is handled there: this
  /// listener is only for a session that dies with nobody watching for it.
  ///
  /// The staleness check and the map removal both happen synchronously,
  /// before any `await`, so a second event for the same identity — or a
  /// race with [disconnect] — is inert rather than double-handled.
  void _watch(ActiveSession entry) {
    _watchers[entry.identity] = entry.session.connectionState.changes.listen((
      s,
    ) {
      if (s is! SessionDisconnected) return;
      if (!_liveSessions.containsKey(entry.identity)) return;
      final dropped = s.cause == DisconnectCause.unexpected
          ? entry.device
          : null;
      _forget(entry.identity, dropped: dropped);
      unawaited(entry.session.close());
    });
  }

  /// Removes [identity] from the registry and cancels its watcher. The map
  /// mutation and the subscription removal both happen before the
  /// subscription is actually cancelled, so a caller never observes a
  /// half-forgotten identity.
  void _forget(DeviceIdentity identity, {DiscoveredDevice? dropped}) {
    final sub = _watchers.remove(identity);
    _setState(
      dropped == null
          ? state.copyWith(
              sessions: <DeviceIdentity, ActiveSession>{...state.sessions}
                ..remove(identity),
            )
          : state.copyWith(
              sessions: <DeviceIdentity, ActiveSession>{...state.sessions}
                ..remove(identity),
              lastDisconnected: dropped,
            ),
    );
    unawaited(sub?.cancel());
  }
}

/// The session for one identity (spec 7.1). Null when nothing is connected
/// to that device.
@Riverpod(keepAlive: true)
ActiveSession? deviceSession(Ref ref, DeviceIdentity identity) =>
    ref.watch(sessionsProvider).sessions[identity];
