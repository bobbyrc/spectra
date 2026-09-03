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
/// screen disables its controls while [CardEditState.busy]. Every
/// assignment to [state] after an `await` is guarded with `ref.mounted`
/// (Phase 6 ruling 2): the detail screen is a pushed sub-route and can be
/// popped (or the app can navigate elsewhere) while a write is still on the
/// wire.
///
/// Task 7 landed the read-only half: fields, the hex viewer, delete. Task 8
/// wires [replaceChunk] to the editable hex viewer and calls [save]/
/// [discard] from it.

@ProviderFor(CardEditor)
final cardEditorProvider = CardEditorFamily._();

/// The detail screen's state, one notifier per card id, so a failure on one
/// card does not grey out another (the `SlotEditor` shape).
///
/// A call made while another write is in flight is dropped, not queued; the
/// screen disables its controls while [CardEditState.busy]. Every
/// assignment to [state] after an `await` is guarded with `ref.mounted`
/// (Phase 6 ruling 2): the detail screen is a pushed sub-route and can be
/// popped (or the app can navigate elsewhere) while a write is still on the
/// wire.
///
/// Task 7 landed the read-only half: fields, the hex viewer, delete. Task 8
/// wires [replaceChunk] to the editable hex viewer and calls [save]/
/// [discard] from it.
final class CardEditorProvider
    extends $AsyncNotifierProvider<CardEditor, CardEditState?> {
  /// The detail screen's state, one notifier per card id, so a failure on one
  /// card does not grey out another (the `SlotEditor` shape).
  ///
  /// A call made while another write is in flight is dropped, not queued; the
  /// screen disables its controls while [CardEditState.busy]. Every
  /// assignment to [state] after an `await` is guarded with `ref.mounted`
  /// (Phase 6 ruling 2): the detail screen is a pushed sub-route and can be
  /// popped (or the app can navigate elsewhere) while a write is still on the
  /// wire.
  ///
  /// Task 7 landed the read-only half: fields, the hex viewer, delete. Task 8
  /// wires [replaceChunk] to the editable hex viewer and calls [save]/
  /// [discard] from it.
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

String _$cardEditorHash() => r'68fa83f73c34c0b3f788a65af4a2a2ae8615f6f8';

/// The detail screen's state, one notifier per card id, so a failure on one
/// card does not grey out another (the `SlotEditor` shape).
///
/// A call made while another write is in flight is dropped, not queued; the
/// screen disables its controls while [CardEditState.busy]. Every
/// assignment to [state] after an `await` is guarded with `ref.mounted`
/// (Phase 6 ruling 2): the detail screen is a pushed sub-route and can be
/// popped (or the app can navigate elsewhere) while a write is still on the
/// wire.
///
/// Task 7 landed the read-only half: fields, the hex viewer, delete. Task 8
/// wires [replaceChunk] to the editable hex viewer and calls [save]/
/// [discard] from it.

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
  /// screen disables its controls while [CardEditState.busy]. Every
  /// assignment to [state] after an `await` is guarded with `ref.mounted`
  /// (Phase 6 ruling 2): the detail screen is a pushed sub-route and can be
  /// popped (or the app can navigate elsewhere) while a write is still on the
  /// wire.
  ///
  /// Task 7 landed the read-only half: fields, the hex viewer, delete. Task 8
  /// wires [replaceChunk] to the editable hex viewer and calls [save]/
  /// [discard] from it.

  CardEditorProvider call(String id) =>
      CardEditorProvider._(argument: id, from: this);

  @override
  String toString() => r'cardEditorProvider';
}

/// The detail screen's state, one notifier per card id, so a failure on one
/// card does not grey out another (the `SlotEditor` shape).
///
/// A call made while another write is in flight is dropped, not queued; the
/// screen disables its controls while [CardEditState.busy]. Every
/// assignment to [state] after an `await` is guarded with `ref.mounted`
/// (Phase 6 ruling 2): the detail screen is a pushed sub-route and can be
/// popped (or the app can navigate elsewhere) while a write is still on the
/// wire.
///
/// Task 7 landed the read-only half: fields, the hex viewer, delete. Task 8
/// wires [replaceChunk] to the editable hex viewer and calls [save]/
/// [discard] from it.

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
