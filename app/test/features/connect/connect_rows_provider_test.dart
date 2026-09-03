import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/discovery/discovery_provider.dart';
import 'package:spectra/core/discovery/scanners.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/data/memory/in_memory_repositories.dart';
import 'package:spectra/features/connect/connect.dart';

import '../../support/app_harness.dart';

void main() {
  test('a manual port is one row with one device, not two', () async {
    final container = ProviderContainer(
      overrides: [
        knownDevicesRepositoryProvider.overrideWithValue(
          InMemoryKnownDevicesRepository(),
        ),
        scannersProvider.overrideWithValue(<DeviceScanner>[
          const StaticScanner(<DiscoveredDevice>[]),
        ]),
      ],
    );
    addTearDown(container.dispose);
    // Discovery only runs while something listens (ruling 20), and it is
    // discovery that folds the manual ports in.
    final sub = container.listen(discoveryProvider, (_, _) {});
    addTearDown(sub.close);
    final rows = container.listen(connectRowsProvider, (_, _) {});
    addTearDown(rows.close);

    container.read(manualPortsProvider.notifier).add('/dev/cu.usbmodem1');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final List<ConnectRow> result = container.read(connectRowsProvider);
    expect(result, hasLength(1));
    expect(
      result.single.devices,
      hasLength(1),
      reason: 'discovery already unions the manual ports in',
    );
  });
}
