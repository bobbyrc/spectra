import 'dart:typed_data';

import 'package:chameleon/chameleon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:spectra/app.dart';
import 'package:spectra/core/errors/problem_view.dart';
import 'package:spectra/core/routing/routes.dart';
import 'package:spectra/data/data.dart';
import 'package:spectra/data/memory/in_memory_repositories.dart';
import 'package:spectra/features/cards/state/saved_cards_provider.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

/// Delegates everything but [watchAll], which fails while [broken] — for
/// exercising the library screens' error path (R32) and the retry that
/// re-subscribes. A count would be flaky: the screen's autoDispose stream
/// provider is built more than once as the shell settles.
final class _BrokenStreamRepository implements SavedCardsRepository {
  _BrokenStreamRepository(this._delegate);
  final SavedCardsRepository _delegate;
  bool broken = true;

  @override
  Future<List<SavedCard>> all() => _delegate.all();

  @override
  Future<SavedCard?> byId(String id) => _delegate.byId(id);

  @override
  Future<void> save(SavedCard card) => _delegate.save(card);

  @override
  Future<void> delete(String id) => _delegate.delete(id);

  @override
  Stream<List<SavedCard>> watchAll() => broken
      ? Stream<List<SavedCard>>.error(const SessionNotReady('boom'))
      : _delegate.watchAll();
}

Future<CardLibrary> openLibrary(
  WidgetTester tester, {
  List<Override> extraOverrides = const <Override>[],
}) async {
  useDesktopSurface(tester);
  if (extraOverrides.isEmpty) {
    await pumpTestApp(tester, transport: (_) => FakeDevice());
  } else {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ...appOverrides(transport: (_) => FakeDevice()),
          ...extraOverrides,
        ],
        child: const SpectraRoot(),
      ),
    );
  }
  await connectToEmulator(tester);
  keepAlive(tester, cardLibraryProvider);
  await tester.tap(find.text('Cards').last);
  await pumpFrames(tester);
  return readProvider(tester, cardLibraryProvider.notifier);
}

Future<void> seed(WidgetTester tester, CardLibrary library) async {
  for (final (String name, String? folder) in <(String, String?)>[
    ('Office badge', 'Work'),
    ('Gym', 'Personal'),
    ('Hotel key', null),
  ]) {
    final Future<String?> pending = library.add(
      name: name,
      type: TagType.mifare1k,
      bytes: Uint8List(64 * 16),
      folder: folder,
    );
    await tester.pump(const Duration(milliseconds: 20));
    await pending;
  }
  await pumpFrames(tester);
}

void main() {
  testWidgetsApp('a broken library stream shows the problem, not "no cards"', (
    tester,
  ) async {
    final _BrokenStreamRepository repo = _BrokenStreamRepository(
      InMemorySavedCardsRepository(),
    );
    await openLibrary(
      tester,
      extraOverrides: <Override>[
        savedCardsRepositoryProvider.overrideWithValue(repo),
      ],
    );
    expect(find.byType(ProblemView), findsOneWidget);
    expect(
      find.text('No cards yet. Read one, or import from another app.'),
      findsNothing,
    );
  });

  testWidgetsApp('the library error offers a retry that re-reads', (
    tester,
  ) async {
    final InMemorySavedCardsRepository inner = InMemorySavedCardsRepository();
    await inner.save(
      SavedCard(
        id: 'a',
        name: 'Office badge',
        tagType: 'mifare1k',
        bytes: Uint8List(64 * 16),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    final _BrokenStreamRepository repo = _BrokenStreamRepository(inner);
    await openLibrary(
      tester,
      extraOverrides: <Override>[
        savedCardsRepositoryProvider.overrideWithValue(repo),
      ],
    );
    expect(find.byType(ProblemView), findsOneWidget);

    repo.broken = false;
    await tester.tap(find.text('Try again'));
    await pumpFrames(tester);

    expect(find.byType(ProblemView), findsNothing);
    expect(find.text('Office badge'), findsOneWidget);
  });

  testWidgetsApp('an empty library says so', (tester) async {
    await openLibrary(tester);
    expect(
      find.text('No cards yet. Read one, or import from another app.'),
      findsOneWidget,
    );
  });

  testWidgetsApp('saved cards are listed and searchable', (tester) async {
    final CardLibrary library = await openLibrary(tester);
    await seed(tester, library);

    expect(find.text('Office badge'), findsOneWidget);
    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('Hotel key'), findsOneWidget);

    await tester.enterText(find.byType(SpectraTextField).first, 'gym');
    await pumpFrames(tester);
    expect(find.text('Office badge'), findsNothing);
    expect(find.text('Gym'), findsOneWidget);

    await tester.enterText(find.byType(SpectraTextField).first, 'zzz');
    await pumpFrames(tester);
    expect(find.text('No cards match that search.'), findsOneWidget);
  });

  testWidgetsApp('a folderless card has no dangling separator', (tester) async {
    final CardLibrary library = await openLibrary(tester);
    await seed(tester, library);

    expect(find.text('MIFARE Classic 1K'), findsOneWidget);
    expect(find.text('MIFARE Classic 1K · '), findsNothing);
  });

  testWidgetsApp('the folder filter narrows to the exact folder', (
    tester,
  ) async {
    final CardLibrary library = await openLibrary(tester);
    await seed(tester, library);

    await tester.tap(find.text('Work'));
    await pumpFrames(tester);
    expect(find.text('Office badge'), findsOneWidget);
    expect(find.text('Gym'), findsNothing);
    expect(find.text('Hotel key'), findsNothing);

    await tester.tap(find.text('All folders'));
    await pumpFrames(tester);
    expect(find.text('Office badge'), findsOneWidget);
    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('Hotel key'), findsOneWidget);
  });

  testWidgetsApp('sorting by name orders the rows alphabetically', (
    tester,
  ) async {
    final CardLibrary library = await openLibrary(tester);
    await seed(tester, library);

    await tester.tap(find.text('Name'));
    await pumpFrames(tester);

    final List<String> names = tester
        .widgetList<SpectraListTile>(find.byType(SpectraListTile))
        .map((SpectraListTile tile) => tile.title)
        .toList();
    expect(names, <String>['Gym', 'Hotel key', 'Office badge']);
  });

  testWidgetsApp('tapping a row navigates to the card route', (tester) async {
    final CardLibrary library = await openLibrary(tester);
    await seed(tester, library);

    final GoRouter router = GoRouter.of(tester.element(find.text('Gym')));

    await tester.tap(find.text('Gym'));
    await pumpFrames(tester);

    final String location = router.routerDelegate.currentConfiguration.uri
        .toString();
    expect(location, startsWith('${AppRoutes.cards}/'));
    expect(location, isNot(AppRoutes.cardRead));
  });

  testWidgetsApp('the read entry is still on the library screen', (
    tester,
  ) async {
    await openLibrary(tester);
    expect(find.text('Read a card'), findsOneWidget);
  });
}
