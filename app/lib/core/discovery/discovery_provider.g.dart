// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discovery_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Runs every scanner at once via [mergedScan] (spec 4.2) and folds in the
/// [manualPortsProvider] entries (spec 5.2) as ordinary usb rows. A
/// scanner's error, forwarded by [mergedScan] with [Stream.addError],
/// becomes [DiscoveryState.error] instead of ending the stream — the other
/// scanners' devices stay listed.

@ProviderFor(discovery)
final discoveryProvider = DiscoveryProvider._();

/// Runs every scanner at once via [mergedScan] (spec 4.2) and folds in the
/// [manualPortsProvider] entries (spec 5.2) as ordinary usb rows. A
/// scanner's error, forwarded by [mergedScan] with [Stream.addError],
/// becomes [DiscoveryState.error] instead of ending the stream — the other
/// scanners' devices stay listed.

final class DiscoveryProvider
    extends
        $FunctionalProvider<
          AsyncValue<DiscoveryState>,
          DiscoveryState,
          Stream<DiscoveryState>
        >
    with $FutureModifier<DiscoveryState>, $StreamProvider<DiscoveryState> {
  /// Runs every scanner at once via [mergedScan] (spec 4.2) and folds in the
  /// [manualPortsProvider] entries (spec 5.2) as ordinary usb rows. A
  /// scanner's error, forwarded by [mergedScan] with [Stream.addError],
  /// becomes [DiscoveryState.error] instead of ending the stream — the other
  /// scanners' devices stay listed.
  DiscoveryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'discoveryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$discoveryHash();

  @$internal
  @override
  $StreamProviderElement<DiscoveryState> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<DiscoveryState> create(Ref ref) {
    return discovery(ref);
  }
}

String _$discoveryHash() => r'193bf170a7a2fdd23872ff8f528d983d8f6f5fe5';

/// Ports the user typed in by hand on desktop, for when enumeration finds
/// nothing (spec 5.2). They join [discoveryProvider]'s list as ordinary usb
/// entries, so the rest of the app does not know the difference.

@ProviderFor(ManualPorts)
final manualPortsProvider = ManualPortsProvider._();

/// Ports the user typed in by hand on desktop, for when enumeration finds
/// nothing (spec 5.2). They join [discoveryProvider]'s list as ordinary usb
/// entries, so the rest of the app does not know the difference.
final class ManualPortsProvider
    extends $NotifierProvider<ManualPorts, List<DiscoveredDevice>> {
  /// Ports the user typed in by hand on desktop, for when enumeration finds
  /// nothing (spec 5.2). They join [discoveryProvider]'s list as ordinary usb
  /// entries, so the rest of the app does not know the difference.
  ManualPortsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'manualPortsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$manualPortsHash();

  @$internal
  @override
  ManualPorts create() => ManualPorts();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<DiscoveredDevice> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<DiscoveredDevice>>(value),
    );
  }
}

String _$manualPortsHash() => r'b96e6ca051d50df6f1e2cf48664875d05357ba06';

/// Ports the user typed in by hand on desktop, for when enumeration finds
/// nothing (spec 5.2). They join [discoveryProvider]'s list as ordinary usb
/// entries, so the rest of the app does not know the difference.

abstract class _$ManualPorts extends $Notifier<List<DiscoveredDevice>> {
  List<DiscoveredDevice> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<List<DiscoveredDevice>, List<DiscoveredDevice>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<DiscoveredDevice>, List<DiscoveredDevice>>,
              List<DiscoveredDevice>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
