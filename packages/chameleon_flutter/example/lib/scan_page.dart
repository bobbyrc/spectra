import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter/material.dart';

import 'session_page.dart';

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
  late final StreamSubscription<List<DiscoveredDevice>> _scanSub;

  List<DiscoveredDevice> _devices = const <DiscoveredDevice>[];

  // Kept separate from _devices so a scanner error (BLE off, no
  // permission, ...) shows as a banner above whatever the other scanners
  // are still producing, instead of blanking the whole list.
  Object? _scanError;

  @override
  void initState() {
    super.initState();
    _scanSub = _scan.listen(
      (devices) {
        debugPrint(
          '[serial_probe] scan: '
          '${devices.map((d) => '${d.name} (${d.kind.name} ${d.transportId}'
              '${d.isBootloader ? ' bootloader' : ''})').join(', ')}',
        );
        if (!mounted) return;
        // Deliberately doesn't clear _scanError: a scanner that has
        // already errored (Stream.error terminates the stream) will never
        // contribute again, so the banner should stay up until dismissed,
        // even while the other scanner keeps producing rows below it.
        setState(() => _devices = devices);
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('[serial_probe] scan error: $error');
        if (!mounted) return;
        setState(() => _scanError = error);
      },
    );
  }

  @override
  void dispose() {
    unawaited(_scanSub.cancel());
    super.dispose();
  }

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
    body: Column(
      children: <Widget>[
        if (_scanError != null)
          MaterialBanner(
            content: Text('Scan failed: $_scanError'),
            actions: <Widget>[
              TextButton(
                onPressed: () => setState(() => _scanError = null),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        Expanded(
          child: _devices.isEmpty
              ? const Center(child: Text('No devices found'))
              : ListView(
                  children: <Widget>[
                    for (final device in _devices)
                      ListTile(
                        title: Text(device.name),
                        subtitle: Text(
                          '${device.kind.name} · ${device.transportId}',
                        ),
                        trailing: device.isBootloader
                            ? const Chip(label: Text('bootloader'))
                            : null,
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => SessionPage(
                              device: device,
                              controlLines: _mode,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    ),
  );
}
