import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spectra/features/dictionaries/dictionaries.dart';
import 'package:spectra_ui/spectra_ui.dart';

import '../../support/app_harness.dart';

Future<void> _openRead(WidgetTester tester) async {
  useDesktopSurface(tester);
  await pumpTestApp(tester);
  await connectToEmulator(tester);
  await tester.tap(find.text('Cards').last);
  await pumpFrames(tester);
  await tester.tap(find.text('Read a card'));
  await pumpFrames(tester);
}

void main() {
  testWidgetsApp('the read screen names the key list it will try', (
    tester,
  ) async {
    await _openRead(tester);
    expect(find.text('Keys: Default keys'), findsOneWidget);
  });

  testWidgetsApp('the picker changes the selection', (tester) async {
    await _openRead(tester);

    // Only the built-in list exists, so choosing it is the whole round
    // trip: sheet opens, tap resolves, selection is unchanged and valid.
    await tester.tap(find.text('Change'));
    await pumpFrames(tester);
    expect(find.byType(SpectraBottomSheet), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Default keys'),
      ),
    );
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    expect(find.byType(SpectraBottomSheet), findsNothing);
    expect(
      readProvider(tester, selectedDictionaryProvider).value!.name,
      '',
      reason: 'the built-in list stores no name; its label is localized',
    );
  });

  testWidgetsApp('an unselectable list is listed but not tappable', (
    tester,
  ) async {
    useDesktopSurface(tester);
    await pumpTestApp(tester);
    await connectToEmulator(tester);

    // Drive the picker directly: the read screen never filters, but the
    // contract other features rely on is that it can.
    final BuildContext context = tester.element(find.byType(SpectraAppShell));
    final Future<Object?> pending = showDictionaryPicker(
      context,
      isSelectable: (_) => false,
    );
    await pumpFrames(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Default keys'),
      ),
    );
    await pumpFrames(tester);

    expect(find.byType(SpectraBottomSheet), findsOneWidget);
    Navigator.of(context).pop();
    await pumpFrames(tester);
    expect(await pending, isNull);
  });
}
