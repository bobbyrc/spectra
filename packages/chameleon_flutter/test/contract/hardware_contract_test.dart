@Tags(<String>['hardware'])
library;

import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'transport_contract.dart';

/// The same contract, against a device that is actually attached.
///
/// Skipped unless run as `flutter test --tags hardware` with a Chameleon
/// plugged in. Nothing here is proof of anything until the user reports
/// hardware handoff H1; see docs/hardware-checklist.md.
///
/// Set SPECTRA_SERIAL_CONTROL_LINES=hardwareFlowControl to run the suite in
/// the other control-line mode; H1 asks the user which one works.
void main() {
  final adapter = defaultSerialPortAdapter();
  if (adapter == null) {
    test('no serial stack on this platform', () {}, skip: true);
    return;
  }

  final mode =
      const String.fromEnvironment('SPECTRA_SERIAL_CONTROL_LINES') ==
          'hardwareFlowControl'
      ? SerialControlLineMode.hardwareFlowControl
      : SerialControlLineMode.dtrOnly;

  late List<DiscoveredDevice> found;

  setUpAll(() async {
    found = await SerialScanner(adapter: adapter).enumerate();
  });

  test('a Chameleon is attached over USB', () {
    expect(
      found,
      isNotEmpty,
      reason: 'plug in a Chameleon Ultra before running --tags hardware',
    );
    // ignore: avoid_print
    print('hardware: found ${found.map((d) => d.transportId).join(', ')}');
  });

  transportContractTests(
    'SerialTransport on real hardware (${mode.name})',
    () => SerialTransport(
      path: found.firstWhere((d) => !d.isBootloader).transportId,
      adapter: adapter,
      controlLines: mode,
    ),
  );
}
