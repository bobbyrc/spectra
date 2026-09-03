// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'read_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Spec 7.7 step 3: read a card through `session.reader`.
///
/// Every `ReaderFacade` method takes its own reader lease, so the device is
/// in reader mode for exactly as long as the operation runs and back in
/// emulator mode afterwards, including when it throws (spec 4.3). That lease
/// is also what holds the wakelock: `sessionNeedsWakelock`
/// (`core/lifecycle/wakelock.dart`) polls `readerLeaseCount > 0 || isBusy`,
/// and `mf1ReadDump` wraps the whole dump in one lease and one `busy`. There
/// is therefore no wakelock code here, and there must not be.
///
/// Failures stay in [ReadState.error] rather than being thrown, so the screen
/// renders them through the spec 9 catalog instead of catching. "No tag in
/// the field" is the facade's empty result, which this turns into the typed
/// [HfTagNotFound]/[LfTagNotFound] the catalog already has words for.
///
/// A call made while another is in flight is dropped, not queued (`_inFlight`);
/// the screen disables its buttons while `state.busy`. This notifier is
/// autoDispose: the Read screen's Back button can tear it down while a read
/// is still on the wire, so every assignment to [state] after an `await` is
/// guarded with `ref.mounted` (Phase 6 ruling 2) — the device read itself
/// still runs to completion, there is simply no longer anywhere to report
/// it.

@ProviderFor(CardReader)
final cardReaderProvider = CardReaderProvider._();

/// Spec 7.7 step 3: read a card through `session.reader`.
///
/// Every `ReaderFacade` method takes its own reader lease, so the device is
/// in reader mode for exactly as long as the operation runs and back in
/// emulator mode afterwards, including when it throws (spec 4.3). That lease
/// is also what holds the wakelock: `sessionNeedsWakelock`
/// (`core/lifecycle/wakelock.dart`) polls `readerLeaseCount > 0 || isBusy`,
/// and `mf1ReadDump` wraps the whole dump in one lease and one `busy`. There
/// is therefore no wakelock code here, and there must not be.
///
/// Failures stay in [ReadState.error] rather than being thrown, so the screen
/// renders them through the spec 9 catalog instead of catching. "No tag in
/// the field" is the facade's empty result, which this turns into the typed
/// [HfTagNotFound]/[LfTagNotFound] the catalog already has words for.
///
/// A call made while another is in flight is dropped, not queued (`_inFlight`);
/// the screen disables its buttons while `state.busy`. This notifier is
/// autoDispose: the Read screen's Back button can tear it down while a read
/// is still on the wire, so every assignment to [state] after an `await` is
/// guarded with `ref.mounted` (Phase 6 ruling 2) — the device read itself
/// still runs to completion, there is simply no longer anywhere to report
/// it.
final class CardReaderProvider
    extends $NotifierProvider<CardReader, ReadState> {
  /// Spec 7.7 step 3: read a card through `session.reader`.
  ///
  /// Every `ReaderFacade` method takes its own reader lease, so the device is
  /// in reader mode for exactly as long as the operation runs and back in
  /// emulator mode afterwards, including when it throws (spec 4.3). That lease
  /// is also what holds the wakelock: `sessionNeedsWakelock`
  /// (`core/lifecycle/wakelock.dart`) polls `readerLeaseCount > 0 || isBusy`,
  /// and `mf1ReadDump` wraps the whole dump in one lease and one `busy`. There
  /// is therefore no wakelock code here, and there must not be.
  ///
  /// Failures stay in [ReadState.error] rather than being thrown, so the screen
  /// renders them through the spec 9 catalog instead of catching. "No tag in
  /// the field" is the facade's empty result, which this turns into the typed
  /// [HfTagNotFound]/[LfTagNotFound] the catalog already has words for.
  ///
  /// A call made while another is in flight is dropped, not queued (`_inFlight`);
  /// the screen disables its buttons while `state.busy`. This notifier is
  /// autoDispose: the Read screen's Back button can tear it down while a read
  /// is still on the wire, so every assignment to [state] after an `await` is
  /// guarded with `ref.mounted` (Phase 6 ruling 2) — the device read itself
  /// still runs to completion, there is simply no longer anywhere to report
  /// it.
  CardReaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cardReaderProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cardReaderHash();

  @$internal
  @override
  CardReader create() => CardReader();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReadState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReadState>(value),
    );
  }
}

String _$cardReaderHash() => r'5b15ef8e71ec194d35b5d335f1a699211d9d475d';

/// Spec 7.7 step 3: read a card through `session.reader`.
///
/// Every `ReaderFacade` method takes its own reader lease, so the device is
/// in reader mode for exactly as long as the operation runs and back in
/// emulator mode afterwards, including when it throws (spec 4.3). That lease
/// is also what holds the wakelock: `sessionNeedsWakelock`
/// (`core/lifecycle/wakelock.dart`) polls `readerLeaseCount > 0 || isBusy`,
/// and `mf1ReadDump` wraps the whole dump in one lease and one `busy`. There
/// is therefore no wakelock code here, and there must not be.
///
/// Failures stay in [ReadState.error] rather than being thrown, so the screen
/// renders them through the spec 9 catalog instead of catching. "No tag in
/// the field" is the facade's empty result, which this turns into the typed
/// [HfTagNotFound]/[LfTagNotFound] the catalog already has words for.
///
/// A call made while another is in flight is dropped, not queued (`_inFlight`);
/// the screen disables its buttons while `state.busy`. This notifier is
/// autoDispose: the Read screen's Back button can tear it down while a read
/// is still on the wire, so every assignment to [state] after an `await` is
/// guarded with `ref.mounted` (Phase 6 ruling 2) — the device read itself
/// still runs to completion, there is simply no longer anywhere to report
/// it.

abstract class _$CardReader extends $Notifier<ReadState> {
  ReadState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ReadState, ReadState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ReadState, ReadState>,
              ReadState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
