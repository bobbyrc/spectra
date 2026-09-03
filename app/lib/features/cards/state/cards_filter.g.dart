// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cards_filter.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CardsFilterState)
final cardsFilterStateProvider = CardsFilterStateProvider._();

final class CardsFilterStateProvider
    extends $NotifierProvider<CardsFilterState, CardsFilter> {
  CardsFilterStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cardsFilterStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cardsFilterStateHash();

  @$internal
  @override
  CardsFilterState create() => CardsFilterState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CardsFilter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CardsFilter>(value),
    );
  }
}

String _$cardsFilterStateHash() => r'6d056ebf1cc100b6bbf6e07798e6748046ba89e8';

abstract class _$CardsFilterState extends $Notifier<CardsFilter> {
  CardsFilter build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CardsFilter, CardsFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CardsFilter, CardsFilter>,
              CardsFilter,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
