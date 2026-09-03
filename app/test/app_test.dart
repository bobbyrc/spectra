import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/l10n/app_localizations_en.dart';

import 'support/app_harness.dart';

void main() {
  test('the generated localizations carry the app title', () {
    expect(AppLocalizationsEn().appTitle, 'Spectra');
  });

  testWidgets('the root boots inside a ProviderScope', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pump();
    expect(find.text('Connect a device'), findsOneWidget);
  });
}
