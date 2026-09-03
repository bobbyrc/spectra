// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lifecycle_host.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(lifecycleController)
final lifecycleControllerProvider = LifecycleControllerProvider._();

final class LifecycleControllerProvider
    extends
        $FunctionalProvider<
          LifecycleController,
          LifecycleController,
          LifecycleController
        >
    with $Provider<LifecycleController> {
  LifecycleControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lifecycleControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lifecycleControllerHash();

  @$internal
  @override
  $ProviderElement<LifecycleController> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LifecycleController create(Ref ref) {
    return lifecycleController(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LifecycleController value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LifecycleController>(value),
    );
  }
}

String _$lifecycleControllerHash() =>
    r'd94c47665ed5d1efa6315f5d96d64ade03b8c13a';
