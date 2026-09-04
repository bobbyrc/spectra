import 'dart:async';

import 'package:chameleon/chameleon.dart';

import '../models/key_dictionary.dart';
import '../models/known_device.dart';
import '../models/saved_card.dart';
import '../repositories.dart';

/// A stream of [snapshot] followed by every value [changes] carries.
///
/// Not `async* { yield snapshot(); yield* changes; }`: that subscribes to
/// [changes] only after the first yield has been *delivered*, which is
/// asynchronous, so a write made between `watchAll()` and the subscriber
/// actually attaching lands on a broadcast controller with no listener and
/// is dropped — the caller then never sees it, because the snapshot it did
/// get was taken before the write. A single-subscription controller's
/// `onListen` runs synchronously inside `listen()`, so the snapshot and the
/// live subscription are both in place before the caller regains control,
/// which is the behaviour Drift's own `watchAll` has.
Stream<T> _snapshotThenChanges<T>(T Function() snapshot, Stream<T> changes) {
  late StreamController<T> controller;
  StreamSubscription<T>? subscription;
  controller = StreamController<T>(
    onListen: () {
      controller.add(snapshot());
      subscription = changes.listen(controller.add, onDone: controller.close);
    },
    onCancel: () => subscription?.cancel(),
  );
  return controller.stream;
}

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
  Stream<List<KnownDevice>> watchAll() =>
      _snapshotThenChanges(() => _sorted(), _changes.stream);

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

/// A [SavedCardsRepository] with no database behind it, for unit tests that
/// are about something else (spec 8.6). Same ordering contract as the Drift
/// one: newest-updated first.
final class InMemorySavedCardsRepository implements SavedCardsRepository {
  final Map<String, SavedCard> _rows = <String, SavedCard>{};
  final StreamController<List<SavedCard>> _changes =
      StreamController<List<SavedCard>>.broadcast();

  @override
  Future<List<SavedCard>> all() async => _sorted();

  @override
  Future<SavedCard?> byId(String id) async => _rows[id];

  @override
  Future<void> save(SavedCard card) async {
    _rows[card.id] = card;
    _emit();
  }

  @override
  Future<void> delete(String id) async {
    _rows.remove(id);
    _emit();
  }

  @override
  Stream<List<SavedCard>> watchAll() =>
      _snapshotThenChanges(() => _sorted(), _changes.stream);

  List<SavedCard> _sorted() =>
      _rows.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  void _emit() {
    if (!_changes.isClosed) _changes.add(_sorted());
  }
}

/// A [DictionariesRepository] with no database behind it, for unit tests
/// that are about something else (spec 8.6). Same ordering contract as the
/// Drift one: newest-updated first.
final class InMemoryDictionariesRepository implements DictionariesRepository {
  final Map<String, KeyDictionary> _rows = <String, KeyDictionary>{};
  final StreamController<List<KeyDictionary>> _changes =
      StreamController<List<KeyDictionary>>.broadcast();

  @override
  Future<List<KeyDictionary>> all() async => _sorted();

  @override
  Future<void> save(KeyDictionary dictionary) async {
    _rows[dictionary.id] = dictionary;
    _emit();
  }

  @override
  Future<void> delete(String id) async {
    _rows.remove(id);
    _emit();
  }

  @override
  Stream<List<KeyDictionary>> watchAll() =>
      _snapshotThenChanges(() => _sorted(), _changes.stream);

  List<KeyDictionary> _sorted() =>
      _rows.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  void _emit() {
    if (!_changes.isClosed) _changes.add(_sorted());
  }
}
