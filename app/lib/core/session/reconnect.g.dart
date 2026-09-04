// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reconnect.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// How long a reconnect waits for [discoveryProvider] to report the known
/// device before giving up. Bounded so a reconnect that finds nothing never
/// hangs waiting on a scan that may never see the device again (asleep,
/// unplugged, out of range). A provider so a test can shorten it.

@ProviderFor(reconnectDiscoveryTimeout)
final reconnectDiscoveryTimeoutProvider = ReconnectDiscoveryTimeoutProvider._();

/// How long a reconnect waits for [discoveryProvider] to report the known
/// device before giving up. Bounded so a reconnect that finds nothing never
/// hangs waiting on a scan that may never see the device again (asleep,
/// unplugged, out of range). A provider so a test can shorten it.

final class ReconnectDiscoveryTimeoutProvider
    extends $FunctionalProvider<Duration, Duration, Duration>
    with $Provider<Duration> {
  /// How long a reconnect waits for [discoveryProvider] to report the known
  /// device before giving up. Bounded so a reconnect that finds nothing never
  /// hangs waiting on a scan that may never see the device again (asleep,
  /// unplugged, out of range). A provider so a test can shorten it.
  ReconnectDiscoveryTimeoutProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reconnectDiscoveryTimeoutProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reconnectDiscoveryTimeoutHash();

  @$internal
  @override
  $ProviderElement<Duration> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Duration create(Ref ref) {
    return reconnectDiscoveryTimeout(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Duration value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Duration>(value),
    );
  }
}

String _$reconnectDiscoveryTimeoutHash() =>
    r'4a8c3db74b4c6392679001bebd74743f096bceed';
