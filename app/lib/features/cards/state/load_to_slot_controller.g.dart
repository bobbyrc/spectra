// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'load_to_slot_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Spec 7.7 step 5: load a dump into one of the eight slots.
///
/// The order matters and is the device's, not a preference: select the slot
/// (so every `EmulatorFacade` call lands on it — that facade always operates
/// on the *active* slot), reset it to the target type (which sets the type
/// and clears that sense's old data in one command, so no byte of the
/// previous card survives), write the data, set the anti-collision, name it,
/// enable it. Every `SlotsFacade` mutation ends in SLOT_DATA_CONFIG_SAVE on
/// its own, so nothing here has to save.
///
/// The load then reads the slot back and compares. A device that stores
/// something else is a [SlotLoadVerificationFailed], which the error catalog
/// has words for — silently reporting success for a slot that will not
/// emulate is the one outcome worth spending an extra round trip to avoid.
///
/// A dump whose byte length does not match [type]'s expected length is
/// refused before any command is sent, as a [CardDumpLengthMismatch]
/// (ruling 4): a stored row of the wrong size was never a valid dump, and
/// half-writing it would leave the slot worse than it started.
///
/// A MIFARE Classic dump with an all-zero sector trailer — the shape a read
/// leaves behind for a sector it never authenticated — is refused the same
/// way, but as [SlotLoadState.unreadSectors] rather than [SlotLoadState
/// .error]: nothing is wrong with the request, the caller just has not
/// confirmed it yet (ruling 23). Passing `confirmUnread: true` proceeds
/// anyway; the caller is expected to have shown the sector list first.
///
/// There is no wakelock code here and there must not be: `writeMf1Blocks`
/// and `readMf1Blocks` run inside `DeviceSession.busy`, as does every
/// `SlotsFacade` mutation but `setActive`, and `sessionNeedsWakelock`
/// (`core/lifecycle/wakelock.dart`) polls exactly that.
///
/// A call made while another is in flight is dropped, not queued
/// (`_inFlight`); the sheet disables its button while `state.busy`. This
/// notifier is autoDispose and lives under a sheet the user can dismiss, so
/// every assignment to [state] after an `await` is guarded with `ref.mounted`
/// (R25) — the device write still runs to completion, there is simply no
/// longer anywhere to report it.

@ProviderFor(SlotLoader)
final slotLoaderProvider = SlotLoaderProvider._();

/// Spec 7.7 step 5: load a dump into one of the eight slots.
///
/// The order matters and is the device's, not a preference: select the slot
/// (so every `EmulatorFacade` call lands on it — that facade always operates
/// on the *active* slot), reset it to the target type (which sets the type
/// and clears that sense's old data in one command, so no byte of the
/// previous card survives), write the data, set the anti-collision, name it,
/// enable it. Every `SlotsFacade` mutation ends in SLOT_DATA_CONFIG_SAVE on
/// its own, so nothing here has to save.
///
/// The load then reads the slot back and compares. A device that stores
/// something else is a [SlotLoadVerificationFailed], which the error catalog
/// has words for — silently reporting success for a slot that will not
/// emulate is the one outcome worth spending an extra round trip to avoid.
///
/// A dump whose byte length does not match [type]'s expected length is
/// refused before any command is sent, as a [CardDumpLengthMismatch]
/// (ruling 4): a stored row of the wrong size was never a valid dump, and
/// half-writing it would leave the slot worse than it started.
///
/// A MIFARE Classic dump with an all-zero sector trailer — the shape a read
/// leaves behind for a sector it never authenticated — is refused the same
/// way, but as [SlotLoadState.unreadSectors] rather than [SlotLoadState
/// .error]: nothing is wrong with the request, the caller just has not
/// confirmed it yet (ruling 23). Passing `confirmUnread: true` proceeds
/// anyway; the caller is expected to have shown the sector list first.
///
/// There is no wakelock code here and there must not be: `writeMf1Blocks`
/// and `readMf1Blocks` run inside `DeviceSession.busy`, as does every
/// `SlotsFacade` mutation but `setActive`, and `sessionNeedsWakelock`
/// (`core/lifecycle/wakelock.dart`) polls exactly that.
///
/// A call made while another is in flight is dropped, not queued
/// (`_inFlight`); the sheet disables its button while `state.busy`. This
/// notifier is autoDispose and lives under a sheet the user can dismiss, so
/// every assignment to [state] after an `await` is guarded with `ref.mounted`
/// (R25) — the device write still runs to completion, there is simply no
/// longer anywhere to report it.
final class SlotLoaderProvider
    extends $NotifierProvider<SlotLoader, SlotLoadState> {
  /// Spec 7.7 step 5: load a dump into one of the eight slots.
  ///
  /// The order matters and is the device's, not a preference: select the slot
  /// (so every `EmulatorFacade` call lands on it — that facade always operates
  /// on the *active* slot), reset it to the target type (which sets the type
  /// and clears that sense's old data in one command, so no byte of the
  /// previous card survives), write the data, set the anti-collision, name it,
  /// enable it. Every `SlotsFacade` mutation ends in SLOT_DATA_CONFIG_SAVE on
  /// its own, so nothing here has to save.
  ///
  /// The load then reads the slot back and compares. A device that stores
  /// something else is a [SlotLoadVerificationFailed], which the error catalog
  /// has words for — silently reporting success for a slot that will not
  /// emulate is the one outcome worth spending an extra round trip to avoid.
  ///
  /// A dump whose byte length does not match [type]'s expected length is
  /// refused before any command is sent, as a [CardDumpLengthMismatch]
  /// (ruling 4): a stored row of the wrong size was never a valid dump, and
  /// half-writing it would leave the slot worse than it started.
  ///
  /// A MIFARE Classic dump with an all-zero sector trailer — the shape a read
  /// leaves behind for a sector it never authenticated — is refused the same
  /// way, but as [SlotLoadState.unreadSectors] rather than [SlotLoadState
  /// .error]: nothing is wrong with the request, the caller just has not
  /// confirmed it yet (ruling 23). Passing `confirmUnread: true` proceeds
  /// anyway; the caller is expected to have shown the sector list first.
  ///
  /// There is no wakelock code here and there must not be: `writeMf1Blocks`
  /// and `readMf1Blocks` run inside `DeviceSession.busy`, as does every
  /// `SlotsFacade` mutation but `setActive`, and `sessionNeedsWakelock`
  /// (`core/lifecycle/wakelock.dart`) polls exactly that.
  ///
  /// A call made while another is in flight is dropped, not queued
  /// (`_inFlight`); the sheet disables its button while `state.busy`. This
  /// notifier is autoDispose and lives under a sheet the user can dismiss, so
  /// every assignment to [state] after an `await` is guarded with `ref.mounted`
  /// (R25) — the device write still runs to completion, there is simply no
  /// longer anywhere to report it.
  SlotLoaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'slotLoaderProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$slotLoaderHash();

  @$internal
  @override
  SlotLoader create() => SlotLoader();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SlotLoadState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SlotLoadState>(value),
    );
  }
}

