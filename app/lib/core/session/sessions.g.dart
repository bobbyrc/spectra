// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sessions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// How a [DiscoveredDevice] becomes a [Transport]. Injected so tests connect
/// to a scripted `FakeDevice` (spec 8.6).

@ProviderFor(transportFactory)
final transportFactoryProvider = TransportFactoryProvider._();

/// How a [DiscoveredDevice] becomes a [Transport]. Injected so tests connect
/// to a scripted `FakeDevice` (spec 8.6).

final class TransportFactoryProvider
    extends
        $FunctionalProvider<
          Transport Function(DiscoveredDevice),
          Transport Function(DiscoveredDevice),
          Transport Function(DiscoveredDevice)
        >
    with $Provider<Transport Function(DiscoveredDevice)> {
  /// How a [DiscoveredDevice] becomes a [Transport]. Injected so tests connect
  /// to a scripted `FakeDevice` (spec 8.6).
  TransportFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transportFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transportFactoryHash();

  @$internal
  @override
  $ProviderElement<Transport Function(DiscoveredDevice)> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Transport Function(DiscoveredDevice) create(Ref ref) {
    return transportFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Transport Function(DiscoveredDevice) value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<Transport Function(DiscoveredDevice)>(value),
    );
  }
}

String _$transportFactoryHash() => r'963cff740bf24a1f5ee0783907db6934403fbb91';

@ProviderFor(sessionOptions)
final sessionOptionsProvider = SessionOptionsProvider._();

final class SessionOptionsProvider
    extends $FunctionalProvider<SessionOptions, SessionOptions, SessionOptions>
    with $Provider<SessionOptions> {
  SessionOptionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionOptionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionOptionsHash();

  @$internal
  @override
  $ProviderElement<SessionOptions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SessionOptions create(Ref ref) {
    return sessionOptions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionOptions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionOptions>(value),
    );
  }
}

String _$sessionOptionsHash() => r'061957716f678dc834fed6e679f97b64be96c055';

@ProviderFor(Sessions)
final sessionsProvider = SessionsProvider._();

final class SessionsProvider
    extends $NotifierProvider<Sessions, SessionsState> {
  SessionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionsHash();

  @$internal
  @override
  Sessions create() => Sessions();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionsState>(value),
    );
  }
}

String _$sessionsHash() => r'2b36ed86b25eecf1d7a54ef52bd11250ea35c83b';

abstract class _$Sessions extends $Notifier<SessionsState> {
  SessionsState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SessionsState, SessionsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SessionsState, SessionsState>,
              SessionsState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The session for one identity (spec 7.1). Null when nothing is connected
/// to that device.

@ProviderFor(deviceSession)
final deviceSessionProvider = DeviceSessionFamily._();

/// The session for one identity (spec 7.1). Null when nothing is connected
/// to that device.

final class DeviceSessionProvider
    extends $FunctionalProvider<ActiveSession?, ActiveSession?, ActiveSession?>
    with $Provider<ActiveSession?> {
  /// The session for one identity (spec 7.1). Null when nothing is connected
  /// to that device.
  DeviceSessionProvider._({
    required DeviceSessionFamily super.from,
    required DeviceIdentity super.argument,
  }) : super(
         retry: null,
         name: r'deviceSessionProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$deviceSessionHash();

  @override
  String toString() {
    return r'deviceSessionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<ActiveSession?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ActiveSession? create(Ref ref) {
    final argument = this.argument as DeviceIdentity;
    return deviceSession(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ActiveSession? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ActiveSession?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DeviceSessionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$deviceSessionHash() => r'4ec76aaa563039d621aff5bdf158d70106e9d1bc';

/// The session for one identity (spec 7.1). Null when nothing is connected
/// to that device.

final class DeviceSessionFamily extends $Family
    with $FunctionalFamilyOverride<ActiveSession?, DeviceIdentity> {
  DeviceSessionFamily._()
    : super(
        retry: null,
        name: r'deviceSessionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// The session for one identity (spec 7.1). Null when nothing is connected
  /// to that device.

  DeviceSessionProvider call(DeviceIdentity identity) =>
      DeviceSessionProvider._(argument: identity, from: this);

  @override
  String toString() => r'deviceSessionProvider';
}
