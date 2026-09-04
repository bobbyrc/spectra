import 'dart:async';

import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
// chameleon's ConnectionState (the session state machine) and Flutter's
// ConnectionState (AsyncSnapshot's) share a name; this page only needs the
// former.
import 'package:flutter/material.dart' hide ConnectionState;

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
  ConnectionState? _connectionState;
  StreamSubscription<ConnectionState>? _connectionSub;
  StreamSubscription<DeviceInfo?>? _deviceInfoSub;
  bool _reportedDeviceInfo = false;

  @override
  void initState() {
    super.initState();
    unawaited(_connect());
  }

  void _say(String line) {
    debugPrint('[serial_probe] $line');
    if (mounted) setState(() => _log.add(line));
  }

  String _describe(ConnectionState state) => switch (state) {
    SessionConnecting() => 'connecting',
    SessionReady() => 'ready',
    SessionLimited(:final reason, :final version) =>
      'limited (${reason.name}, firmware ${version?.label ?? 'unknown'})',
    SessionUpdating() => 'updating',
    SessionDisconnected(:final cause, :final error) =>
      'disconnected (${cause.name}${error == null ? '' : ': $error'})',
  };

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

      // Subscribed before open() so no transition — including the ones the
      // handshake makes on its way to SessionReady — is missed, and so the
      // page tracks connectionState live rather than the one-shot value
      // open() happened to return with (a later disconnect shows here too).
      _connectionSub = session.connectionState.changes.listen((state) {
        if (mounted) setState(() => _connectionState = state);
        _say('connection state: ${_describe(state)}');
      });

      // DeviceInfo — and the chip id inside it — is filled in by the
      // session's tolerant background load after SessionReady, not by
      // open() itself, so this has to observe it rather than read
      // deviceInfo.value once open() returns.
      _deviceInfoSub = session.deviceInfo.changes.listen((info) {
        if (info == null || _reportedDeviceInfo) return;
        _reportedDeviceInfo = true;
        _say('device: ${info.model.name} firmware ${info.version.label}');
        _say('chip id: ${info.identity?.chipId ?? '?'}');
      });

      await session.open();
      if (mounted) {
        setState(() => _connectionState = session.connectionState.value);
      }
    } on ChameleonException catch (e) {
      final guidance = transport is GuidedTransport
          ? (transport as GuidedTransport).guidance?.name
          : null;
      _say('failed: $e${guidance == null ? '' : ' (guidance: $guidance)'}');
    }
  }

  /// H1's slot round trip: rename slot 1's HF nickname, then re-read it
  /// from the device (not the SDK's write-through cache) to prove the
  /// write actually reached the firmware.
  Future<void> _renameSlot() async {
    final session = _session;
    if (session == null) return;
    final nick = 'H1 ${DateTime.now().toIso8601String()}';
    try {
      await session.slots.rename(0, Sense.hf, nick);
      _say('slot 1 nickname written: $nick');
      final slots = await session.slots.refresh();
      final readBack = slots.isEmpty ? '?' : slots.first.hfNick;
      _say('slot 1 nickname read back: $readBack');
      _say(
        readBack == nick ? 'slot round trip OK' : 'slot round trip MISMATCH',
      );
    } on ChameleonException catch (e) {
      _say('slot round trip failed: $e');
    }
  }

  @override
  void dispose() {
    unawaited(_connectionSub?.cancel());
    unawaited(_deviceInfoSub?.cancel());
    unawaited(_session?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.device.name),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(24),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            _connectionState == null
                ? 'connecting…'
                : _describe(_connectionState!),
          ),
        ),
      ),
    ),
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
