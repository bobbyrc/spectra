// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives `DfuOrchestrator` for the update screen (spec 4.5, 7.7 step 6).
///
/// Two entry points, one run: a connected device (the orchestrator sends
/// ENTER_BOOTLOADER itself and the session moves to `SessionUpdating`), and a
/// device already sitting in its bootloader — the recovery path spec 5.6
/// guarantees, reached from the connect screen's "Recover" action.
///
/// Cancellation goes through the [CancelToken], never by cancelling the
/// subscription: unsubscribing closes the channel under an in-flight transfer
/// and leaves a half-written image on the device (`DfuOrchestrator`'s own doc).

@ProviderFor(UpdateController)
final updateControllerProvider = UpdateControllerProvider._();

/// Drives `DfuOrchestrator` for the update screen (spec 4.5, 7.7 step 6).
///
/// Two entry points, one run: a connected device (the orchestrator sends
/// ENTER_BOOTLOADER itself and the session moves to `SessionUpdating`), and a
/// device already sitting in its bootloader — the recovery path spec 5.6
/// guarantees, reached from the connect screen's "Recover" action.
///
/// Cancellation goes through the [CancelToken], never by cancelling the
/// subscription: unsubscribing closes the channel under an in-flight transfer
/// and leaves a half-written image on the device (`DfuOrchestrator`'s own doc).
final class UpdateControllerProvider
    extends $NotifierProvider<UpdateController, UpdateState> {
  /// Drives `DfuOrchestrator` for the update screen (spec 4.5, 7.7 step 6).
  ///
  /// Two entry points, one run: a connected device (the orchestrator sends
  /// ENTER_BOOTLOADER itself and the session moves to `SessionUpdating`), and a
  /// device already sitting in its bootloader — the recovery path spec 5.6
  /// guarantees, reached from the connect screen's "Recover" action.
  ///
  /// Cancellation goes through the [CancelToken], never by cancelling the
  /// subscription: unsubscribing closes the channel under an in-flight transfer
  /// and leaves a half-written image on the device (`DfuOrchestrator`'s own doc).
  UpdateControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateControllerHash();

  @$internal
  @override
  UpdateController create() => UpdateController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateState>(value),
    );
  }
}

String _$updateControllerHash() => r'8c65ab005b4e15a5f8c2b74d7982ce0b92e5b722';

/// Drives `DfuOrchestrator` for the update screen (spec 4.5, 7.7 step 6).
///
/// Two entry points, one run: a connected device (the orchestrator sends
/// ENTER_BOOTLOADER itself and the session moves to `SessionUpdating`), and a
/// device already sitting in its bootloader — the recovery path spec 5.6
/// guarantees, reached from the connect screen's "Recover" action.
///
/// Cancellation goes through the [CancelToken], never by cancelling the
/// subscription: unsubscribing closes the channel under an in-flight transfer
/// and leaves a half-written image on the device (`DfuOrchestrator`'s own doc).

abstract class _$UpdateController extends $Notifier<UpdateState> {
  UpdateState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<UpdateState, UpdateState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UpdateState, UpdateState>,
              UpdateState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
