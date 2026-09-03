// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every device-settings change, as state the screen renders (spec 7.7 step
/// 7, spec 8.1).
///
/// Failures stay in [DeviceSettingsEditState.error] rather than being
/// thrown, so the screen shows them through the spec 9 catalog. A call made
/// while another is in flight is dropped, not queued, and the screen
/// disables its controls while `busy`. Every post-`await` assignment is
/// guarded with `ref.mounted` (R25): the Settings tab can be left while a
/// write is on the wire.
///
/// Unlike `SlotsFacade`, `SettingsFacade`'s methods do not wrap themselves in
/// `DeviceSession.busy` — they are not "load a full tag dump" long, but they
/// are still a round trip over the wire, so this controller wraps every
/// facade call itself, holding the wakelock (`core/lifecycle/wakelock.dart`)
/// for its duration the same way the slots and cards controllers do.

@ProviderFor(DeviceSettingsController)
final deviceSettingsControllerProvider = DeviceSettingsControllerProvider._();

/// Every device-settings change, as state the screen renders (spec 7.7 step
/// 7, spec 8.1).
///
/// Failures stay in [DeviceSettingsEditState.error] rather than being
/// thrown, so the screen shows them through the spec 9 catalog. A call made
/// while another is in flight is dropped, not queued, and the screen
/// disables its controls while `busy`. Every post-`await` assignment is
/// guarded with `ref.mounted` (R25): the Settings tab can be left while a
/// write is on the wire.
///
/// Unlike `SlotsFacade`, `SettingsFacade`'s methods do not wrap themselves in
/// `DeviceSession.busy` — they are not "load a full tag dump" long, but they
/// are still a round trip over the wire, so this controller wraps every
/// facade call itself, holding the wakelock (`core/lifecycle/wakelock.dart`)
/// for its duration the same way the slots and cards controllers do.
final class DeviceSettingsControllerProvider
    extends
        $NotifierProvider<DeviceSettingsController, DeviceSettingsEditState> {
  /// Every device-settings change, as state the screen renders (spec 7.7 step
  /// 7, spec 8.1).
  ///
  /// Failures stay in [DeviceSettingsEditState.error] rather than being
  /// thrown, so the screen shows them through the spec 9 catalog. A call made
  /// while another is in flight is dropped, not queued, and the screen
  /// disables its controls while `busy`. Every post-`await` assignment is
  /// guarded with `ref.mounted` (R25): the Settings tab can be left while a
  /// write is on the wire.
  ///
  /// Unlike `SlotsFacade`, `SettingsFacade`'s methods do not wrap themselves in
  /// `DeviceSession.busy` — they are not "load a full tag dump" long, but they
  /// are still a round trip over the wire, so this controller wraps every
  /// facade call itself, holding the wakelock (`core/lifecycle/wakelock.dart`)
  /// for its duration the same way the slots and cards controllers do.
  DeviceSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceSettingsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceSettingsControllerHash();

  @$internal
  @override
  DeviceSettingsController create() => DeviceSettingsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeviceSettingsEditState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeviceSettingsEditState>(value),
    );
  }
}

String _$deviceSettingsControllerHash() =>
    r'f815e0660872ff1fb3a643ba50d9c453e378b960';

/// Every device-settings change, as state the screen renders (spec 7.7 step
/// 7, spec 8.1).
///
/// Failures stay in [DeviceSettingsEditState.error] rather than being
/// thrown, so the screen shows them through the spec 9 catalog. A call made
/// while another is in flight is dropped, not queued, and the screen
/// disables its controls while `busy`. Every post-`await` assignment is
/// guarded with `ref.mounted` (R25): the Settings tab can be left while a
/// write is on the wire.
///
/// Unlike `SlotsFacade`, `SettingsFacade`'s methods do not wrap themselves in
/// `DeviceSession.busy` — they are not "load a full tag dump" long, but they
/// are still a round trip over the wire, so this controller wraps every
/// facade call itself, holding the wakelock (`core/lifecycle/wakelock.dart`)
/// for its duration the same way the slots and cards controllers do.

abstract class _$DeviceSettingsController
    extends $Notifier<DeviceSettingsEditState> {
  DeviceSettingsEditState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<DeviceSettingsEditState, DeviceSettingsEditState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DeviceSettingsEditState, DeviceSettingsEditState>,
              DeviceSettingsEditState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
