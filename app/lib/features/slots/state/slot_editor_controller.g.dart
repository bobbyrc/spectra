// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'slot_editor_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every change to one slot, as an [AsyncValue] the screen renders.
///
/// Failures stay in the state rather than being thrown, so the editor shows
/// them through the error catalog (spec 9) instead of catching. One notifier
/// per slot index, so a failure on slot 3 does not grey out slot 4.
///
/// Nothing here refreshes afterwards: every [SlotsFacade] method already
/// ends with SLOT_DATA_CONFIG_SAVE and writes the change through to
/// `DeviceSession.slotsState`, which `slotViewsProvider` is watching.
/// `setActive` is the one exception to both of those — it is a single
/// SET_ACTIVE_SLOT command with no save step, and (unlike the other five
/// methods) it is not wrapped in `DeviceSession.busy`, so the wakelock
/// `sessionNeedsWakelock` polls is not held while it runs.

@ProviderFor(SlotEditor)
final slotEditorProvider = SlotEditorFamily._();

/// Every change to one slot, as an [AsyncValue] the screen renders.
///
/// Failures stay in the state rather than being thrown, so the editor shows
/// them through the error catalog (spec 9) instead of catching. One notifier
/// per slot index, so a failure on slot 3 does not grey out slot 4.
///
/// Nothing here refreshes afterwards: every [SlotsFacade] method already
/// ends with SLOT_DATA_CONFIG_SAVE and writes the change through to
/// `DeviceSession.slotsState`, which `slotViewsProvider` is watching.
/// `setActive` is the one exception to both of those — it is a single
/// SET_ACTIVE_SLOT command with no save step, and (unlike the other five
/// methods) it is not wrapped in `DeviceSession.busy`, so the wakelock
/// `sessionNeedsWakelock` polls is not held while it runs.
final class SlotEditorProvider
    extends $AsyncNotifierProvider<SlotEditor, void> {
  /// Every change to one slot, as an [AsyncValue] the screen renders.
  ///
  /// Failures stay in the state rather than being thrown, so the editor shows
  /// them through the error catalog (spec 9) instead of catching. One notifier
  /// per slot index, so a failure on slot 3 does not grey out slot 4.
  ///
  /// Nothing here refreshes afterwards: every [SlotsFacade] method already
  /// ends with SLOT_DATA_CONFIG_SAVE and writes the change through to
  /// `DeviceSession.slotsState`, which `slotViewsProvider` is watching.
  /// `setActive` is the one exception to both of those — it is a single
  /// SET_ACTIVE_SLOT command with no save step, and (unlike the other five
  /// methods) it is not wrapped in `DeviceSession.busy`, so the wakelock
  /// `sessionNeedsWakelock` polls is not held while it runs.
  SlotEditorProvider._({
    required SlotEditorFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'slotEditorProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$slotEditorHash();

  @override
  String toString() {
    return r'slotEditorProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SlotEditor create() => SlotEditor();

  @override
  bool operator ==(Object other) {
    return other is SlotEditorProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$slotEditorHash() => r'ac30cd693fb99638f57c81bb39177c82436539cc';

/// Every change to one slot, as an [AsyncValue] the screen renders.
///
/// Failures stay in the state rather than being thrown, so the editor shows
/// them through the error catalog (spec 9) instead of catching. One notifier
/// per slot index, so a failure on slot 3 does not grey out slot 4.
///
/// Nothing here refreshes afterwards: every [SlotsFacade] method already
/// ends with SLOT_DATA_CONFIG_SAVE and writes the change through to
/// `DeviceSession.slotsState`, which `slotViewsProvider` is watching.
/// `setActive` is the one exception to both of those — it is a single
/// SET_ACTIVE_SLOT command with no save step, and (unlike the other five
/// methods) it is not wrapped in `DeviceSession.busy`, so the wakelock
/// `sessionNeedsWakelock` polls is not held while it runs.

final class SlotEditorFamily extends $Family
    with
        $ClassFamilyOverride<
          SlotEditor,
          AsyncValue<void>,
          void,
          FutureOr<void>,
          int
        > {
  SlotEditorFamily._()
    : super(
        retry: null,
        name: r'slotEditorProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Every change to one slot, as an [AsyncValue] the screen renders.
  ///
  /// Failures stay in the state rather than being thrown, so the editor shows
  /// them through the error catalog (spec 9) instead of catching. One notifier
  /// per slot index, so a failure on slot 3 does not grey out slot 4.
  ///
  /// Nothing here refreshes afterwards: every [SlotsFacade] method already
  /// ends with SLOT_DATA_CONFIG_SAVE and writes the change through to
  /// `DeviceSession.slotsState`, which `slotViewsProvider` is watching.
  /// `setActive` is the one exception to both of those — it is a single
  /// SET_ACTIVE_SLOT command with no save step, and (unlike the other five
  /// methods) it is not wrapped in `DeviceSession.busy`, so the wakelock
  /// `sessionNeedsWakelock` polls is not held while it runs.

  SlotEditorProvider call(int index) =>
      SlotEditorProvider._(argument: index, from: this);

  @override
  String toString() => r'slotEditorProvider';
}

/// Every change to one slot, as an [AsyncValue] the screen renders.
///
/// Failures stay in the state rather than being thrown, so the editor shows
/// them through the error catalog (spec 9) instead of catching. One notifier
/// per slot index, so a failure on slot 3 does not grey out slot 4.
///
/// Nothing here refreshes afterwards: every [SlotsFacade] method already
/// ends with SLOT_DATA_CONFIG_SAVE and writes the change through to
/// `DeviceSession.slotsState`, which `slotViewsProvider` is watching.
/// `setActive` is the one exception to both of those — it is a single
/// SET_ACTIVE_SLOT command with no save step, and (unlike the other five
/// methods) it is not wrapped in `DeviceSession.busy`, so the wakelock
/// `sessionNeedsWakelock` polls is not held while it runs.

abstract class _$SlotEditor extends $AsyncNotifier<void> {
  late final _$args = ref.$arg as int;
  int get index => _$args;

  FutureOr<void> build(int index);
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
    return element.handleCreate(ref, () => build(_$args));
  }
}
