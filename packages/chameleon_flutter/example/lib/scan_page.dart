import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter/material.dart';

import 'session_page.dart';

/// The union of every scanner's latest result list, de-duplicated by
/// [DiscoveredDevice] identity (transport kind plus transport id) — the
/// merge the connect screen will do properly in Phase 4 (spec 4.2).
Stream<List<DiscoveredDevice>> mergedScan(List<DeviceScanner> scanners) {
  final latest = <int, List<DiscoveredDevice>>{};
  final controller = StreamController<List<DiscoveredDevice>>();
  final subs = <StreamSubscription<List<DiscoveredDevice>>>[];

  controller.onListen = () {
    for (var i = 0; i < scanners.length; i++) {
      final index = i;
      subs.add(
        scanners[i].scan().listen((devices) {
          latest[index] = devices;
          final merged = <DiscoveredDevice, DiscoveredDevice>{};
          for (final list in latest.values) {
            for (final d in list) {
              merged[d] = d;
            }
          }
          if (!controller.isClosed) {
            controller.add(List<DiscoveredDevice>.unmodifiable(merged.values));
          }
        }, onError: (Object e, StackTrace s) => controller.addError(e, s)),
      );
    }
  };
  controller.onCancel = () async {
    for (final s in subs) {
      await s.cancel();
    }
    await controller.close();
  };
  return controller.stream;
}

class ScanPage extends StatefulWidget {
  const ScanPage({required this.scanners, super.key});

  final List<DeviceScanner> scanners;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  SerialControlLineMode _mode = SerialControlLineMode.dtrOnly;

  // Created once, not per build (a fresh merge would re-subscribe every
  // scanner on every rebuild, dropping and rebuilding connections for no
  // reason).
  late final Stream<List<DiscoveredDevice>> _scan = mergedScan(widget.scanners);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('serial_probe'),
      actions: <Widget>[
        DropdownButton<SerialControlLineMode>(
          value: _mode,
          onChanged: (m) => setState(() => _mode = m ?? _mode),
          items: <DropdownMenuItem<SerialControlLineMode>>[
            for (final m in SerialControlLineMode.values)
              DropdownMenuItem<SerialControlLineMode>(
                value: m,
                child: Text(m.name),
              ),
          ],
        ),
      ],
    ),
    body: StreamBuilder<List<DiscoveredDevice>>(
      stream: _scan,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: SelectableText('Scan failed: ${snapshot.error}'),
          );
        }
        final devices = snapshot.data ?? const <DiscoveredDevice>[];
        if (devices.isEmpty) {
          return const Center(child: Text('No devices found'));
        }
        return ListView(
          children: <Widget>[
            for (final device in devices)
              ListTile(
                title: Text(device.name),
                subtitle: Text('${device.kind.name} · ${device.transportId}'),
                trailing: device.isBootloader
                    ? const Chip(label: Text('bootloader'))
                    : null,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        SessionPage(device: device, controlLines: _mode),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
