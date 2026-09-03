import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/app.dart';

void main() {
  testWidgets('the app boots', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SpectraRoot()));
    await tester.pump();
    expect(find.text('Spectra'), findsOneWidget);
  });
}
