// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'slot_views_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The eight slots, ready to render. Empty while nothing is connected —
/// `slotsProvider` yields `const []` in that case, so no screen has to
/// special-case "no session" a second time.
///
/// `.value` (never `valueOrNull`, which riverpod 3 does not have) because a
/// stream provider's first frame is `AsyncLoading` and an empty grid is the
/// right thing to show for that one frame.

@ProviderFor(slotViews)
final slotViewsProvider = SlotViewsProvider._();

/// The eight slots, ready to render. Empty while nothing is connected —
/// `slotsProvider` yields `const []` in that case, so no screen has to
/// special-case "no session" a second time.
///
/// `.value` (never `valueOrNull`, which riverpod 3 does not have) because a
/// stream provider's first frame is `AsyncLoading` and an empty grid is the
/// right thing to show for that one frame.

final class SlotViewsProvider
    extends $FunctionalProvider<List<SlotView>, List<SlotView>, List<SlotView>>
    with $Provider<List<SlotView>> {
  /// The eight slots, ready to render. Empty while nothing is connected —
  /// `slotsProvider` yields `const []` in that case, so no screen has to
  /// special-case "no session" a second time.
  ///
  /// `.value` (never `valueOrNull`, which riverpod 3 does not have) because a
  /// stream provider's first frame is `AsyncLoading` and an empty grid is the
  /// right thing to show for that one frame.
  SlotViewsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'slotViewsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$slotViewsHash();

  @$internal
  @override
  $ProviderElement<List<SlotView>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<SlotView> create(Ref ref) {
    return slotViews(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<SlotView> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<SlotView>>(value),
    );
  }
}

String _$slotViewsHash() => r'6ad22fed0de9a8dba71fc305651d593455098b92';
