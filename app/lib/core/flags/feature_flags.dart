import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/data.dart';

part 'feature_flags.g.dart';

/// Flags that gate work the user's hardware has not validated yet
/// (roadmap, hardware handoffs).
final class FeatureFlags {
  const FeatureFlags({this.dfuOverBleEnabled = false});

  /// BLE and iOS DFU are built in full but stay off until the user reports
  /// hardware handoff H2 passed. Phase 8 reads this; nothing flips it here.
  final bool dfuOverBleEnabled;

  static const String dfuOverBleKey = 'flag.dfuOverBleEnabled';

  FeatureFlags copyWith({bool? dfuOverBleEnabled}) => FeatureFlags(
    dfuOverBleEnabled: dfuOverBleEnabled ?? this.dfuOverBleEnabled,
  );
}

@Riverpod(keepAlive: true)
class FeatureFlagsController extends _$FeatureFlagsController {
  @override
  Future<FeatureFlags> build() async {
    final prefs = ref.watch(preferencesRepositoryProvider);
    return FeatureFlags(
      dfuOverBleEnabled: await prefs.read(FeatureFlags.dfuOverBleKey) == 'true',
    );
  }

  Future<void> setDfuOverBleEnabled(bool enabled) async {
    await ref
        .read(preferencesRepositoryProvider)
        .write(FeatureFlags.dfuOverBleKey, '$enabled');
    state = AsyncData(
      (state.value ?? const FeatureFlags()).copyWith(
        dfuOverBleEnabled: enabled,
      ),
    );
  }
}

/// Flags as a plain value. Everything off until the load finishes, which is
/// the safe direction for every flag in this file.
@Riverpod(keepAlive: true)
FeatureFlags featureFlags(Ref ref) =>
    ref.watch(featureFlagsControllerProvider).value ?? const FeatureFlags();
