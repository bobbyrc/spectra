// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_device.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Names the one session the UI is showing (spec 7.1). Features read
/// [activeSessionProvider] and never reach into [sessionsProvider].

@ProviderFor(ActiveDevice)
final activeDeviceProvider = ActiveDeviceProvider._();

/// Names the one session the UI is showing (spec 7.1). Features read
/// [activeSessionProvider] and never reach into [sessionsProvider].
final class ActiveDeviceProvider
    extends $NotifierProvider<ActiveDevice, DeviceIdentity?> {
  /// Names the one session the UI is showing (spec 7.1). Features read
  /// [activeSessionProvider] and never reach into [sessionsProvider].
  ActiveDeviceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeDeviceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeDeviceHash();

  @$internal
  @override
  ActiveDevice create() => ActiveDevice();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeviceIdentity? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeviceIdentity?>(value),
    );
  }
}

String _$activeDeviceHash() => r'6ceb04a1cfe5cfdf18b3cea96ed5942373ccb56c';

/// Names the one session the UI is showing (spec 7.1). Features read
/// [activeSessionProvider] and never reach into [sessionsProvider].

abstract class _$ActiveDevice extends $Notifier<DeviceIdentity?> {
  DeviceIdentity? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DeviceIdentity?, DeviceIdentity?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DeviceIdentity?, DeviceIdentity?>,
              DeviceIdentity?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(activeSession)
final activeSessionProvider = ActiveSessionProvider._();

final class ActiveSessionProvider
    extends $FunctionalProvider<ActiveSession?, ActiveSession?, ActiveSession?>
    with $Provider<ActiveSession?> {
  ActiveSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeSessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeSessionHash();

  @$internal
  @override
  $ProviderElement<ActiveSession?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ActiveSession? create(Ref ref) {
    return activeSession(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ActiveSession? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ActiveSession?>(value),
    );
  }
}

String _$activeSessionHash() => r'465273bde2312c99d09edc728c809d1d5ad9c320';
