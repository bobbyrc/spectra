// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scanners.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Spec 7.5: the connect screen lists real devices plus one emulated
/// Chameleon Ultra. On by default, because it is also how screenshots and
/// manual QA happen with no hardware attached.

@ProviderFor(EmulatorMode)
final emulatorModeProvider = EmulatorModeProvider._();

/// Spec 7.5: the connect screen lists real devices plus one emulated
/// Chameleon Ultra. On by default, because it is also how screenshots and
/// manual QA happen with no hardware attached.
final class EmulatorModeProvider extends $NotifierProvider<EmulatorMode, bool> {
  /// Spec 7.5: the connect screen lists real devices plus one emulated
  /// Chameleon Ultra. On by default, because it is also how screenshots and
  /// manual QA happen with no hardware attached.
  EmulatorModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'emulatorModeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$emulatorModeHash();

  @$internal
  @override
  EmulatorMode create() => EmulatorMode();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$emulatorModeHash() => r'425cac3adfd8fea6b55890a8258030f3e42f6624';

/// Spec 7.5: the connect screen lists real devices plus one emulated
/// Chameleon Ultra. On by default, because it is also how screenshots and
/// manual QA happen with no hardware attached.

abstract class _$EmulatorMode extends $Notifier<bool> {
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

/// Seams for [scannersProvider]'s platform and adapter inputs to
/// [ChameleonTransports.defaultScanners]. Production leaves all three
/// `null`, which is [defaultScanners]'s own "use the real one" default;
/// tests override them so a scan never touches `UniversalBleAdapter` or
/// libserialport.

@ProviderFor(scannerPlatform)
final scannerPlatformProvider = ScannerPlatformProvider._();

/// Seams for [scannersProvider]'s platform and adapter inputs to
/// [ChameleonTransports.defaultScanners]. Production leaves all three
/// `null`, which is [defaultScanners]'s own "use the real one" default;
/// tests override them so a scan never touches `UniversalBleAdapter` or
/// libserialport.

final class ScannerPlatformProvider
    extends $FunctionalProvider<HostPlatform?, HostPlatform?, HostPlatform?>
    with $Provider<HostPlatform?> {
  /// Seams for [scannersProvider]'s platform and adapter inputs to
  /// [ChameleonTransports.defaultScanners]. Production leaves all three
  /// `null`, which is [defaultScanners]'s own "use the real one" default;
  /// tests override them so a scan never touches `UniversalBleAdapter` or
  /// libserialport.
  ScannerPlatformProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'scannerPlatformProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$scannerPlatformHash();

  @$internal
  @override
  $ProviderElement<HostPlatform?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HostPlatform? create(Ref ref) {
    return scannerPlatform(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HostPlatform? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HostPlatform?>(value),
    );
  }
}

String _$scannerPlatformHash() => r'8c0942fb6e616bfa3837dbbce511abe0671a6184';

@ProviderFor(scannerBleAdapter)
final scannerBleAdapterProvider = ScannerBleAdapterProvider._();

final class ScannerBleAdapterProvider
    extends $FunctionalProvider<BleAdapter?, BleAdapter?, BleAdapter?>
    with $Provider<BleAdapter?> {
  ScannerBleAdapterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'scannerBleAdapterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$scannerBleAdapterHash();

  @$internal
  @override
  $ProviderElement<BleAdapter?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BleAdapter? create(Ref ref) {
    return scannerBleAdapter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BleAdapter? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BleAdapter?>(value),
    );
  }
}

String _$scannerBleAdapterHash() => r'181d4f93efb044f79c54596e1e27d7b9c31dd61c';

@ProviderFor(scannerSerialAdapter)
final scannerSerialAdapterProvider = ScannerSerialAdapterProvider._();

final class ScannerSerialAdapterProvider
    extends
        $FunctionalProvider<
          SerialPortAdapter?,
          SerialPortAdapter?,
          SerialPortAdapter?
        >
    with $Provider<SerialPortAdapter?> {
  ScannerSerialAdapterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'scannerSerialAdapterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$scannerSerialAdapterHash();

  @$internal
  @override
  $ProviderElement<SerialPortAdapter?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SerialPortAdapter? create(Ref ref) {
    return scannerSerialAdapter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SerialPortAdapter? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SerialPortAdapter?>(value),
    );
  }
}

String _$scannerSerialAdapterHash() =>
    r'bca31878d5d12fc16bcaa0e49ac0ae7832df0024';

/// The platform's scanners, plus the SDK's [FakeScanner] in emulator mode
/// (spec 8.2: a plain list, no registry).

@ProviderFor(scanners)
final scannersProvider = ScannersProvider._();

/// The platform's scanners, plus the SDK's [FakeScanner] in emulator mode
/// (spec 8.2: a plain list, no registry).

final class ScannersProvider
    extends
        $FunctionalProvider<
          List<DeviceScanner>,
          List<DeviceScanner>,
          List<DeviceScanner>
        >
    with $Provider<List<DeviceScanner>> {
  /// The platform's scanners, plus the SDK's [FakeScanner] in emulator mode
  /// (spec 8.2: a plain list, no registry).
  ScannersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'scannersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$scannersHash();

  @$internal
  @override
  $ProviderElement<List<DeviceScanner>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<DeviceScanner> create(Ref ref) {
    return scanners(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<DeviceScanner> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<DeviceScanner>>(value),
    );
  }
}

String _$scannersHash() => r'44241717108bd64bee3bee7991add0f0ea7ddab4';
