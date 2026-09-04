// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dfu_runtime.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// True while a flash is running. Spec 7.4 and 5.6: the app holds a wakelock
/// and blocks navigation for as long as this is set. Lives in core because
/// two core rules (the router's redirect, the wakelock controller) read it
/// and the feature that sets it must not be imported by either.

@ProviderFor(DfuActivity)
final dfuActivityProvider = DfuActivityProvider._();

/// True while a flash is running. Spec 7.4 and 5.6: the app holds a wakelock
/// and blocks navigation for as long as this is set. Lives in core because
/// two core rules (the router's redirect, the wakelock controller) read it
/// and the feature that sets it must not be imported by either.
final class DfuActivityProvider extends $NotifierProvider<DfuActivity, bool> {
  /// True while a flash is running. Spec 7.4 and 5.6: the app holds a wakelock
  /// and blocks navigation for as long as this is set. Lives in core because
  /// two core rules (the router's redirect, the wakelock controller) read it
  /// and the feature that sets it must not be imported by either.
  DfuActivityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dfuActivityProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dfuActivityHash();

  @$internal
  @override
  DfuActivity create() => DfuActivity();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$dfuActivityHash() => r'b28970f4d0358c967ee802ef76502496c7d24451';

/// True while a flash is running. Spec 7.4 and 5.6: the app holds a wakelock
/// and blocks navigation for as long as this is set. Lives in core because
/// two core rules (the router's redirect, the wakelock controller) read it
/// and the feature that sets it must not be imported by either.

abstract class _$DfuActivity extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Budget for each of `DfuOrchestrator`'s scans and for the reboot before the
/// first of them. A seam so a widget test does not sit out 30 seconds when a
/// scan is meant to fail.

@ProviderFor(dfuScanTimeout)
final dfuScanTimeoutProvider = DfuScanTimeoutProvider._();

/// Budget for each of `DfuOrchestrator`'s scans and for the reboot before the
/// first of them. A seam so a widget test does not sit out 30 seconds when a
/// scan is meant to fail.

final class DfuScanTimeoutProvider
    extends $FunctionalProvider<Duration, Duration, Duration>
    with $Provider<Duration> {
  /// Budget for each of `DfuOrchestrator`'s scans and for the reboot before the
  /// first of them. A seam so a widget test does not sit out 30 seconds when a
  /// scan is meant to fail.
  DfuScanTimeoutProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dfuScanTimeoutProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dfuScanTimeoutHash();

  @$internal
  @override
  $ProviderElement<Duration> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Duration create(Ref ref) {
    return dfuScanTimeout(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Duration value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Duration>(value),
    );
  }
}

String _$dfuScanTimeoutHash() => r'e88b97e9bd2ffda794f6b35f883a06f88271f57c';

/// The emulated device behind `FakeScanner.emulatedBootloader`: a fake that
/// is already in DFU mode, so the recovery path (spec 5.5) has something to
/// flash in emulator mode. Created lazily — nothing reads it unless a fake
/// bootloader is actually the target — and kept alive so the scan that
/// follows the flash sees the *same* device leave the bootloader.

@ProviderFor(emulatorBootloader)
final emulatorBootloaderProvider = EmulatorBootloaderProvider._();

/// The emulated device behind `FakeScanner.emulatedBootloader`: a fake that
/// is already in DFU mode, so the recovery path (spec 5.5) has something to
/// flash in emulator mode. Created lazily — nothing reads it unless a fake
/// bootloader is actually the target — and kept alive so the scan that
/// follows the flash sees the *same* device leave the bootloader.

final class EmulatorBootloaderProvider
    extends $FunctionalProvider<FakeDevice, FakeDevice, FakeDevice>
    with $Provider<FakeDevice> {
  /// The emulated device behind `FakeScanner.emulatedBootloader`: a fake that
  /// is already in DFU mode, so the recovery path (spec 5.5) has something to
  /// flash in emulator mode. Created lazily — nothing reads it unless a fake
  /// bootloader is actually the target — and kept alive so the scan that
  /// follows the flash sees the *same* device leave the bootloader.
  EmulatorBootloaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'emulatorBootloaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$emulatorBootloaderHash();

  @$internal
  @override
  $ProviderElement<FakeDevice> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FakeDevice create(Ref ref) {
    return emulatorBootloader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FakeDevice value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FakeDevice>(value),
    );
  }
}

String _$emulatorBootloaderHash() =>
    r'8541ca72d513d2cdc97c68622a91ea70b575f37a';

/// Opens a DFU channel to a discovered bootloader (spec 4.5's
/// `DfuChannelOpener`, spec 5.3's two channels).
///
/// USB is enabled everywhere it exists; BLE is refused while
/// `dfuOverBleEnabled` is off (roadmap H2), which is belt and braces beside
/// the screen never offering it — the flag is the single gate spec 5.6 asks
/// for, and it has to hold even if a caller gets here another way.

