// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'host_platform_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Injection seam for `currentHostPlatform()` (`chameleon_flutter` reads the
/// real OS directly and takes no parameter, so there is nothing to override
/// there). A test overrides this provider to exercise a platform's branch
/// without depending on the host the suite runs on.
///
/// Distinct from `core/discovery/scanners.dart`'s `scannerPlatformProvider`
/// family, which feeds `ChameleonTransports.defaultScanners` a different
/// parameter (`HostPlatform?`, `null` meaning "ask the OS") for an unrelated
/// purpose.

@ProviderFor(hostPlatform)
final hostPlatformProvider = HostPlatformProvider._();

/// Injection seam for `currentHostPlatform()` (`chameleon_flutter` reads the
/// real OS directly and takes no parameter, so there is nothing to override
/// there). A test overrides this provider to exercise a platform's branch
/// without depending on the host the suite runs on.
///
/// Distinct from `core/discovery/scanners.dart`'s `scannerPlatformProvider`
/// family, which feeds `ChameleonTransports.defaultScanners` a different
/// parameter (`HostPlatform?`, `null` meaning "ask the OS") for an unrelated
/// purpose.

final class HostPlatformProvider
    extends $FunctionalProvider<HostPlatform, HostPlatform, HostPlatform>
    with $Provider<HostPlatform> {
  /// Injection seam for `currentHostPlatform()` (`chameleon_flutter` reads the
  /// real OS directly and takes no parameter, so there is nothing to override
  /// there). A test overrides this provider to exercise a platform's branch
  /// without depending on the host the suite runs on.
  ///
  /// Distinct from `core/discovery/scanners.dart`'s `scannerPlatformProvider`
  /// family, which feeds `ChameleonTransports.defaultScanners` a different
  /// parameter (`HostPlatform?`, `null` meaning "ask the OS") for an unrelated
  /// purpose.
  HostPlatformProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hostPlatformProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hostPlatformHash();

  @$internal
  @override
  $ProviderElement<HostPlatform> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HostPlatform create(Ref ref) {
    return hostPlatform(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HostPlatform value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HostPlatform>(value),
    );
  }
}

String _$hostPlatformHash() => r'71e756231a717641641b3423f2bf6e1f58dc704f';
