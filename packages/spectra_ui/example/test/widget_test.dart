import 'package:flutter_test/flutter_test.dart';
import 'package:spectra_ui_gallery/main.dart';

void main() {
  testWidgets('renders the placeholder', (tester) async {
    await tester.pumpWidget(const SpectraUiGalleryApp());
    expect(find.text('Spectra UI gallery'), findsOneWidget);
  });
}
