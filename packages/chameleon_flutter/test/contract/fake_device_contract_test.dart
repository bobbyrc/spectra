import 'package:chameleon/chameleon.dart';

import 'transport_contract.dart';

void main() {
  transportContractTests('FakeDevice', FakeDevice.new);
  transportContractTests(
    'FakeDevice with latency and small chunks',
    () => FakeDevice(latency: const Duration(milliseconds: 1), chunkSize: 8),
  );
}
