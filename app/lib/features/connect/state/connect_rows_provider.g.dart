// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connect_rows_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(knownDevices)
final knownDevicesProvider = KnownDevicesProvider._();

final class KnownDevicesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<KnownDevice>>,
          List<KnownDevice>,
          Stream<List<KnownDevice>>
        >
    with
        $FutureModifier<List<KnownDevice>>,
        $StreamProvider<List<KnownDevice>> {
  KnownDevicesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'knownDevicesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$knownDevicesHash();

  @$internal
  @override
  $StreamProviderElement<List<KnownDevice>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<KnownDevice>> create(Ref ref) {
    return knownDevices(ref);
  }
}

String _$knownDevicesHash() => r'8ce47e14525a4e5533c7165eaa87ca0129de1dce';

/// What the connect screen draws: discovery plus the manual ports, merged
/// against what the app remembers (spec 4.2), with the device whose link
/// just dropped unexpectedly (spec 7.4) preselected. This never reconnects
/// on its own — it only flags the row for the UI to highlight.

@ProviderFor(connectRows)
final connectRowsProvider = ConnectRowsProvider._();

/// What the connect screen draws: discovery plus the manual ports, merged
/// against what the app remembers (spec 4.2), with the device whose link
/// just dropped unexpectedly (spec 7.4) preselected. This never reconnects
/// on its own — it only flags the row for the UI to highlight.

final class ConnectRowsProvider
    extends
        $FunctionalProvider<
          List<ConnectRow>,
          List<ConnectRow>,
          List<ConnectRow>
        >
    with $Provider<List<ConnectRow>> {
  /// What the connect screen draws: discovery plus the manual ports, merged
  /// against what the app remembers (spec 4.2), with the device whose link
  /// just dropped unexpectedly (spec 7.4) preselected. This never reconnects
  /// on its own — it only flags the row for the UI to highlight.
  ConnectRowsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectRowsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectRowsHash();

  @$internal
  @override
  $ProviderElement<List<ConnectRow>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<ConnectRow> create(Ref ref) {
    return connectRows(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<ConnectRow> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<ConnectRow>>(value),
    );
  }
}

String _$connectRowsHash() => r'9dacb2f9995d254859ec670002e50a8758c15668';
