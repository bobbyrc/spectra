// The Spectra transport example.
//
// Lists what every scanner on this platform can see, opens a transport for
// the row you tap, runs a DeviceSession handshake and offers a slot rename
// round trip. This is the app hardware handoff H1 is run from; see
// docs/hardware-checklist.md.

import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter/material.dart';

import 'scan_page.dart';

void main() {
  runApp(const TransportExampleApp());
}

class TransportExampleApp extends StatelessWidget {
  const TransportExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'serial_probe',
    home: ScanPage(
      scanners: ChameleonTransports.defaultScanners(emulator: true),
    ),
  );
}
