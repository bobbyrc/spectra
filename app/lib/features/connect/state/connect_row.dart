import 'package:chameleon/chameleon.dart';

import '../../../data/data.dart';

/// One device on the connect screen. A device reachable over both USB and
/// BLE is one row with two transport badges (spec 4.2).
final class ConnectRow {
  const ConnectRow({
    required this.key,
    required this.name,
    required this.devices,
    required this.isBootloader,
    this.identity,
    this.lastSeen,
    this.isPreselected = false,
  });

  final String key;
  final String name;
  final List<DiscoveredDevice> devices;
  final bool isBootloader;
  final DeviceIdentity? identity;
  final DateTime? lastSeen;

  /// True for the row holding the device whose link just dropped
  /// unexpectedly (spec 7.4) — the row the connect screen sorts first and
  /// highlights. Set by [mergeConnectRows]'s `preselect` argument; this
  /// state layer never reconnects on its own.
  final bool isPreselected;

  bool get isKnown => identity != null;

  List<TransportKind> get kinds =>
      devices.map((d) => d.kind).toSet().toList(growable: false);

  /// USB first: it is faster and needs no pairing. The fake comes last, so a
  /// real device is never shadowed by the emulator.
  DiscoveredDevice get preferred {
    for (final kind in const <TransportKind>[
      TransportKind.usb,
      TransportKind.ble,
      TransportKind.fake,
    ]) {
      final match = devices.where((d) => d.kind == kind).firstOrNull;
      if (match != null) return match;
    }
    return devices.first;
  }
}

/// Spec 4.2: entries merge by identity when the identity is known, and by
/// name plus transport kind otherwise. A device in the bootloader never
/// merges with an application device — it is a different thing to connect to
/// (spec 5.5).
///
/// [preselect] (spec 7.4) is the device whose link just dropped
/// unexpectedly, if any: the row it lands in sorts first and carries
/// [ConnectRow.isPreselected]. It does not otherwise change how rows merge.
List<ConnectRow> mergeConnectRows({
  required List<DiscoveredDevice> discovered,
  required List<KnownDevice> known,
  DiscoveredDevice? preselect,
}) {
  final groups = <String, List<DiscoveredDevice>>{};
  final identities = <String, KnownDevice>{};

  for (final device in discovered) {
    final match = device.isBootloader
        ? null
        : known.where((k) => k.matches(device)).firstOrNull;
    final key = match != null
        ? 'id:${match.identity.chipId}'
        : 'name:${device.name}|${device.kind.name}|${device.isBootloader}';
    groups.putIfAbsent(key, () => <DiscoveredDevice>[]).add(device);
    if (match != null) identities[key] = match;
  }

  final rows = <ConnectRow>[
    for (final entry in groups.entries)
      ConnectRow(
        key: entry.key,
        name: identities[entry.key]?.displayName ?? entry.value.first.name,
        devices: List<DiscoveredDevice>.unmodifiable(entry.value),
        isBootloader: entry.value.first.isBootloader,
        identity: identities[entry.key]?.identity,
        lastSeen: identities[entry.key]?.lastSeen,
        isPreselected: preselect != null && entry.value.contains(preselect),
      ),
  ];

  // The preselected row (spec 7.4) sorts first, then known devices, newest
  // first, then everything else by name — so "the one that just dropped" or
  // "the one I used yesterday" is always the top row.
  rows.sort((a, b) {
    if (a.isPreselected != b.isPreselected) return a.isPreselected ? -1 : 1;
    if (a.isKnown != b.isKnown) return a.isKnown ? -1 : 1;
    if (a.isKnown && b.isKnown) {
      final byLastSeen = b.lastSeen!.compareTo(a.lastSeen!);
      // Drift stores `lastSeen` at second precision, so two devices
      // remembered in the same second tie; the key breaks it, so the order
      // is at least stable from one rebuild to the next.
      if (byLastSeen != 0) return byLastSeen;
      return a.key.compareTo(b.key);
    }
    return a.name.compareTo(b.name);
  });
  return List<ConnectRow>.unmodifiable(rows);
}
