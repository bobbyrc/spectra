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
/// `SlotsFacade`'s own methods call `DeviceSession.busy` internally;
/// `SettingsFacade`'s do not. Its writes are not "load a full tag dump"
/// long, but they are still a round trip over the wire, so this controller
/// wraps every facade call itself in `active.session.busy`, holding the
/// wakelock (`core/lifecycle/wakelock.dart`) for its duration the same way
/// a slot mutation does.

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
/// `SlotsFacade`'s own methods call `DeviceSession.busy` internally;
/// `SettingsFacade`'s do not. Its writes are not "load a full tag dump"
/// long, but they are still a round trip over the wire, so this controller
/// wraps every facade call itself in `active.session.busy`, holding the
/// wakelock (`core/lifecycle/wakelock.dart`) for its duration the same way
/// a slot mutation does.
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
  /// `SlotsFacade`'s own methods call `DeviceSession.busy` internally;
  /// `SettingsFacade`'s do not. Its writes are not "load a full tag dump"
  /// long, but they are still a round trip over the wire, so this controller
  /// wraps every facade call itself in `active.session.busy`, holding the
  /// wakelock (`core/lifecycle/wakelock.dart`) for its duration the same way
  /// a slot mutation does.
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
    r'07f6a91df9a6d85ecbfe9b5e9eee87b0b7c2a81f';

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
/// `SlotsFacade`'s own methods call `DeviceSession.busy` internally;
/// `SettingsFacade`'s do not. Its writes are not "load a full tag dump"
/// long, but they are still a round trip over the wire, so this controller
/// wraps every facade call itself in `active.session.busy`, holding the
/// wakelock (`core/lifecycle/wakelock.dart`) for its duration the same way
/// a slot mutation does.

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
