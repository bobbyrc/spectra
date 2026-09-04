import 'package:chameleon/chameleon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectra/features/slots/state/slot_view.dart';
import 'package:spectra/features/slots/state/slot_views_provider.dart';

import '../../support/app_harness.dart';

void main() {
  testWidgetsApp('the provider reports the fake device\'s eight slots', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(transport: (_) => FakeDevice()));
    await connectToEmulator(tester);

    // `slotViewsProvider` watches `slotsProvider`, an autoDispose stream
    // provider nothing in `lib/` listens to; a bare read would see
    // `AsyncLoading` and yield `[]`. Keep it alive for the duration of this
    // test and pump a few frames so the stream's first (and only, for a
    // fake device with no further slot changes) value lands.
    keepAlive(tester, slotViewsProvider);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    final List<SlotView> views = readProvider(tester, slotViewsProvider);
    expect(views, hasLength(8));
    // FakeFirmware's constructor seeds slot 0 with a 1K + EM410x pair and
    // makes it the active slot.
    expect(views.first.isActive, isTrue);
    expect(views.first.nickname, 'Fake 1K');
    expect(views.first.presentTypes, <TagType>[
      TagType.mifare1k,
      TagType.em410x,
    ]);
    expect(views[1].isEnabled, isFalse);
  });
}
