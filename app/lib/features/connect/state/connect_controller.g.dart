// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connect_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The connect action, with its progress and its failure. Failures stay in
/// the state rather than being thrown, so the screen renders them through
/// the error catalog (spec 9) instead of catching.
///
/// Every attempt opens a fresh [DeviceSession] via [Sessions.connect] — this
/// never reuses a session across attempts.

@ProviderFor(ConnectController)
final connectControllerProvider = ConnectControllerProvider._();

/// The connect action, with its progress and its failure. Failures stay in
/// the state rather than being thrown, so the screen renders them through
/// the error catalog (spec 9) instead of catching.
///
/// Every attempt opens a fresh [DeviceSession] via [Sessions.connect] — this
/// never reuses a session across attempts.
final class ConnectControllerProvider
    extends $AsyncNotifierProvider<ConnectController, void> {
  /// The connect action, with its progress and its failure. Failures stay in
  /// the state rather than being thrown, so the screen renders them through
  /// the error catalog (spec 9) instead of catching.
  ///
  /// Every attempt opens a fresh [DeviceSession] via [Sessions.connect] — this
  /// never reuses a session across attempts.
  ConnectControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectControllerHash();

  @$internal
  @override
  ConnectController create() => ConnectController();
}

String _$connectControllerHash() => r'216caa34ef8ce9e0bf44c1a835bcc39dd12ef36b';

/// The connect action, with its progress and its failure. Failures stay in
/// the state rather than being thrown, so the screen renders them through
/// the error catalog (spec 9) instead of catching.
///
/// Every attempt opens a fresh [DeviceSession] via [Sessions.connect] — this
/// never reuses a session across attempts.

abstract class _$ConnectController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
