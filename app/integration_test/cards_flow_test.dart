import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import 'support.dart';

/// `test/fixtures/reference_card_mifare_mini.json`, inlined: a relative
/// `File` read resolves against the app package root under `flutter test`
/// but not under `flutter test integration_test -d macos` (the built
/// macOS app's working directory is not the package root), so the fixture
/// text is copied here rather than adding an asset bundle entry for one
/// test file.
const String _referenceCardMifareMiniJson = '''
[
  {
    "id": "3f7c1d20-0a1b-4c5d-8e9f-102030405060",
    "name": "Reference Mini",
    "uid": "DE:AD:BE:EF",
    "sak": "08",
    "atqa": "0400",
    "ats": "",
    "tag": "mifareMini",
    "color": 4284790262,
    "folder": "Imported",
    "data": [
      "DEADBEEF2208040001020304050607 08",
      "00000000000000000000000000000000",
      "00000000000000000000000000000000",
      "FFFFFFFFFFFFFF078069FFFFFFFFFFFF",
      "00000000000000000000000000000000",
      "00000000000000000000000000000000",
      "00000000000000000000000000000000",
      "FFFFFFFFFFFFFF078069FFFFFFFFFFFF",
      "00000000000000000000000000000000",
      "00000000000000000000000000000000",
      "00000000000000000000000000000000",
      "FFFFFFFFFFFFFF078069FFFFFFFFFFFF",
      "00000000000000000000000000000000",
      "00000000000000000000000000000000",
      "00000000000000000000000000000000",
      "FFFFFFFFFFFFFF078069FFFFFFFFFFFF",
      "00000000000000000000000000000000",
      "00000000000000000000000000000000",
      "00000000000000000000000000000000",
      "FFFFFFFFFFFFFF078069FFFFFFFFFFFF"
    ]
  }
]
''';

/// The Phase 6 gate on a real engine. Emulator mode only: no hardware is
/// touched, and none is needed. Reading a *real* card is hardware-validated
/// and lives in `docs/hardware-checklist.md` (H1, H3).
///
/// No `transportFactoryProvider` override (ruling 9): [testApp] with no
/// `transport` argument leaves the production `emulatorAwareTransport` in
/// place, so the emulated device's own demo cards are what gets read
/// (Task 12, ruling 25).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('scan a fake card, save it, edit it, import a fixture', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await tester.pump();

    await tester.tap(find.text(FakeScanner.emulatedUltra.name));
    await pumpFrames(tester, count: 30);
    expect(find.byType(SpectraAppShell), findsOneWidget);

    // 1. Scan. The Read screen is pushed on the Cards branch's own
    // navigator, so getting back to the library later is `BackButton`, not
    // another rail tap: the shell's `onDestinationSelected` calls
    // `goBranch(index, initialLocation: false)`, a no-op while already on
    // that branch's index.
    await tester.tap(find.text('Cards').last);
    await pumpFrames(tester);
    await tester.tap(find.text('Read a card'));
    await pumpFrames(tester);
    await tester.tap(find.text('Scan high frequency'));
    await pumpFrames(tester, count: 60);
    expect(find.text('DEADBEEF'), findsOneWidget);

    // 2. Save.
    await tester.tap(find.text('Save to library'));
    await pumpFrames(tester);
    await tester.enterText(
      find
          .descendant(
            of: find.byType(SpectraBottomSheet),
            matching: find.byType(SpectraTextField),
          )
          .first,
      'Gate card',
    );
    await pumpFrames(tester, count: 5);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Save'),
      ),
    );
    await pumpFrames(tester, count: 30);

    // 3. Edit: back to the library, open the saved card, change block 1.
    await tester.tap(find.byType(BackButton));
    await pumpFrames(tester);
    await tester.tap(find.text('Gate card'));
    await pumpFrames(tester);
    await tester.enterText(find.byKey(const Key('cardEditIndex')), '1');
    await tester.enterText(
      find.byKey(const Key('cardEditValue')),
      '000102030405060708090A0B0C0D0E0F',
    );
    await pumpFrames(tester, count: 5);
    await tester.ensureVisible(find.text('Apply'));
    await pumpFrames(tester);
    await tester.tap(find.text('Apply'));
    await pumpFrames(tester);
    await tester.ensureVisible(find.text('Save changes'));
    await pumpFrames(tester);
    await tester.tap(find.text('Save changes'));
    await pumpFrames(tester, count: 30);

    // 4. Import the reference-app fixture: back to the library, then Import.
    await tester.tap(find.byType(BackButton));
    await pumpFrames(tester);
    await tester.tap(find.text('Import'));
    await pumpFrames(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.byType(SpectraTextField),
      ),
      _referenceCardMifareMiniJson,
    );
    await pumpFrames(tester, count: 5);
    await tester.tap(
      find.descendant(
        of: find.byType(SpectraBottomSheet),
        matching: find.text('Import'),
      ),
    );
    await pumpFrames(tester, count: 30);

    expect(find.text('Reference Mini'), findsOneWidget);
    expect(find.text('Gate card'), findsOneWidget);
  });
}
