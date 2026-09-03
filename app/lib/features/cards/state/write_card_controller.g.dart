// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'write_card_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Spec 7.7 step 5: write a saved dump back onto a physical card.
///
/// Only the two families the SDK's `ReaderFacade` can write are offered —
/// MIFARE Classic block by block (`mf1WriteDump`), and an EM410x id onto a
/// T55xx blank (`em410xWriteToT55xx`). Everything else is
/// [CardWriteState.unsupported]: a typed state the sheet renders as a
/// sentence, never a silent no-op and never a guess at some other encoding.
/// Ultralight has no reader write in spec 8.1's `ReaderFacade` at all
/// (`write_target.dart`'s `CardWriteMethod` doc), so it lands here too.
///
/// [write]'s `writeTrailers` defaults to false, matching
/// `ReaderFacade.mf1WriteDump`: a saved dump's sector trailers only go onto
/// the card when the caller explicitly opts in, and a *read* dump carries
/// key A zeroed out in every trailer, so writing trailers from one straight
/// back overwrites the card's real key A with zeros (the same footgun the
/// facade's own doc comment carries). The sheet's copy is the one place
/// that warns about it before the opt-in is even offered (Task 9).
///
/// A dump with all-zero sector trailers *and* `writeTrailers: true` is
/// refused before any command is sent, as [CardWriteState.unreadSectors]
/// (ruling 23), until a second call passes `confirmUnread: true`.
///
/// A device that bails the whole dump early — `InvalidCommand` when
/// MF1_WRITE_ONE_BLOCK is missing from the device's advertised
/// capabilities (a Lite has no 2009) — is not special-cased: `InvalidCommand`
/// already has its own words in `ErrorCatalog` (`errorInvalidCommand`), so
/// landing it in [CardWriteState.error] is exactly the typed state ruling 25
/// asks for, not the generic "something unexpected went wrong" fallback.
///
/// **`hardware-validate` (checklist H3): nothing here is proven on a real
/// card.** `FakeDevice` accepts every write and hands the bytes straight
/// back, which proves the app's sequencing and nothing about a card whose
/// access bits refuse a key or a blank that will not take a password. The
/// sheet says so on screen for as long as that stays true.
///
/// No wakelock code: `mf1WriteDump` runs the whole write inside one reader
/// lease and one `DeviceSession.busy`, which is exactly what
/// `sessionNeedsWakelock` (`core/lifecycle/wakelock.dart`) polls.
///
/// Drop, do not queue (`_inFlight`); the sheet disables its button while
/// `state.busy`. Every post-`await` assignment is guarded with `ref.mounted`
/// (R25) — the device write still runs to completion, there is simply no
/// longer anywhere to report it.

@ProviderFor(CardWriter)
final cardWriterProvider = CardWriterProvider._();

/// Spec 7.7 step 5: write a saved dump back onto a physical card.
///
/// Only the two families the SDK's `ReaderFacade` can write are offered —
/// MIFARE Classic block by block (`mf1WriteDump`), and an EM410x id onto a
/// T55xx blank (`em410xWriteToT55xx`). Everything else is
/// [CardWriteState.unsupported]: a typed state the sheet renders as a
/// sentence, never a silent no-op and never a guess at some other encoding.
/// Ultralight has no reader write in spec 8.1's `ReaderFacade` at all
/// (`write_target.dart`'s `CardWriteMethod` doc), so it lands here too.
///
/// [write]'s `writeTrailers` defaults to false, matching
/// `ReaderFacade.mf1WriteDump`: a saved dump's sector trailers only go onto
/// the card when the caller explicitly opts in, and a *read* dump carries
/// key A zeroed out in every trailer, so writing trailers from one straight
/// back overwrites the card's real key A with zeros (the same footgun the
/// facade's own doc comment carries). The sheet's copy is the one place
/// that warns about it before the opt-in is even offered (Task 9).
///
/// A dump with all-zero sector trailers *and* `writeTrailers: true` is
/// refused before any command is sent, as [CardWriteState.unreadSectors]
/// (ruling 23), until a second call passes `confirmUnread: true`.
///
/// A device that bails the whole dump early — `InvalidCommand` when
/// MF1_WRITE_ONE_BLOCK is missing from the device's advertised
/// capabilities (a Lite has no 2009) — is not special-cased: `InvalidCommand`
/// already has its own words in `ErrorCatalog` (`errorInvalidCommand`), so
/// landing it in [CardWriteState.error] is exactly the typed state ruling 25
/// asks for, not the generic "something unexpected went wrong" fallback.
///
/// **`hardware-validate` (checklist H3): nothing here is proven on a real
/// card.** `FakeDevice` accepts every write and hands the bytes straight
/// back, which proves the app's sequencing and nothing about a card whose
/// access bits refuse a key or a blank that will not take a password. The
/// sheet says so on screen for as long as that stays true.
///
/// No wakelock code: `mf1WriteDump` runs the whole write inside one reader
/// lease and one `DeviceSession.busy`, which is exactly what
/// `sessionNeedsWakelock` (`core/lifecycle/wakelock.dart`) polls.
///
/// Drop, do not queue (`_inFlight`); the sheet disables its button while
/// `state.busy`. Every post-`await` assignment is guarded with `ref.mounted`
/// (R25) — the device write still runs to completion, there is simply no
/// longer anywhere to report it.
final class CardWriterProvider
    extends $NotifierProvider<CardWriter, CardWriteState> {
  /// Spec 7.7 step 5: write a saved dump back onto a physical card.
  ///
  /// Only the two families the SDK's `ReaderFacade` can write are offered —
  /// MIFARE Classic block by block (`mf1WriteDump`), and an EM410x id onto a
  /// T55xx blank (`em410xWriteToT55xx`). Everything else is
  /// [CardWriteState.unsupported]: a typed state the sheet renders as a
  /// sentence, never a silent no-op and never a guess at some other encoding.
  /// Ultralight has no reader write in spec 8.1's `ReaderFacade` at all
  /// (`write_target.dart`'s `CardWriteMethod` doc), so it lands here too.
  ///
  /// [write]'s `writeTrailers` defaults to false, matching
  /// `ReaderFacade.mf1WriteDump`: a saved dump's sector trailers only go onto
  /// the card when the caller explicitly opts in, and a *read* dump carries
  /// key A zeroed out in every trailer, so writing trailers from one straight
  /// back overwrites the card's real key A with zeros (the same footgun the
  /// facade's own doc comment carries). The sheet's copy is the one place
  /// that warns about it before the opt-in is even offered (Task 9).
  ///
  /// A dump with all-zero sector trailers *and* `writeTrailers: true` is
  /// refused before any command is sent, as [CardWriteState.unreadSectors]
  /// (ruling 23), until a second call passes `confirmUnread: true`.
  ///
  /// A device that bails the whole dump early — `InvalidCommand` when
  /// MF1_WRITE_ONE_BLOCK is missing from the device's advertised
  /// capabilities (a Lite has no 2009) — is not special-cased: `InvalidCommand`
  /// already has its own words in `ErrorCatalog` (`errorInvalidCommand`), so
  /// landing it in [CardWriteState.error] is exactly the typed state ruling 25
  /// asks for, not the generic "something unexpected went wrong" fallback.
  ///
  /// **`hardware-validate` (checklist H3): nothing here is proven on a real
  /// card.** `FakeDevice` accepts every write and hands the bytes straight
  /// back, which proves the app's sequencing and nothing about a card whose
  /// access bits refuse a key or a blank that will not take a password. The
  /// sheet says so on screen for as long as that stays true.
  ///
  /// No wakelock code: `mf1WriteDump` runs the whole write inside one reader
  /// lease and one `DeviceSession.busy`, which is exactly what
  /// `sessionNeedsWakelock` (`core/lifecycle/wakelock.dart`) polls.
  ///
  /// Drop, do not queue (`_inFlight`); the sheet disables its button while
  /// `state.busy`. Every post-`await` assignment is guarded with `ref.mounted`
  /// (R25) — the device write still runs to completion, there is simply no
  /// longer anywhere to report it.
  CardWriterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cardWriterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cardWriterHash();

  @$internal
  @override
  CardWriter create() => CardWriter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CardWriteState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CardWriteState>(value),
    );
  }
}

