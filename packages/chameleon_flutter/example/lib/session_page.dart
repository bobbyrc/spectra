import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter/material.dart';

/// Opens a transport, runs the handshake and shows what came back, plus a
/// slot rename round trip. Hardware handoff H1 is observed here.
class SessionPage extends StatefulWidget {
  const SessionPage({
    required this.device,
    required this.controlLines,
    super.key,
  });

  final DiscoveredDevice device;
  final SerialControlLineMode controlLines;

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  final List<String> _log = <String>[];
  DeviceSession? _session;

  @override
  void initState() {
    super.initState();
    unawaited(_connect());
  }

  void _say(String line) {
    // ignore: avoid_print
    print('[serial_probe] $line');
    if (mounted) setState(() => _log.add(line));
  }

  Future<void> _connect() async {
    Transport? transport;
    try {
      transport = ChameleonTransports.transportFor(
        widget.device,
        controlLines: widget.controlLines,
      );
      _say('transport: ${transport.runtimeType} (${widget.controlLines.name})');
      final session = DeviceSession(transport);
      _session = session;
      await session.open();
      _say('connection state: ${session.connectionState.value}');
      final info = session.deviceInfo.value;
      _say('device: ${info?.model.name} firmware ${info?.version.label}');
      _say('chip id: ${info?.identity?.chipId ?? '?'}');
    } on ChameleonException catch (e) {
      final guidance = transport is GuidedTransport
          ? (transport as GuidedTransport).guidance?.name
          : null;
      _say('failed: $e${guidance == null ? '' : ' (guidance: $guidance)'}');
    }
  }

  /// H1's slot round trip: rename slot 1's HF nickname, read it back.
  Future<void> _renameSlot() async {
    final session = _session;
    if (session == null) return;
    final nick = 'H1 ${DateTime.now().toIso8601String()}';
    try {
      await session.slots.rename(0, Sense.hf, nick);
      final slots = session.slotsState.value;
      _say('slot 1 nickname now: ${slots.isEmpty ? '?' : slots.first.hfNick}');
      _say(
        slots.isNotEmpty && slots.first.hfNick == nick
            ? 'slot round trip OK'
            : 'slot round trip MISMATCH',
      );
    } on ChameleonException catch (e) {
      _say('slot round trip failed: $e');
    }
  }

  @override
  void dispose() {
    unawaited(_session?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.device.name)),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _renameSlot,
      label: const Text('Rename slot 1'),
      icon: const Icon(Icons.edit),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        for (final line in _log)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SelectableText(line),
          ),
      ],
    ),
  );
}
