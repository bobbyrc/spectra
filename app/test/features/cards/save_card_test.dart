import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/features/cards/state/saved_cards_provider.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

FakeDevice deviceWithCard() {
  final FakeFirmware firmware = FakeFirmware()
    ..present(
      FakeMf1Card.classic1k(
        uid: Uint8List.fromList(<int>[0xDE, 0xAD, 0xBE, 0xEF]),
      ),
    );
  return FakeDevice(firmware: firmware);
}

void main() {
  testWidgetsApp('the library notifier writes a card through the repository', (
    tester,
  ) async {
    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await connectToEmulator(tester);
    keepAlive(tester, cardLibraryProvider);
    final CardLibrary library = readProvider(
      tester,
      cardLibraryProvider.notifier,
    );

    final Future<String?> pending = library.add(
      name: 'Office badge',
      type: TagType.mifare1k,
      bytes: Uint8List(64 * 16),
      folder: 'Work',
      color: cardColors.first,
    );
    await tester.pump(const Duration(milliseconds: 50));
    final String? id = await pending;
    expect(id, isNotNull);

    final SavedCardsRepository repo = readProvider(
      tester,
      savedCardsRepositoryProvider,
    );
    final SavedCard? saved = await repo.byId(id!);
    expect(saved!.name, 'Office badge');
    expect(saved.tagType, 'mifare1k');
    expect(saved.folder, 'Work');
    expect(saved.bytes, hasLength(64 * 16));
  });

  testWidgetsApp('reading a card and saving it puts it in the library', (
    tester,
  ) async {
    useDesktopSurface(tester);

    await pumpTestApp(tester, transport: (_) => deviceWithCard());
    await connectToEmulator(tester);
    await tester.tap(find.text('Cards').last);
    await pumpFrames(tester, count: 10);
    await tester.tap(find.text('Read a card'));
    await pumpFrames(tester, count: 10);
    await tester.tap(find.text('Scan high frequency'));
    await pumpFrames(tester, count: 40);

    await tester.tap(find.text('Save to library'));
    await pumpFrames(tester, count: 10);
    expect(find.text('Save this card'), findsOneWidget);

    await tester.enterText(
      find
          .descendant(
            of: find.byType(SpectraBottomSheet),
            matching: find.byType(SpectraTextField),
          )
          .first,
      'Office badge',
    );
    await pumpFrames(tester, count: 5);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Save'),
      ),
    );
    await pumpFrames(tester, count: 20);

    keepAlive(tester, savedCardsProvider);
    await pumpFrames(tester, count: 5);
    final List<SavedCard> cards =
        readProvider(tester, savedCardsProvider).value ?? const <SavedCard>[];
    expect(cards, hasLength(1));
    expect(cards.single.name, 'Office badge');
    expect(cards.single.tagType, 'mifare1k');
  });

  testWidgetsApp('an empty name is refused before anything is written', (
    tester,
  ) async {
    useDesktopSurface(tester);

    await pumpTestApp(tester, transport: (_) => deviceWithCard());
    await connectToEmulator(tester);
    await tester.tap(find.text('Cards').last);
    await pumpFrames(tester, count: 10);
    await tester.tap(find.text('Read a card'));
    await pumpFrames(tester, count: 10);
    await tester.tap(find.text('Scan high frequency'));
    await pumpFrames(tester, count: 40);
    await tester.tap(find.text('Save to library'));
    await pumpFrames(tester, count: 10);

    await tester.enterText(
      find
          .descendant(
            of: find.byType(SpectraBottomSheet),
            matching: find.byType(SpectraTextField),
          )
          .first,
      '   ',
    );
    await pumpFrames(tester, count: 5);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Save'),
      ),
    );
    await pumpFrames(tester, count: 10);

    expect(find.text('Give the card a name.'), findsOneWidget);
    expect(find.text('Save this card'), findsOneWidget, reason: 'still open');
  });

  testWidgetsApp('a write failure renders through the catalog', (tester) async {
    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await connectToEmulator(tester);
    keepAlive(tester, cardLibraryProvider);
    final CardLibrary library = readProvider(
      tester,
      cardLibraryProvider.notifier,
    );
    // Let `build()` settle to AsyncData first, so debugFail's AsyncError is
    // not clobbered by the build future resolving afterwards.
    await pumpFrames(tester, count: 2);

    library.debugFail(const SessionNotReady('boom'));
    await pumpFrames(tester, count: 2);

    final AsyncValue<void> state = readProvider(tester, cardLibraryProvider);
    expect(state.hasError, isTrue);
  });

  testWidgetsApp('a dispose mid-save does not crash', (tester) async {
    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await connectToEmulator(tester);
    final ProviderSubscription<AsyncValue<void>> sub = keepAlive(
      tester,
      cardLibraryProvider,
    );
    final CardLibrary library = readProvider(
      tester,
      cardLibraryProvider.notifier,
    );

    final Future<String?> pending = library.add(
      name: 'Disposed mid-save',
      type: TagType.mifare1k,
      bytes: Uint8List(64 * 16),
    );
    // Dispose the notifier while the write is still on the wire.
    sub.close();
    await pumpFrames(tester, count: 5);

    // The write itself must not throw even though nothing is left to
    // report its outcome to.
    await pending;
  });
}
