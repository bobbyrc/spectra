import 'package:chameleon/chameleon.dart';
import 'package:drift/drift.dart';

import '../models/known_device.dart';
import '../repositories.dart';
import 'spectra_database.dart';

/// Encodes the transport list as `kind:transportId` lines. Read and written
/// whole, so a join table would only add ceremony (spec 7.3).
const String _separator = '\n';

final class DriftKnownDevicesRepository implements KnownDevicesRepository {
  DriftKnownDevicesRepository(this._db);
  final SpectraDatabase _db;

  @override
  Future<List<KnownDevice>> all() async =>
      (await _db.select(_db.knownDevices).get()).map(_toModel).toList();

  @override
  Future<KnownDevice?> byIdentity(DeviceIdentity identity) async {
    final row = await (_db.select(
      _db.knownDevices,
    )..where((t) => t.identity.equals(identity.chipId))).getSingleOrNull();
    return row == null ? null : _toModel(row);
  }

  @override
  Future<KnownDevice?> lastSeen() async {
    final row =
        await (_db.select(_db.knownDevices)
              ..orderBy([(t) => OrderingTerm.desc(t.lastSeen)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toModel(row);
  }

  @override
  Future<void> remember({
    required DeviceIdentity identity,
    required String displayName,
    required TransportKind kind,
    required String transportId,
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    final existing = await byIdentity(identity);
    final transports = <KnownTransport>[
      KnownTransport(kind: kind, transportId: transportId),
      if (existing != null)
        for (final t in existing.transports)
          if (t.kind != kind || t.transportId != transportId) t,
    ];
    await _db
        .into(_db.knownDevices)
        .insertOnConflictUpdate(
          KnownDevicesCompanion.insert(
            identity: identity.chipId,
            displayName: displayName,
            transports: _encode(transports),
            lastSeen: now,
          ),
        );
  }

  @override
  Future<void> forget(DeviceIdentity identity) async {
    await (_db.delete(
      _db.knownDevices,
    )..where((t) => t.identity.equals(identity.chipId))).go();
  }

  @override
  Stream<List<KnownDevice>> watchAll() => _db
      .select(_db.knownDevices)
      .watch()
      .map((rows) => rows.map(_toModel).toList(growable: false));

  // Drift's unix-epoch DateTime storage round-trips the same instant but
  // reads it back in the local zone; normalise to UTC so callers get back
  // exactly what they wrote (`remember`'s [at] defaults to UTC-safe usage
  // throughout the app).
  KnownDevice _toModel(KnownDeviceRow row) => KnownDevice(
    identity: DeviceIdentity(row.identity),
    displayName: row.displayName,
    transports: _decode(row.transports),
    lastSeen: row.lastSeen.toUtc(),
  );

  static String _encode(List<KnownTransport> transports) =>
      transports.map((t) => '${t.kind.name}:${t.transportId}').join(_separator);

  static List<KnownTransport> _decode(String raw) => <KnownTransport>[
    for (final line in raw.split(_separator))
      if (line.contains(':'))
        KnownTransport(
          kind: TransportKind.values.firstWhere(
            (k) => k.name == line.substring(0, line.indexOf(':')),
            orElse: () => TransportKind.usb,
          ),
          transportId: line.substring(line.indexOf(':') + 1),
        ),
  ];
}