String _$cardWriterHash() => r'2cab9a74c6a828ed48b73b14ae00385556d0a9c3';

/// Spec 7.7 step 5: write a saved dump back onto a physical card.
///
/// Only the two families the SDK's `ReaderFacade` can write are offered —
/// MIFARE Classic block by block (`mf1WriteDump`), and an EM410x id onto a
/// T55xx blank (`em410xWriteToT55xx`). Everything else is
/// [CardWriteState.unsupported]: a typed state the sheet renders as a
/// sentence, never a silent no-op and never a guess at some other encoding.
/// Ultralight has no reader write in spec 8.1's `ReaderFacade` at all
/// (`write_target.dart`'s `CardWriteMethod` doc), so it lands here too.
///
/// [write]'s `writeTrailers` defaults to false, matching
/// `ReaderFacade.mf1WriteDump`: a saved dump's sector trailers only go onto
/// the card when the caller explicitly opts in, and a *read* dump carries
/// key A zeroed out in every trailer, so writing trailers from one straight
/// back overwrites the card's real key A with zeros (the same footgun the
/// facade's own doc comment carries). The sheet's copy is the one place
/// that warns about it before the opt-in is even offered (Task 9).
///
/// A dump with all-zero sector trailers *and* `writeTrailers: true` is
/// refused before any command is sent, as [CardWriteState.unreadSectors]
/// (ruling 23), until a second call passes `confirmUnread: true`.
///
/// A device that bails the whole dump early — `InvalidCommand` when
/// MF1_WRITE_ONE_BLOCK is missing from the device's advertised
/// capabilities (a Lite has no 2009) — is not special-cased: `InvalidCommand`
/// already has its own words in `ErrorCatalog` (`errorInvalidCommand`), so
/// landing it in [CardWriteState.error] is exactly the typed state ruling 25
/// asks for, not the generic "something unexpected went wrong" fallback.
///
/// **`hardware-validate` (checklist H3): nothing here is proven on a real
/// card.** `FakeDevice` accepts every write and hands the bytes straight
/// back, which proves the app's sequencing and nothing about a card whose
/// access bits refuse a key or a blank that will not take a password. The
/// sheet says so on screen for as long as that stays true.
///
/// No wakelock code: `mf1WriteDump` runs the whole write inside one reader
/// lease and one `DeviceSession.busy`, which is exactly what
/// `sessionNeedsWakelock` (`core/lifecycle/wakelock.dart`) polls.
///
/// Drop, do not queue (`_inFlight`); the sheet disables its button while
/// `state.busy`. Every post-`await` assignment is guarded with `ref.mounted`
/// (R25) — the device write still runs to completion, there is simply no
/// longer anywhere to report it.

abstract class _$CardWriter extends $Notifier<CardWriteState> {
  CardWriteState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CardWriteState, CardWriteState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CardWriteState, CardWriteState>,
              CardWriteState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
