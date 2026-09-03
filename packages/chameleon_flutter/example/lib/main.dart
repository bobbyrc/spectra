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

String _hex16(int? value) =>
    value == null ? '?' : '0x${value.toRadixString(16).padLeft(4, '0')}';

/// Enumerates every serial port the platform reports, one display line each.
///
/// Enumeration call: `SerialPort.getAvailablePorts()` for the names, then
/// `SerialPort(name).getInfo()` for description, manufacturer and USB
/// VID/PID (`SerialPortInfo.usbVid` / `.usbPid` / `.usbManufacturer`).
List<String> probeSerialPorts() {
  if (Platform.isIOS) {
    return const ['serial unsupported on this platform'];
  }
  final List<String> names;
  try {
    names = SerialPort.getAvailablePorts();
  } on SerialPortException catch (error) {
    return ['enumeration failed: ${error.code} ${error.message}'];
  }
  if (names.isEmpty) {
    return const ['no serial ports found'];
  }
  final lines = <String>[];
  for (final name in names) {
    final port = SerialPort(name);
    try {
      final info = port.getInfo();
      lines.add(
        '${info.name} | ${info.description} | ${info.transport.name} | '
        'vid=${_hex16(info.usbVid)} pid=${_hex16(info.usbPid)} | '
        'mfr=${info.usbManufacturer ?? '?'} '
        'product=${info.usbProduct ?? '?'}',
      );
    } on SerialPortException catch (error) {
      lines.add('$name | info failed: ${error.message}');
    } finally {
      port.dispose();
    }
  }
  return lines;
}

class SerialProbeApp extends StatefulWidget {
  const SerialProbeApp({super.key});

  @override
  State<SerialProbeApp> createState() => _SerialProbeAppState();
}

class _SerialProbeAppState extends State<SerialProbeApp> {
  List<String> _lines = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final lines = probeSerialPorts();
    for (final line in lines) {
      debugPrint('[serial_probe] $line');
    }
    setState(() => _lines = lines);
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
            for (final line in _lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SelectableText(line),
              ),
          ],
        ),
      ),
    );
  }
}
