import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/core/flags/feature_flags.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/data/memory/in_memory_repositories.dart';

ProviderContainer containerWith(InMemoryPreferencesRepository prefs) {
  final container = ProviderContainer(
    overrides: [preferencesRepositoryProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('dfuOverBleEnabled defaults to off', () async {
    final container = containerWith(InMemoryPreferencesRepository());
    final flags = await container.read(featureFlagsControllerProvider.future);
    expect(flags.dfuOverBleEnabled, isFalse);
  });

  test('the synchronous view is all-off before preferences load', () {
    final container = containerWith(InMemoryPreferencesRepository());
    expect(container.read(featureFlagsProvider).dfuOverBleEnabled, isFalse);
  });

  test('a stored true is read back on the next build', () async {
    final prefs = InMemoryPreferencesRepository();
    await prefs.write(FeatureFlags.dfuOverBleKey, 'true');
    final container = containerWith(prefs);
    final flags = await container.read(featureFlagsControllerProvider.future);
    expect(flags.dfuOverBleEnabled, isTrue);
  });

  test('setting the flag persists it and updates the state', () async {
    final prefs = InMemoryPreferencesRepository();
    final container = containerWith(prefs);
    await container.read(featureFlagsControllerProvider.future);
    await container
        .read(featureFlagsControllerProvider.notifier)
        .setDfuOverBleEnabled(true);
    expect(await prefs.read(FeatureFlags.dfuOverBleKey), 'true');
    expect(container.read(featureFlagsProvider).dfuOverBleEnabled, isTrue);
  });
}