@ProviderFor(dfuChannelOpener)
final dfuChannelOpenerProvider = DfuChannelOpenerProvider._();

/// Opens a DFU channel to a discovered bootloader (spec 4.5's
/// `DfuChannelOpener`, spec 5.3's two channels).
///
/// USB is enabled everywhere it exists; BLE is refused while
/// `dfuOverBleEnabled` is off (roadmap H2), which is belt and braces beside
/// the screen never offering it — the flag is the single gate spec 5.6 asks
/// for, and it has to hold even if a caller gets here another way.

final class DfuChannelOpenerProvider
    extends
        $FunctionalProvider<
          DfuChannelOpener,
          DfuChannelOpener,
          DfuChannelOpener
        >
    with $Provider<DfuChannelOpener> {
  /// Opens a DFU channel to a discovered bootloader (spec 4.5's
  /// `DfuChannelOpener`, spec 5.3's two channels).
  ///
  /// USB is enabled everywhere it exists; BLE is refused while
  /// `dfuOverBleEnabled` is off (roadmap H2), which is belt and braces beside
  /// the screen never offering it — the flag is the single gate spec 5.6 asks
  /// for, and it has to hold even if a caller gets here another way.
  DfuChannelOpenerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dfuChannelOpenerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dfuChannelOpenerHash();

  @$internal
  @override
  $ProviderElement<DfuChannelOpener> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DfuChannelOpener create(Ref ref) {
    return dfuChannelOpener(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DfuChannelOpener value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DfuChannelOpener>(value),
    );
  }
}

String _$dfuChannelOpenerHash() => r'5bef4b4c39369b8689a8b2ab135510ba04a5e3e4';

/// The scanners one run uses to find the bootloader and then the device
/// again.
///
/// In emulator mode a plain `FakeScanner` reports a static list, so it would
/// never show the device as a bootloader after the reboot — and never show it
/// back in the application after the flash. `FakeScanner.forDevice` follows
/// one fake's actual mode, which is exactly what the orchestrator's two scans
/// need. Real devices use the app's own scanner list unchanged.

@ProviderFor(dfuScanners)
final dfuScannersProvider = DfuScannersFamily._();

/// The scanners one run uses to find the bootloader and then the device
/// again.
///
/// In emulator mode a plain `FakeScanner` reports a static list, so it would
/// never show the device as a bootloader after the reboot — and never show it
/// back in the application after the flash. `FakeScanner.forDevice` follows
/// one fake's actual mode, which is exactly what the orchestrator's two scans
/// need. Real devices use the app's own scanner list unchanged.

final class DfuScannersProvider
    extends
        $FunctionalProvider<
          List<DeviceScanner>,
          List<DeviceScanner>,
          List<DeviceScanner>
        >
    with $Provider<List<DeviceScanner>> {
  /// The scanners one run uses to find the bootloader and then the device
  /// again.
  ///
  /// In emulator mode a plain `FakeScanner` reports a static list, so it would
  /// never show the device as a bootloader after the reboot — and never show it
  /// back in the application after the flash. `FakeScanner.forDevice` follows
  /// one fake's actual mode, which is exactly what the orchestrator's two scans
  /// need. Real devices use the app's own scanner list unchanged.
  DfuScannersProvider._({
    required DfuScannersFamily super.from,
    required DfuTarget super.argument,
  }) : super(
         retry: null,
         name: r'dfuScannersProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$dfuScannersHash();

  @override
  String toString() {
    return r'dfuScannersProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<List<DeviceScanner>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<DeviceScanner> create(Ref ref) {
    final argument = this.argument as DfuTarget;
    return dfuScanners(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<DeviceScanner> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<DeviceScanner>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DfuScannersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dfuScannersHash() => r'8c1fda7ae11da50428b89b18ca69de6b3277e55a';

/// The scanners one run uses to find the bootloader and then the device
/// again.
///
/// In emulator mode a plain `FakeScanner` reports a static list, so it would
/// never show the device as a bootloader after the reboot — and never show it
/// back in the application after the flash. `FakeScanner.forDevice` follows
/// one fake's actual mode, which is exactly what the orchestrator's two scans
/// need. Real devices use the app's own scanner list unchanged.

final class DfuScannersFamily extends $Family
    with $FunctionalFamilyOverride<List<DeviceScanner>, DfuTarget> {
  DfuScannersFamily._()
    : super(
        retry: null,
        name: r'dfuScannersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// The scanners one run uses to find the bootloader and then the device
  /// again.
  ///
  /// In emulator mode a plain `FakeScanner` reports a static list, so it would
  /// never show the device as a bootloader after the reboot — and never show it
  /// back in the application after the flash. `FakeScanner.forDevice` follows
  /// one fake's actual mode, which is exactly what the orchestrator's two scans
  /// need. Real devices use the app's own scanner list unchanged.

  DfuScannersProvider call(DfuTarget target) =>
      DfuScannersProvider._(argument: target, from: this);

  @override
  String toString() => r'dfuScannersProvider';
}
