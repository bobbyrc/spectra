import 'dart:async';

import 'package:chameleon/chameleon.dart';

import '../models/known_device.dart';
import '../repositories.dart';

/// Repository implementations with no database behind them, for unit tests
/// that are about something else (spec 8.6).
final class InMemoryKnownDevicesRepository implements KnownDevicesRepository {
  final Map<String, KnownDevice> _rows = <String, KnownDevice>{};
  final StreamController<List<KnownDevice>> _changes =
      StreamController<List<KnownDevice>>.broadcast();

  @override
  Future<List<KnownDevice>> all() async => _sorted();

  @override
  Future<KnownDevice?> byIdentity(DeviceIdentity identity) async =>
      _rows[identity.chipId];

  @override
  Future<KnownDevice?> lastSeen() async {
    final rows = _sorted();
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<void> remember({
    required DeviceIdentity identity,
    required String displayName,
    required TransportKind kind,
    required String transportId,
    DateTime? at,
  }) async {
    final existing = _rows[identity.chipId];
    _rows[identity.chipId] = KnownDevice(
      identity: identity,
      displayName: displayName,
      transports: <KnownTransport>[
        KnownTransport(kind: kind, transportId: transportId),
        if (existing != null)
          for (final t in existing.transports)
            if (t.kind != kind || t.transportId != transportId) t,
      ],
      lastSeen: at ?? DateTime.now(),
    );
    _emit();
  }

  @override
  Future<void> forget(DeviceIdentity identity) async {
    _rows.remove(identity.chipId);
    _emit();
  }

  @override
  Stream<List<KnownDevice>> watchAll() async* {
    yield _sorted();
    yield* _changes.stream;
  }

  List<KnownDevice> _sorted() =>
      _rows.values.toList()..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));

  void _emit() {
    if (!_changes.isClosed) _changes.add(_sorted());
  }
}

/// A [PreferencesRepository] with no database behind it, for unit tests that
/// are about something else (spec 8.6).
final class InMemoryPreferencesRepository implements PreferencesRepository {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}
