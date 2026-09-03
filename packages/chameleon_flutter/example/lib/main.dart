// Spike A probe (Phase 0, task 7).
//
// Enumerates serial ports through `libserialport_plus` and shows each port's
// name, description, manufacturer and USB VID/PID. The purpose is to prove the
// package's build hook compiles libserialport on macOS, Windows and Linux and
// that enumeration runs. Phase 3 replaces this with the real transport example.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:libserialport_plus/libserialport_plus.dart';

void main() {
  runApp(const SerialProbeApp());
}

/// One enumerated port, flattened to strings for display.
class ProbeResult {
  const ProbeResult(this.line);
  final String line;
}

String _hex16(int? value) =>
    value == null ? '?' : '0x${value.toRadixString(16).padLeft(4, '0')}';

/// Enumerates every serial port the platform reports.
///
/// Enumeration call: `SerialPort.getAvailablePorts()` for the names, then
/// `SerialPort(name).getInfo()` for description, manufacturer and USB
/// VID/PID (`SerialPortInfo.usbVid` / `.usbPid` / `.usbManufacturer`).
List<ProbeResult> probeSerialPorts() {
  if (Platform.isIOS) {
    return const [ProbeResult('serial unsupported on this platform')];
  }
  final List<String> names;
  try {
    names = SerialPort.getAvailablePorts();
  } on SerialPortException catch (error) {
    return [ProbeResult('enumeration failed: ${error.code} ${error.message}')];
  }
  if (names.isEmpty) {
    return const [ProbeResult('no serial ports found')];
  }
  final results = <ProbeResult>[];
  for (final name in names) {
    final port = SerialPort(name);
    try {
      final info = port.getInfo();
      results.add(
        ProbeResult(
          '${info.name} | ${info.description} | ${info.transport.name} | '
          'vid=${_hex16(info.usbVid)} pid=${_hex16(info.usbPid)} | '
          'mfr=${info.usbManufacturer ?? '?'} '
          'product=${info.usbProduct ?? '?'}',
        ),
      );
    } on SerialPortException catch (error) {
      results.add(ProbeResult('$name | info failed: ${error.message}'));
    } finally {
      port.dispose();
    }
  }
  return results;
}

class SerialProbeApp extends StatefulWidget {
  const SerialProbeApp({super.key});

  @override
  State<SerialProbeApp> createState() => _SerialProbeAppState();
}

class _SerialProbeAppState extends State<SerialProbeApp> {
  List<ProbeResult> _results = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final results = probeSerialPorts();
    for (final result in results) {
      debugPrint('[serial_probe] ${result.line}');
    }
    setState(() => _results = results);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'serial_probe',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('serial_probe'),
          actions: [
            IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Re-enumerate',
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final result in _results)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SelectableText(result.line),
              ),
          ],
        ),
      ),
    );
  }
}