String _$slotLoaderHash() => r'56d03b4e48d23b65698262c9803f685501191938';

/// Spec 7.7 step 5: load a dump into one of the eight slots.
///
/// The order matters and is the device's, not a preference: select the slot
/// (so every `EmulatorFacade` call lands on it — that facade always operates
/// on the *active* slot), reset it to the target type (which sets the type
/// and clears that sense's old data in one command, so no byte of the
/// previous card survives), write the data, set the anti-collision, name it,
/// enable it. Every `SlotsFacade` mutation ends in SLOT_DATA_CONFIG_SAVE on
/// its own, so nothing here has to save.
///
/// The load then reads the slot back and compares. A device that stores
/// something else is a [SlotLoadVerificationFailed], which the error catalog
/// has words for — silently reporting success for a slot that will not
/// emulate is the one outcome worth spending an extra round trip to avoid.
///
/// A dump whose byte length does not match [type]'s expected length is
/// refused before any command is sent, as a [CardDumpLengthMismatch]
/// (ruling 4): a stored row of the wrong size was never a valid dump, and
/// half-writing it would leave the slot worse than it started.
///
/// A MIFARE Classic dump with an all-zero sector trailer — the shape a read
/// leaves behind for a sector it never authenticated — is refused the same
/// way, but as [SlotLoadState.unreadSectors] rather than [SlotLoadState
/// .error]: nothing is wrong with the request, the caller just has not
/// confirmed it yet (ruling 23). Passing `confirmUnread: true` proceeds
/// anyway; the caller is expected to have shown the sector list first.
///
/// There is no wakelock code here and there must not be: `writeMf1Blocks`
/// and `readMf1Blocks` run inside `DeviceSession.busy`, as does every
/// `SlotsFacade` mutation but `setActive`, and `sessionNeedsWakelock`
/// (`core/lifecycle/wakelock.dart`) polls exactly that.
///
/// A call made while another is in flight is dropped, not queued
/// (`_inFlight`); the sheet disables its button while `state.busy`. This
/// notifier is autoDispose and lives under a sheet the user can dismiss, so
/// every assignment to [state] after an `await` is guarded with `ref.mounted`
/// (R25) — the device write still runs to completion, there is simply no
/// longer anywhere to report it.

abstract class _$SlotLoader extends $Notifier<SlotLoadState> {
  SlotLoadState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SlotLoadState, SlotLoadState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SlotLoadState, SlotLoadState>,
              SlotLoadState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
