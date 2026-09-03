// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wakelock.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(wakelock)
final wakelockProvider = WakelockProvider._();

final class WakelockProvider
    extends
        $FunctionalProvider<
          WakelockController,
          WakelockController,
          WakelockController
        >
    with $Provider<WakelockController> {
  WakelockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wakelockProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wakelockHash();

  @$internal
  @override
  $ProviderElement<WakelockController> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WakelockController create(Ref ref) {
    return wakelock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WakelockController value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WakelockController>(value),
    );
  }
}

String _$wakelockHash() => r'b92bbba6f1406246a9a97705c90cf41f27c4832d';
