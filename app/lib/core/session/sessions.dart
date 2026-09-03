import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/data.dart';
import 'active_session.dart';
import 'session_identity.dart';

part 'sessions.g.dart';

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
  /// screen preselects it (spec 7.4).
  final DiscoveredDevice? lastDisconnected;

  SessionsState copyWith({
    Map<DeviceIdentity, ActiveSession>? sessions,
    DiscoveredDevice? lastDisconnected,
  }) => SessionsState(
    sessions: sessions ?? this.sessions,
    lastDisconnected: lastDisconnected ?? this.lastDisconnected,
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
  // element down, so reading `state` from inside it is refused; this field
  // is what the dispose callback closes instead.
  Map<DeviceIdentity, ActiveSession> _liveSessions =
      <DeviceIdentity, ActiveSession>{};

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
  Future<DeviceIdentity> connect(DiscoveredDevice device) async {
    final existing = state.sessions.entries
        .where((e) => e.value.device == device)
        .firstOrNull;
    if (existing != null) return existing.key;

    final session = DeviceSession(ref.read(transportFactoryProvider)(device));
    try {
      await session.open();
    } on Object {
      await session.close();
      rethrow;
    }
    final identity = await resolveIdentity(session, device);
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
    await _forget(identity);
    await entry.session.close();
  }

  Future<void> disconnectAll() async {
    for (final identity in state.sessions.keys.toList()) {
      await disconnect(identity);
    }
  }

  /// A link that dies on its own drops the session and leaves the device
  /// behind for the connect screen to preselect (spec 7.4). A close the app
  /// asked for is already handled by [disconnect].
  void _watch(ActiveSession entry) {
    _watchers[entry.identity] = entry.session.connectionState.changes.listen((
      s,
    ) async {
      if (s is! SessionDisconnected) return;
      if (!state.sessions.containsKey(entry.identity)) return;
      await _forget(entry.identity, dropped: entry.device);
      await entry.session.close();
    });
  }

  Future<void> _forget(
    DeviceIdentity identity, {
    DiscoveredDevice? dropped,
  }) async {
    await _watchers.remove(identity)?.cancel();
    _setState(
      SessionsState(
        sessions: <DeviceIdentity, ActiveSession>{...state.sessions}
          ..remove(identity),
        lastDisconnected: dropped ?? state.lastDisconnected,
      ),
    );
  }
}

/// The session for one identity (spec 7.1). Null when nothing is connected
/// to that device.
@Riverpod(keepAlive: true)
ActiveSession? deviceSession(Ref ref, DeviceIdentity identity) =>
    ref.watch(sessionsProvider).sessions[identity];
