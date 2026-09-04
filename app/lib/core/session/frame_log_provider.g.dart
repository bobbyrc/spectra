// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'frame_log_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Spec 9: the ring buffer is always on, and viewing and exporting it are
/// available in every build. It belongs to the session, so it is null when
/// nothing is connected.

@ProviderFor(frameLog)
final frameLogProvider = FrameLogProvider._();

/// Spec 9: the ring buffer is always on, and viewing and exporting it are
/// available in every build. It belongs to the session, so it is null when
/// nothing is connected.

final class FrameLogProvider
    extends $FunctionalProvider<FrameLog?, FrameLog?, FrameLog?>
    with $Provider<FrameLog?> {
  /// Spec 9: the ring buffer is always on, and viewing and exporting it are
  /// available in every build. It belongs to the session, so it is null when
  /// nothing is connected.
  FrameLogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'frameLogProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$frameLogHash();

  @$internal
  @override
  $ProviderElement<FrameLog?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FrameLog? create(Ref ref) {
    return frameLog(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FrameLog? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FrameLog?>(value),
    );
  }
}

String _$frameLogHash() => r'04665f7feb8c0cc2ba3dd2e8e0b586fb3f35b4ef';

/// A snapshot of the log once a second. [FrameLog] is a plain ring buffer
/// with no change notification — polling is what keeps the SDK free of a
/// stream nothing else needs.

@ProviderFor(frameLogEntries)
final frameLogEntriesProvider = FrameLogEntriesProvider._();

/// A snapshot of the log once a second. [FrameLog] is a plain ring buffer
/// with no change notification — polling is what keeps the SDK free of a
/// stream nothing else needs.

final class FrameLogEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<FrameLogEntry>>,
          List<FrameLogEntry>,
          Stream<List<FrameLogEntry>>
        >
    with
        $FutureModifier<List<FrameLogEntry>>,
        $StreamProvider<List<FrameLogEntry>> {
  /// A snapshot of the log once a second. [FrameLog] is a plain ring buffer
  /// with no change notification — polling is what keeps the SDK free of a
  /// stream nothing else needs.
  FrameLogEntriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'frameLogEntriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$frameLogEntriesHash();

  @$internal
  @override
  $StreamProviderElement<List<FrameLogEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<FrameLogEntry>> create(Ref ref) {
    return frameLogEntries(ref);
  }
}

String _$frameLogEntriesHash() => r'1e1b867be2f4cf4db57cd52dd34b8c071b66ec55';
