import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui/spectra_ui.dart';
import 'package:spectra_ui_gallery/gallery_app.dart';
import 'package:spectra_ui_gallery/gallery_entry.dart';
import 'package:spectra_ui_gallery/gallery_router.dart';

/// Pumps a bounded number of frames rather than `pumpAndSettle`.
///
/// The buttons and progress pages deliberately show a busy/indeterminate
/// state (spec 6.3: sample data for every component state), which is a
/// perpetually-repeating animation. `pumpAndSettle` asserts the frame
/// schedule empties out and throws otherwise, so it can never return once
/// such a page is on screen. A fixed number of frames is enough to let
/// every finite animation (for example `SpectraDisclosure`'s expand fade)
/// complete, without asserting that nothing is still animating.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('the index lists every component page', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GalleryApp());
    await _pumpFrames(tester);

    for (final GalleryEntry entry in galleryEntries) {
      expect(find.text(entry.title), findsWidgets, reason: entry.path);
    }
  });

  testWidgets('every route builds without throwing', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = buildGalleryRouter();
    await tester.pumpWidget(GalleryApp(router: router));
    await _pumpFrames(tester);

    for (final GalleryEntry entry in galleryEntries) {
      router.go(entry.path);
      await _pumpFrames(tester);
      expect(tester.takeException(), isNull, reason: entry.path);
      expect(find.byType(SpectraAppShell), findsOneWidget, reason: entry.path);
    }
  });

  testWidgets('the theme toggle switches the shell to dark', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GalleryApp());
    await _pumpFrames(tester);

    await tester.tap(find.bySemanticsLabel('Toggle dark mode'));
    await _pumpFrames(tester);

    final BuildContext context = tester.element(find.byType(SpectraAppShell));
    expect(SpectraTheme.of(context).brightness, Brightness.dark);
  });

  testWidgets('/ redirects to the first component page', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = buildGalleryRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(SpectraApp(routerConfig: router));
    await _pumpFrames(tester);

    router.go('/');
    await _pumpFrames(tester);

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      galleryEntries.first.path,
    );
  });
}
