// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'card_editor_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The detail screen's state, one notifier per card id, so a failure on one
/// card does not grey out another (the `SlotEditor` shape).
///
/// A call made while another write is in flight is dropped, not queued; the
/// screen disables its controls while `state.isLoading`. Every assignment to
/// [state] after an `await` is guarded with `ref.mounted` (Phase 6 ruling 2):
/// the detail screen is a pushed sub-route and can be popped (or the app can
/// navigate elsewhere) while a write is still on the wire.
///
/// Task 7 lands the read-only half: fields, the hex viewer, delete.
/// [replaceChunk] is Task 8's extension point — it only ever touches the
/// in-memory working copy, so the read-only screen this task builds already
/// works unmodified once Task 8 starts calling it from an editable hex
/// viewer.

@ProviderFor(CardEditor)
final cardEditorProvider = CardEditorFamily._();

/// The detail screen's state, one notifier per card id, so a failure on one
/// card does not grey out another (the `SlotEditor` shape).
///
/// A call made while another write is in flight is dropped, not queued; the
/// screen disables its controls while `state.isLoading`. Every assignment to
/// [state] after an `await` is guarded with `ref.mounted` (Phase 6 ruling 2):
/// the detail screen is a pushed sub-route and can be popped (or the app can
/// navigate elsewhere) while a write is still on the wire.
///
/// Task 7 lands the read-only half: fields, the hex viewer, delete.
/// [replaceChunk] is Task 8's extension point — it only ever touches the
/// in-memory working copy, so the read-only screen this task builds already
/// works unmodified once Task 8 starts calling it from an editable hex
/// viewer.
final class CardEditorProvider
    extends $AsyncNotifierProvider<CardEditor, CardEditState?> {
  /// The detail screen's state, one notifier per card id, so a failure on one
  /// card does not grey out another (the `SlotEditor` shape).
  ///
  /// A call made while another write is in flight is dropped, not queued; the
  /// screen disables its controls while `state.isLoading`. Every assignment to
  /// [state] after an `await` is guarded with `ref.mounted` (Phase 6 ruling 2):
  /// the detail screen is a pushed sub-route and can be popped (or the app can
  /// navigate elsewhere) while a write is still on the wire.
  ///
  /// Task 7 lands the read-only half: fields, the hex viewer, delete.
  /// [replaceChunk] is Task 8's extension point — it only ever touches the
  /// in-memory working copy, so the read-only screen this task builds already
  /// works unmodified once Task 8 starts calling it from an editable hex
  /// viewer.
  CardEditorProvider._({
    required CardEditorFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'cardEditorProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$cardEditorHash();

  @override
  String toString() {
    return r'cardEditorProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CardEditor create() => CardEditor();

  @override
  bool operator ==(Object other) {
    return other is CardEditorProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$cardEditorHash() => r'8caa40b30449b12ab1aa993833eaf1a15a0c29ef';

/// The detail screen's state, one notifier per card id, so a failure on one
/// card does not grey out another (the `SlotEditor` shape).
///
/// A call made while another write is in flight is dropped, not queued; the
/// screen disables its controls while `state.isLoading`. Every assignment to
/// [state] after an `await` is guarded with `ref.mounted` (Phase 6 ruling 2):
/// the detail screen is a pushed sub-route and can be popped (or the app can
/// navigate elsewhere) while a write is still on the wire.
///
/// Task 7 lands the read-only half: fields, the hex viewer, delete.
/// [replaceChunk] is Task 8's extension point — it only ever touches the
/// in-memory working copy, so the read-only screen this task builds already
/// works unmodified once Task 8 starts calling it from an editable hex
/// viewer.

final class CardEditorFamily extends $Family
    with
        $ClassFamilyOverride<
          CardEditor,
          AsyncValue<CardEditState?>,
          CardEditState?,
          FutureOr<CardEditState?>,
          String
        > {
  CardEditorFamily._()
    : super(
        retry: null,
        name: r'cardEditorProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The detail screen's state, one notifier per card id, so a failure on one
  /// card does not grey out another (the `SlotEditor` shape).
  ///
  /// A call made while another write is in flight is dropped, not queued; the
  /// screen disables its controls while `state.isLoading`. Every assignment to
  /// [state] after an `await` is guarded with `ref.mounted` (Phase 6 ruling 2):
  /// the detail screen is a pushed sub-route and can be popped (or the app can
  /// navigate elsewhere) while a write is still on the wire.
  ///
  /// Task 7 lands the read-only half: fields, the hex viewer, delete.
  /// [replaceChunk] is Task 8's extension point — it only ever touches the
  /// in-memory working copy, so the read-only screen this task builds already
  /// works unmodified once Task 8 starts calling it from an editable hex
  /// viewer.

  CardEditorProvider call(String id) =>
      CardEditorProvider._(argument: id, from: this);

  @override
  String toString() => r'cardEditorProvider';
}

/// The detail screen's state, one notifier per card id, so a failure on one
/// card does not grey out another (the `SlotEditor` shape).
///
/// A call made while another write is in flight is dropped, not queued; the
/// screen disables its controls while `state.isLoading`. Every assignment to
/// [state] after an `await` is guarded with `ref.mounted` (Phase 6 ruling 2):
/// the detail screen is a pushed sub-route and can be popped (or the app can
/// navigate elsewhere) while a write is still on the wire.
///
/// Task 7 lands the read-only half: fields, the hex viewer, delete.
/// [replaceChunk] is Task 8's extension point — it only ever touches the
/// in-memory working copy, so the read-only screen this task builds already
/// works unmodified once Task 8 starts calling it from an editable hex
/// viewer.

abstract class _$CardEditor extends $AsyncNotifier<CardEditState?> {
  late final _$args = ref.$arg as String;
  String get id => _$args;

  FutureOr<CardEditState?> build(String id);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<CardEditState?>, CardEditState?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<CardEditState?>, CardEditState?>,
              AsyncValue<CardEditState?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
