// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feature_flags.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(FeatureFlagsController)
final featureFlagsControllerProvider = FeatureFlagsControllerProvider._();

final class FeatureFlagsControllerProvider
    extends $AsyncNotifierProvider<FeatureFlagsController, FeatureFlags> {
  FeatureFlagsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featureFlagsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$featureFlagsControllerHash();

  @$internal
  @override
  FeatureFlagsController create() => FeatureFlagsController();
}

String _$featureFlagsControllerHash() =>
    r'6caeab060ed102d61462da3495ed78fe234c6192';

abstract class _$FeatureFlagsController extends $AsyncNotifier<FeatureFlags> {
  FutureOr<FeatureFlags> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<FeatureFlags>, FeatureFlags>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<FeatureFlags>, FeatureFlags>,
              AsyncValue<FeatureFlags>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Flags as a plain value. Everything off until the load finishes, which is
/// the safe direction for every flag in this file.

@ProviderFor(featureFlags)
final featureFlagsProvider = FeatureFlagsProvider._();

/// Flags as a plain value. Everything off until the load finishes, which is
/// the safe direction for every flag in this file.

final class FeatureFlagsProvider
    extends $FunctionalProvider<FeatureFlags, FeatureFlags, FeatureFlags>
    with $Provider<FeatureFlags> {
  /// Flags as a plain value. Everything off until the load finishes, which is
  /// the safe direction for every flag in this file.
  FeatureFlagsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featureFlagsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$featureFlagsHash();

  @$internal
  @override
  $ProviderElement<FeatureFlags> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FeatureFlags create(Ref ref) {
    return featureFlags(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FeatureFlags value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FeatureFlags>(value),
    );
  }
}

String _$featureFlagsHash() => r'5c8e18c6689865bfe219d59ee31153dfebf3d5e1';
