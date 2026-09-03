// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wakelock.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The gateway seam as a provider, so a widget test can stub the plugin
/// out at the app root instead of every test tripping over a real method
/// channel.

@ProviderFor(wakelockGateway)
final wakelockGatewayProvider = WakelockGatewayProvider._();

/// The gateway seam as a provider, so a widget test can stub the plugin
/// out at the app root instead of every test tripping over a real method
/// channel.

final class WakelockGatewayProvider
    extends
        $FunctionalProvider<WakelockGateway, WakelockGateway, WakelockGateway>
    with $Provider<WakelockGateway> {
  /// The gateway seam as a provider, so a widget test can stub the plugin
  /// out at the app root instead of every test tripping over a real method
  /// channel.
  WakelockGatewayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wakelockGatewayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wakelockGatewayHash();

  @$internal
  @override
  $ProviderElement<WakelockGateway> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WakelockGateway create(Ref ref) {
    return wakelockGateway(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WakelockGateway value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WakelockGateway>(value),
    );
  }
}

String _$wakelockGatewayHash() => r'8732fb0b33bb1ee5d204948e8a98c66a0c856959';

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

String _$wakelockHash() => r'7d856c635714d1cd009c12152b242594caa17fb7';
