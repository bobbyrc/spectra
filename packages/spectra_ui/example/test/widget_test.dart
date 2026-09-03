import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra_ui_gallery/main.dart';

void main() {
  testWidgets('navigates between the two routes and themes the components', (
    tester,
  ) async {
    await tester.pumpWidget(SpectraUiGalleryApp(router: buildGalleryRouter()));
    await tester.pumpAndSettle();

    expect(find.text('Spectra UI gallery'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // The material_ui components resolve the material_ui ThemeData supplied by
    // MaterialApp.router, not a fallback theme.
    final theme = Theme.of(tester.element(find.byType(ElevatedButton)));
    expect(
      theme.colorScheme.primary,
      galleryTheme(Brightness.light).colorScheme.primary,
    );

    await tester.tap(find.text('Go to details'));
    await tester.pumpAndSettle();

    expect(find.text('Details'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.text('Back to gallery'));
    await tester.pumpAndSettle();

    expect(find.text('Spectra UI gallery'), findsOneWidget);
  });
}
