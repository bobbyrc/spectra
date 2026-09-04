import 'dart:async';

import 'package:chameleon/chameleon.dart';

import 'transport_contract.dart';

void _drop(Transport t) => unawaited((t as FakeDevice).simulateLinkLoss());

void main() {
  transportContractTests('FakeDevice', FakeDevice.new, simulateLinkLoss: _drop);
  transportContractTests(
    'FakeDevice with latency and small chunks',
    () => FakeDevice(latency: const Duration(milliseconds: 1), chunkSize: 8),
    simulateLinkLoss: _drop,
  );
}
