// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firmware_package_source.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(firmwarePackageSource)
final firmwarePackageSourceProvider = FirmwarePackageSourceProvider._();

final class FirmwarePackageSourceProvider
    extends
        $FunctionalProvider<
          FirmwarePackageSource,
          FirmwarePackageSource,
          FirmwarePackageSource
        >
    with $Provider<FirmwarePackageSource> {
  FirmwarePackageSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'firmwarePackageSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$firmwarePackageSourceHash();

  @$internal
  @override
  $ProviderElement<FirmwarePackageSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FirmwarePackageSource create(Ref ref) {
    return firmwarePackageSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FirmwarePackageSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FirmwarePackageSource>(value),
    );
  }
}

String _$firmwarePackageSourceHash() =>
    r'720dfab32a4a88ac0ddf22294096cd4a0d60ccf6';
