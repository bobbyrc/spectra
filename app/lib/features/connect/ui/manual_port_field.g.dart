// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manual_port_field.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Injection seam for `currentHostPlatform()` (`chameleon_flutter` reads the
/// real OS directly and takes no parameter, so there is nothing to override
/// there). [ManualPortField] is the only widget that needs to know the host
/// platform, so the seam lives beside it rather than in
/// `core/discovery/scanners.dart`'s `scannerPlatformProvider` family, which
/// feeds `ChameleonTransports.defaultScanners` a different parameter
/// (`HostPlatform?`, `null` meaning "ask the OS") for an unrelated purpose.
/// A test overrides this provider directly to exercise both branches of
/// [ManualPortField.build] without depending on the host the suite runs on.

@ProviderFor(hostPlatform)
final hostPlatformProvider = HostPlatformProvider._();

/// Injection seam for `currentHostPlatform()` (`chameleon_flutter` reads the
/// real OS directly and takes no parameter, so there is nothing to override
/// there). [ManualPortField] is the only widget that needs to know the host
/// platform, so the seam lives beside it rather than in
/// `core/discovery/scanners.dart`'s `scannerPlatformProvider` family, which
/// feeds `ChameleonTransports.defaultScanners` a different parameter
/// (`HostPlatform?`, `null` meaning "ask the OS") for an unrelated purpose.
/// A test overrides this provider directly to exercise both branches of
/// [ManualPortField.build] without depending on the host the suite runs on.

final class HostPlatformProvider
    extends $FunctionalProvider<HostPlatform, HostPlatform, HostPlatform>
    with $Provider<HostPlatform> {
  /// Injection seam for `currentHostPlatform()` (`chameleon_flutter` reads the
  /// real OS directly and takes no parameter, so there is nothing to override
  /// there). [ManualPortField] is the only widget that needs to know the host
  /// platform, so the seam lives beside it rather than in
  /// `core/discovery/scanners.dart`'s `scannerPlatformProvider` family, which
  /// feeds `ChameleonTransports.defaultScanners` a different parameter
  /// (`HostPlatform?`, `null` meaning "ask the OS") for an unrelated purpose.
  /// A test overrides this provider directly to exercise both branches of
  /// [ManualPortField.build] without depending on the host the suite runs on.
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
