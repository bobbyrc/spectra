import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/main.dart';

void main() {
  testWidgets('renders the placeholder', (tester) async {
    await tester.pumpWidget(const SpectraApp());
    expect(find.text('Spectra'), findsOneWidget);
  });
}
