import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:spectra_ui/spectra_ui.dart';

import '../support/app_harness.dart';

/// The roadmap's Phase 5 gate: edit and save a slot on the emulator.
/// `testWidgetsApp` (not plain `testWidgets`) so the app root's
/// stream-backed `ConnectPage` settles cleanly on teardown — see its own
/// doc comment.
void main() {
  testWidgetsApp('rename a slot, set its type, make it active', (tester) async {
    useDesktopSurface(tester);

    await pumpTestApp(tester, transport: (_) => FakeDevice());
    await tester.pump();
    await connectToEmulator(tester);
    await openSlots(tester);

    expect(find.byType(SpectraSlotTile), findsNWidgets(8));
    await openSlot(tester, 3);

    // Name it.
    await tester.enterText(find.byType(SpectraTextField).first, 'Front door');
    await tester.pump();
    await tester.tap(find.text('Save name').first);
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    // Give it a tag type.
    await tester.tap(find.text('Change type').first);
    await pumpFrames(tester);
    await tester.tap(find.text('NTAG215'));
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));

    // Emulate it.
    await tester.tap(find.text('Make active'));
    await pumpFrames(tester, count: 20, step: const Duration(milliseconds: 50));
    expect(find.text('Make active'), findsNothing);

    // Back on the grid, all three changes are visible.
    await tester.tap(find.byType(BackButton));
    await pumpFrames(tester);
    final SpectraSlotTile third = tester.widget<SpectraSlotTile>(
      find.byType(SpectraSlotTile).at(2),
    );
    expect(third.nickname, 'Front door');
    expect(third.tagTypes, contains('NTAG215'));
    expect(third.active, isTrue);
  });
}
