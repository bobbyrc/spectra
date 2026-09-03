// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_streams.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The one piece of session state routing needs synchronously (spec 7.2), so
/// it is a notifier seeded from the stream's current value rather than an
/// `AsyncValue`.

@ProviderFor(ConnectionStatus)
final connectionStatusProvider = ConnectionStatusProvider._();

/// The one piece of session state routing needs synchronously (spec 7.2), so
/// it is a notifier seeded from the stream's current value rather than an
/// `AsyncValue`.
final class ConnectionStatusProvider
    extends $NotifierProvider<ConnectionStatus, ConnectionState> {
  /// The one piece of session state routing needs synchronously (spec 7.2), so
  /// it is a notifier seeded from the stream's current value rather than an
  /// `AsyncValue`.
  ConnectionStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectionStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectionStatusHash();

  @$internal
  @override
  ConnectionStatus create() => ConnectionStatus();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConnectionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConnectionState>(value),
    );
  }
}

String _$connectionStatusHash() => r'9b158780b9df23931983f5dc925de1385c78c286';

/// The one piece of session state routing needs synchronously (spec 7.2), so
/// it is a notifier seeded from the stream's current value rather than an
/// `AsyncValue`.

abstract class _$ConnectionStatus extends $Notifier<ConnectionState> {
  ConnectionState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ConnectionState, ConnectionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ConnectionState, ConnectionState>,
              ConnectionState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(deviceInfo)
final deviceInfoProvider = DeviceInfoProvider._();

final class DeviceInfoProvider
    extends
        $FunctionalProvider<
          AsyncValue<DeviceInfo?>,
          DeviceInfo?,
          Stream<DeviceInfo?>
        >
    with $FutureModifier<DeviceInfo?>, $StreamProvider<DeviceInfo?> {
  DeviceInfoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceInfoProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceInfoHash();

  @$internal
  @override
  $StreamProviderElement<DeviceInfo?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<DeviceInfo?> create(Ref ref) {
    return deviceInfo(ref);
  }
}

String _$deviceInfoHash() => r'967d63b27b8d56861ec99b8d171fe4ae6c180e09';

@ProviderFor(battery)
final batteryProvider = BatteryProvider._();

final class BatteryProvider
    extends
        $FunctionalProvider<
          AsyncValue<BatteryInfo?>,
          BatteryInfo?,
          Stream<BatteryInfo?>
        >
    with $FutureModifier<BatteryInfo?>, $StreamProvider<BatteryInfo?> {
  BatteryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'batteryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$batteryHash();

  @$internal
  @override
  $StreamProviderElement<BatteryInfo?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<BatteryInfo?> create(Ref ref) {
    return battery(ref);
  }
}

String _$batteryHash() => r'a374a95ecd44cf521c258e87ed1c5ddde4919b8c';

@ProviderFor(slots)
final slotsProvider = SlotsProvider._();

final class SlotsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Slot>>,
          List<Slot>,
          Stream<List<Slot>>
        >
    with $FutureModifier<List<Slot>>, $StreamProvider<List<Slot>> {
  SlotsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'slotsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$slotsHash();

  @$internal
  @override
  $StreamProviderElement<List<Slot>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Slot>> create(Ref ref) {
    return slots(ref);
  }
}

String _$slotsHash() => r'47bd266971cd54b6a136f6f103b59bc058475db3';

@ProviderFor(activeSlot)
final activeSlotProvider = ActiveSlotProvider._();

final class ActiveSlotProvider
    extends $FunctionalProvider<AsyncValue<int?>, int?, Stream<int?>>
    with $FutureModifier<int?>, $StreamProvider<int?> {
  ActiveSlotProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeSlotProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeSlotHash();

  @$internal
  @override
  $StreamProviderElement<int?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int?> create(Ref ref) {
    return activeSlot(ref);
  }
}

String _$activeSlotHash() => r'83ef92b6364397af518cb4e2972639e06c4bd8d9';

@ProviderFor(mode)
final modeProvider = ModeProvider._();

final class ModeProvider
    extends
        $FunctionalProvider<
          AsyncValue<DeviceMode?>,
          DeviceMode?,
          Stream<DeviceMode?>
        >
    with $FutureModifier<DeviceMode?>, $StreamProvider<DeviceMode?> {
  ModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modeHash();

  @$internal
  @override
  $StreamProviderElement<DeviceMode?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<DeviceMode?> create(Ref ref) {
    return mode(ref);
  }
}

String _$modeHash() => r'180685a44d37b07311ce9b1795512cae7606a8f8';

@ProviderFor(settings)
final settingsProvider = SettingsProvider._();

final class SettingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<DeviceSettings?>,
          DeviceSettings?,
          Stream<DeviceSettings?>
        >
    with $FutureModifier<DeviceSettings?>, $StreamProvider<DeviceSettings?> {
  SettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsHash();

  @$internal
  @override
  $StreamProviderElement<DeviceSettings?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<DeviceSettings?> create(Ref ref) {
    return settings(ref);
  }
}

String _$settingsHash() => r'5455389067f2adbccadcf447cd8ea437cc85acd0';
