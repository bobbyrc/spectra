import 'package:chameleon/chameleon.dart';
import 'package:chameleon_flutter/chameleon_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/dfu/dfu_runtime.dart';
import 'package:spectra/core/flags/feature_flags.dart';
import 'package:spectra/data/memory/in_memory_repositories.dart';
import 'package:spectra/data/repository_providers.dart';

ProviderContainer _container({bool bleEnabled = false}) {
  final container = ProviderContainer(
    overrides: <Override>[
      preferencesRepositoryProvider.overrideWithValue(
        InMemoryPreferencesRepository(),
      ),
      if (bleEnabled)
        featureFlagsProvider.overrideWithValue(
          const FeatureFlags(dfuOverBleEnabled: true),
        ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  const fakeBootloader = DiscoveredDevice(
    name: 'CU',
    kind: TransportKind.fake,
    transportId: 'fake-bootloader',
    isBootloader: true,
  );
  const bleBootloader = DiscoveredDevice(
    name: 'CU',
    kind: TransportKind.ble,
    transportId: 'AA:BB:CC:DD:EE:FF',
    isBootloader: true,
  );

  test('the activity flag starts false and toggles', () {
    final container = _container();
    expect(container.read(dfuActivityProvider), isFalse);
    container.read(dfuActivityProvider.notifier).setRunning(true);
    expect(container.read(dfuActivityProvider), isTrue);
  });

  test('the emulator bootloader is a fake device already in DFU mode', () {
    final container = _container();
    final device = container.read(emulatorBootloaderProvider);
    expect(device.inBootloader, isTrue);
    expect(
      identical(container.read(emulatorBootloaderProvider), device),
      isTrue,
    );
  });

  test('a fake bootloader opens a channel onto that same fake', () async {
    final container = _container();
    final opener = container.read(dfuChannelOpenerProvider);
    final channel = await opener(fakeBootloader);
    expect(channel, isA<FakeDfuChannel>());
    await channel.close();
  });

  test('a BLE bootloader is refused while the flag is off', () async {
    final container = _container();
    final opener = container.read(dfuChannelOpenerProvider);
    expect(() => opener(bleBootloader), throwsA(isA<DfuError>()));
  });

  test('a BLE bootloader opens a BleDfuChannel once the flag is on', () async {
    final container = _container(bleEnabled: true);
    final opener = container.read(dfuChannelOpenerProvider);
    final channel = await opener(bleBootloader);
    expect(channel, isA<BleDfuChannel>());
    await channel.close();
  });

  test('a fake target scans through the fake it will flash', () {
    final container = _container();
    final scanners = container.read(
      dfuScannersProvider(const DfuTarget(bootloader: fakeBootloader)),
    );
    expect(scanners.single, isA<FakeScanner>());
  });
}
