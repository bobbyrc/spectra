import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/app.dart';
import 'package:spectra/l10n/app_localizations_en.dart';

void main() {
  test('the generated localizations carry the app title', () {
    expect(AppLocalizationsEn().appTitle, 'Spectra');
  });

  testWidgets('the root boots inside a ProviderScope', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SpectraRoot()));
    await tester.pump();
    expect(find.byType(SpectraRoot), findsOneWidget);
  });
}
