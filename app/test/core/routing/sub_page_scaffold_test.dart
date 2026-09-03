import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra/core/routing/sub_page_scaffold.dart';

void main() {
  testWidgets('it shows a title and a back button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SubPageScaffold(title: 'Slot 3', body: Text('body')),
      ),
    );
    expect(find.text('Slot 3'), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });
}
